// Supabase Edge Function: process-signup
// Handles user signup with seller/factory profile creation

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
  companyName?: string;
  businessLicense?: string;
  latitude?: number;
  longitude?: number;
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
      companyName,
      businessLicense,
      latitude,
      longitude,
    } = data;

    console.log("Processing signup for:", email, "Account Type:", accountType);

    // Validate required fields
    if (!userId || !email || !fullName) {
      throw new Error("Missing required fields");
    }

    // Parse full name into parts
    const nameParts = fullName.split(" ");
    const firstName = nameParts[0] || "";
    const secondName = nameParts[1] || "";
    const thirdName = nameParts[2] || "";
    const fourthName = nameParts[3] || "";

    // Create profile based on account type
    if (accountType === "seller") {
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

    // If account type is factory, create factory profile
    if (accountType === "factory") {
      // Create factory record in database
      const { data: factory, error: factoryError } = await supabase
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
          account_type: "factory",
          is_verified: false,
          company_name: companyName || null,
          business_license: businessLicense || null,
          latitude: latitude || null,
          longitude: longitude || null,
          created_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (factoryError) {
        console.error("Error creating factory profile:", factoryError);
        throw new Error(`Failed to create factory profile: ${factoryError.message}`);
      }

      console.log("Factory profile created successfully:", factory.user_id);

      return new Response(
        JSON.stringify({
          success: true,
          message: "Factory account created successfully",
          data: {
            userId,
            email,
            factoryId: factory.id,
          },
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    // For other account types, just return success
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
