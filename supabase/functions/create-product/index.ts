import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client with service role (bypasses RLS for validation)
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

    // Parse request body
    const { 
      title, 
      description, 
      brand, 
      price, 
      quantity, 
      status, 
      category, 
      subcategory, 
      attributes, 
      brandId, 
      isLocalBrand, 
      images,
      sellerId,
      currency 
    } = await req.json();

    // Validate required fields
    if (!title || !brand || !category || !subcategory) {
      throw new Error('Missing required fields: title, brand, category, subcategory');
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

    // Generate ASIN if not provided
    const asin = `ASN-${Date.now()}-${Math.random().toString(36).substr(2, 9).toUpperCase()}`;

    // Validate attributes if subcategory has schema
    if (subcategory && attributes) {
      const { data: subcategoryData } = await supabaseClient
        .from('subcategories')
        .select('attribute_schema')
        .eq('name', subcategory)
        .single();

      if (subcategoryData?.attribute_schema) {
        const schema = subcategoryData.attribute_schema;
        
        // Check required fields
        if (schema.required) {
          for (const field of schema.required) {
            if (!attributes[field]) {
              throw new Error(`Missing required attribute: ${field}`);
            }
          }
        }
      }
    }

    // Insert product into database
    const { data, error } = await supabaseClient
      .from('products')
      .insert({
        asin,
        seller_id: sellerId,
        title,
        description,
        brand,
        price,
        quantity,
        status: status || 'draft',
        category,
        subcategory,
        attributes: attributes || {},
        brand_id: brandId,
        is_local_brand: isLocalBrand || false,
        images: images || [],
        color_hex: attributes?.color_hex ?? null,
        currency: currency || 'USD',
      })
      .select()
      .single();

    if (error) {
      console.error('Database insert error:', error);
      throw error;
    }

    // Return success response
    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Product created successfully',
        product: data,
        asin: data.asin 
      }), 
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 201,
      }
    );

  } catch (error: any) {
    console.error('create-product error:', error);
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
