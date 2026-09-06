const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function verify() {
  const { data: acts, error: actsError } = await supabase
    .from('bare_acts')
    .select('id, title')
    .in('id', ['11b868c7-9888-4bb7-b431-44d280310e47', '77c22e4c-1f63-4b8c-9c7a-5e0d4a9f6d4d']);

  if (actsError) {
    console.error('Error fetching acts:', actsError);
    return;
  }

  console.log('--- Verification of Personal Law Expansion ---');
  for (const act of acts) {
    const { count, error: countError } = await supabase
      .from('bare_act_sections')
      .select('*', { count: 'exact', head: true })
      .eq('act_id', act.id);

    if (countError) {
      console.error(`Error counting sections for ${act.title}:`, countError);
    } else {
      console.log(`- ${act.title}: ${count} sections imported successfully.`);
    }
  }
}

verify();
