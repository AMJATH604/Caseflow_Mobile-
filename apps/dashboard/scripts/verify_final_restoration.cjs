const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_PUBLISHABLE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function verify() {
  console.log('Searching for Art 21...');
  const { data: art21, error: error21 } = await supabase
    .from('bare_act_sections')
    .select('section_number, section_title, section_text, bare_acts(title)')
    .eq('act_id', 'd5b51044-61cd-4072-90d5-a1848cac80bd')
    .eq('section_number', '21');

  if (error21) console.error(error21);
  else {
    console.log(`Result: ${art21[0]?.section_title}`);
    console.log(`Text Sample: ${art21[0]?.section_text.substring(0, 100)}...`);
  }

  console.log('\nSearching for Art 15...');
  const { data: art15, error: error15 } = await supabase
    .from('bare_act_sections')
    .select('section_number, section_title, section_text, bare_acts(title)')
    .eq('act_id', 'd5b51044-61cd-4072-90d5-a1848cac80bd')
    .eq('section_number', '15');

  if (error15) console.error(error15);
  else {
    console.log(`Result: ${art15[0]?.section_title}`);
  }
}

verify();
