// Supabase Edge Function: get-or-create-conversation
// Purpose: Get existing conversation or create new one between two users
// Created: 2026-03-14
// Status: READY FOR DEPLOYMENT

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// CORS headers for cross-origin requests
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Request interface
interface GetOrCreateConversationRequest {
  participantId: string; // The other user's ID
  subject?: string; // Optional conversation subject
  metadata?: Record<string, any>; // Additional metadata
}

// Response interface
interface ConversationResponse {
  success: boolean;
  conversationId?: string;
  isNew?: boolean;
  message?: string;
  error?: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Only allow POST requests
    if (req.method !== "POST") {
      throw new Error("Method not allowed");
    }

    // Create Supabase client with admin privileges
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    
    if (!supabaseUrl || !supabaseServiceRoleKey) {
      throw new Error("Missing Supabase credentials");
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Get authenticated user from request headers
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      throw new Error("Missing authorization header");
    }

    const token = authHeader.replace("Bearer ", "");
    
    // Verify the user
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);
    
    if (userError || !user) {
      throw new Error("Unauthorized: Invalid token");
    }

    const currentUserId = user.id;

    // Parse request body
    const body: GetOrCreateConversationRequest = await req.json();
    const { participantId, subject, metadata } = body;

    // Validate input
    if (!participantId) {
      throw new Error("participantId is required");
    }

    if (participantId === currentUserId) {
      throw new Error("Cannot create conversation with yourself");
    }

    // Check if participant exists
    const { data: participant, error: participantError } = await supabaseAdmin
      .from("sellers")
      .select("id, user_id")
      .eq("user_id", participantId)
      .single();

    if (participantError && participantError.code !== "PGRST116") {
      throw new Error(`Participant lookup failed: ${participantError.message}`);
    }

    // Try to find existing conversation
    // A conversation exists if both users are participants (regardless of order)
    const { data: existingConversations, error: searchError } = await supabaseAdmin
      .from("conversations")
      .select(`
        id,
        participants:conversation_participants(
          user_id
        )
      `)
      .in("id", (
        await supabaseAdmin
          .from("conversation_participants")
          .select("conversation_id")
          .in("user_id", [currentUserId, participantId])
      ).data?.map((p: any) => p.conversation_id) || []);

    if (searchError) {
      throw new Error(`Failed to search conversations: ${searchError.message}`);
    }

    // Find conversation with exactly these two participants
    let existingConversationId: string | undefined;
    
    if (existingConversations && existingConversations.length > 0) {
      for (const conv of existingConversations) {
        const participantIds = conv.participants?.map((p: any) => p.user_id) || [];
        const hasBothUsers = participantIds.includes(currentUserId) && 
                            participantIds.includes(participantId);
        const hasOnlyTwoUsers = participantIds.length === 2;
        
        if (hasBothUsers && hasOnlyTwoUsers) {
          existingConversationId = conv.id;
          break;
        }
      }
    }

    // If conversation exists, return it
    if (existingConversationId) {
      const response: ConversationResponse = {
        success: true,
        conversationId: existingConversationId,
        isNew: false,
        message: "Existing conversation found",
      };

      return new Response(JSON.stringify(response), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    // Create new conversation
    const { data: newConversation, error: createError } = await supabaseAdmin
      .from("conversations")
      .insert({
        subject: subject || null,
        metadata: metadata || {},
        created_by: currentUserId,
      })
      .select()
      .single();

    if (createError) {
      throw new Error(`Failed to create conversation: ${createError.message}`);
    }

    // Add both users as participants
    const { error: participantsError } = await supabaseAdmin
      .from("conversation_participants")
      .insert([
        {
          conversation_id: newConversation.id,
          user_id: currentUserId,
          role: "admin",
        },
        {
          conversation_id: newConversation.id,
          user_id: participantId,
          role: "participant",
        },
      ]);

    if (participantsError) {
      // Rollback: delete the conversation if participants fail
      await supabaseAdmin
        .from("conversations")
        .delete()
        .eq("id", newConversation.id);
      
      throw new Error(`Failed to add participants: ${participantsError.message}`);
    }

    // Success response
    const response: ConversationResponse = {
      success: true,
      conversationId: newConversation.id,
      isNew: true,
      message: "Conversation created successfully",
    };

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 201,
    });

  } catch (error) {
    console.error("Error in get-or-create-conversation:", error);
    
    const errorResponse = {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error occurred",
    };

    return new Response(JSON.stringify(errorResponse), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: error instanceof Error && error.message.includes("Unauthorized") ? 401 : 400,
    });
  }
});
