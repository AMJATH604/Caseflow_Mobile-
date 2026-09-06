import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { verifyWebhookAuth } from "../_shared/auth_guard.ts";

// ═══════════════════════════════════════════════════════════
// CaseFlow RAG: Embedding Pipeline
// 
// Reads Bare Acts, Legal Templates, and Dictionary entries from
// Supabase and generates vector embeddings using Google's
// text-embedding-004 model. Stores them in legal_embeddings
// table for RAG similarity search.
//
// Run once (re-runnable — uses upsert logic).
// Invoke: POST /functions/v1/embedding-pipeline
// Auth: Requires service_role key
// ═══════════════════════════════════════════════════════════

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const EMBEDDING_MODEL = "gemini-embedding-001";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ─── Text Chunking ──────────────────────────────────────────
// Splits long text into ~500-token chunks with overlap for context continuity.
function chunkText(text: string, maxChars: number = 1500, overlap: number = 200): string[] {
  if (text.length <= maxChars) return [text];

  const chunks: string[] = [];
  let start = 0;

  while (start < text.length) {
    let end = start + maxChars;

    // Try to break at a sentence boundary
    if (end < text.length) {
      const lastPeriod = text.lastIndexOf(".", end);
      const lastSemicolon = text.lastIndexOf(";", end);
      const breakPoint = Math.max(lastPeriod, lastSemicolon);
      if (breakPoint > start + maxChars / 2) {
        end = breakPoint + 1;
      }
    }

    chunks.push(text.slice(start, end).trim());
    start = end - overlap;
  }

  return chunks.filter(c => c.length > 50); // Skip tiny fragments
}

// ─── Generate Embeddings via Google API ─────────────────────
async function generateEmbedding(text: string): Promise<number[]> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${EMBEDDING_MODEL}:embedContent?key=${GEMINI_API_KEY}`;
  
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: `models/${EMBEDDING_MODEL}`,
      content: { parts: [{ text }] },
      outputDimensionality: 768,
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Embedding API error ${response.status}: ${err}`);
  }

  const data = await response.json();
  return data.embedding.values;
}

// ─── Process Bare Acts ──────────────────────────────────────
async function processBareActs(supabase: any): Promise<number> {
  console.log("📚 Processing Bare Acts...");

  // Fetch all acts
  const { data: acts, error: actsError } = await supabase
    .from("bare_acts")
    .select("id, title, short_title")
    .eq("is_active", true);

  if (actsError || !acts) {
    console.error("Error fetching acts:", actsError);
    return 0;
  }

  let totalEmbedded = 0;

  for (const act of acts) {
    console.log(`  → Processing: ${act.title}`);

    // Fetch all sections for this act
    const { data: sections, error: secError } = await supabase
      .from("bare_act_sections")
      .select("id, section_number, section_title, section_text")
      .eq("act_id", act.id)
      .order("sequence_order", { ascending: true });

    if (secError || !sections) {
      console.error(`  ✗ Error fetching sections for ${act.title}:`, secError);
      continue;
    }

    for (const section of sections) {
      const fullText = section.section_text || "";
      if (!fullText || fullText.length < 20) continue;

      // Build the content string with rich context for better retrieval
      const sectionLabel = `${act.short_title || act.title} — Section ${section.section_number}: ${section.section_title || ""}`;
      const contentForEmbedding = `${sectionLabel}\n\n${fullText}`;

      // Chunk long sections
      const chunks = chunkText(contentForEmbedding);

      for (let i = 0; i < chunks.length; i++) {
        const chunk = chunks[i];
        const sourceRef = chunks.length > 1
          ? `${act.short_title || act.title} — Section ${section.section_number} (Part ${i + 1}/${chunks.length})`
          : `${act.short_title || act.title} — Section ${section.section_number}`;

        try {
          const embedding = await generateEmbedding(chunk);

          // Upsert (delete existing + insert) to make pipeline re-runnable
          await supabase
            .from("legal_embeddings")
            .delete()
            .eq("source_type", "bare_act")
            .eq("source_ref", sourceRef);

          await supabase
            .from("legal_embeddings")
            .insert({
              content: chunk,
              source_type: "bare_act",
              source_ref: sourceRef,
              act_id: act.id,
              section_id: section.id,
              metadata: {
                act_title: act.title,
                short_title: act.short_title,
                section_number: section.section_number,
                section_title: section.section_title,
                chunk_index: i,
                total_chunks: chunks.length,
              },
              embedding: `[${embedding.join(",")}]`,
            });

          totalEmbedded++;

          // Rate limit: ~300 RPM for embedding API
          if (totalEmbedded % 10 === 0) {
            await new Promise(r => setTimeout(r, 2000));
          }
        } catch (e) {
          console.error(`  ✗ Failed to embed ${sourceRef}:`, e);
        }
      }
    }

    console.log(`  ✓ ${act.title}: embedded ${sections.length} sections`);
  }

  return totalEmbedded;
}

// ─── Process Legal Templates ────────────────────────────────
async function processLegalTemplates(supabase: any): Promise<number> {
  console.log("📝 Processing Legal Templates...");

  const { data: templates, error } = await supabase
    .from("legal_templates")
    .select("id, title, description, category, content");

  if (error || !templates) {
    console.error("Error fetching templates:", error);
    return 0;
  }

  let count = 0;

  for (const template of templates) {
    const contentText = `Legal Template: ${template.title}\nCategory: ${template.category}\nDescription: ${template.description || ""}\n\n${template.content || ""}`;
    
    if (contentText.length < 30) continue;

    const chunks = chunkText(contentText);

    for (let i = 0; i < chunks.length; i++) {
      const sourceRef = chunks.length > 1
        ? `Template: ${template.title} (Part ${i + 1}/${chunks.length})`
        : `Template: ${template.title}`;

      try {
        const embedding = await generateEmbedding(chunks[i]);

        await supabase
          .from("legal_embeddings")
          .delete()
          .eq("source_type", "template")
          .eq("source_ref", sourceRef);

        await supabase
          .from("legal_embeddings")
          .insert({
            content: chunks[i],
            source_type: "template",
            source_ref: sourceRef,
            metadata: {
              title: template.title,
              category: template.category,
              description: template.description,
              chunk_index: i,
              total_chunks: chunks.length,
            },
            embedding: `[${embedding.join(",")}]`,
          });

        count++;

        if (count % 10 === 0) {
          await new Promise(r => setTimeout(r, 2000));
        }
      } catch (e) {
        console.error(`  ✗ Failed to embed template ${template.title}:`, e);
      }
    }
  }

  console.log(`  ✓ Embedded ${count} template chunks`);
  return count;
}

// ─── Main Handler ───────────────────────────────────────────
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Admin/cron operation: builds a service-role client and runs deletes and
  // inserts against legal_embeddings driven by the request body, while
  // billing embedding calls to the project's Gemini quota. The header claimed
  // "Requires service_role key" long before anything enforced it.
  const authError = await verifyWebhookAuth(req);
  if (authError) return authError;

  try {
    if (!GEMINI_API_KEY) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY not configured in environment" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
    const { target = "all", act_id = null } = body;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const startTime = Date.now();

    let bareActCount = 0;
    let templateCount = 0;

    if (target === "all" || target === "acts") {
      // Fetch specific act or all acts
      let query = supabase.from("bare_acts").select("id, title, short_title").eq("is_active", true);
      if (act_id) {
        query = query.eq("id", act_id);
      }
      const { data: acts } = await query;

      if (acts) {
        for (const act of acts) {
          const { data: sections } = await supabase
            .from("bare_act_sections")
            .select("id, section_number, section_title, section_text")
            .eq("act_id", act.id)
            .order("sequence_order", { ascending: true });

          if (!sections) continue;

          for (const section of sections) {
            const fullText = section.section_text || "";
            if (!fullText || fullText.length < 20) continue;

            const sectionLabel = `${act.short_title || act.title} — Section ${section.section_number}: ${section.section_title || ""}`;
            const contentForEmbedding = `${sectionLabel}\n\n${fullText}`;
            const chunks = chunkText(contentForEmbedding);

            for (let i = 0; i < chunks.length; i++) {
              const chunk = chunks[i];
              const sourceRef = chunks.length > 1
                ? `${act.short_title || act.title} — Section ${section.section_number} (Part ${i + 1}/${chunks.length})`
                : `${act.short_title || act.title} — Section ${section.section_number}`;

              try {
                const embedding = await generateEmbedding(chunk);
                await supabase.from("legal_embeddings").delete().eq("source_type", "bare_act").eq("source_ref", sourceRef);
                await supabase.from("legal_embeddings").insert({
                  content: chunk,
                  source_type: "bare_act",
                  source_ref: sourceRef,
                  act_id: act.id,
                  section_id: section.id,
                  metadata: {
                    act_title: act.title,
                    short_title: act.short_title,
                    section_number: section.section_number,
                    section_title: section.section_title,
                    chunk_index: i,
                    total_chunks: chunks.length,
                  },
                  embedding: embedding,
                });
                bareActCount++;
              } catch (e) {
                console.error(`Failed to embed ${sourceRef}:`, e);
              }
            }
          }
        }
      }
    }

    if (target === "all" || target === "templates") {
      templateCount = await processLegalTemplates(supabase);
    }

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);

    const summary = {
      success: true,
      target,
      embedded: {
        bare_acts: bareActCount,
        templates: templateCount,
        total: bareActCount + templateCount,
      },
      elapsed_seconds: parseFloat(elapsed),
    };

    console.log("✅ Embedding batch complete:", JSON.stringify(summary));
    return new Response(JSON.stringify(summary), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  } catch (e) {
    console.error("Pipeline error:", e);
    return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});

