const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function findAmjath() {
  const { data, error } = await supabase
    .from('profiles')
    .select('full_name, email')
    .ilike('full_name', '%Amjath%');

  if (error) {
    console.error('Search error:', error);
    return;
  }

  console.log('Found Amjath profiles:');
  console.log(JSON.stringify(data, null, 2));
}

findAmjath();
