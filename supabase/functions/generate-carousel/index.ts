import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
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
    if (!GEMINI_API_KEY) {
      throw new Error("GEMINI_API_KEY environment variable is not set");
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const prompt = `
      Generate exactly 8 highly educational and engaging daily legal cards (slides) for Indian citizens to learn about their laws, rights, and landmarks.
      The output must contain a diverse mix of categories:
      - ⚖️ LEGAL WORD OF THE DAY (e.g. Latin terms, legal vocabulary)
      - 📜 CONSTITUTIONAL FACT (fundamental rights, interesting articles, duties)
      - 💡 LEGAL TIP (police interactions, consumer rights, filing FIRs, Zero FIR)
      - 🏛️ LANDMARK CASE (landmark judgements of Supreme Court of India like Kesavananda Bharati, Maneka Gandhi, etc.)
      - 💡 KNOW YOUR RIGHT (RTI, women's rights, labor laws, child rights)

      For each card, generate comprehensive and detailed explanations. Ensure legal accuracy. Reference new criminal laws if applicable (BNS, BNSS, BSA).

      Return the data strictly as JSON matching this schema:
      {
        "slides": [
          {
            "type": "⚖️ LEGAL WORD OF THE DAY",
            "title": "Sub Judice",
            "body": "A matter currently under trial or consideration by a court of law.",
            "gradient_colors": ["#7C3AED", "#A855F7"],
            "icon_name": "translate_rounded",
            "action": "Learn More",
            "detail_title": "Sub Judice Rule",
            "detail_body": "Sub Judice is Latin for 'under judgment'. It refers to a case or matter that is currently under trial or active consideration by a judge or court.\\n\\nOnce a matter is sub judice, public discussion, media trials, or publication of opinions that could influence or prejudice the jury or judge are legally restricted to ensure a fair trial and uphold the integrity of the judicial process.",
            "custom_route_path": "/citizen-tools",
            "tool_id": "legal_dictionary"
          }
        ]
      }

      Strict Constraints:
      1. 'gradient_colors' must contain exactly two hex color strings. Select from the following modern combinations:
         - Purple/Lavender: ["#7C3AED", "#A855F7"]
         - Amber/Orange: ["#B45309", "#D97706"]
         - Emerald/Teal: ["#065F46", "#10B981"]
         - Blue/Indigo: ["#1E40AF", "#6366F1"]
         - Red/Crimson: ["#991B1B", "#DC2626"]
         - Cyan/Teal: ["#0E7490", "#06B6D4"]
         - Violet/Fuchsia: ["#6B21A8", "#9333EA"]
         - Indigo/Cyan: ["#4F46E5", "#06B6D4"]
      2. 'icon_name' must be exactly one of: "balance_rounded", "translate_rounded", "account_balance_rounded", "tips_and_updates_rounded", "spellcheck_rounded", "gavel_rounded", "info_rounded", "record_voice_over_rounded", "menu_book_rounded".
      3. 'custom_route_path' must be "/know-your-rights" or "/citizen-tools".
      4. 'tool_id' must be one of: "bare_acts", "legal_dictionary", "court-fee", or null. Omit or set to null if no tool is relevant.
      5. The generated cards must change daily. Make the topics diverse, spanning civil rights, criminal procedures, consumer rights, constitutional principles, and fundamental legal terms.
    `;

    console.log("Calling Gemini API to generate daily slides...");
    const url = "https://generativelanguage.googleapis.com/v1beta/models/" + GEMINI_MODEL + ":generateContent?key=" + GEMINI_API_KEY;
    const geminiResponse = await fetch(
      url,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.85,
            responseMimeType: "application/json",
            responseSchema: {
              type: "OBJECT",
              properties: {
                slides: {
                  type: "ARRAY",
                  items: {
                    type: "OBJECT",
                    properties: {
                      type: { type: "STRING" },
                      title: { type: "STRING" },
                      body: { type: "STRING" },
                      gradient_colors: {
                        type: "ARRAY",
                        items: { type: "STRING" }
                      },
                      icon_name: { type: "STRING" },
                      action: { type: "STRING" },
                      detail_title: { type: "STRING" },
                      detail_body: { type: "STRING" },
                      custom_route_path: { type: "STRING" },
                      tool_id: { type: "STRING", nullable: true }
                    },
                    required: ["type", "title", "body", "gradient_colors", "icon_name", "action", "detail_title", "detail_body", "custom_route_path"]
                  }
                }
              },
              required: ["slides"]
            }
          }
        })
      }
    );

    if (!geminiResponse.ok) {
      const errText = await geminiResponse.text();
      throw new Error("Gemini API returned error: " + geminiResponse.status + " - " + errText);
    }

    const result = await geminiResponse.json();
    const responseText = result.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!responseText) {
      throw new Error("Empty response from Gemini API");
    }

    const { slides } = JSON.parse(responseText);
    if (!slides || !Array.isArray(slides) || slides.length === 0) {
      throw new Error("Invalid or empty slides array generated by Gemini");
    }

    console.log("Successfully generated " + slides.length + " slides. Updating database...");

    // We mark all existing active slides as inactive
    const { error: deactivateError } = await supabase
      .from("carousel_slides")
      .update({ active: false })
      .eq("active", true);

    if (deactivateError) {
      console.warn("Failed to deactivate old slides:", deactivateError.message);
    }

    // Insert new slides
    const newSlides = slides.map(slide => ({
      ...slide,
      active: true,
      created_at: new Date().toISOString()
    }));

    const { error: insertError } = await supabase
      .from("carousel_slides")
      .insert(newSlides);

    if (insertError) {
      throw new Error("Failed to insert new slides: " + insertError.message);
    }

    // Keep database size healthy: delete inactive slides older than 14 days
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 14);
    const { error: deleteError } = await supabase
      .from("carousel_slides")
      .delete()
      .eq("active", false)
      .lt("created_at", cutoffDate.toISOString());

    if (deleteError) {
      console.warn("Failed to clean up old inactive slides:", deleteError.message);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Generated and inserted " + newSlides.length + " new carousel slides.",
        slides: newSlides
      }),
      { headers: corsHeaders }
    );
  } catch (error) {
    console.error("Error in generate-carousel function:", error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: corsHeaders }
    );
  }
});
