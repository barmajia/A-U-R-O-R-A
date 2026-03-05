import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client with service role key
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        global: {
          headers: {
            Authorization: req.headers.get('Authorization')!,
          },
        },
      }
    );

    // Parse request body
    const { asin, updates, sellerId } = await req.json();

    // Validate required fields
    if (!asin) {
      throw new Error('ASIN is required');
    }
    if (!sellerId) {
      throw new Error('sellerId is required');
    }
    if (!updates || typeof updates !== 'object') {
      throw new Error('Updates object is required');
    }

    // Verify authentication
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new Error('Unauthorized: Missing authentication token');
    }

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(
      authHeader.replace('Bearer ', '')
    );

    if (userError || !user) {
      throw new Error(`Unauthorized: ${userError?.message || 'Invalid authentication token'}`);
    }

    // Verify sellerId matches authenticated user
    if (user.id !== sellerId) {
      throw new Error('Unauthorized: sellerId does not match authenticated user');
    }

    // Verify ownership - get existing product
    const { data: existingProduct, error: fetchError } = await supabaseClient
      .from('products')
      .select('seller_id, asin, status')
      .eq('asin', asin)
      .maybeSingle();

    if (fetchError) {
      throw new Error(`Product lookup failed: ${fetchError.message}`);
    }

    if (!existingProduct) {
      throw new Error('Product not found');
    }

    if (existingProduct.seller_id !== sellerId) {
      throw new Error('Unauthorized: You can only update your own products');
    }

    // Validate updates if attributes are being changed
    if (updates.attributes && updates.subcategory) {
      try {
        const { data: subcategoryData } = await supabaseClient
          .from('subcategories')
          .select('attribute_schema')
          .eq('name', updates.subcategory)
          .maybeSingle();

        if (subcategoryData?.attribute_schema) {
          const schema = subcategoryData.attribute_schema as { required?: string[] };

          if (schema.required && Array.isArray(schema.required)) {
            const missingAttrs = schema.required.filter(
              (field: string) => !updates.attributes[field]
            );
            if (missingAttrs.length > 0) {
              throw new Error(`Missing required attributes: ${missingAttrs.join(', ')}`);
            }
          }
        }
      } catch (schemaError) {
        console.warn('Attribute validation skipped:', schemaError);
      }
    }

    // Sanitize and prepare updates
    const sanitizedUpdates: Record<string, any> = {};
    
    // Allowed fields for update
    const allowedFields = [
      'title', 'description', 'brand', 'price', 'quantity',
      'status', 'category', 'subcategory', 'attributes',
      'brand_id', 'is_local_brand', 'images', 'color_hex',
    ];

    for (const field of allowedFields) {
      if (updates[field] !== undefined) {
        if (typeof updates[field] === 'string') {
          sanitizedUpdates[field] = updates[field].trim();
        } else {
          sanitizedUpdates[field] = updates[field];
        }
      }
    }

    // Add updated_at timestamp
    sanitizedUpdates.updated_at = new Date().toISOString();

    // Update product
    const { data: updatedProduct, error: updateError } = await supabaseClient
      .from('products')
      .update(sanitizedUpdates)
      .eq('asin', asin)
      .eq('seller_id', sellerId) // Extra security check
      .select()
      .single();

    if (updateError) {
      console.error('Database update error:', updateError);
      throw new Error(`Database error: ${updateError.message}`);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Product updated successfully',
        product: updatedProduct,
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
        error: error.message || 'An unexpected error occurred',
        code: error.code || 'UNKNOWN_ERROR',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: error.message?.includes('Unauthorized') ? 401 : 400,
      }
    );
  }
});
