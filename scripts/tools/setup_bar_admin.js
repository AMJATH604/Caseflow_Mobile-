const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function setupBarAdmin() {
  try {
    console.log('--- STARTING BAR ASSOCIATION SETUP ---');

    // 1. Create or get Bar Association
    const inviteCode = 'SCBA2026';
    let associationId;
    
    const { data: existingAssoc, error: assocGetErr } = await supabase
      .from('bar_associations')
      .select('id')
      .eq('invite_code', inviteCode)
      .maybeSingle();

    if (assocGetErr) throw assocGetErr;

    if (existingAssoc) {
      associationId = existingAssoc.id;
      console.log(`Bar Association already exists with ID: ${associationId}`);
    } else {
      const { data: newAssoc, error: assocCreateErr } = await supabase
        .from('bar_associations')
        .insert({
          name: 'Supreme Court Bar Association',
          district: 'New Delhi',
          court: 'Supreme Court of India',
          address: 'Tilak Marg, New Delhi, Delhi 110001',
          annual_fee: 1200.00,
          invite_code: inviteCode,
          subscription_plan: 'premium'
        })
        .select('id')
        .single();

      if (assocCreateErr) throw assocCreateErr;
      associationId = newAssoc.id;
      console.log(`Created new Bar Association with ID: ${associationId}`);
    }

    // 2. Create Admin User in auth.users
    const adminEmail = 'secretary@barcouncil.in';
    const adminPassword = 'Password123';
    let adminUserId;

    // Check if user already exists
    const { data: { users }, error: listErr } = await supabase.auth.admin.listUsers();
    if (listErr) throw listErr;

    const existingUser = users.find(u => u.email === adminEmail);

    if (existingUser) {
      adminUserId = existingUser.id;
      console.log(`Admin Auth User already exists with ID: ${adminUserId}`);
    } else {
      const { data: newUser, error: userCreateErr } = await supabase.auth.admin.createUser({
        email: adminEmail,
        password: adminPassword,
        email_confirm: true
      });

      if (userCreateErr) throw userCreateErr;
      adminUserId = newUser.user.id;
      console.log(`Created new Admin Auth User with ID: ${adminUserId}`);
    }

    // 3. Ensure profile is updated
    const { error: profileErr } = await supabase
      .from('profiles')
      .upsert({
        id: adminUserId,
        email: adminEmail,
        full_name: 'Adv. Rajesh Kumar',
        bar_association_id: associationId
      });

    if (profileErr) {
      console.warn('Profile upsert warning (might be fine if trigger handled it):', profileErr.message);
    } else {
      console.log('Profile updated successfully.');
    }

    // 4. Ensure Bar Member record exists for the admin
    let memberId;
    const { data: existingMember, error: memberGetErr } = await supabase
      .from('bar_members')
      .select('id')
      .eq('association_id', associationId)
      .eq('user_id', adminUserId)
      .maybeSingle();

    if (memberGetErr) throw memberGetErr;

    if (existingMember) {
      memberId = existingMember.id;
      console.log(`Bar Member record already exists with ID: ${memberId}`);
    } else {
      const { data: newMember, error: memberCreateErr } = await supabase
        .from('bar_members')
        .insert({
          association_id: associationId,
          user_id: adminUserId,
          name: 'Adv. Rajesh Kumar',
          enrollment_number: 'D/4820/2012',
          mobile: '9876543210',
          email: adminEmail,
          membership_type: 'life',
          status: 'active',
          joined_year: 2012,
          fee_paid_until: 2026,
          is_caseflow_user: true
        })
        .select('id')
        .single();

      if (memberCreateErr) throw memberCreateErr;
      memberId = newMember.id;
      console.log(`Created Bar Member record with ID: ${memberId}`);
    }

    // 5. Ensure Bar Admin record exists
    const { data: existingAdmin, error: adminGetErr } = await supabase
      .from('bar_admins')
      .select('id')
      .eq('association_id', associationId)
      .eq('user_id', adminUserId)
      .maybeSingle();

    if (adminGetErr) throw adminGetErr;

    if (existingAdmin) {
      console.log(`Bar Admin record already exists with ID: ${existingAdmin.id}`);
    } else {
      const { data: newAdmin, error: adminCreateErr } = await supabase
        .from('bar_admins')
        .insert({
          association_id: associationId,
          user_id: adminUserId,
          role: 'secretary'
        })
        .select('id')
        .single();

      if (adminCreateErr) throw adminCreateErr;
      console.log(`Created Bar Admin record with ID: ${newAdmin.id}`);
    }

    // 6. Insert Mock Data (Members, Notices, Events, Payments) if they don't exist
    const { count: memberCount, error: countErr } = await supabase
      .from('bar_members')
      .select('id', { count: 'exact', head: true })
      .eq('association_id', associationId);

    if (countErr) throw countErr;

    console.log(`Current member count for association: ${memberCount}`);

    // If we only have the 1 admin member, add some more
    if (memberCount <= 1) {
      console.log('Inserting mock members...');
      const mockMembers = [
        {
          association_id: associationId,
          name: 'Adv. Priya Sharma',
          enrollment_number: 'D/1234/2015',
          mobile: '9812345678',
          email: 'priya.sharma@gmail.com',
          membership_type: 'regular',
          status: 'active',
          joined_year: 2015,
          fee_paid_until: 2026,
          is_caseflow_user: true
        },
        {
          association_id: associationId,
          name: 'Adv. Amit Patel',
          enrollment_number: 'D/5678/2018',
          mobile: '9823456789',
          email: 'amit.patel@yahoo.com',
          membership_type: 'regular',
          status: 'active',
          joined_year: 2018,
          fee_paid_until: 2025,
          is_caseflow_user: false
        },
        {
          association_id: associationId,
          name: 'Adv. Vikram Singh',
          enrollment_number: 'D/9012/2010',
          mobile: '9834567890',
          email: 'vikram.singh@outlook.com',
          membership_type: 'life',
          status: 'active',
          joined_year: 2010,
          fee_paid_until: 2026,
          is_caseflow_user: true
        },
        {
          association_id: associationId,
          name: 'Adv. Sneha Reddy',
          enrollment_number: 'D/3456/2021',
          mobile: '9845678901',
          email: 'sneha.reddy@gmail.com',
          membership_type: 'regular',
          status: 'suspended',
          joined_year: 2021,
          fee_paid_until: 2024,
          is_caseflow_user: false
        }
      ];

      const { data: insertedMembers, error: mockMemErr } = await supabase
        .from('bar_members')
        .insert(mockMembers)
        .select('id, name');

      if (mockMemErr) throw mockMemErr;
      console.log(`Inserted ${insertedMembers.length} mock members.`);

      // Create payments for these members
      console.log('Inserting mock payments...');
      const mockPayments = insertedMembers.map((m, idx) => ({
        association_id: associationId,
        member_id: m.id,
        amount: 1200.00,
        fee_year: 2026,
        payment_method: idx % 2 === 0 ? 'razorpay' : 'cash',
        status: idx === 3 ? 'pending' : 'paid',
        receipt_number: `BAR/2026/000${idx + 1}`,
        paid_at: idx === 3 ? null : new Date(Date.now() - idx * 24 * 60 * 60 * 1000).toISOString()
      }));

      // Add a payment for the admin too
      mockPayments.push({
        association_id: associationId,
        member_id: memberId,
        amount: 1200.00,
        fee_year: 2026,
        payment_method: 'razorpay',
        status: 'paid',
        receipt_number: 'BAR/2026/0005',
        paid_at: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString()
      });

      const { error: payErr } = await supabase.from('bar_fee_payments').insert(mockPayments);
      if (payErr) throw payErr;
      console.log('Inserted mock payments.');
    }

    // Insert notices if none exist
    const { count: noticeCount, error: noticeCountErr } = await supabase
      .from('bar_notices')
      .select('id', { count: 'exact', head: true })
      .eq('association_id', associationId);

    if (noticeCountErr) throw noticeCountErr;

    if (noticeCount === 0) {
      console.log('Inserting mock notices...');
      const mockNotices = [
        {
          association_id: associationId,
          title: 'Annual General Body Meeting 2026',
          body: 'All members of the Supreme Court Bar Association are hereby requested to attend the Annual General Body Meeting scheduled for July 15, 2026 at 4:30 PM in the Main Auditorium. Agenda includes review of accounts and discussion on new library facilities.',
          category: 'general',
          is_pinned: true,
          published_by: adminUserId
        },
        {
          association_id: associationId,
          title: 'Urgent: Revision of Library Timings',
          body: 'Please note that the library timings have been revised. Effective from next Monday, the library will remain open from 9:00 AM to 8:00 PM on all working days. On Saturdays, it will open from 10:00 AM to 5:00 PM.',
          category: 'urgent',
          is_pinned: false,
          published_by: adminUserId
        },
        {
          association_id: associationId,
          title: 'SCBA Annual Sports Meet 2026',
          body: 'Registration is now open for the Annual Sports Meet. Events include Badminton, Table Tennis, Chess, and Cricket. Interested members can register at the counter before July 5, 2026.',
          category: 'event',
          is_pinned: false,
          published_by: adminUserId
        }
      ];

      const { error: noticeErr } = await supabase.from('bar_notices').insert(mockNotices);
      if (noticeErr) throw noticeErr;
      console.log('Inserted mock notices.');
    }

    // Insert events if none exist
    const { count: eventCount, error: eventCountErr } = await supabase
      .from('bar_events')
      .select('id', { count: 'exact', head: true })
      .eq('association_id', associationId);

    if (eventCountErr) throw eventCountErr;

    if (eventCount === 0) {
      console.log('Inserting mock events...');
      const today = new Date();
      const nextWeek = new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000);

      const mockEvents = [
        {
          association_id: associationId,
          title: 'Lecture on Constitutional Law Reforms',
          description: 'A guest lecture by Retired Supreme Court Justice on recent constitutional amendments and judicial activism.',
          event_date: nextWeek.toISOString().split('T')[0],
          start_time: '16:00:00',
          end_time: '18:00:00',
          location: 'Seminar Hall, A-Block',
          agenda: '1. Opening remarks\n2. Guest Lecture\n3. Q&A Session\n4. High Tea',
          category: 'lecture',
          created_by: adminUserId
        },
        {
          association_id: associationId,
          title: 'Independence Day Celebrations',
          description: 'Flag hoisting ceremony followed by breakfast and interaction with senior advocates.',
          event_date: '2026-08-15',
          start_time: '08:30:00',
          end_time: '10:30:00',
          location: 'Front Lawns',
          agenda: 'Flag hoisting, National Anthem, Speeches, Breakfast',
          category: 'annual',
          created_by: adminUserId
        }
      ];

      const { error: eventErr } = await supabase.from('bar_events').insert(mockEvents);
      if (eventErr) throw eventErr;
      console.log('Inserted mock events.');
    }

    console.log('--- BAR ASSOCIATION SETUP COMPLETED SUCCESSFULLY ---');
    console.log(`Login Email: ${adminEmail}`);
    console.log(`Login Password: ${adminPassword}`);
    console.log('----------------------------------------------------');

  } catch (error) {
    console.error('Failed to setup bar association data:', error);
  }
}

setupBarAdmin();
