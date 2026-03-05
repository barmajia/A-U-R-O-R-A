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

    const { bucket, path, sellerId } = await req.json();

    if (!bucket || !path || !sellerId) {
      throw new Error('Missing required fields: bucket, path, sellerId');
    }

    // Verify ownership (seller can only delete their own images)
    const pathParts = path.split('/');
    const imageSellerId = pathParts[0];
    
    if (imageSellerId !== sellerId) {
      throw new Error('Unauthorized: Cannot delete another seller\'s images');
    }

    // Delete from storage
    const { error } = await supabaseClient.storage
      .from(bucket)
      .remove([path]);

    if (error) throw error;

    return new Response(JSON.stringify({
      success: true,
      message: 'Image deleted successfully',
      data: { path },
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error: any) {
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
