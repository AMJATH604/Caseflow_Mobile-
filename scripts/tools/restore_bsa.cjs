const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
require('dotenv').config();

// Use credentials from app_constants.dart
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY;
const TARGET_ACT_ID = '87bbd472-6d1f-486d-bf75-9a9703366631';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function restoreBsa(filename) {
  console.log(`Reading data from ${filename}`);
  if (!fs.existsSync(filename)) {
    console.error(`File not found: ${filename}`);
    return;
  }

  const data = JSON.parse(fs.readFileSync(filename, 'utf8'));
  console.log(`Loaded ${data.length} records.`);

  console.log('--- PURGE PHASE ---');
  const { error: purgeError } = await supabase
    .from('bare_act_sections')
    .delete()
    .eq('act_id', TARGET_ACT_ID);
  
  if (purgeError) {
    console.error('Purge error:', purgeError);
    return;
  }
  console.log('Successfully purged existing records.');

  console.log('--- UPLOAD PHASE ---');
  const batchSize = 50;
  let inserted = 0;
  let failed = 0;

  for (let i = 0; i < data.length; i += batchSize) {
    const batch = data.slice(i, i + batchSize);
    console.log(`Uploading batch ${Math.floor(i/batchSize) + 1} (${batch.length} records)...`);
    
    const { error } = await supabase
      .from('bare_act_sections')
      .insert(batch);

    if (error) {
      console.error('Insert error in batch:', error);
      failed += batch.length;
    } else {
      inserted += batch.length;
    }
  }

  console.log('--- RESTORE COMPLETE ---');
  console.log(`Successfully inserted: ${inserted}`);
  console.log(`Failed to insert: ${failed}`);
}

const targetFile = process.argv[2] || 'ready_for_dashboard_bsa.json';
restoreBsa(targetFile);
