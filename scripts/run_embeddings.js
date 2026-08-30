// ═══════════════════════════════════════════════════════════
// CaseFlow RAG: Local Embedding Pipeline
// 
// Runs locally (no edge function timeout). Reads bare acts
// and templates from Supabase, generates Gemini embeddings,
// and stores them in legal_embeddings table.
//
// Usage: node scripts/run_embeddings.js
// ═══════════════════════════════════════════════════════════

const SUPABASE_URL = "https://asrjqsnyezvcakvkokcl.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzcmpxc255ZXp2Y2Frdmtva2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5NTQ1MjYsImV4cCI6MjA4NzUzMDUyNn0._W7YwzwxA2m83VxITvQMDVUSbTlnJi1Ij389Sxp-Mls";
const GEMINI_API_KEY = "AQ.Ab8RN6Jx0zJre_d_jJPGPs4a5fNgIGIyjs8cqll-P9WzZ6vczw";
const EMBEDDING_MODEL = "gemini-embedding-001";

// ─── Text Chunking ──────────────────────────────────────────
function chunkText(text, maxChars = 1500, overlap = 200) {
  if (text.length <= maxChars) return [text];
  const chunks = [];
  let start = 0;
  while (start < text.length) {
    let end = start + maxChars;
    if (end < text.length) {
      const lastPeriod = text.lastIndexOf(".", end);
      const lastSemicolon = text.lastIndexOf(";", end);
      const breakPoint = Math.max(lastPeriod, lastSemicolon);
      if (breakPoint > start + maxChars / 2) end = breakPoint + 1;
    }
    chunks.push(text.slice(start, end).trim());
    start = end - overlap;
  }
  return chunks.filter(c => c.length > 50);
}

// ─── Supabase REST helpers ──────────────────────────────────
async function supabaseGet(table, params = "") {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${params}`, {
    headers: {
      "apikey": SUPABASE_ANON_KEY,
      "Authorization": `Bearer ${SUPABASE_ANON_KEY}`,
    },
  });
  if (!res.ok) throw new Error(`Supabase GET ${table} failed: ${res.status} ${await res.text()}`);
  return res.json();
}

async function supabaseDelete(table, filters) {
  const params = Object.entries(filters).map(([k, v]) => `${k}=eq.${encodeURIComponent(v)}`).join("&");
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${params}`, {
    method: "DELETE",
    headers: {
      "apikey": SUPABASE_ANON_KEY,
      "Authorization": `Bearer ${SUPABASE_ANON_KEY}`,
    },
  });
  if (!res.ok) {
    const errText = await res.text();
    // Ignore "no rows deleted" type responses
    if (res.status !== 404) console.warn(`  ⚠ Delete warning: ${res.status} ${errText}`);
  }
}

async function supabaseInsert(table, data) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: "POST",
    headers: {
      "apikey": SUPABASE_ANON_KEY,
      "Authorization": `Bearer ${SUPABASE_ANON_KEY}`,
      "Content-Type": "application/json",
      "Prefer": "return=minimal",
    },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error(`Supabase INSERT ${table} failed: ${res.status} ${await res.text()}`);
}

// ─── RPC call ───────────────────────────────────────────────
async function supabaseRpc(fnName, params) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fnName}`, {
    method: "POST",
    headers: {
      "apikey": SUPABASE_ANON_KEY,
      "Authorization": `Bearer ${SUPABASE_ANON_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(params),
  });
  if (!res.ok) throw new Error(`Supabase RPC ${fnName} failed: ${res.status} ${await res.text()}`);
  return res.json();
}

// ─── Generate Embedding via Gemini ──────────────────────────
async function generateEmbedding(text, retries = 3) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${EMBEDDING_MODEL}:embedContent?key=${GEMINI_API_KEY}`;

  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: `models/${EMBEDDING_MODEL}`,
          content: { parts: [{ text }] },
          outputDimensionality: 768,
        }),
      });

      if (res.status === 429 || res.status >= 500) {
        console.log(`  ⏳ Rate limited / server error (attempt ${attempt}/${retries}), waiting 10s...`);
        await new Promise(r => setTimeout(r, 10000));
        continue;
      }

      if (!res.ok) {
        const err = await res.text();
        throw new Error(`Embedding API error ${res.status}: ${err}`);
      }

      const data = await res.json();
      return data.embedding.values;
    } catch (e) {
      if (attempt === retries) throw e;
      console.log(`  ⏳ Retry ${attempt}/${retries}: ${e.message}`);
      await new Promise(r => setTimeout(r, 5000));
    }
  }
}

// ─── Sleep helper ───────────────────────────────────────────
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

// ─── Main Pipeline ──────────────────────────────────────────
async function main() {
  console.log("═══════════════════════════════════════════════════");
  console.log("  CaseFlow RAG: Local Embedding Pipeline");
  console.log("═══════════════════════════════════════════════════\n");

  const startTime = Date.now();
  let totalEmbedded = 0;

  // ── 1. Process Bare Acts ──────────────────────────────────
  console.log("📚 Fetching Bare Acts...");
  const acts = await supabaseGet("bare_acts", "select=id,title,short_title&is_active=eq.true");
  console.log(`   Found ${acts.length} active acts\n`);

  for (const act of acts) {
    console.log(`📖 ${act.title}`);

    const sections = await supabaseGet(
      "bare_act_sections",
      `select=id,section_number,section_title,section_text&act_id=eq.${act.id}&order=sequence_order.asc`
    );

    if (!sections || sections.length === 0) {
      console.log("   (no sections found, skipping)\n");
      continue;
    }

    let actCount = 0;

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

          // Delete existing then insert (upsert)
          await supabaseDelete("legal_embeddings", { source_type: "bare_act", source_ref: sourceRef });

          await supabaseInsert("legal_embeddings", {
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

          actCount++;
          totalEmbedded++;

          // Rate limiting: pause every 5 embeddings
          if (totalEmbedded % 5 === 0) {
            process.stdout.write(`   ✓ ${actCount} chunks (${totalEmbedded} total)...\r`);
            await sleep(4000);
          }
        } catch (e) {
          console.error(`   ✗ Failed: ${sourceRef} — ${e.message}`);
        }
      }
    }

    console.log(`   ✓ ${actCount} chunks embedded for ${act.short_title || act.title}`);
  }

  // ── 2. Process Legal Templates ────────────────────────────
  console.log("\n📝 Fetching Legal Templates...");
  let templateCount = 0;

  try {
    const templates = await supabaseGet("legal_templates", "select=id,title,description,category,content");
    console.log(`   Found ${templates.length} templates\n`);

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

          await supabaseDelete("legal_embeddings", { source_type: "template", source_ref: sourceRef });

          await supabaseInsert("legal_embeddings", {
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
            embedding: embedding,
          });

          templateCount++;
          totalEmbedded++;

          if (totalEmbedded % 5 === 0) {
            await sleep(1500);
          }
        } catch (e) {
          console.error(`   ✗ Failed: ${sourceRef} — ${e.message}`);
        }
      }
    }

    console.log(`   ✓ ${templateCount} template chunks embedded`);
  } catch (e) {
    console.log(`   ⚠ Templates table not found or empty: ${e.message}`);
  }

  // ── Summary ───────────────────────────────────────────────
  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log("\n═══════════════════════════════════════════════════");
  console.log(`  ✅ DONE! Embedded ${totalEmbedded} chunks in ${elapsed}s`);
  console.log(`     Bare Acts: ${totalEmbedded - templateCount}`);
  console.log(`     Templates: ${templateCount}`);
  console.log("═══════════════════════════════════════════════════\n");
}

main().catch(e => {
  console.error("❌ Pipeline failed:", e);
  process.exit(1);
});
