import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "AIzaSyDRgOpQ3L-Y72VZY4kKUNH_vOKQPKaaO3g";
// Using Gemini 2.5 Flash for state-of-the-art vision support
const GEMINI_MODEL = "gemini-2.5-flash";

Deno.serve(async (req: Request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Content-Type": "application/json",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), { status: 401, headers: corsHeaders });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    
    // Create Supabase client with the user's JWT to ensure authentication
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ 
          error: "Authentication Failed", 
          details: authError?.message || "User session invalid" 
        }), 
        { status: 401, headers: corsHeaders }
      );
    }

    const body = await req.json();
    const { prompt, history, image, mimeType } = body;

    if (!prompt && !image) {
      return new Response(JSON.stringify({ error: "Missing 'prompt' or 'image' in request body" }), { status: 400, headers: corsHeaders });
    }

    if (!GEMINI_API_KEY) {
      return new Response(JSON.stringify({ error: "GEMINI_API_KEY not configured in Supabase secrets" }), { status: 500, headers: corsHeaders });
    }

    console.log(`Processing multimodal request for user: ${user.id}`);

    // Build the request contents
    const contents = [...(history || [])];

    // Current message parts
    const currentParts: any[] = [];
    
    // Add image if provided (Multimodal)
    if (image && mimeType) {
      currentParts.push({
        inlineData: {
          mimeType: mimeType,
          data: image // Expected to be base64 string
        }
      });
    }

    // Add text prompt
    currentParts.push({ text: prompt || "Analyze this image" });

    // Append to contents
    contents.push({ role: "user", parts: currentParts });

    // Call Google Gemini API (v1beta for advanced models)
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ 
          contents, 
          generationConfig: { 
            temperature: 0.15,
            topP: 0.95,
            topK: 40,
            maxOutputTokens: 2048,
          } 
        }),
      }
    );

    if (!response.ok) {
      const errText = await response.text();
      console.error(`Gemini API Error: ${response.status} - ${errText}`);
      return new Response(
        JSON.stringify({ error: "Gemini API failure", details: errText }), 
        { status: 500, headers: corsHeaders }
      );
    }

    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text || "I apologize, I could not generate a response.";
    
    return new Response(
      JSON.stringify({ 
        text, 
        model: GEMINI_MODEL,
        usage: data.usageMetadata 
      }),
      { headers: corsHeaders }
    );

  } catch (error) {
    console.error("Critical Proxy Error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders });
  }
});
