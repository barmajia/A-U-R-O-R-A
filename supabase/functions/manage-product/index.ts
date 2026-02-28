// Supabase Edge Function: manage-product
// Handles product CRUD operations (Create, Update, Delete)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ManageProductRequest {
  action: 'create' | 'update' | 'delete';
  asin?: string;
  data?: any;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      throw new Error("Missing authorization header");
    }

    const token = authHeader.replace("Bearer ", "");
    
    // Verify the user
    const { data: { user }, error: userError } = await supabase.auth.getUser(token);
    
    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, message: "Unauthorized" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
      );
    }

    // Parse request body
    const body: ManageProductRequest = await req.json();
    const { action, asin, data } = body;

    console.log(`Product ${action} request from user: ${user.id}`, { asin, action });

    let result;

    switch (action) {
      case 'create': {
        // Create new product - Server generates ASIN and SKU as UUID
        if (!data) {
          throw new Error("Missing product data");
        }

        // Generate ASIN and SKU as UUIDs on server side
        const generatedAsin = crypto.randomUUID();
        const generatedSku = crypto.randomUUID();
        
        // Create QR data string (compact JSON without whitespace)
        const qrData = {
          asin: generatedAsin,
          sku: generatedSku,
          title: data.title,
          brand: data.brand,
          price: data.selling_price,
          currency: data.currency,
          quantity: data.quantity,
        };
        const qrDataString = JSON.stringify(qrData);

        const productData = {
          ...data,
          asin: generatedAsin, // Server-generated ASIN
          sku: generatedSku,   // Server-generated SKU (for QR code)
          qr_data: qrDataString, // Store QR-ready JSON data
          seller_id: user.id,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };

        const { data: newProduct, error } = await supabase
          .from("products")
          .insert(productData)
          .select()
          .single();

        if (error) throw error;

        console.log(`Product created with ASIN: ${generatedAsin}, SKU: ${generatedSku}`);

        result = {
          success: true,
          message: "Product created successfully",
          data: newProduct,
          asin: generatedAsin, // Return the generated ASIN
          sku: generatedSku,   // Return the generated SKU (for QR code)
          qr_data: qrDataString, // Return QR-ready data
        };
        break;
      }

      case 'update': {
        // Update existing product
        if (!asin) {
          throw new Error("Missing ASIN");
        }

        if (!data) {
          throw new Error("Missing product data");
        }

        const updateData = {
          ...data,
          updated_at: new Date().toISOString(),
        };

        const { data: updatedProduct, error } = await supabase
          .from("products")
          .update(updateData)
          .eq("asin", asin)
          .eq("seller_id", user.id) // Ensure user owns this product
          .select()
          .single();

        if (error) throw error;

        result = {
          success: true,
          message: "Product updated successfully",
          data: updatedProduct,
        };
        break;
      }

      case 'delete': {
        // Soft delete product
        if (!asin) {
          throw new Error("Missing ASIN");
        }

        const { error } = await supabase
          .from("products")
          .update({
            is_deleted: true,
            deleted_at: new Date().toISOString(),
          })
          .eq("asin", asin)
          .eq("seller_id", user.id);

        if (error) throw error;

        result = {
          success: true,
          message: "Product deleted successfully",
        };
        break;
      }

      default:
        throw new Error("Invalid action. Must be 'create', 'update', or 'delete'");
    }

    return new Response(
      JSON.stringify(result),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );

  } catch (error) {
    console.error("Error in manage-product:", error);

    return new Response(
      JSON.stringify({
        success: false,
        message: error instanceof Error ? error.message : "An error occurred",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
