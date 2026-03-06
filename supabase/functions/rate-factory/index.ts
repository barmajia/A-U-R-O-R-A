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

    const { 
      factoryId, 
      rating, 
      deliveryRating, 
      qualityRating, 
      communicationRating, 
      review 
    } = await req.json();

    // Validate input
    if (!factoryId || !rating) {
      throw new Error('Factory ID and rating are required');
    }

    if (rating < 1 || rating > 5) {
      throw new Error('Rating must be between 1 and 5');
    }

    // Verify authentication
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(
      req.headers.get('Authorization')?.replace('Bearer ', '')
    );

    if (userError || !user) {
      throw new Error('Unauthorized');
    }

    const sellerId = user.id;

    // Check if already rated
    const { data: existing } = await supabaseClient
      .from('factory_ratings')
      .select()
      .eq('factory_id', factoryId)
      .eq('seller_id', sellerId)
      .maybeSingle();

    let result;
    
    if (existing) {
      // Update existing rating
      const { data, error } = await supabaseClient
        .from('factory_ratings')
        .update({
          rating: rating,
          review: review || null,
          delivery_rating: deliveryRating || rating,
          quality_rating: qualityRating || rating,
          communication_rating: communicationRating || rating,
          updated_at: new Date().toISOString(),
        })
        .eq('factory_id', factoryId)
        .eq('seller_id', sellerId)
        .select()
        .single();

      if (error) throw error;
      result = data;
    } else {
      // Create new rating
      const { data, error } = await supabaseClient
        .from('factory_ratings')
        .insert({
          factory_id: factoryId,
          seller_id: sellerId,
          rating: rating,
          review: review || null,
          delivery_rating: deliveryRating || rating,
          quality_rating: qualityRating || rating,
          communication_rating: communicationRating || rating,
        })
        .select()
        .single();

      if (error) throw error;
      result = data;
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Rating submitted successfully', rating: result }), 
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );

  } catch (error: any) {
    console.error('Error in rate-factory:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }), 
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});
