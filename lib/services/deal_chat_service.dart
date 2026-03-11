import 'dart:async';

import 'package:aurora/models/chat/deal_proposal.dart';
import 'package:aurora/services/supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for handling deal proposals in chat conversations
class DealChatService {
  final SupabaseProvider _supabaseProvider;
  SupabaseClient get _client => _supabaseProvider.client;

  DealChatService(this._supabaseProvider);

  /// Get current user ID
  String? get currentUserId => _supabaseProvider.currentUser?.id;

  /// Check if user can propose a deal to another user
  Future<bool> _canProposeDeal(String recipientId) async {
    if (currentUserId == null) return false;

    try {
      final result = await _client.rpc(
        'can_start_conversation',
        params: {
          'from_user_id': currentUserId,
          'to_user_id': recipientId,
          'conversation_type': 'deal_negotiation',
        },
      );

      return result == true;
    } catch (e) {
      debugPrint('❌ [DealChatService] Permission check failed: $e');
      return false;
    }
  }

  /// Create a deal proposal in a conversation (with linked deals record)
  Future<Map<String, dynamic>?> createDealProposal({
    required String conversationId,
    required String recipientId,
    required double commissionRate,
    int? minOrderQuantity,
    String? terms,
    DateTime? expiresAt,
    List<String>? productIds,
  }) async {
    if (currentUserId == null) {
      debugPrint('❌ [DealChatService] No user logged in');
      return null;
    }

    // Check permission first
    final canPropose = await _canProposeDeal(recipientId);
    if (!canPropose) {
      debugPrint('❌ [DealChatService] Permission denied to propose deal');
      return null;
    }

    try {
      final proposalData = DealProposalData(
        commissionRate: commissionRate,
        minOrderQuantity: minOrderQuantity,
        terms: terms,
        productIds: productIds,
      );

      // Step 1: Create the deals record (commission agreement)
      final dealResult = await _client
          .from('deals')
          .insert({
            'middleman_id': currentUserId, // Factory acts as middleman for now
            'party_a_id': currentUserId, // Proposer
            'party_b_id': recipientId, // Recipient
            'commission_rate': commissionRate,
            'status': 'pending',
          })
          .select()
          .single();

      if (dealResult is! Map<String, dynamic>) {
        throw Exception('Failed to create deal record');
      }

      final dealId = dealResult['id'] as String;

      // Step 2: Create the conversation_deals proposal
      final proposalDataMap = <String, dynamic>{
        'conversation_id': conversationId,
        'deal_id': dealId, // Link to the deals record
        'proposer_id': currentUserId,
        'recipient_id': recipientId,
        'proposal_data': proposalData.toJson(),
        'status': 'pending',
      };

      if (expiresAt != null) {
        proposalDataMap['expires_at'] = expiresAt.toIso8601String();
      }

      final result = await _client
          .from('conversation_deals')
          .insert(proposalDataMap)
          .select()
          .single();

      return result as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      debugPrint('❌ [DealChatService] Postgrest error: ${e.message}');
      if (e.code == '42501') {
        debugPrint('🔐 RLS policy blocked the operation');
      }
      return null;
    } catch (e) {
      debugPrint('❌ [DealChatService] Error creating deal proposal: $e');
      return null;
    }
  }

  /// Respond to a deal proposal (accept/reject) - updates both tables
  Future<bool> respondToDeal({
    required String dealProposalId,
    required bool accepted,
  }) async {
    try {
      final newStatus = accepted ? 'accepted' : 'rejected';

      // Step 1: Update conversation_deals status
      await _client
          .from('conversation_deals')
          .update({'status': newStatus})
          .eq('id', dealProposalId);

      // Step 2: Get the linked deal_id and update deals table
      final proposal = await _client
          .from('conversation_deals')
          .select('deal_id')
          .eq('id', dealProposalId)
          .single();

      if (proposal is Map<String, dynamic> && proposal['deal_id'] != null) {
        final dealStatus = accepted ? 'active' : 'cancelled';

        await _client
            .from('deals')
            .update({'status': dealStatus})
            .eq('id', proposal['deal_id']);
      }

      return true;
    } on PostgrestException catch (e) {
      debugPrint('❌ [DealChatService] Postgrest error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ [DealChatService] Error responding to deal: $e');
      return false;
    }
  }

  /// Get all deals for a conversation (with RLS-safe query)
  Future<List<Map<String, dynamic>>> getConversationDeals(
    String conversationId,
  ) async {
    try {
      final response = await _client
          .from('conversation_deals')
          .select('''
            id,
            conversation_id,
            deal_id,
            proposer_id,
            recipient_id,
            proposal_data,
            status,
            expires_at,
            created_at,
            updated_at
          ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      debugPrint('❌ [DealChatService] RLS error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('❌ [DealChatService] Error getting conversation deals: $e');
      return [];
    }
  }

  /// Get a specific deal proposal with linked deal info
  Future<Map<String, dynamic>?> getDeal(String dealId) async {
    try {
      final response = await _client
          .from('conversation_deals')
          .select('''
            *,
            deals (
              id,
              commission_rate,
              party_a_id,
              party_b_id,
              status
            )
          ''')
          .eq('id', dealId)
          .single();

      return response as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('❌ [DealChatService] Error getting deal: $e');
      return null;
    }
  }

  /// Subscribe to deal updates for a conversation (realtime)
  /// Returns a StreamController that emits deal updates
  StreamController<Map<String, dynamic>> subscribeToDealUpdates(
    String conversationId,
  ) {
    final controller = StreamController<Map<String, dynamic>>();
    final channel = _client.channel('conversation_deals:$conversationId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'conversation_deals',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) {
        controller.add(payload.newRecord);
      },
    );

    channel.subscribe();

    return controller;
  }

  /// Unsubscribe from deal updates (call this in dispose)
  void unsubscribeFromDealUpdates(String conversationId) {
    _client.removeChannel(
      _client.channel('conversation_deals:$conversationId'),
    );
  }

  /// Cancel a pending deal proposal (only proposer can cancel)
  Future<bool> cancelDealProposal(String dealProposalId) async {
    if (currentUserId == null) return false;

    try {
      // First verify the user is the proposer
      final proposal = await _client
          .from('conversation_deals')
          .select('proposer_id, status')
          .eq('id', dealProposalId)
          .single();

      if (proposal is! Map<String, dynamic> ||
          proposal['proposer_id'] != currentUserId ||
          proposal['status'] != 'pending') {
        return false;
      }

      await _client
          .from('conversation_deals')
          .update({'status': 'cancelled'})
          .eq('id', dealProposalId);

      // Also cancel the linked deal
      if (proposal['deal_id'] != null) {
        await _client
            .from('deals')
            .update({'status': 'cancelled'})
            .eq('id', proposal['deal_id']);
      }

      return true;
    } catch (e) {
      debugPrint('❌ [DealChatService] Error cancelling deal: $e');
      return false;
    }
  }

  /// Get deals for the current user (as proposer or recipient)
  Future<List<Map<String, dynamic>>> getUserDeals() async {
    if (currentUserId == null) return [];

    try {
      final response = await _client
          .from('conversation_deals')
          .select('''
            id,
            conversation_id,
            deal_id,
            proposer_id,
            recipient_id,
            proposal_data,
            status,
            expires_at,
            created_at,
            deals (
              commission_rate,
              party_a_id,
              party_b_id,
              status as deal_status
            )
          ''')
          .or('proposer_id.eq.$currentUserId,recipient_id.eq.$currentUserId')
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ [DealChatService] Error getting user deals: $e');
      return [];
    }
  }

  /// Get active deals for commission calculation
  Future<List<Map<String, dynamic>>> getActiveDeals() async {
    if (currentUserId == null) return [];

    try {
      final response = await _client
          .from('deals')
          .select('''
            id,
            commission_rate,
            party_a_id,
            party_b_id,
            product_id,
            status,
            conversation_deals (
              id,
              conversation_id,
              proposal_data
            )
          ''')
          .or(
            'party_a_id.eq.$currentUserId,party_b_id.eq.$currentUserId,middleman_id.eq.$currentUserId',
          )
          .eq('status', 'active');

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ [DealChatService] Error getting active deals: $e');
      return [];
    }
  }
}
