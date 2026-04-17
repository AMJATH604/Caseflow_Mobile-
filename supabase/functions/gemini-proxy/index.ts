// Supabase Edge Function: gemini-proxy
// Proxies Gemini API calls to keep the API key server-side.
//
// Deploy: supabase functions deploy gemini-proxy
// Set secret: supabase secrets set GEMINI_API_KEY=your_key_here
//
// Client calls this function instead of Google directly,
// so the API key never leaves the server.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const GEMINI_MODEL = "gemini-2.0-flash";

Deno.serve(async (req: Request) => {
  // CORS headers for Flutter client
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Content-Type": "application/json",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Verify the user is authenticated via Supabase JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: corsHeaders }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: corsHeaders }
      );
    }

    // Parse request body
    const body = await req.json();
    const { prompt, systemInstruction, history } = body;

    if (!prompt) {
      return new Response(
        JSON.stringify({ error: "Missing 'prompt' in request body" }),
        { status: 400, headers: corsHeaders }
      );
    }

    // Build Gemini API request
    const contents: any[] = [];

    // Add conversation history if provided
    if (history && Array.isArray(history)) {
      contents.push(...history);
    }

    // Add current user message
    contents.push({
      role: "user",
      parts: [{ text: prompt }],
    });

    const geminiBody: any = { contents };

    // Add system instruction if provided
    if (systemInstruction) {
      geminiBody.systemInstruction = {
        parts: [{ text: systemInstruction }],
      };
    }

    // Call Gemini API
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(geminiBody),
      }
    );

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error(`Gemini API error: ${geminiResponse.status} - ${errorText}`);
      return new Response(
        JSON.stringify({ error: "Gemini API request failed", details: errorText }),
        { status: geminiResponse.status, headers: corsHeaders }
      );
    }

    const geminiData = await geminiResponse.json();

    // Extract the text response
    const text = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text || "";

    return new Response(
      JSON.stringify({
        text,
        model: GEMINI_MODEL,
        usage: geminiData?.usageMetadata,
      }),
      { headers: corsHeaders }
    );
  } catch (error) {
    console.error("Error:", error.message);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
