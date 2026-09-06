const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
require('dotenv').config(); // Load variables if .env exists

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY;
const TARGET_ACT_ID = '04ac82bd-f734-4fa8-9dbd-d697cfbfcadb'; // Negotiable Instruments Act UUID

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const FILE_PATH = 'ni_act.json';

async function uploadAll() {
  console.log('=== READING NI ACT JSON ===');
  if (!fs.existsSync(FILE_PATH)) {
    console.error(`File not found: ${FILE_PATH}`);
    process.exit(1);
  }

  const rawData = JSON.parse(fs.readFileSync(FILE_PATH, 'utf8'));
  console.log(`Read ${rawData.length} sections from ${FILE_PATH}`);

  // === TRANSFORM WITH CONTINUOUS SEQUENCE ORDER ===
  console.log('\n=== TRANSFORMING ===');
  const transformed = rawData.map((item, index) => ({
    act_id: TARGET_ACT_ID,
    chapter_number: item[1] || '',
    chapter_title: item[2] || '',
    section_number: item[3] || '',
    section_title: item[4] || '',
    section_text: item[5] || '',
    title: item[4] || '',
    content: item[5] || '',
    sequence_order: index + 1,
  }));
  console.log(`Transformed ${transformed.length} records.`);

  // === PURGE OLD DATA FOR THIS ACT ===
  console.log('\n=== PURGE PHASE ===');
  const { error: purgeError } = await supabase
    .from('bare_act_sections')
    .delete()
    .eq('act_id', TARGET_ACT_ID);

  if (purgeError) {
    console.error('Purge error:', purgeError);
    return;
  }
  console.log('Successfully purged existing NI Act records.');

  // === UPLOAD IN BATCHES ===
  console.log('\n=== UPLOAD PHASE ===');
  const batchSize = 50;
  let inserted = 0;
  let failed = 0;

  for (let i = 0; i < transformed.length; i += batchSize) {
    const batch = transformed.slice(i, i + batchSize);
    const batchNum = Math.floor(i / batchSize) + 1;
    const totalBatches = Math.ceil(transformed.length / batchSize);
    console.log(`Uploading batch ${batchNum}/${totalBatches} (${batch.length} records)...`);

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
