const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function listAdmins() {
  const { data, error } = await supabase
    .from('profiles')
    .select('email, full_name, is_admin')
    .eq('is_admin', true);

  if (error) {
    console.error('Error fetching admins:', error);
    return;
  }

  console.log('--- ACTIVE CASEFLOW ADMINISTRATORS ---');
  if (!data || data.length === 0) {
    console.log('No admins found in the database.');
  } else {
    data.forEach(p => {
      console.log(`- Email: ${p.email} | Name: ${p.full_name || 'N/A'}`);
    });
  }
}

listAdmins();
