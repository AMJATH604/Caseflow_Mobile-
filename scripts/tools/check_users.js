const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function checkUsers() {
  console.log('Fetching bar admins...');
  const { data: barAdmins, error: adminErr } = await supabase
    .from('bar_admins')
    .select('*');

  if (adminErr) {
    console.error('Error fetching bar admins:', adminErr);
  } else {
    console.log('Bar Admins in database:', barAdmins);
  }

  console.log('Fetching bar members...');
  const { data: barMembers, error: memberErr } = await supabase
    .from('bar_members')
    .select('*')
    .limit(10);

  if (memberErr) {
    console.error('Error fetching bar members:', memberErr);
  } else {
    console.log('Sample Bar Members:', barMembers.map(m => ({ id: m.id, name: m.name, email: m.email, user_id: m.user_id })));
  }

  console.log('Fetching auth users...');
  // Since we have the service_role key, we can list users from auth.admin
  const { data: { users }, error: authErr } = await supabase.auth.admin.listUsers();

  if (authErr) {
    console.error('Error fetching auth users:', authErr);
  } else {
    console.log('Auth Users (first 10):');
    users.slice(0, 10).forEach(u => {
      console.log(`- ID: ${u.id} | Email: ${u.email}`);
    });
  }
}

checkUsers();
