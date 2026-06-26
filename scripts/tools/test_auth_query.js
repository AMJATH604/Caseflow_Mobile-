const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

// We need to use the client-side SUPABASE_URL and VITE_SUPABASE_ANON_KEY to simulate the client browser
const supabaseUrl = process.env.SUPABASE_URL || 'https://asrjqsnyezvcakvkokcl.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzcmpxc255ZXp2Y2Frdmtva2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5NTQ1MjYsImV4cCI6MjA4NzUzMDUyNn0._W7YwzwxA2m83VxITvQMDVUSbTlnJi1Ij389Sxp-Mls';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function testAuthQuery() {
  const email = 'secretary@barcouncil.in';
  const password = 'Password123';

  console.log(`Attempting login for ${email}...`);
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({ email, password });
  
  if (authError) {
    console.error('Auth Login failed:', authError);
    return;
  }

  console.log('Auth login successful! User ID:', authData.user.id);

  console.log('Querying auth.getUser()...');
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError) {
    console.error('getUser failed:', userError);
  } else {
    console.log('getUser user.id:', user?.id);
  }

  console.log('Querying bar_admins table...');
  const { data: adminData, error: adminError } = await supabase
    .from('bar_admins')
    .select('id, association_id, user_id, role')
    .eq('user_id', user?.id)
    .maybeSingle();

  if (adminError) {
    console.error('Error querying bar_admins:', adminError);
  } else {
    console.log('Result from bar_admins:', adminData);
  }

  console.log('Querying bar_members table...');
  const { data: memberData, error: memberError } = await supabase
    .from('bar_members')
    .select('id, name, email, association_id')
    .eq('user_id', user?.id)
    .maybeSingle();

  if (memberError) {
    console.error('Error querying bar_members:', memberError);
  } else {
    console.log('Result from bar_members:', memberData);
  }

  // Sign out
  await supabase.auth.signOut();
}

testAuthQuery();
