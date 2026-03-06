import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    );

    const { factoryId, notes } = await req.json();

    // Validate input
    if (!factoryId) {
      throw new Error('Factory ID is required');
    }

    // Verify authentication
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(
      req.headers.get('Authorization')?.replace('Bearer ', '')
    );

    if (userError || !user) {
      throw new Error('Unauthorized');
    }

    // Check if connection already exists
    const { data: existing } = await supabaseClient
      .from('factory_connections')
      .select()
      .eq('factory_id', factoryId)
      .eq('seller_id', user.id)
      .single();

    if (existing) {
      throw new Error('Connection request already exists');
    }

    // Create connection request
    const { data: connection, error } = await supabaseClient
      .from('factory_connections')
      .insert({
        factory_id: factoryId,
        seller_id: user.id,
        status: 'pending',
        notes: notes || null
      })
      .select()
      .single();

    if (error) throw error;

    // Create notification for factory
    const { error: notifError } = await supabaseClient
      .from('notifications')
      .insert({
        user_id: factoryId,
        type: 'system',
        title: 'New Factory Connection Request',
        message: `A seller wants to connect with your factory`,
        metadata: { connection_id: connection.id, type: 'factory_connection' }
      });

    if (notifError) {
      console.error('Failed to create notification:', notifError);
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Connection request sent', connection }), 
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 201,
      }
    );

  } catch (error: any) {
    console.error('Error in request-factory-connection:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }), 
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});
