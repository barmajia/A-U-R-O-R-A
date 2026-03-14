import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client with service role key (bypasses RLS for validation)
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      {
        global: {
          headers: {
            Authorization: req.headers.get("Authorization")!,
          },
        },
      },
    );

    // Parse request body
    const requestBody = await req.json();

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
      currency,
      sku, // Accept SKU from client
    } = requestBody;

    // Validate required fields
    const missingFields: string[] = [];
    if (!title) missingFields.push("title");
    if (!brand) missingFields.push("brand");
    if (!category) missingFields.push("category");
    if (!subcategory) missingFields.push("subcategory");
    if (!sellerId) missingFields.push("sellerId");

    if (missingFields.length > 0) {
      throw new Error(`Missing required fields: ${missingFields.join(", ")}`);
    }

    // Verify authentication
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      throw new Error("Unauthorized: Missing authentication token");
    }

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser(authHeader.replace("Bearer ", ""));

    if (userError || !user) {
      throw new Error(
        `Unauthorized: ${userError?.message || "Invalid authentication token"}`,
      );
    }

    // Verify sellerId matches authenticated user
    if (user.id !== sellerId) {
      throw new Error(
        "Unauthorized: sellerId does not match authenticated user",
      );
    }

    // Generate ASIN server-side (format: ASN-{timestamp}-{random})
    const timestamp = Date.now();
    const randomStr = Math.random().toString(36).substring(2, 11).toUpperCase();
    const asin = `ASN-${timestamp}-${randomStr}`;

    // Use client-provided SKU or generate one
    const finalSku = sku || `SKU-${timestamp}-${randomStr}`;

    // Validate attributes if subcategory has schema
    if (subcategory && attributes) {
      try {
        const { data: subcategoryData, error: subcategoryError } =
          await supabaseClient
            .from("subcategories")
            .select("attribute_schema")
            .eq("name", subcategory)
            .maybeSingle();

        if (subcategoryError) {
          console.warn(
            "Could not fetch subcategory schema:",
            subcategoryError.message,
          );
        }

        if (subcategoryData?.attribute_schema) {
          const schema = subcategoryData.attribute_schema as {
            required?: string[];
          };

          // Check required attributes
          if (schema.required && Array.isArray(schema.required)) {
            const missingAttrs = schema.required.filter(
              (field: string) => !attributes[field],
            );
            if (missingAttrs.length > 0) {
              throw new Error(
                `Missing required attributes: ${missingAttrs.join(", ")}`,
              );
            }
          }
        }
      } catch (schemaError) {
        console.warn("Attribute validation skipped:", schemaError);
        // Continue without schema validation
      }
    }

    // Prepare product data
    const productData = {
      asin,
      sku: finalSku, // Add SKU to product data
      seller_id: sellerId,
      title: title.trim(),
      description: description?.trim() || null,
      brand: brand.trim(),
      price,
      quantity: quantity || 0,
      status: status || "draft",
      category: category.trim(),
      subcategory: subcategory.trim(),
      attributes: attributes || {},
      brand_id: brandId || null,
      is_local_brand: isLocalBrand || false,
      images: images || [],
      color_hex: attributes?.color_hex || null,
      currency: currency || "USD",
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    // Insert product into database
    const { data: product, error: insertError } = await supabaseClient
      .from("products")
      .insert(productData)
      .select()
      .single();

    if (insertError) {
      console.error("Database insert error:", insertError);
      throw new Error(`Database error: ${insertError.message}`);
    }

    // Log successful creation with ASIN and SKU
    console.log(`✅ Product created: ASIN=${product.asin}, SKU=${product.sku}`);

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        message: "Product created successfully",
        asin: product.asin,
        sku: product.sku,
        seller_id: product.seller_id,
        product: product,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 201,
      },
    );
  } catch (error: any) {
    console.error("create-product error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || "An unexpected error occurred",
        code: error.code || "UNKNOWN_ERROR",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: error.message?.includes("Unauthorized") ? 401 : 400,
      },
    );
  }
});
