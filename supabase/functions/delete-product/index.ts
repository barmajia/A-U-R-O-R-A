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

    const { asin, sellerId } = await req.json();

    // Validate required fields
    if (!asin) {
      throw new Error('ASIN is required');
    }
    if (!sellerId) {
      throw new Error('sellerId is required');
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

    // Get product to fetch image URLs before deletion
    const { data: product, error: fetchError } = await supabaseClient
      .from('products')
      .select('seller_id, images, asin')
      .eq('asin', asin)
      .maybeSingle();

    if (fetchError) {
      throw new Error(`Product lookup failed: ${fetchError.message}`);
    }

    if (!product) {
      throw new Error('Product not found');
    }

    if (product.seller_id !== sellerId) {
      throw new Error('Unauthorized: You can only delete your own products');
    }

    // Delete images from storage if they exist
    const deletedImages: string[] = [];
    const failedImages: string[] = [];

    if (product.images && Array.isArray(product.images)) {
      for (const img of product.images) {
        if (img.url) {
          try {
            // Extract path from URL
            // Format: https://<project>.supabase.co/storage/v1/object/public/product-images/<seller_id>/<product_id>/<image>
            const urlParts = img.url.split('/product-images/');
            if (urlParts.length > 1) {
              const imagePath = urlParts[1]; // seller_id/product_id/image.jpg

              const { error: storageError } = await supabaseClient.storage
                .from('product-images')
                .remove([imagePath]);

              if (storageError) {
                console.warn(`Could not delete image: ${imagePath}`, storageError);
                failedImages.push(imagePath);
              } else {
                deletedImages.push(imagePath);
              }
            }
          } catch (e) {
            console.warn(`Error processing image URL: ${img.url}`, e);
            failedImages.push(img.url);
          }
        }
      }
    }

    // Delete product from database
    const { error: deleteError } = await supabaseClient
      .from('products')
      .delete()
      .eq('asin', asin)
      .eq('seller_id', sellerId); // Extra security check

    if (deleteError) {
      console.error('Database delete error:', deleteError);
      throw new Error(`Database error: ${deleteError.message}`);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Product deleted successfully',
        deletedImages: deletedImages.length,
        failedImages: failedImages.length,
        asin: asin,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );

  } catch (error: any) {
    console.error('delete-product error:', error);
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
