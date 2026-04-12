const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_PUBLISHABLE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function check() {
  const { data, error } = await supabase
    .from('bare_acts')
    .select('id, title');

  if (error) {
    console.error('Error:', error);
    return;
  }

  console.log('Bare Acts:');
  data.forEach(row => {
    console.log(`- ID: ${row.id}, Title: ${row.title}`);
  });
}

check();
