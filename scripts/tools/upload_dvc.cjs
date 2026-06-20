const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

require('dotenv').config();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY;
const DVC_ACT_ID = '4400cfc2-2e21-477d-844a-9e1e4a1f6d4d';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const FILE_PATH = path.join(__dirname, '../../data/legal/dvc.json');

async function uploadAll() {
  console.log('=== READING DVC ACT JSON ===');
  if (!fs.existsSync(FILE_PATH)) {
    console.error(`File not found: ${FILE_PATH}`);
    process.exit(1);
  }

  const rawData = JSON.parse(fs.readFileSync(FILE_PATH, 'utf8'));
  console.log(`Read ${rawData.length} sections from ${FILE_PATH}`);

  // === TRANSFORM WITH CONTINUOUS SEQUENCE ORDER ===
  console.log('\n=== TRANSFORMING ===');
  const transformed = rawData.map((item, index) => ({
    act_id: DVC_ACT_ID,
    chapter_number: item.chapter_number || '',
    chapter_title: item.chapter_title || '',
    section_number: item.section_number || '',
    section_title: item.section_title || '',
    section_text: item.section_text || '',
    title: item.section_title || '',
    content: item.section_text || '',
    sequence_order: index + 1,
  }));
  console.log(`Transformed ${transformed.length} records.`);

  // === PURGE OLD DATA FOR THIS ACT ===
  console.log('\n=== PURGE PHASE ===');
  const { error: purgeError } = await supabase
    .from('bare_act_sections')
    .delete()
    .eq('act_id', DVC_ACT_ID);

  if (purgeError) {
    console.error('Purge error:', purgeError);
    return;
  }
  console.log('Successfully purged existing DVC Act records.');

  // === UPLOAD IN BATCHES ===
  console.log('\n=== UPLOAD PHASE ===');
  const batchSize = 10;
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
