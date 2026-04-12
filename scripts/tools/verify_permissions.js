const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function verify() {
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('email, is_admin')
      .in('email', ['admin@caseflow.com', 'amjath10now@gmail.com']);

    if (error) {
      console.error('Verification Error:', error);
      return;
    }

    console.log('Permission Verification Results:');
    if (!data || data.length === 0) {
      console.log('No matching users found.');
    } else {
      data.forEach(p => {
        console.log(`- User: ${p.email} | Admin Status: ${p.is_admin ? '✅ ADMIN' : '❌ REGULAR USER'}`);
      });
    }
  } catch (err) {
    console.error('Unexpected Error:', err);
  }
}

verify();
