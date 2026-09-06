/**
 * ═══════════════════════════════════════════════════════════════════
 *  CaseFlow — Universal Bare Act Importer
 * ═══════════════════════════════════════════════════════════════════
 *
 *  Usage:
 *    node scripts/tools/import_bare_act.cjs --file <path> --title "Act Title" --short-title "Short"
 *    node scripts/tools/import_bare_act.cjs --file <path> --act-id <uuid>
 *
 *  Supports both JSON formats:
 *    Object: [{chapter_number, chapter_title, section_number, section_title, section_text}, ...]
 *    Array:  [["act_name", "chapter_num", "chapter_title", "section_num", "section_title", "section_text"], ...]
 *
 *  Features:
 *    - Auto-detects JSON format
 *    - Creates act in bare_acts table if --act-id not provided
 *    - Purges existing sections before re-import (idempotent)
 *    - Uploads in batches of 50 to avoid Supabase payload limits
 *    - Optional --year flag for act year
 *    - Optional --no-purge flag to append instead of replace
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// ─── Load Environment ────────────────────────────────────────────
// Try loading .env from project root
try {
  require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });
} catch (e) {
  // dotenv not installed — that's fine, env vars may already be set
}

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY;

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_KEY in environment / .env file');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// ─── Parse CLI Arguments ─────────────────────────────────────────
function parseArgs() {
  const args = process.argv.slice(2);
  const opts = {
    file: null,
    title: null,
    shortTitle: null,
    actId: null,
    year: null,
    purge: true,     // default: purge old sections before import
    batchSize: 50,
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--file':
      case '-f':
        opts.file = args[++i];
        break;
      case '--title':
      case '-t':
        opts.title = args[++i];
        break;
      case '--short-title':
      case '-s':
        opts.shortTitle = args[++i];
        break;
      case '--act-id':
      case '-id':
        opts.actId = args[++i];
        break;
      case '--year':
      case '-y':
        opts.year = parseInt(args[++i], 10);
        break;
      case '--no-purge':
        opts.purge = false;
        break;
      case '--batch-size':
        opts.batchSize = parseInt(args[++i], 10);
        break;
      case '--help':
      case '-h':
        printHelp();
        process.exit(0);
    }
  }

  return opts;
}

function printHelp() {
  console.log(`
╔═══════════════════════════════════════════════════════════════╗
║          CaseFlow — Universal Bare Act Importer              ║
╚═══════════════════════════════════════════════════════════════╝

Usage:
  node scripts/tools/import_bare_act.cjs [options]

Required:
  --file, -f <path>         Path to the JSON file containing sections

Act Identity (one of these is required):
  --act-id, -id <uuid>      Use an existing act ID (skips act creation)
  --title, -t <string>      Full title of the act (creates act if not found)
  --short-title, -s <str>   Short title / abbreviation (used with --title)

Optional:
  --year, -y <number>       Year of the act (e.g., 1988)
  --no-purge                Append sections instead of replacing existing ones
  --batch-size <number>     Batch size for uploads (default: 50)
  --help, -h                Show this help message

Supported JSON Formats:
  Object format:
    [{"chapter_number": "I", "chapter_title": "...", "section_number": "1",
      "section_title": "...", "section_text": "..."}, ...]

  Array format:
    [["Act Name", "Chapter I", "Title", "1", "Section Title", "Section Text"], ...]

Examples:
  node scripts/tools/import_bare_act.cjs \\
    --file data/legal/motor_vehicles_act.json \\
    --title "Motor Vehicles Act, 1988" \\
    --short-title "Motor Vehicles Act" \\
    --year 1988

  node scripts/tools/import_bare_act.cjs \\
    --file ni_act.json \\
    --act-id "04ac82bd-f734-4fa8-9dbd-d697cfbfcadb"
  `);
}

function generateUUID() {
  return crypto.randomUUID ? crypto.randomUUID() : 
    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = (Math.random() * 16) | 0;
      const v = c === 'x' ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
}

// ─── Detect JSON Format & Transform ──────────────────────────────
function detectAndTransform(rawData, actId) {
  if (!Array.isArray(rawData) || rawData.length === 0) {
    console.error('❌ JSON must be a non-empty array');
    process.exit(1);
  }

  const sample = rawData[0];
  let format;

  if (Array.isArray(sample)) {
    // Array format: ["act_name", "chapter_num", "chapter_title", "section_num", "section_title", "section_text"]
    // Some variants: 5-element (no act name) or 6-element
    format = 'array';
    console.log(`  📋 Detected format: Array (${sample.length}-element tuples)`);
  } else if (typeof sample === 'object' && sample !== null) {
    // Object format: {chapter_number, chapter_title, section_number, section_title, section_text}
    format = 'object';
    console.log('  📋 Detected format: Object/Dictionary');
  } else {
    console.error('❌ Unrecognized JSON format. Expected array of objects or array of arrays.');
    process.exit(1);
  }

  const transformed = [];

  rawData.forEach((item, index) => {
    let record;

    if (format === 'array') {
      // Handle different array lengths
      if (item.length >= 6) {
        // [act_name, chapter_num, chapter_title, section_num, section_title, section_text]
        record = {
          chapter_number: item[1] || '',
          chapter_title: item[2] || '',
          section_number: item[3] || '',
          section_title: item[4] || '',
          section_text: item[5] || '',
        };
      } else if (item.length >= 5) {
        // [chapter_num, chapter_title, section_num, section_title, section_text]
        record = {
          chapter_number: item[0] || '',
          chapter_title: item[1] || '',
          section_number: item[2] || '',
          section_title: item[3] || '',
          section_text: item[4] || '',
        };
      } else {
        console.warn(`  ⚠️  Skipping row ${index + 1}: too few elements (${item.length})`);
        return;
      }
    } else {
      // Object format — flexible field mapping
      record = {
        chapter_number: item.chapter_number || item.chapter || '',
        chapter_title: item.chapter_title || item.chapter_name || '',
        section_number: item.section_number || item.number || item.article_number || '',
        section_title: item.section_title || item.title || item.heading || '',
        section_text: item.section_text || item.text || item.content || item.body || '',
      };
    }

    // Skip empty sections
    if (!record.section_number && !record.section_title && !record.section_text) {
      console.warn(`  ⚠️  Skipping row ${index + 1}: all fields empty`);
      return;
    }

    transformed.push({
      act_id: actId,
      chapter_number: record.chapter_number,
      chapter_title: record.chapter_title,
      section_number: record.section_number,
      section_title: record.section_title,
      section_text: record.section_text,
      title: record.section_title,
      content: record.section_text,
      sequence_order: transformed.length + 1,
    });
  });

  return transformed;
}

// ─── Main Import Function ────────────────────────────────────────
async function main() {
  const opts = parseArgs();

  // Validate required args
  if (!opts.file) {
    console.error('❌ --file is required. Use --help for usage.');
    process.exit(1);
  }

  if (!opts.actId && !opts.title) {
    console.error('❌ Either --act-id or --title is required. Use --help for usage.');
    process.exit(1);
  }

  // ── Read JSON File ──
  console.log('\n╔═══════════════════════════════════════════════════════════════╗');
  console.log('║          CaseFlow — Universal Bare Act Importer              ║');
  console.log('╚═══════════════════════════════════════════════════════════════╝\n');

  const filePath = path.resolve(opts.file);
  if (!fs.existsSync(filePath)) {
    console.error(`❌ File not found: ${filePath}`);
    process.exit(1);
  }

  console.log(`📂 Reading: ${filePath}`);
  const rawData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  console.log(`  Found ${rawData.length} entries in JSON file\n`);

  // ── Resolve or Create Act ──
  let actId = opts.actId;

  if (!actId) {
    console.log('🔍 Looking up act in database...');

    // Check if act already exists by title
    const { data: existing, error: lookupErr } = await supabase
      .from('bare_acts')
      .select('id, title')
      .ilike('title', opts.title)
      .limit(1);

    if (lookupErr) {
      console.error('❌ Error looking up act:', lookupErr.message);
      process.exit(1);
    }

    if (existing && existing.length > 0) {
      actId = existing[0].id;
      console.log(`  ✅ Found existing act: "${existing[0].title}" (${actId})\n`);
    } else {
      // Create new act
      actId = generateUUID();
      const actRecord = {
        id: actId,
        title: opts.title,
        short_title: opts.shortTitle || opts.title,
        is_active: true,
      };
      if (opts.year) actRecord.year = opts.year;

      console.log(`  📝 Creating new act: "${opts.title}"`);

      const { error: createErr } = await supabase
        .from('bare_acts')
        .insert([actRecord]);

      if (createErr) {
        console.error('❌ Error creating act:', createErr.message);
        process.exit(1);
      }
      console.log(`  ✅ Created act with ID: ${actId}\n`);
    }
  } else {
    // Verify act exists
    const { data: actData, error: verifyErr } = await supabase
      .from('bare_acts')
      .select('id, title')
      .eq('id', actId)
      .single();

    if (verifyErr || !actData) {
      console.error(`❌ Act with ID "${actId}" not found in database.`);
      process.exit(1);
    }
    console.log(`  ✅ Using existing act: "${actData.title}" (${actId})\n`);
  }

  // ── Transform Data ──
  console.log('🔄 Transforming data...');
  const sections = detectAndTransform(rawData, actId);
  console.log(`  ✅ Transformed ${sections.length} sections\n`);

  if (sections.length === 0) {
    console.error('❌ No valid sections found after transformation.');
    process.exit(1);
  }

  // ── Purge Existing Sections ──
  if (opts.purge) {
    console.log('🗑️  Purging existing sections for this act...');
    const { error: purgeError, count } = await supabase
      .from('bare_act_sections')
      .delete()
      .eq('act_id', actId);

    if (purgeError) {
      console.error('❌ Purge error:', purgeError.message);
      process.exit(1);
    }
    console.log('  ✅ Purged existing sections\n');
  } else {
    console.log('⏭️  Skipping purge (--no-purge flag set)\n');
  }

  // ── Upload in Batches ──
  console.log('📤 Uploading sections in batches...');
  const totalBatches = Math.ceil(sections.length / opts.batchSize);
  let inserted = 0;
  let failed = 0;

  for (let i = 0; i < sections.length; i += opts.batchSize) {
    const batch = sections.slice(i, i + opts.batchSize);
    const batchNum = Math.floor(i / opts.batchSize) + 1;
    const seqRange = `seq ${batch[0].sequence_order}–${batch[batch.length - 1].sequence_order}`;

    process.stdout.write(`  Batch ${batchNum}/${totalBatches} (${batch.length} sections, ${seqRange})... `);

    const { error } = await supabase
      .from('bare_act_sections')
      .insert(batch);

    if (error) {
      console.log('❌ FAILED');
      console.error(`    Error: ${error.message}`);
      failed += batch.length;
    } else {
      console.log('✅');
      inserted += batch.length;
    }
  }

  // ── Summary ──
  console.log('\n══════════════════════════════════════════════════════════');
  console.log('  IMPORT COMPLETE');
  console.log('══════════════════════════════════════════════════════════');
  console.log(`  Act ID:      ${actId}`);
  console.log(`  Inserted:    ${inserted} sections ✅`);
  if (failed > 0) {
    console.log(`  Failed:      ${failed} sections ❌`);
  }
  console.log(`  Total:       ${inserted + failed} / ${sections.length}`);
  console.log('══════════════════════════════════════════════════════════\n');

  if (failed > 0) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('💥 Fatal error:', err);
  process.exit(1);
});
