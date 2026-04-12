const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
require('dotenv').config();

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// Fixed UUIDs (to match create_personal_laws_acts.sql)
const MOHAMMEDAN_LAW_ID = '11b868c7-9888-4bb7-b431-44d280310e47';
const HINDU_LAW_ID = '77c22e4c-1f63-4b8c-9c7a-5e0d4a9f6d4d';

async function uploadSections(actId, title, jsonFile) {
  console.log(`\n========================================`);
  console.log(`Uploading Sections for: ${title}`);
  console.log(`Act ID: ${actId}`);
  console.log(`JSON File: ${jsonFile}`);
  console.log(`========================================\n`);

  // Check if the act exists
  const { data: act, error: actCheckError } = await supabase
    .from('bare_acts')
    .select('id')
    .eq('id', actId)
    .single();

  if (actCheckError || !act) {
    console.error(`Error: Act with ID ${actId} not found. Please run create_personal_laws_acts.sql first!`);
    return;
  }

  // Purge existing sections
  console.log('Purging existing sections...');
  const { error: purgeError } = await supabase
    .from('bare_act_sections')
    .delete()
    .eq('act_id', actId);

  if (purgeError) {
    console.error('Purge error:', purgeError);
    return;
  }
  console.log('Purged successfully.');

  // Read JSON data
  if (!fs.existsSync(jsonFile)) {
    console.error(`File not found: ${jsonFile}`);
    return;
  }

  const sections = JSON.parse(fs.readFileSync(jsonFile, 'utf8'));
  console.log(`Loaded ${sections.length} sections from ${jsonFile}`);

  // Add act_id to each section
  const records = sections.map(s => ({
    ...s,
    act_id: actId,
  }));

  // Upload in batches
  const batchSize = 30;
  let inserted = 0;
  let failed = 0;

  for (let i = 0; i < records.length; i += batchSize) {
    const batch = records.slice(i, i + batchSize);
    console.log(`Uploading batch ${Math.floor(i / batchSize) + 1} (${batch.length} records)...`);

    const { error } = await supabase
      .from('bare_act_sections')
      .insert(batch);

    if (error) {
      console.error('Insert error:', error);
      failed += batch.length;
    } else {
      inserted += batch.length;
    }
  }

  console.log(`\n--- UPLOAD COMPLETE ---`);
  console.log(`Act: ${title}`);
  console.log(`Successfully inserted: ${inserted}`);
  console.log(`Failed: ${failed}`);
}

async function main() {
  const args = process.argv.slice(2);

  if (args.includes('--mohammedan') || args.includes('--all')) {
    await uploadSections(
      MOHAMMEDAN_LAW_ID,
      'Mohammedan Law (Muslim Personal Law)',
      'data/legal/mohammedan_law.json'
    );
  }

  if (args.includes('--hindu') || args.includes('--all')) {
    await uploadSections(
      HINDU_LAW_ID,
      'Hindu Law (Personal Law)',
      'data/legal/hindu_law.json'
    );
  }

  if (!args.includes('--mohammedan') && !args.includes('--hindu') && !args.includes('--all')) {
    console.log('Usage:');
    console.log('  node upload_personal_laws.cjs --mohammedan   Upload Mohammedan Law sections');
    console.log('  node upload_personal_laws.cjs --hindu         Upload Hindu Law sections');
    console.log('  node upload_personal_laws.cjs --all           Upload both');
  }
}

main().catch(console.error);
