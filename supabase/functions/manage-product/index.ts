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
        // Create new product - Server generates ASIN and SKU as UUID
        if (!data) {
          throw new Error("Missing product data");
        }

        // Generate ASIN and SKU as UUIDs on server side
        const generatedAsin = crypto.randomUUID();
        const generatedSku = crypto.randomUUID();

        // Create QR data string with ALL product details (compact JSON)
        const qrData = {
          // Core identifiers
          asin: generatedAsin,
          sku: generatedSku,

          // Basic product info
          title: data.title,
          description: data.description,
          brand: data.brand,
          manufacturer: data.manufacturer,

          // Category hierarchy
          category: data.category,
          subcategory: data.subcategory,
          product_type: data.product_type,

          // Pricing
          selling_price: data.selling_price,
          list_price: data.list_price,
          business_price: data.business_price,
          currency: data.currency,
          tax_code: data.tax_code,

          // Inventory
          quantity: data.quantity,
          fulfillment_channel: data.fulfillment_channel,
          availability_status: data.availability_status,
          lead_time_to_ship: data.lead_time_to_ship,

          // Attributes (flexible JSONB fields)
          attributes: data.attributes,

          // Variations
          variations: data.variations,

          // Images (main image URLs)
          images: data.images,

          // Compliance
          compliance: data.compliance,

          // Metadata
          status: data.status,
          language: data.language,
          bullet_points: data.bullet_points,
        };
        const qrDataString = JSON.stringify(qrData);

        const productData = {
          ...data,
          asin: generatedAsin, // Server-generated ASIN
          sku: generatedSku, // Server-generated SKU (for QR code)
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

        console.log(
          `Product created with ASIN: ${generatedAsin}, SKU: ${generatedSku}`,
        );

        result = {
          success: true,
          message: "Product created successfully",
          data: newProduct,
          asin: generatedAsin, // Return the generated ASIN
          sku: generatedSku, // Return the generated SKU (for QR code)
          qr_data: qrDataString, // Return QR-ready data
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
          .select("sku, qr_data")
          .eq("asin", asin)
          .eq("seller_id", user.id)
          .single();

        let sku = existingProduct?.sku;
        let qrDataString = existingProduct?.qr_data;

        // Generate SKU if product doesn't have one
        if (!sku) {
          const generatedSku = crypto.randomUUID();
          sku = generatedSku;

          // Generate full QR data with all product details
          const qrData = {
            // Core identifiers
            asin: asin,
            sku: generatedSku,

            // Basic product info
            title: data.title,
            description: data.description,
            brand: data.brand,
            manufacturer: data.manufacturer,

            // Category hierarchy
            category: data.category,
            subcategory: data.subcategory,
            product_type: data.product_type,

            // Pricing
            selling_price: data.selling_price,
            list_price: data.list_price,
            business_price: data.business_price,
            currency: data.currency,
            tax_code: data.tax_code,

            // Inventory
            quantity: data.quantity,
            fulfillment_channel: data.fulfillment_channel,
            availability_status: data.availability_status,
            lead_time_to_ship: data.lead_time_to_ship,

            // Attributes (flexible JSONB fields)
            attributes: data.attributes,

            // Variations
            variations: data.variations,

            // Images (main image URLs)
            images: data.images,

            // Compliance
            compliance: data.compliance,

            // Metadata
            status: data.status,
            language: data.language,
            bullet_points: data.bullet_points,
          };
          qrDataString = JSON.stringify(qrData);

          // Add SKU and QR data to update
          data.sku = sku;
          data.qr_data = qrDataString;
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
          message:
            sku === existingProduct?.sku
              ? "Product updated successfully"
              : "SKU generated successfully",
          data: updatedProduct,
          sku: sku, // Return the SKU (new or existing)
          qr_data: qrDataString, // Return QR-ready data
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
