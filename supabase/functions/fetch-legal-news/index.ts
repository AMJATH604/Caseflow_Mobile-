import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { verifyWebhookAuth } from "../_shared/auth_guard.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── RSS Feed Sources ────────────────────────────────────────────────
const FEEDS = [
  {
    url: "https://www.barandbench.com/feed",
    source: "barandbench",
    defaultCategory: "general",
  },
  {
    url: "https://www.livelaw.in/feed",
    source: "livelaw",
    defaultCategory: "general",
  },
];

// ─── Category Classifier ────────────────────────────────────────────
function classifyCategory(title: string): string {
  const t = title.toLowerCase();
  if (t.includes("supreme court")) return "supreme_court";
  if (t.includes("high court") || t.includes("hc ")) return "high_court";
  if (t.includes("bail")) return "bail";
  if (t.includes("fir") || t.includes("criminal") || t.includes("arrest"))
    return "criminal";
  if (
    t.includes("property") ||
    t.includes("land") ||
    t.includes("partition")
  )
    return "property";
  if (t.includes("family") || t.includes("divorce") || t.includes("maintenance"))
    return "family";
  if (
    t.includes("tax") ||
    t.includes("gst") ||
    t.includes("income tax") ||
    t.includes("customs")
  )
    return "tax";
  if (t.includes("arbitration") || t.includes("mediation"))
    return "arbitration";
  if (t.includes("constitution") || t.includes("fundamental right"))
    return "constitutional";
  if (t.includes("ibc") || t.includes("insolvency") || t.includes("nclt"))
    return "insolvency";
  if (t.includes("cyber") || t.includes("it act") || t.includes("data"))
    return "cyber";
  if (
    t.includes("bar council") ||
    t.includes("advocate") ||
    t.includes("legal profession")
  )
    return "legal_profession";
  return "general";
}

// ─── Minimal XML Parser (no deps) ───────────────────────────────────
function extractTag(xml: string, tag: string): string {
  // Handle CDATA sections
  const cdataPattern = new RegExp(
    `<${tag}[^>]*>\\s*<!\\[CDATA\\[([\\s\\S]*?)\\]\\]>\\s*</${tag}>`,
    "i"
  );
  const cdataMatch = xml.match(cdataPattern);
  if (cdataMatch) return cdataMatch[1].trim();

  const pattern = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, "i");
  const match = xml.match(pattern);
  return match ? match[1].trim() : "";
}

function extractImageUrl(itemXml: string): string | null {
  // Try media:content
  const mediaMatch = itemXml.match(/url="(https?:\/\/[^"]+\.(jpg|jpeg|png|webp)[^"]*)"/i);
  if (mediaMatch) return mediaMatch[1];

  // Try enclosure
  const enclosureMatch = itemXml.match(/<enclosure[^>]+url="(https?:\/\/[^"]+)"/i);
  if (enclosureMatch) return enclosureMatch[1];

  // Try image in description/content
  const imgMatch = itemXml.match(/<img[^>]+src="(https?:\/\/[^"]+)"/i);
  if (imgMatch) return imgMatch[1];

  return null;
}

function parseRssItems(xml: string): Array<{
  title: string;
  link: string;
  summary: string;
  imageUrl: string | null;
  publishedAt: string | null;
}> {
  const items: Array<{
    title: string;
    link: string;
    summary: string;
    imageUrl: string | null;
    publishedAt: string | null;
  }> = [];

  // Split by <item> tags
  const itemRegex = /<item[\s>]([\s\S]*?)<\/item>/gi;
  let match;

  while ((match = itemRegex.exec(xml)) !== null) {
    const itemXml = match[1];
    const title = extractTag(itemXml, "title")
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"')
      .replace(/&#039;/g, "'")
      .replace(/<[^>]*>/g, ""); // Strip any remaining HTML

    const link = extractTag(itemXml, "link").replace(/<[^>]*>/g, "").trim();

    // Get summary from description, strip HTML
    let summary = extractTag(itemXml, "description")
      .replace(/<[^>]*>/g, "")
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"')
      .replace(/&#039;/g, "'")
      .replace(/&nbsp;/g, " ")
      .trim();

    // Truncate summary to 500 chars
    if (summary.length > 500) {
      summary = summary.substring(0, 497) + "...";
    }

    const imageUrl = extractImageUrl(itemXml);

    // Parse date
    const pubDateStr = extractTag(itemXml, "pubDate");
    let publishedAt: string | null = null;
    if (pubDateStr) {
      try {
        publishedAt = new Date(pubDateStr).toISOString();
      } catch {
        publishedAt = null;
      }
    }

    if (title && link) {
      items.push({ title, link, summary, imageUrl, publishedAt });
    }
  }

  return items;
}

// ─── Main Handler ───────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Content-Type": "application/json",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // ─── Auth Guard: Verify webhook/cron caller ────────────────
  // Invoked two ways: by cron to refresh the feed, and by users via
  // pull-to-refresh on the Legal Pulse screen. allowUserJwt lets a
  // verified end-user token through; it is validated against Supabase
  // Auth, not merely shape-checked.
  const authError = await verifyWebhookAuth(req, { allowUserJwt: true });
  if (authError) return authError;

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Use service role key for server-to-server DB writes
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  let totalInserted = 0;
  const errors: string[] = [];

  for (const feed of FEEDS) {
    try {
      console.log(`Fetching feed: ${feed.url}`);
      const response = await fetch(feed.url, {
        headers: {
          "User-Agent":
            "CaseFlow/2.0 (Legal News Aggregator; +https://caseflow.app)",
          Accept: "application/rss+xml, application/xml, text/xml",
        },
      });

      if (!response.ok) {
        const errMsg = `Feed ${feed.source} returned ${response.status}`;
        console.warn(errMsg);
        errors.push(errMsg);
        continue;
      }

      const xml = await response.text();
      const items = parseRssItems(xml);
      console.log(`Parsed ${items.length} items from ${feed.source}`);

      if (items.length === 0) continue;

      // Get existing links to deduplicate
      const links = items.map((i) => i.link);
      const { data: existingRows } = await supabase
        .from("legal_news")
        .select("link")
        .in("link", links);

      const existingLinks = new Set(
        (existingRows || []).map((r: { link: string }) => r.link)
      );

      const newArticles = items
        .filter((item) => !existingLinks.has(item.link))
        .map((item) => ({
          title: item.title,
          summary: item.summary || null,
          link: item.link,
          image_url: item.imageUrl,
          category: classifyCategory(item.title),
          source: feed.source,
          published_at: item.publishedAt || new Date().toISOString(),
          fetched_at: new Date().toISOString(),
        }));

      if (newArticles.length > 0) {
        const { error: insertErr } = await supabase
          .from("legal_news")
          .insert(newArticles);

        if (insertErr) {
          console.error(`Insert error for ${feed.source}:`, insertErr.message);
          errors.push(`Insert ${feed.source}: ${insertErr.message}`);
        } else {
          totalInserted += newArticles.length;
          console.log(
            `Inserted ${newArticles.length} new articles from ${feed.source}`
          );
        }
      } else {
        console.log(`No new articles from ${feed.source}`);
      }
    } catch (err) {
      const errMsg = `Feed ${feed.source} error: ${(err as any).message}`;
      console.error(errMsg);
      errors.push(errMsg);
    }
  }

  return new Response(
    JSON.stringify({
      success: true,
      message:
        totalInserted > 0
          ? `Inserted ${totalInserted} new articles`
          : "No new articles found",
      inserted: totalInserted,
      errors: errors.length > 0 ? errors : undefined,
    }),
    { headers: corsHeaders }
  );
});
