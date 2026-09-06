const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const dotenv = require('dotenv');

dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

const TARGET_ACT_ID = '17caffb2-5ee4-40f0-9692-221a51858382';

async function restoreDB() {
  const fileToUpload = process.argv[2] || 'ready_for_dashboard_cpc.json';
  console.log('Reading data from ' + fileToUpload);
  
  const rawData = fs.readFileSync(fileToUpload, 'utf-8');
  let data = JSON.parse(rawData);
  console.log('Loaded ' + data.length + ' records.');

  console.log('--- PURGE PHASE ---');
  console.log('Deleting all existing sections for CPC (' + TARGET_ACT_ID + ')...');
  
  const { error: deleteError } = await supabase
    .from('bare_act_sections')
    .delete()
    .eq('act_id', TARGET_ACT_ID);
    
  if (deleteError) {
    console.error('Failed to purge existing records:', deleteError);
    return;
  }
  console.log('Successfully purged existing records.');

  console.log('--- UPLOAD PHASE ---');
  let successCount = 0;
  let errorCount = 0;
  
  const batchSize = 50;
  for (let i = 0; i < data.length; i += batchSize) {
    const batch = data.slice(i, i + batchSize);
    console.log('Uploading batch ' + (i / batchSize + 1) + ' (' + batch.length + ' records)...');
    
    const { error } = await supabase
      .from('bare_act_sections')
      .insert(batch);
      
    if (error) {
      console.error('Batch upload error:', error);
      errorCount += batch.length;
    } else {
      successCount += batch.length;
    }
  }

  console.log('--- RESTORE COMPLETE ---');
  console.log('Successfully inserted: ' + successCount);
  console.log('Failed to insert: ' + errorCount);
}

restoreDB().catch(console.error);
