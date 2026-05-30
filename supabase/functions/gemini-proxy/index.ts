import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── Security: API Key from environment ONLY (no fallback) ──────────
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_MODEL = "gemini-2.5-flash";

// ─── Rate Limiting: Per-user request tracking ───────────────────────
// In-memory rate limiter (resets on cold start, which is acceptable for Edge Functions)
const rateLimitStore = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT_MAX = 30;          // Max requests per window
const RATE_LIMIT_WINDOW_MS = 3600000; // 1 hour window

function checkRateLimit(userId: string): { allowed: boolean; remaining: number } {
  const now = Date.now();
  const entry = rateLimitStore.get(userId);

  if (!entry || now > entry.resetAt) {
    rateLimitStore.set(userId, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return { allowed: true, remaining: RATE_LIMIT_MAX - 1 };
  }

  if (entry.count >= RATE_LIMIT_MAX) {
    return { allowed: false, remaining: 0 };
  }

  entry.count++;
  return { allowed: true, remaining: RATE_LIMIT_MAX - entry.count };
}

// ─── Input Sanitization ─────────────────────────────────────────────
const MAX_PROMPT_LENGTH = 10000;  // 10K character limit
const MAX_BODY_SIZE_MB = 5;       // 5MB max request body (for images)

// Known prompt injection patterns to detect and block
const INJECTION_PATTERNS = [
  /ignore\s+(all\s+)?previous\s+instructions/i,
  /disregard\s+(all\s+)?(your\s+)?instructions/i,
  /forget\s+(all\s+)?(your\s+)?instructions/i,
  /you\s+are\s+now\s+(?:a|an)\s+(?!caseflow)/i,
  /system\s*:\s*/i,
  /\[INST\]/i,
  /<<SYS>>/i,
];

function sanitizePrompt(prompt: string): { safe: boolean; reason?: string } {
  if (!prompt || typeof prompt !== "string") {
    return { safe: false, reason: "Prompt must be a non-empty string" };
  }

  if (prompt.length > MAX_PROMPT_LENGTH) {
    return { safe: false, reason: `Prompt exceeds maximum length of ${MAX_PROMPT_LENGTH} characters` };
  }

  for (const pattern of INJECTION_PATTERNS) {
    if (pattern.test(prompt)) {
      return { safe: false, reason: "Prompt contains disallowed patterns" };
    }
  }

  return { safe: true };
}

// ─── CORS Configuration ─────────────────────────────────────────────
const ALLOWED_ORIGINS = [
  "https://asrjqsnyezvcakvkokcl.supabase.co",  // Supabase project
  "http://localhost:5173",                        // Local dashboard dev
  "http://localhost:3000",                        // Alternative local dev
];

function getCorsHeaders(origin: string | null): Record<string, string> {
  // For mobile apps (Flutter), origin is null — allow those
  // For web requests, validate against allowed origins
  const allowedOrigin = !origin || ALLOWED_ORIGINS.includes(origin)
    ? (origin || "*")
    : ALLOWED_ORIGINS[0]; // Fallback to primary

  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin");
  const corsHeaders = getCorsHeaders(origin);

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  try {
    // ─── Auth Check ───────────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    
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
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ─── Rate Limiting ────────────────────────────────────────
    const rateCheck = checkRateLimit(user.id);
    if (!rateCheck.allowed) {
      return new Response(
        JSON.stringify({ 
          error: "Rate limit exceeded. Maximum 30 AI requests per hour.",
          retryAfter: "3600"
        }),
        { 
          status: 429, 
          headers: { 
            ...corsHeaders, 
            "Content-Type": "application/json",
            "Retry-After": "3600",
            "X-RateLimit-Remaining": "0",
          } 
        }
      );
    }

    // ─── Request Size Check ───────────────────────────────────
    const contentLength = parseInt(req.headers.get("content-length") || "0");
    if (contentLength > MAX_BODY_SIZE_MB * 1024 * 1024) {
      return new Response(
        JSON.stringify({ error: `Request body exceeds ${MAX_BODY_SIZE_MB}MB limit` }),
        { status: 413, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json();
    const { prompt, history, image, mimeType, stream: useStream } = body;

    if (!prompt && !image) {
      return new Response(JSON.stringify({ error: "Missing 'prompt' or 'image' in request body" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ─── API Key Check ────────────────────────────────────────
    if (!GEMINI_API_KEY) {
      console.error("GEMINI_API_KEY not configured in Supabase secrets");
      return new Response(JSON.stringify({ error: "AI service not configured. Contact admin." }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ─── Input Sanitization ───────────────────────────────────
    if (prompt) {
      const sanitizeResult = sanitizePrompt(prompt);
      if (!sanitizeResult.safe) {
        return new Response(
          JSON.stringify({ error: sanitizeResult.reason }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    console.log(`[AI] ${useStream ? 'stream' : 'standard'} | user: ${user.id.substring(0, 8)}... | remaining: ${rateCheck.remaining}`);

    // Build the request contents
    const contents = [...(history || [])];

    const currentParts: any[] = [];
    
    if (image && mimeType) {
      currentParts.push({
        inlineData: {
          mimeType: mimeType,
          data: image
        }
      });
    }

    currentParts.push({ text: prompt || "Analyze this image" });
    contents.push({ role: "user", parts: currentParts });

    const requestBody = JSON.stringify({ 
      contents, 
      generationConfig: { 
        temperature: 0.15,
        topP: 0.95,
        topK: 40,
        maxOutputTokens: 4096,  // Increased from 2048 for detailed legal analysis
      } 
    });

    // ─── STREAMING MODE ─────────────────────────────────────
    if (useStream) {
      const streamUrl = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:streamGenerateContent?alt=sse&key=${GEMINI_API_KEY}`;
      
      const geminiResponse = await fetch(streamUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: requestBody,
      });

      if (!geminiResponse.ok) {
        const errText = await geminiResponse.text();
        console.error(`Gemini Stream API Error: ${geminiResponse.status} - ${errText}`);
        return new Response(
          JSON.stringify({ error: "AI service temporarily unavailable", details: errText }), 
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(geminiResponse.body, {
        headers: {
          ...corsHeaders,
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          "Connection": "keep-alive",
          "X-RateLimit-Remaining": String(rateCheck.remaining),
        },
      });
    }

    // ─── STANDARD (NON-STREAMING) MODE ──────────────────────
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: requestBody,
      }
    );

    if (!response.ok) {
      const errText = await response.text();
      console.error(`Gemini API Error: ${response.status} - ${errText}`);
      return new Response(
        JSON.stringify({ error: "AI service temporarily unavailable", details: errText }), 
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text || "I apologize, I could not generate a response.";
    
    return new Response(
      JSON.stringify({ 
        text, 
        model: GEMINI_MODEL,
        usage: data.usageMetadata,
        rateLimitRemaining: rateCheck.remaining,
      }),
      { 
        headers: { 
          ...corsHeaders, 
          "Content-Type": "application/json",
          "X-RateLimit-Remaining": String(rateCheck.remaining),
        } 
      }
    );

  } catch (error) {
    console.error("Critical Proxy Error:", error.message);
    return new Response(JSON.stringify({ error: "Internal server error" }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
