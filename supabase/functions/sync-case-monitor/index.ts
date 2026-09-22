// Supabase Edge Function: sync-case-monitor
//
// Daily eCourts sync for cases with auto-sync enabled, via Apify. Called by the
// daily-case-sync-monitor cron job.
//
// This function was deployed without being in the repository. Its only "auth"
// was checking that an Authorization header EXISTED — any string passed — after
// which it updated cases with the service role and spent Apify credits. It is
// now guarded like every other cron-driven function.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.7';
import { verifyWebhookAuth } from "../_shared/auth_guard.ts";
import { requireSecretKey } from "../_shared/keys.ts";

interface CaseUpdateResult {
  next_hearing_date?: string | null;
  case_status?: string | null;
  judge_name?: string | null;
  registration_date?: string | null;
  petitioner_name?: string | null;
  respondent_name?: string | null;
  history?: any[];
  ias?: any[];
}

Deno.serve(async (req) => {
  const authError = await verifyWebhookAuth(req);
  if (authError) return authError;

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    requireSecretKey()
  );

  const APIFY_TOKEN = Deno.env.get('APIFY_TOKEN');
  if (!APIFY_TOKEN) {
    return new Response(JSON.stringify({ 
      error: 'APIFY_TOKEN is missing. Please run: npx supabase secrets set APIFY_TOKEN=your_token_here' 
    }), { status: 500 });
  }

  try {
    let reqBody = {} as any;
    try { reqBody = await req.json(); } catch (e) {}
    
    // FETCH CASES TO SYNC
    let query = supabase
      .from('cases')
      .select('id, cnr_number, created_by, next_hearing_date, stage')
      .eq('is_auto_sync_enabled', true);
      
    if (reqBody.case_id) {
      query = query.eq('id', reqBody.case_id);
    }

    const { data: casesToSync, error: fetchError } = await query;
    if (fetchError) throw fetchError;

    if (!casesToSync || casesToSync.length === 0) {
      return new Response(JSON.stringify({ success: true, message: 'No cases to sync' }));
    }

    const results = [];

    // BATCHING: Send all CNRs to Apify in one go if multiple cases
    const cnrs = casesToSync.map(c => c.cnr_number).filter(Boolean);
    console.log(`[APIFY SYNC] Starting batch sync for ${cnrs.length} cases...`);

    const apifyRes = await fetch(`https://api.apify.com/v2/acts/codingfrontend~ecourts-case-scraper/run-sync-get-dataset-items?token=${APIFY_TOKEN}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        caseNos: cnrs,
        maxCaptchaRetries: 10 // Increase for better reliability
      })
    });

    if (!apifyRes.ok) {
      const errorText = await apifyRes.text();
      throw new Error(`Apify API Error: ${apifyRes.status} - ${errorText}`);
    }

    const datasetItems = await apifyRes.json();
    console.log(`[APIFY SYNC] Received ${datasetItems.length} results from Apify`);

    // PROCESS RESULTS
    for (const caseRecord of casesToSync) {
      // Find the specific item in Apify results for this CNR
      const apifyItem = datasetItems.find((item: any) => 
        item.cnr_number === caseRecord.cnr_number || 
        item.cnr === caseRecord.cnr_number ||
        item.case_number === caseRecord.cnr_number
      );

      if (!apifyItem) {
        console.warn(`[APIFY SYNC] No data found for CNR: ${caseRecord.cnr_number}`);
        results.push({ id: caseRecord.id, cnr: caseRecord.cnr_number, status: 'not_found' });
        continue;
      }

      try {
        const mappedData = mapApifyToSupabase(apifyItem);
        
        // 1. Check for Changes
        const oldHearingDate = caseRecord.next_hearing_date;
        const newHearingDate = parseEcourtDate(mappedData.next_hearing_date);
        const oldStatus = caseRecord.stage;
        const newStatus = mappedData.case_status;

        const hasChanged = oldHearingDate !== newHearingDate || oldStatus !== newStatus;

        // 2. Update Cases Table
        const { error: updateError } = await supabase.from('cases').update({
          next_hearing_date: newHearingDate,
          stage: newStatus,
          judge_name: mappedData.judge_name,
          registration_date: parseEcourtDate(mappedData.registration_date),
          petitioner_name: mappedData.petitioner_name,
          respondent_name: mappedData.respondent_name,
          last_auto_sync_at: new Date().toISOString(),
          last_sync_status: 'success',
          sync_attempt_count: 0
        }).eq('id', caseRecord.id);

        if (updateError) throw updateError;

        // 3. Upsert History
        if (mappedData.history?.length) {
          const historyRows = mappedData.history.map((h: any) => ({
            case_id: caseRecord.id,
            cnr_number: caseRecord.cnr_number,
            hearing_date: parseEcourtDate(h.hearing_date || h.date),
            purpose: h.purpose || "",
            business_done: h.business_done || h.business || "",
            next_date: parseEcourtDate(h.next_date || h.nextDate),
            judge_name: h.judge || "",
            source: 'apify_monitor',
            created_by: caseRecord.created_by
          })).filter((h: any) => h.hearing_date !== null);

          if (historyRows.length > 0) {
            await supabase.from('ecourt_hearing_history').upsert(historyRows, { onConflict: 'case_id,cnr_number,hearing_date' });
          }
        }

        // 4. Notify if changed
        if (hasChanged) {
          console.log(`[NOTIFY] Change detected for ${caseRecord.cnr_number}`);
          await supabase.functions.invoke('send-sync-notifications', {
            body: { 
              case_id: caseRecord.id, 
              old_date: oldHearingDate, 
              new_date: newHearingDate,
              old_status: oldStatus,
              new_status: newStatus
            }
          });
        }

        results.push({ id: caseRecord.id, cnr: caseRecord.cnr_number, status: 'success' });

      } catch (err) {
        console.error(`[SYNC FAIL] ${caseRecord.cnr_number}:`, (err as Error).message);
        results.push({ id: caseRecord.id, cnr: caseRecord.cnr_number, status: 'error', message: (err as Error).message });
      }
    }

    return new Response(JSON.stringify({ success: true, results }), { headers: { 'Content-Type': 'application/json' } });

  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), { status: 500 });
  }
});

/**
 * Robust Mapper: Handles variations in field names between different actors
 */
function mapApifyToSupabase(item: any): CaseUpdateResult {
  return {
    next_hearing_date: item.next_hearing_date || item.nextHearingDate || item.Next_Hearing_Date || item.case_details?.['Next Hearing Date'],
    case_status: item.case_status || item.status || item.stage || item.case_status_table?.['Case Status'],
    judge_name: item.judge_name || item.judge || item.judgeName || item.case_status_table?.['Court Number and Judge'],
    registration_date: item.registration_date || item.registrationDate || item.case_details?.['Registration Date'],
    petitioner_name: item.petitioner_name || item.petitioner || item.petitioner_and_advocate?.split('\n')[0],
    respondent_name: item.respondent_name || item.respondent || item.respondent_and_advocate?.split('\n')[0],
    history: item.history || item.case_history || item.hearing_history || [],
    ias: item.ias || item.ia_status || item.interim_applications || []
  };
}

function parseEcourtDate(dateStr: string | undefined | null): string | null {
  if (!dateStr || typeof dateStr !== 'string' || dateStr.trim() === "" || /N\/A|Not|None/i.test(dateStr)) return null;
  
  // Normalize format
  const cleanStr = dateStr.replace(/(\d+)(st|nd|rd|th)/i, '$1').trim();
  
  // Check DD-MM-YYYY or DD/MM/YYYY
  if (/^\d{1,2}[-/]\d{1,2}[-/]\d{2,4}$/.test(cleanStr)) {
    const parts = cleanStr.split(/[-/]/);
    const day = parts[0].padStart(2, '0');
    const month = parts[1].padStart(2, '0');
    const year = parts[2].length === 2 ? `20${parts[2]}` : parts[2];
    return `${year}-${month}-${day}`;
  }
  
  try {
    const d = new Date(cleanStr);
    if (!isNaN(d.getTime())) return d.toISOString().split('T')[0];
  } catch (e) {}

  return null;
}
