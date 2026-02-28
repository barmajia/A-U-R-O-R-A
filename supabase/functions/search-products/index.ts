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
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { 
        global: { 
          headers: { 
            Authorization: req.headers.get('Authorization')! 
          } 
        } 
      }
    );

    const { 
      query, 
      category, 
      subcategory, 
      brand, 
      minPrice, 
      maxPrice, 
      attributes, 
      status,
      sellerId,
      limit = 100,
      offset = 0
    } = await req.json();

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

    // Build query
    let dbQuery = supabaseClient
      .from('products')
      .select('*', { count: 'exact' })
      .eq('seller_id', sellerId);

    // Apply filters
    if (query) {
      // Full-text search on title_description tsvector
      dbQuery = dbQuery.textSearch('title_description', query, {
        config: 'english',
        type: 'plainto_tsquery'
      });
    }

    if (category) {
      dbQuery = dbQuery.eq('category', category);
    }

    if (subcategory) {
      dbQuery = dbQuery.eq('subcategory', subcategory);
    }

    if (brand) {
      dbQuery = dbQuery.eq('brand', brand);
    }

    if (status) {
      dbQuery = dbQuery.eq('status', status);
    }

    if (minPrice !== undefined && minPrice !== null) {
      dbQuery = dbQuery.gte('price', minPrice);
    }

    if (maxPrice !== undefined && maxPrice !== null) {
      dbQuery = dbQuery.lte('price', maxPrice);
    }

    // Filter by JSONB attributes
    if (attributes && typeof attributes === 'object') {
      for (const [key, value] of Object.entries(attributes)) {
        if (value !== null && value !== undefined) {
          dbQuery = dbQuery.eq(`attributes->>${key}`, String(value));
        }
      }
    }

    // Apply pagination
    dbQuery = dbQuery.range(offset, offset + limit - 1);

    // Order by created_at descending (newest first)
    dbQuery = dbQuery.order('created_at', { ascending: false });

    // Execute query
    const { data, error, count } = await dbQuery;

    if (error) {
      console.error('Database search error:', error);
      throw error;
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        products: data || [],
        count: count || 0,
        limit,
        offset,
        hasMore: (count || 0) > (offset + limit)
      }), 
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );

  } catch (error: any) {
    console.error('search-products error:', error);
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
