import 'package:aurora/models/chat/deal_proposal.dart';
import 'package:aurora/services/deal_chat_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget to display a deal proposal in a chat conversation
///
/// Features:
/// - Card with header showing "🤝 Deal Proposal"
/// - Status badge (color-coded: pending=yellow, accepted=green, rejected=red)
/// - Commission rate display (bold, large)
/// - Min order quantity (if exists)
/// - Terms & conditions (if exists)
/// - Expiry date (if exists)
/// - Accept/Reject buttons (for recipient, when pending)
/// - "Awaiting response" message (for proposer, when pending)
class DealProposalCard extends StatelessWidget {
  final DealProposal proposal;
  final bool isProposer;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onViewDetails;

  const DealProposalCard({
    super.key,
    required this.proposal,
    required this.isProposer,
    this.onAccept,
    this.onReject,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final statusColors = {
      'pending': Colors.amber,
      'accepted': Colors.green,
      'rejected': Colors.red,
      'expired': Colors.grey,
      'cancelled': Colors.grey,
    };

    final statusColor = statusColors[proposal.status] ?? Colors.grey;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shadowColor: statusColor.withValues(alpha: 0.3),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.surface, statusColor.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and status badge
              _buildHeader(statusColor, colorScheme),

              const SizedBox(height: 16),

              // Commission Rate (main highlight)
              _buildCommissionRate(colorScheme),

              // Min Order Quantity (if exists)
              if (proposal.proposalData.minOrderQuantity != null) ...[
                const SizedBox(height: 10),
                _buildMinOrder(colorScheme),
              ],

              // Terms & Conditions (if exists)
              if (proposal.proposalData.terms != null &&
                  proposal.proposalData.terms!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildTerms(colorScheme),
              ],

              // Expiry Date (if exists)
              if (proposal.expiresAt != null) ...[
                const SizedBox(height: 12),
                _buildExpiryDate(colorScheme),
              ],

              // Action Buttons or Status Messages
              _buildActions(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color statusColor, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.handshake, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              '🤝 Deal Proposal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        _buildStatusBadge(statusColor),
      ],
    );
  }

  Widget _buildStatusBadge(Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (proposal.status == 'pending')
            const Icon(Icons.hourglass_empty, size: 14, color: Colors.white),
          if (proposal.status == 'accepted')
            const Icon(Icons.check_circle, size: 14, color: Colors.white),
          if (proposal.status == 'rejected')
            const Icon(Icons.cancel, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            proposal.status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionRate(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commission Rate',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${proposal.proposalData.commissionRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Icon(
            Icons.percent,
            size: 40,
            color: colorScheme.primary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildMinOrder(ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(
          Icons.inventory_2_outlined,
          size: 18,
          color: colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 8),
        Text(
          'Min Order:',
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${proposal.proposalData.minOrderQuantity} units',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTerms(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'Terms & Conditions',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            proposal.proposalData.terms!,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpiryDate(ColorScheme colorScheme) {
    final isExpired =
        proposal.expiresAt != null &&
        DateTime.now().isAfter(proposal.expiresAt!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            size: 16,
            color: isExpired ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 8),
          Text(
            isExpired
                ? 'Expired: ${DateFormat('MMM dd, yyyy').format(proposal.expiresAt!)}'
                : 'Expires: ${DateFormat('MMM dd, yyyy').format(proposal.expiresAt!)}',
            style: TextStyle(
              color: isExpired ? Colors.red : Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    ColorScheme colorScheme, {
    DealChatService? dealService,
  }) {
    // Action buttons for recipient (when pending)
    if (!isProposer && proposal.status == 'pending') {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _handleAcceptDeal(dealService),
                icon: const Icon(Icons.check, size: 20),
                label: const Text('Accept Deal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 3,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleRejectDeal(dealService),
                icon: const Icon(Icons.close, size: 20),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Status message for proposer (when pending)
    if (isProposer && proposal.status == 'pending') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.amber[700], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Awaiting Response',
                    style: TextStyle(
                      color: Colors.amber[700],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Waiting for the other party to respond',
                    style: TextStyle(color: Colors.amber[700], fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Success message for accepted deals
    if (proposal.status == 'accepted') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deal Accepted',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Commission agreement is now active',
                    style: TextStyle(color: Colors.green[700], fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Rejected deal message
    if (proposal.status == 'rejected') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red[700], size: 20),
            const SizedBox(width: 12),
            Text(
              'Deal was rejected',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Expired or cancelled
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[700], size: 20),
          const SizedBox(width: 12),
          Text(
            'This deal is no longer active',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Deal Action Handlers
  // ==========================================================================

  /// Handle accept deal action
  Future<void> _handleAcceptDeal(DealChatService? dealService) async {
    if (dealService == null) {
      debugPrint('Deal service not available');
      return;
    }

    try {
      // Call backend to accept deal
      final success = await dealService.respondToDeal(
        dealProposalId: proposal.id,
        accepted: true,
      );

      if (success && onAccept != null) {
        onAccept!();
      }
    } catch (e) {
      debugPrint('Error accepting deal: $e');
    }
  }

  /// Handle reject deal action
  Future<void> _handleRejectDeal(DealChatService? dealService) async {
    if (dealService == null) {
      debugPrint('Deal service not available');
      return;
    }

    try {
      // Call backend to reject deal
      final success = await dealService.respondToDeal(
        dealProposalId: proposal.id,
        accepted: false,
      );

      if (success && onReject != null) {
        onReject!();
      }
    } catch (e) {
      debugPrint('Error rejecting deal: $e');
    }
  }
}
