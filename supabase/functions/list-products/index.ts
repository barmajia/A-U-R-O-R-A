// Supabase Edge Function: list-products
// Handles listing products with pagination, filtering, and search

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ListProductsRequest {
  page?: number;
  limit?: number;
  search?: string;
  status?: string;
  brand?: string;
  inStock?: boolean;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
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

    // Parse query parameters
    const url = new URL(req.url);
    const params: ListProductsRequest = {
      page: parseInt(url.searchParams.get("page") || "1"),
      limit: parseInt(url.searchParams.get("limit") || "20"),
      search: url.searchParams.get("search") || undefined,
      status: url.searchParams.get("status") || undefined,
      brand: url.searchParams.get("brand") || undefined,
      inStock: url.searchParams.get("inStock") === "true",
      sortBy: url.searchParams.get("sortBy") || "created_at",
      sortOrder: (url.searchParams.get("sortOrder") as 'asc' | 'desc') || "desc",
    };

    console.log(`List products request from user: ${user.id}`, params);

    // Build query
    let query = supabase
      .from("products")
      .select("*", { count: "exact" })
      .eq("seller_id", user.id)
      .eq("is_deleted", false);

    // Apply filters
    if (params.search) {
      query = query.or(`title.ilike.%${params.search}%,description.ilike.%${params.search}%,asin.ilike.%${params.search}%`);
    }

    if (params.status) {
      query = query.eq("status", params.status);
    }

    if (params.brand) {
      query = query.eq("brand", params.brand);
    }

    if (params.inStock) {
      query = query.gt("quantity", 0);
    }

    // Apply sorting
    query = query.order(params.sortBy!, { ascending: params.sortOrder === "asc" });

    // Apply pagination
    const from = (params.page! - 1) * params.limit!;
    const to = from + params.limit! - 1;
    query = query.range(from, to);

    const { data: products, error, count } = await query;

    if (error) throw error;

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          products,
          pagination: {
            page: params.page,
            limit: params.limit,
            total: count,
            totalPages: Math.ceil((count || 0) / params.limit!),
          },
        },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );

  } catch (error) {
    console.error("Error in list-products:", error);

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
