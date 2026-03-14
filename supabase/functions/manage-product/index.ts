// Supabase Edge Function: manage-product
// Handles product CRUD operations (Create, Update, Delete)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ManageProductRequest {
  action: "create" | "update" | "delete";
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
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser(token);

    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, message: "Unauthorized" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 401,
        },
      );
    }

    // Parse request body
    const body: ManageProductRequest = await req.json();
    const { action, asin, data } = body;

    console.log(`Product ${action} request from user: ${user.id}`, {
      asin,
      action,
    });

    let result;

    switch (action) {
      case "create": {
        // Create new product - Server generates ASIN, Client provides SKU
        if (!data) {
          throw new Error("Missing product data");
        }

        // Generate ASIN as UUID (server-side)
        const generatedAsin = crypto.randomUUID();

        // Get SKU from client, or generate if not provided
        const providedSku = data.sku as string | undefined;
        const finalSku = providedSku || crypto.randomUUID();

        const productData = {
          ...data,
          asin: generatedAsin, // Server-generated ASIN
          sku: finalSku, // Client-provided SKU (or server-generated fallback)
          seller_id: user.id,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          // qr_data will be added by Flutter app
        };

        const { data: newProduct, error } = await supabase
          .from("products")
          .insert(productData)
          .select()
          .single();

        if (error) throw error;

        console.log(
          `Product created with ASIN: ${generatedAsin}, SKU: ${finalSku}`,
        );

        result = {
          success: true,
          message: "Product created successfully",
          data: newProduct,
          asin: generatedAsin,
          sku: finalSku,
          seller_id: user.id,
        };
        break;
      }

      case "update": {
        // Update existing product
        if (!asin) {
          throw new Error("Missing ASIN");
        }

        if (!data) {
          throw new Error("Missing product data");
        }

        // Get existing product to check if SKU needs to be generated
        const { data: existingProduct } = await supabase
          .from("products")
          .select("sku")
          .eq("asin", asin)
          .eq("seller_id", user.id)
          .single();

        let sku = existingProduct?.sku;

        // Generate SKU if product doesn't have one (for legacy products)
        if (!sku) {
          const generatedSku = crypto.randomUUID();
          sku = generatedSku;
          // Add SKU to update data
          data.sku = sku;
        }

        // Note: qr_data is now managed by Flutter app, not edge function

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
          message:
            sku === existingProduct?.sku
              ? "Product updated successfully"
              : "SKU generated successfully",
          data: updatedProduct,
          sku: sku,
        };
        break;
      }

      case "delete": {
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
        throw new Error(
          "Invalid action. Must be 'create', 'update', or 'delete'",
        );
    }

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
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
      },
    );
  }
});
