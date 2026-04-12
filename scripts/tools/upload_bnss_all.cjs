const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
require('dotenv').config();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY;
const TARGET_ACT_ID = 'b8cd8ff9-5e27-411b-8a6d-73a68173bbdb'; // BNSS Act UUID

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const PART_FILES = [
  'data/legal/bnss_part1.json',
  'data/legal/bnss_part2.json',
  'data/legal/bnss_part3.json',
  'data/legal/bnss_part4.json',
  'data/legal/bnss_part5.json',
  'data/legal/bnss_part6.json',
  'data/legal/bnss_part7.json',
  'data/legal/bnss_part8.json',
  'data/legal/bnss_part9.json',
  'data/legal/bnss_part10.json',
  'data/legal/bnss_patch.json',
];

async function uploadAll() {
  // === MERGE ALL PARTS ===
  console.log('=== MERGING ALL BNSS PARTS ===');
  let allRaw = [];
  for (const file of PART_FILES) {
    if (!fs.existsSync(file)) {
      console.error(`File not found: ${file} — skipping`);
      continue;
    }
    const data = JSON.parse(fs.readFileSync(file, 'utf8'));
    console.log(`  ${file}: ${data.length} sections`);
    allRaw = allRaw.concat(data);
  }
  console.log(`Total raw sections merged: ${allRaw.length}`);

  // === SORT BY SECTION NUMBER (numeric) ===
  allRaw.sort((a, b) => {
    const numA = parseInt(a[2], 10);
    const numB = parseInt(b[2], 10);
    return numA - numB;
  });
  console.log('Sorted by section number.');

  // === DEDUPLICATE (keep first occurrence) ===
  const seen = new Set();
  allRaw = allRaw.filter(item => {
    if (seen.has(item[2])) return false;
    seen.add(item[2]);
    return true;
  });
  console.log(`After dedup: ${allRaw.length} unique sections`);

  // === TRANSFORM WITH CONTINUOUS SEQUENCE ORDER ===
  console.log('\n=== TRANSFORMING ===');
  const transformed = allRaw.map((item, index) => ({
    act_id: TARGET_ACT_ID,
    section_number: item[2],
    section_title: item[3],
    section_text: item[4],
    chapter_number: item[0],
    chapter_title: item[1],
    sequence_order: index + 1,
  }));
  console.log(`Transformed ${transformed.length} records with sequence_order 1–${transformed.length}`);

  // === PURGE OLD BNSS DATA ===
  console.log('\n=== PURGE PHASE ===');
  const { error: purgeError } = await supabase
    .from('bare_act_sections')
    .delete()
    .eq('act_id', TARGET_ACT_ID);

  if (purgeError) {
    console.error('Purge error:', purgeError);
    return;
  }
  console.log('Successfully purged existing BNSS records.');

  // === UPLOAD IN BATCHES ===
  console.log('\n=== UPLOAD PHASE ===');
  const batchSize = 50;
  let inserted = 0;
  let failed = 0;

  for (let i = 0; i < transformed.length; i += batchSize) {
    const batch = transformed.slice(i, i + batchSize);
    const batchNum = Math.floor(i / batchSize) + 1;
    const totalBatches = Math.ceil(transformed.length / batchSize);
    console.log(`Uploading batch ${batchNum}/${totalBatches} (${batch.length} records, seq ${batch[0].sequence_order}–${batch[batch.length-1].sequence_order})...`);

    const { error } = await supabase
      .from('bare_act_sections')
      .insert(batch);

    if (error) {
      console.error(`  Insert error in batch ${batchNum}:`, error.message || error);
      failed += batch.length;
    } else {
      inserted += batch.length;
    }
  }

  console.log('\n=== UPLOAD COMPLETE ===');
  console.log(`Successfully inserted: ${inserted}`);
  console.log(`Failed to insert: ${failed}`);
  console.log(`Total: ${inserted + failed}/${transformed.length}`);
}

uploadAll().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
