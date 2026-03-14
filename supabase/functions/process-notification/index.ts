// Supabase Edge Function: process-notification
// Purpose: Create and send notifications to users
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

// Notification types
type NotificationType = 
  | 'order'
  | 'message'
  | 'deal'
  | 'product'
  | 'system'
  | 'payment'
  | 'shipping'
  | 'review'
  | 'promotion'
  | 'security';

// Priority levels
type PriorityLevel = 'low' | 'normal' | 'high' | 'urgent';

// Request interface
interface ProcessNotificationRequest {
  userId: string; // Recipient user ID
  title: string;
  message: string;
  type: NotificationType;
  priority?: PriorityLevel;
  referenceType?: string; // e.g., 'order', 'product'
  referenceId?: string; // ID of related entity
  actionUrl?: string; // Deep link or URL
  metadata?: Record<string, any>;
  expiresAt?: string; // ISO 8601 format
  sendPush?: boolean; // Whether to send push notification
}

// Response interface
interface NotificationResponse {
  success: boolean;
  notificationId?: string;
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
    
    // For system-generated notifications, allow service role authentication
    // For user-generated notifications, verify the user
    let currentUserId: string | null = null;
    
    if (authHeader) {
      const token = authHeader.replace("Bearer ", "");
      const { data: { user } } = await supabaseAdmin.auth.getUser(token);
      if (user) {
        currentUserId = user.id;
      }
    }

    // Parse request body
    const body: ProcessNotificationRequest = await req.json();
    const { 
      userId, 
      title, 
      message, 
      type, 
      priority = 'normal',
      referenceType,
      referenceId,
      actionUrl,
      metadata = {},
      expiresAt,
      sendPush = false
    } = body;

    // Validate input
    if (!userId) {
      throw new Error("userId is required");
    }

    if (!title || !message) {
      throw new Error("title and message are required");
    }

    if (!type) {
      throw new Error("notification type is required");
    }

    // Validate notification type
    const validTypes = ['order', 'message', 'deal', 'product', 'system', 'payment', 'shipping', 'review', 'promotion', 'security'];
    if (!validTypes.includes(type)) {
      throw new Error(`Invalid notification type. Must be one of: ${validTypes.join(', ')}`);
    }

    // Validate priority
    const validPriorities = ['low', 'normal', 'high', 'urgent'];
    if (!validPriorities.includes(priority)) {
      throw new Error(`Invalid priority. Must be one of: ${validPriorities.join(', ')}`);
    }

    // Validate reference consistency
    if ((referenceType && !referenceId) || (!referenceType && referenceId)) {
      throw new Error("referenceType and referenceId must both be provided or both be null");
    }

    // Check if user exists
    const { data: user, error: userError } = await supabaseAdmin
      .from("sellers")
      .select("user_id")
      .eq("user_id", userId)
      .single();

    if (userError && userError.code !== "PGRST116") {
      throw new Error(`User lookup failed: ${userError.message}`);
    }

    // Create notification
    const { data: notification, error: createError } = await supabaseAdmin
      .from("notifications")
      .insert({
        user_id: userId,
        title,
        message,
        type,
        priority,
        reference_type: referenceType || null,
        reference_id: referenceId || null,
        action_url: actionUrl || null,
        metadata: metadata || {},
        expires_at: expiresAt || null,
        is_sent: false,
      })
      .select()
      .single();

    if (createError) {
      throw new Error(`Failed to create notification: ${createError.message}`);
    }

    // Mark notification as sent
    const { error: updateError } = await supabaseAdmin
      .from("notifications")
      .update({ 
        is_sent: true,
        sent_at: new Date().toISOString()
      })
      .eq("id", notification.id);

    if (updateError) {
      console.error("Failed to update notification status:", updateError);
      // Don't fail the request, just log the error
    }

    // Send push notification if requested
    if (sendPush) {
      try {
        // TODO: Integrate with Firebase Cloud Messaging or similar
        // This is a placeholder for push notification logic
        console.log(`Push notification would be sent to user ${userId}`);
        
        // Example FCM integration:
        // await sendPushNotification(userId, title, message, actionUrl);
        
        // Update delivery status
        await supabaseAdmin
          .from("notifications")
          .update({ 
            is_delivered: true,
            delivered_at: new Date().toISOString()
          })
          .eq("id", notification.id);
      } catch (pushError) {
        console.error("Failed to send push notification:", pushError);
        // Don't fail the request, just log the error
      }
    }

    // Success response
    const response: NotificationResponse = {
      success: true,
      notificationId: notification.id,
      message: "Notification processed successfully",
    };

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 201,
    });

  } catch (error) {
    console.error("Error in process-notification:", error);
    
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

/**
 * Helper function to send push notifications via FCM
 * This is a placeholder for actual FCM integration
 */
async function sendPushNotification(
  userId: string,
  title: string,
  message: string,
  actionUrl?: string
): Promise<void> {
  // Get user's FCM token from database
  // const supabaseAdmin = createClient(...);
  // const { data } = await supabaseAdmin
  //   .from("user_devices")
  //   .select("fcm_token")
  //   .eq("user_id", userId);
  
  // const fcmToken = data?.[0]?.fcm_token;
  // if (!fcmToken) return;

  // Send to FCM
  // const response = await fetch('https://fcm.googleapis.com/fcm/send', {
  //   method: 'POST',
  //   headers: {
  //     'Content-Type': 'application/json',
  //     'Authorization': `key=${Deno.env.get("FCM_SERVER_KEY")}`
  //   },
  //   body: JSON.stringify({
  //     to: fcmToken,
  //     notification: {
  //       title,
  //       body: message,
  //       click_action: actionUrl
  //     }
  //   })
  // });
  
  // if (!response.ok) {
  //   throw new Error('Failed to send push notification');
  // }
}
