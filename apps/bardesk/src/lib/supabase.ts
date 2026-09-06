import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://asrjqsnyezvcakvkokcl.supabase.co';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzcmpxc255ZXp2Y2Frdmtva2NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5NTQ1MjYsImV4cCI6MjA4NzUzMDUyNn0._W7YwzwxA2m83VxITvQMDVUSbTlnJi1Ij389Sxp-Mls';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
