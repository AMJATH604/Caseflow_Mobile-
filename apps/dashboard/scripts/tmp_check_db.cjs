const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_PUBLISHABLE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function check() {
  const { data, error } = await supabase
    .from('bare_act_sections')
    .select('section_number, section_title, bare_acts(title)')
    .in('section_number', ['15', '21']);

  if (error) {
    console.error('Error:', error);
    return;
  }

  console.log('Results:');
  data.forEach(row => {
    console.log(`- Act: ${row.bare_acts.title}, Number: ${row.section_number}, Title: ${row.section_title}`);
  });
}

check();
