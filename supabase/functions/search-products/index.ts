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
    // Initialize Supabase client with anon key (respects RLS)
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: {
            Authorization: req.headers.get('Authorization')!,
          },
        },
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
      offset = 0,
    } = await req.json();

    // Validate required fields
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

    // Build query with RLS compliance (filters by seller_id)
    let dbQuery = supabaseClient
      .from('products')
      .select('*', { count: 'exact' })
      .eq('seller_id', sellerId)
      .eq('is_deleted', false); // Exclude soft-deleted products

    // Apply text search if query provided
    if (query && query.trim()) {
      // Use ilike for case-insensitive partial match on title and description
      dbQuery = dbQuery.or(`title.ilike.%${query}%,description.ilike.%${query}%`);
    }

    // Apply category filter
    if (category) {
      dbQuery = dbQuery.eq('category', category);
    }

    // Apply subcategory filter
    if (subcategory) {
      dbQuery = dbQuery.eq('subcategory', subcategory);
    }

    // Apply brand filter
    if (brand) {
      dbQuery = dbQuery.eq('brand', brand);
    }

    // Apply status filter
    if (status) {
      dbQuery = dbQuery.eq('status', status);
    }

    // Apply price filters
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
    const rangeStart = offset;
    const rangeEnd = offset + limit - 1;
    dbQuery = dbQuery.range(rangeStart, rangeEnd);

    // Order by created_at descending (newest first)
    dbQuery = dbQuery.order('created_at', { ascending: false });

    // Execute query
    const { data: products, error: searchError, count } = await dbQuery;

    if (searchError) {
      console.error('Database search error:', searchError);
      throw new Error(`Database error: ${searchError.message}`);
    }

    // Calculate hasMore
    const total = count || 0;
    const hasMore = total > (offset + limit);

    return new Response(
      JSON.stringify({
        success: true,
        products: products || [],
        count: total,
        limit,
        offset,
        hasMore,
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
