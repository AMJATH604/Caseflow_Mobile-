const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;

if (!supabaseKey) {
  console.error("Missing Supabase Key!");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

const ACT_ID = 'd5b51044-61cd-4072-90d5-a1848cac80bd'; // Constitution

async function restoreConstitution() {
  console.log('--- PURGE PHASE ---');
  console.log(`Deleting all existing sections for Constitution (${ACT_ID})...`);
  
  const { error: deleteError } = await supabase
    .from('bare_act_sections')
    .delete()
    .eq('act_id', ACT_ID);

  if (deleteError) {
    console.error('Purge failed:', deleteError);
    return;
  }
  console.log('Purge successful.');

  console.log('--- UPLOAD PHASE ---');
  const jsonData = JSON.parse(fs.readFileSync('./ready_for_dashboard.json', 'utf8'));
  const entries = jsonData.map(item => ({
    act_id: ACT_ID,
    chapter_number: item.chapter_number,
    chapter_title: item.chapter_title,
    section_number: item.section_number,
    section_title: item.section_title,
    section_text: item.section_text,
    sequence_order: item.sequence_order,
    created_at: new Date().toISOString()
  }));

  console.log(`Uploading ${entries.length} entries in batches...`);
  
  const batchSize = 50;
  for (let i = 0; i < entries.length; i += batchSize) {
    const batch = entries.slice(i, i + batchSize);
    const { error: uploadError } = await supabase
      .from('bare_act_sections')
      .insert(batch);
    
    if (uploadError) {
      console.error(`Batch ${i/batchSize + 1} failed:`, uploadError);
      return;
    }
    console.log(`Uploaded batch ${Math.floor(i/batchSize) + 1}/${Math.ceil(entries.length/batchSize)}`);
  }

  console.log('ALL DONE! Constitution restored successfully.');
}

restoreConstitution();
