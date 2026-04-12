# Tasks - Securing Admin Panel

- [x] **Database Migration**
    - [x] Provide SQL migration to user (Manually run in Supabase)
- [x] **Web Dashboard Updates**
    - [x] Modify `useAuth.tsx` to handle `isAdmin` state
    - [x] Create `Unauthorized.tsx` access denied page
    - [x] Update `App.tsx` to enforce admin-only routing
- [x] **Verification**
    - [x] Confirm regular users are redirected to Unauthorized page

# Tasks - [x] Clear out legacy "hectic" manual sync code
- [x] Database & Model Expansion
- [x] UI/UX Overhaul for "Set and Forget"
- [x] Backend Intelligence (Supabase Edge Functions)
    - [x] Create `sync-case-monitor` Edge Function (Scaffold)
    - [x] Implement orchestration logic (Cron trigger)
    - [x] Create `send-sync-notifications` notification bridge
    - [x] Implement Gemini-based Free Captcha Solver
    - [x] Integrate Browserless for headless eCourts scraping
- [x] Notification System
- [x] Verification & Polish
