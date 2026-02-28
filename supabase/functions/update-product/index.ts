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
      { 
        global: { 
          headers: { 
            Authorization: req.headers.get('Authorization')! 
          } 
        } 
      }
    );

    const { 
      asin, 
      updates,
      sellerId 
    } = await req.json();

    if (!asin) {
      throw new Error('ASIN is required');
    }

    if (!sellerId) {
      throw new Error('sellerId is required');
    }

    // Verify authentication
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(
      req.headers.get('Authorization')?.replace('Bearer ', '')
    );

    if (userError || !user) {
      throw new Error('Unauthorized: Invalid or missing authentication token');
    }

    // Verify sellerId matches authenticated user
    if (user.id !== sellerId) {
      throw new Error('Unauthorized: sellerId does not match authenticated user');
    }

    // Verify ownership - get existing product
    const { data: existingProduct, error: fetchError } = await supabaseClient
      .from('products')
      .select('seller_id, asin')
      .eq('asin', asin)
      .single();

    if (fetchError || !existingProduct) {
      throw new Error('Product not found');
    }

    if (existingProduct.seller_id !== sellerId) {
      throw new Error('Unauthorized: You can only update your own products');
    }

    // Validate updates if attributes are being changed
    if (updates.attributes && updates.subcategory) {
      const { data: subcategoryData } = await supabaseClient
        .from('subcategories')
        .select('attribute_schema')
        .eq('name', updates.subcategory)
        .single();

      if (subcategoryData?.attribute_schema) {
        const schema = subcategoryData.attribute_schema;
        
        if (schema.required) {
          for (const field of schema.required) {
            if (!updates.attributes[field]) {
              throw new Error(`Missing required attribute: ${field}`);
            }
          }
        }
      }
    }

    // Add updated_at timestamp
    const updatesWithTimestamp = {
      ...updates,
      updated_at: new Date().toISOString(),
    };

    // Update product
    const { data, error } = await supabaseClient
      .from('products')
      .update(updatesWithTimestamp)
      .eq('asin', asin)
      .eq('seller_id', sellerId) // Extra security check
      .select()
      .single();

    if (error) {
      console.error('Database update error:', error);
      throw error;
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Product updated successfully',
        product: data 
      }), 
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );

  } catch (error: any) {
    console.error('update-product error:', error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message,
        code: error.code || 'UNKNOWN_ERROR' 
      }), 
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});
