// Supabase Edge Function: process-signup
// Handles user signup with seller profile creation

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface SignupData {
  userId: string;
  email: string;
  fullName: string;
  accountType: string;
  phone: string;
  location: string;
  currency: string;
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
    const data: SignupData = await req.json();
    const {
      userId,
      email,
      fullName,
      accountType,
      phone,
      location,
      currency,
    } = data;

    console.log("Processing signup for:", email, "Account Type:", accountType);

    // Validate required fields
    if (!userId || !email || !fullName) {
      throw new Error("Missing required fields");
    }

    // If account type is seller, create seller profile
    if (accountType === "seller") {
      // Parse full name into parts
      const nameParts = fullName.split(" ");
      const firstName = nameParts[0] || "";
      const secondName = nameParts[1] || "";
      const thirdName = nameParts[2] || "";
      const fourthName = nameParts[3] || "";

      // Create seller record in database
      const { data: seller, error: sellerError } = await supabase
        .from("sellers")
        .insert({
          user_id: userId,
          email: email,
          full_name: fullName,
          firstname: firstName,
          secoundname: secondName,
          thirdname: thirdName,
          forthname: fourthName,
          phone: phone,
          location: location,
          currency: currency,
          account_type: "seller",
          is_verified: false,
          created_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (sellerError) {
        console.error("Error creating seller profile:", sellerError);
        throw new Error(`Failed to create seller profile: ${sellerError.message}`);
      }

      console.log("Seller profile created successfully:", seller.user_id);

      // Optionally: Send welcome email
      // await sendWelcomeEmail(email, fullName);

      return new Response(
        JSON.stringify({
          success: true,
          message: "Seller account created successfully",
          data: {
            userId,
            email,
            sellerId: seller.id,
          },
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    // For regular users, just return success
    return new Response(
      JSON.stringify({
        success: true,
        message: "Account created successfully",
        data: {
          userId,
          email,
          accountType,
        },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error in process-signup:", error);
    
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
