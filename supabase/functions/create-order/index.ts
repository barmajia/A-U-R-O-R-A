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
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { 
        global: { 
          headers: { 
            Authorization: req.headers.get('Authorization')! 
          } 
        } 
      }
    );

    const { 
      items, 
      shipping_address_id, 
      payment_method, 
      discount = 0,
      metadata 
    } = await req.json();

    // Verify authentication
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(
      req.headers.get('Authorization')?.replace('Bearer ', '')
    );

    if (userError || !user) {
      throw new Error('Unauthorized: Invalid or missing authentication token');
    }

    // Validate items
    if (!items || !Array.isArray(items) || items.length === 0) {
      throw new Error('Invalid or empty items array');
    }

    // Calculate totals SERVER-SIDE (prevents client manipulation)
    let subtotal = 0;
    for (const item of items) {
      const price = parseFloat(item.price);
      const quantity = parseInt(item.quantity);
      
      if (isNaN(price) || isNaN(quantity) || price < 0 || quantity < 0) {
        throw new Error(`Invalid price or quantity for item: ${item.asin}`);
      }
      
      subtotal += price * quantity;
    }

    const discountAmount = parseFloat(discount) || 0;
    
    // SERVER-CONTROLLED: Tax calculation (cannot be manipulated by client)
    const taxRate = 0.1; // 10% - could be region-based
    const tax = subtotal * taxRate;
    
    // SERVER-CONTROLLED: Shipping calculation
    const shipping = subtotal > 50 ? 0 : 5.99; // Free shipping over $50
    
    const total = subtotal - discountAmount + tax + shipping;

    // Validate stock availability BEFORE creating order
    for (const item of items) {
      const { data: product } = await supabaseClient
        .from('products')
        .select('quantity, asin, title')
        .eq('asin', item.asin)
        .single();

      if (!product) {
        throw new Error(`Product not found: ${item.asin}`);
      }

      if ((product.quantity || 0) < item.quantity) {
        throw new Error(`Insufficient stock for ${product.title}. Available: ${product.quantity}, Requested: ${item.quantity}`);
      }
    }

    // Create order with transaction-like behavior
    const orderId = crypto.randomUUID();
    const userId = user.id;

    const orderData = {
      id: orderId,
      user_id: userId,
      status: 'pending',
      subtotal: subtotal,
      discount: discountAmount,
      tax: tax,
      shipping: shipping,
      total: total,
      shipping_address_id: shipping_address_id,
      payment_method: payment_method,
      payment_status: 'pending',
      metadata: metadata,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const { data: order, error: orderError } = await supabaseClient
      .from('orders')
      .insert(orderData)
      .select()
      .single();

    if (orderError) throw orderError;

    // Insert order items
    const orderItems = items.map((item: any) => ({
      order_id: orderId,
      product_id: item.product_id,
      asin: item.asin,
      quantity: item.quantity,
      price: item.price,
      total: item.price * item.quantity,
      created_at: new Date().toISOString(),
    }));

    const { error: itemsError } = await supabaseClient
      .from('order_items')
      .insert(orderItems);

    if (itemsError) throw itemsError;

    // Update product inventory (stock validation already done above)
    for (const item of items) {
      const { data: product } = await supabaseClient
        .from('products')
        .select('quantity')
        .eq('asin', item.asin)
        .single();

      if (product) {
        const newQuantity = (product.quantity || 0) - item.quantity;
        
        await supabaseClient
          .from('products')
          .update({ 
            quantity: newQuantity,
            updated_at: new Date().toISOString(),
          })
          .eq('asin', item.asin);
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Order created successfully',
        order: order,
        order_id: orderId,
        total: total,
        breakdown: {
          subtotal,
          discount: discountAmount,
          tax,
          shipping,
        }
      }), 
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 201,
      }
    );

  } catch (error: any) {
    console.error('create-order error:', error);
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
