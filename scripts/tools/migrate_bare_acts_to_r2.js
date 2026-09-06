const { createClient } = require("@supabase/supabase-js");
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "../../.env") });
require("dotenv").config({ path: path.join(__dirname, "../../apps/dashboard/.env") });

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.VITE_SUPABASE_PUBLISHABLE_KEY;

const R2_ACCOUNT_ID = process.env.R2_ACCOUNT_ID;
const R2_ACCESS_KEY_ID = process.env.R2_ACCESS_KEY_ID;
const R2_SECRET_ACCESS_KEY = process.env.R2_SECRET_ACCESS_KEY;
const R2_BUCKET_NAME = process.env.R2_BUCKET_NAME || "caseflow-storage";

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error("Missing Supabase configuration in environment variables.");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

let s3Client = null;
if (R2_ACCOUNT_ID && R2_ACCESS_KEY_ID && R2_SECRET_ACCESS_KEY) {
  s3Client = new S3Client({
    region: "auto",
    endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: R2_ACCESS_KEY_ID,
      secretAccessKey: R2_SECRET_ACCESS_KEY,
    },
  });
}

async function migrateBareActs() {
  console.log("🚀 Starting Bare Acts migration to Cloudflare R2...");

  if (!s3Client) {
    console.log("⚠️  R2 credentials are not configured in .env!");
    console.log("Please set R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, and R2_SECRET_ACCESS_KEY before running this script.");
    return;
  }

  const { data: acts, error } = await supabase
    .from("bare_acts")
    .select("id, short_title, pdf_url")
    .not("pdf_url", "is", null);

  if (error) {
    console.error("❌ Failed to fetch bare acts from database:", error.message);
    return;
  }

  console.log(`Found ${acts.length} bare act records with PDF URLs.`);
  let migratedCount = 0;

  for (const act of acts) {
    if (!act.pdf_url) continue;

    // Check if already in R2
    if (act.pdf_url.includes("r2.cloudflarestorage.com") || act.pdf_url.startsWith("r2://")) {
      console.log(`[SKIP] Act ID ${act.id} (${act.short_title}) is already on R2.`);
      continue;
    }

    try {
      // Extract filename from URL
      const fileName = act.pdf_url.split("/").pop();
      if (!fileName) continue;

      console.log(`[MIGRATING] Act ID ${act.id} (${act.short_title}) - File: ${fileName}`);

      // 1. Download file from Supabase Storage
      const { data: fileData, error: downloadError } = await supabase.storage
        .from("bare_acts")
        .download(fileName);

      if (downloadError) {
        console.warn(`  ⚠️ Could not download ${fileName} from Supabase Storage:`, downloadError.message);
        continue;
      }

      const buffer = Buffer.from(await fileData.arrayBuffer());
      const r2Key = `bare_acts/${fileName}`;

      // 2. Upload to Cloudflare R2
      await s3Client.send(
        new PutObjectCommand({
          Bucket: R2_BUCKET_NAME,
          Key: r2Key,
          Body: buffer,
          ContentType: "application/pdf",
        })
      );

      // 3. Update database record with R2 reference
      const newPdfUrl = `r2://${r2Key}`;
      const { error: updateError } = await supabase
        .from("bare_acts")
        .update({ pdf_url: newPdfUrl })
        .eq("id", act.id);

      if (updateError) {
        console.error(`  ❌ Failed to update database record for act ID ${act.id}:`, updateError.message);
      } else {
        console.log(`  ✅ Successfully migrated to R2 (${r2Key})`);
        migratedCount++;
      }
    } catch (err) {
      console.error(`  ❌ Unexpected error migrating act ID ${act.id}:`, err.message);
    }
  }

  console.log(`\n🎉 Migration complete! ${migratedCount} files migrated to Cloudflare R2.`);
}

migrateBareActs();
