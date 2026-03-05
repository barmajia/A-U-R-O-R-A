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
    const { bucket, path, transform } = await req.json();

    if (!bucket || !path) {
      throw new Error('Missing required fields: bucket, path');
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    );

    // Get public URL
    const { publicUrl } = supabaseClient.storage
      .from(bucket)
      .getPublicUrl(path);

    // Apply optional transforms (resize, format, quality)
    let finalUrl = publicUrl;
    if (transform) {
      const params = new URLSearchParams();
      if (transform.width) params.append('width', transform.width.toString());
      if (transform.height) params.append('height', transform.height.toString());
      if (transform.quality) params.append('quality', transform.quality.toString());
      if (transform.format) params.append('format', transform.format);
      
      if (params.toString()) {
        finalUrl = `${publicUrl}?${params.toString()}`;
      }
    }

    return new Response(JSON.stringify({
      success: true,
      data: {
        url: finalUrl,
        originalUrl: publicUrl,
      },
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
