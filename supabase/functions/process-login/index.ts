// Supabase Edge Function: process-login
// Handles seller login with verification

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface LoginData {
  userId: string;
  email: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Create Supabase client with admin key
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Parse request body
    const data: LoginData = await req.json();
    const { userId, email } = data;

    console.log("Processing login for:", email);

    // Validate required fields
    if (!userId || !email) {
      throw new Error("Missing required fields");
    }

    // Check if user exists in sellers table
    const { data: seller, error: sellerError } = await supabase
      .from("sellers")
      .select("*")
      .eq("user_id", userId)
      .eq("email", email)
      .maybeSingle();

    if (sellerError) {
      console.error("Error checking seller:", sellerError);
      throw new Error("Failed to verify seller account");
    }

    if (!seller) {
      return new Response(
        JSON.stringify({
          success: false,
          message: "Seller account not found. Please register as a seller first.",
          isSeller: false,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 404,
        }
      );
    }

    // Check if seller is verified (optional - you can enforce this)
    // if (!seller.is_verified) {
    //   return new Response(
    //     JSON.stringify({
    //       success: false,
    //       message: "Account not verified yet. Please wait for admin approval.",
    //       isSeller: true,
    //       isVerified: false,
    //     }),
    //     {
    //       headers: { ...corsHeaders, "Content-Type": "application/json" },
    //       status: 403,
    //     }
    //   );
    // }

    // Update last login timestamp
    await supabase
      .from("sellers")
      .update({
        last_login: new Date().toISOString(),
      })
      .eq("user_id", userId);

    console.log("Seller login successful:", seller.user_id);

    return new Response(
      JSON.stringify({
        success: true,
        message: "Seller login verified",
        isSeller: true,
        isVerified: seller.is_verified,
        data: {
          userId: seller.user_id,
          email: seller.email,
          fullName: seller.full_name,
          storeName: seller.store_name,
          accountType: seller.account_type,
        },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error in process-login:", error);
    
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
