-- ═══════════════════════════════════════════════════════════════
-- RLS + storage hardening — Phase A
--
-- Every hole closed here was proven against the live database first, as an
-- ordinary user or a logged-out visitor, inside transactions that were rolled
-- back. None requires an app update.
--
--   D9  Any user could set profiles.firm_id to any advocate's id and read that
--       firm's cases and hearings (0 → 219 cases, 214 hearings in the test).
--   D9b Removing a junior never cleared their profiles.firm_id (the app's update
--       of another user's profile is silently blocked by RLS), so removed
--       juniors kept access.
--   D1  An invited collaborator could rewrite case_id on their invitation and
--       read any case (0 → 1 in the test).
--   D2  A junior could rewrite owner_id on their membership and join any firm.
--   D3  A logged-out visitor could delete/edit legal_embeddings (AI knowledge).
--   D4  Any user could edit bare acts, sections, stamp values, templates, portals.
--   D7  Any user could vote in any bar election.
--   S1-S4 Storage: anyone could LIST case documents, chat attachments and
--       commission files, and any user could delete them.
--
-- Deferred to Phase B (need an app update): making buckets private with signed
-- URLs, trimming profile columns visible to others, a server-side bar
-- association join (invite codes are readable by every user), and server-side
-- vote hashing (voter_hash is computed on the client).
-- ═══════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────
-- D9: profiles.firm_id may only point at a firm you actually belong to
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.guard_profile_firm_id()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $fn$
BEGIN
  -- Server-side writes (service role, triggers without a JWT) are trusted.
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.firm_id IS NULL OR NEW.firm_id = NEW.id THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.firm_id IS NOT DISTINCT FROM OLD.firm_id THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.firm_members fm
     WHERE fm.owner_id = NEW.firm_id
       AND fm.member_id = NEW.id
       AND fm.status = 'accepted'
  ) THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'You can only join a firm by accepting its invitation.'
    USING ERRCODE = '42501';
END;
$fn$;

REVOKE ALL ON FUNCTION public.guard_profile_firm_id() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_guard_profile_firm_id ON public.profiles;
CREATE TRIGGER trg_guard_profile_firm_id
  BEFORE INSERT OR UPDATE OF firm_id ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_profile_firm_id();


-- ─────────────────────────────────────────────────────────
-- D9b: leaving or being removed from a firm clears the profile link
-- ─────────────────────────────────────────────────────────
-- SECURITY DEFINER because the firm owner removing a junior must be able to
-- clear the JUNIOR's profile, which RLS (own row only) otherwise blocks.
CREATE OR REPLACE FUNCTION public.clear_firm_link_on_membership_end()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
DECLARE
  v_owner  uuid := OLD.owner_id;
  v_member uuid := OLD.member_id;
BEGIN
  IF v_member IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF TG_OP = 'DELETE'
     OR NEW.status IS DISTINCT FROM 'accepted'
     OR NEW.member_id IS DISTINCT FROM OLD.member_id
     OR NEW.owner_id IS DISTINCT FROM OLD.owner_id THEN
    UPDATE public.profiles
       SET firm_id = NULL
     WHERE id = v_member
       AND firm_id = v_owner
       AND NOT EXISTS (
         SELECT 1 FROM public.firm_members fm
          WHERE fm.owner_id = v_owner AND fm.member_id = v_member
            AND fm.status = 'accepted'
            AND (TG_OP = 'DELETE' OR fm.id <> OLD.id)
       );
  END IF;

  RETURN COALESCE(NEW, OLD);
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'clear_firm_link_on_membership_end: %', SQLERRM;
  RETURN COALESCE(NEW, OLD);
END;
$fn$;

REVOKE ALL ON FUNCTION public.clear_firm_link_on_membership_end() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_clear_firm_link_on_membership_end ON public.firm_members;
CREATE TRIGGER trg_clear_firm_link_on_membership_end
  AFTER UPDATE OR DELETE ON public.firm_members
  FOR EACH ROW EXECUTE FUNCTION public.clear_firm_link_on_membership_end();


-- ─────────────────────────────────────────────────────────
-- D1 + D2: an invitee may answer an invitation, never re-point it
-- ─────────────────────────────────────────────────────────
-- RLS WITH CHECK cannot compare OLD and NEW, so the respond policies could only
-- constrain the new status. This trigger pins every other column for anyone who
-- is not the row's owner.
CREATE OR REPLACE FUNCTION public.guard_invitation_response()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $fn$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR v_uid = OLD.owner_id THEN
    RETURN NEW;
  END IF;

  IF TG_TABLE_NAME = 'firm_members' THEN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.owner_id IS DISTINCT FROM OLD.owner_id
       OR NEW.member_email IS DISTINCT FROM OLD.member_email
       OR NEW.role IS DISTINCT FROM OLD.role
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
       OR (NEW.member_id IS DISTINCT FROM OLD.member_id AND NEW.member_id IS DISTINCT FROM v_uid) THEN
      RAISE EXCEPTION 'An invitation can only be accepted or declined.'
        USING ERRCODE = '42501';
    END IF;
  ELSE
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.owner_id IS DISTINCT FROM OLD.owner_id
       OR NEW.case_id IS DISTINCT FROM OLD.case_id
       OR NEW.collaborator_email IS DISTINCT FROM OLD.collaborator_email
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
       OR (NEW.collaborator_id IS DISTINCT FROM OLD.collaborator_id AND NEW.collaborator_id IS DISTINCT FROM v_uid) THEN
      RAISE EXCEPTION 'An invitation can only be accepted or declined.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION public.guard_invitation_response() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_guard_invitation_response ON public.firm_members;
CREATE TRIGGER trg_guard_invitation_response
  BEFORE UPDATE ON public.firm_members
  FOR EACH ROW EXECUTE FUNCTION public.guard_invitation_response();

DROP TRIGGER IF EXISTS trg_guard_invitation_response ON public.case_collaborations;
CREATE TRIGGER trg_guard_invitation_response
  BEFORE UPDATE ON public.case_collaborations
  FOR EACH ROW EXECUTE FUNCTION public.guard_invitation_response();


-- ─────────────────────────────────────────────────────────
-- D3: legal_embeddings — writes only through the service role
-- ─────────────────────────────────────────────────────────
-- These three policies were NAMED "service_role" but granted to role `public`,
-- i.e. everyone including logged-out visitors. The service role bypasses RLS
-- and needs no policy; embedding-pipeline writes with it.
DROP POLICY IF EXISTS "Allow service_role insert on legal_embeddings" ON public.legal_embeddings;
DROP POLICY IF EXISTS "Allow service_role update on legal_embeddings" ON public.legal_embeddings;
DROP POLICY IF EXISTS "Allow service_role delete on legal_embeddings" ON public.legal_embeddings;


-- ─────────────────────────────────────────────────────────
-- D4: shared legal content — administrators write, everyone reads
-- ─────────────────────────────────────────────────────────
-- Admin check inline rather than via a SECURITY DEFINER helper: a user can
-- always read their own profile row, and protect_profile_privilege_columns
-- stops anyone granting themselves is_admin.

-- bare_acts
DROP POLICY IF EXISTS "Authenticated users can insert bare acts" ON public.bare_acts;
DROP POLICY IF EXISTS "Authenticated users can update bare acts" ON public.bare_acts;
DROP POLICY IF EXISTS "Authenticated users can delete bare acts" ON public.bare_acts;
DROP POLICY IF EXISTS "Admins can insert bare acts" ON public.bare_acts;
DROP POLICY IF EXISTS "Admins can update bare acts" ON public.bare_acts;
DROP POLICY IF EXISTS "Admins can delete bare acts" ON public.bare_acts;
CREATE POLICY "Admins can insert bare acts" ON public.bare_acts FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin));
CREATE POLICY "Admins can update bare acts" ON public.bare_acts FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin));
CREATE POLICY "Admins can delete bare acts" ON public.bare_acts FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin));

-- bare_act_sections
DROP POLICY IF EXISTS "Authenticated users can insert sections" ON public.bare_act_sections;
DROP POLICY IF EXISTS "Authenticated users can update sections" ON public.bare_act_sections;
DROP POLICY IF EXISTS "Authenticated users can delete sections" ON public.bare_act_sections;
DROP POLICY IF EXISTS "Admins can insert sections" ON public.bare_act_sections;
DROP POLICY IF EXISTS "Admins can update sections" ON public.bare_act_sections;
DROP POLICY IF EXISTS "Admins can delete sections" ON public.bare_act_sections;
CREATE POLICY "Admins can insert sections" ON public.bare_act_sections FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin));
CREATE POLICY "Admins can update sections" ON public.bare_act_sections FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin));
CREATE POLICY "Admins can delete sections" ON public.bare_act_sections FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin));

-- stamp_values
DROP POLICY IF EXISTS "Allow authenticated users to insert stamp_values" ON public.stamp_values;
DROP POLICY IF EXISTS "Allow authenticated users to update stamp_values" ON public.stamp_values;
DROP POLICY IF EXISTS "Allow authenticated users to delete stamp_values" ON public.stamp_values;
DROP POLICY IF EXISTS "Admins can insert stamp_values" ON public.stamp_values;
DROP POLICY IF EXISTS "Admins can update stamp_values" ON public.stamp_values;
DROP POLICY IF EXISTS "Admins can delete stamp_values" ON public.stamp_values;
CREATE POLICY "Admins can insert stamp_values" ON public.stamp_values FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin));
CREATE POLICY "Admins can update stamp_values" ON public.stamp_values FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin));
CREATE POLICY "Admins can delete stamp_values" ON public.stamp_values FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin));

-- legal_templates (public read policy is separate and stays)
DROP POLICY IF EXISTS "Auth management for legal templates" ON public.legal_templates;
DROP POLICY IF EXISTS "Admins manage legal templates" ON public.legal_templates;
CREATE POLICY "Admins manage legal templates" ON public.legal_templates FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin));

-- district_portals
DROP POLICY IF EXISTS "Authenticated users can insert portals" ON public.district_portals;
DROP POLICY IF EXISTS "Admins can insert portals" ON public.district_portals;
CREATE POLICY "Admins can insert portals" ON public.district_portals FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin));


-- ─────────────────────────────────────────────────────────
-- D7: only members of the association may vote in its elections
-- ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Authenticated users cast votes" ON public.bar_votes;
DROP POLICY IF EXISTS "Members cast votes in their association" ON public.bar_votes;
CREATE POLICY "Members cast votes in their association" ON public.bar_votes FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1
      FROM public.bar_election_posts bp
      JOIN public.bar_elections be ON be.id = bp.election_id
     WHERE bp.id = bar_votes.post_id
       AND public.is_association_member(be.association_id, auth.uid())
  ));


-- ─────────────────────────────────────────────────────────
-- S1-S4: storage — only people with access to the record reach its files
-- ─────────────────────────────────────────────────────────
-- Folder layouts (from the app):
--   case-documents        <case_id>/<file>
--   chat-attachments      dms/<conversation_id>/<file>  |  chambers/<firm_owner_id>/<file>
--   commission-*          <commission_id>/...
-- Each subquery runs under the caller's own RLS, so "EXISTS a case with this
-- id" means "a case this user is allowed to see".
--
-- These buckets are still PUBLIC, so an existing link keeps opening the file —
-- the app depends on that today. What this removes is LISTING (finding files)
-- and cross-user delete/overwrite. Private buckets + signed URLs are Phase B.

-- case-documents
DROP POLICY IF EXISTS "Users can read documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own documents" ON storage.objects;
DROP POLICY IF EXISTS "case_documents_select" ON storage.objects;
DROP POLICY IF EXISTS "case_documents_insert" ON storage.objects;
DROP POLICY IF EXISTS "case_documents_update" ON storage.objects;
DROP POLICY IF EXISTS "case_documents_delete" ON storage.objects;
CREATE POLICY "case_documents_select" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'case-documents'
         AND EXISTS (SELECT 1 FROM public.cases c WHERE c.id::text = (storage.foldername(name))[1]));
CREATE POLICY "case_documents_insert" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'case-documents'
              AND EXISTS (SELECT 1 FROM public.cases c WHERE c.id::text = (storage.foldername(name))[1]));
CREATE POLICY "case_documents_update" ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'case-documents'
         AND EXISTS (SELECT 1 FROM public.cases c WHERE c.id::text = (storage.foldername(name))[1]))
  WITH CHECK (bucket_id = 'case-documents'
              AND EXISTS (SELECT 1 FROM public.cases c WHERE c.id::text = (storage.foldername(name))[1]));
CREATE POLICY "case_documents_delete" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'case-documents'
         AND EXISTS (SELECT 1 FROM public.cases c WHERE c.id::text = (storage.foldername(name))[1]));

-- chat-attachments
DROP POLICY IF EXISTS "chat_attachments_select" ON storage.objects;
DROP POLICY IF EXISTS "chat_attachments_insert" ON storage.objects;
DROP POLICY IF EXISTS "chat_attachments_delete" ON storage.objects;
CREATE POLICY "chat_attachments_select" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'chat-attachments' AND (
    ((storage.foldername(name))[1] = 'dms'
      AND EXISTS (SELECT 1 FROM public.direct_conversations d WHERE d.id::text = (storage.foldername(name))[2]))
    OR ((storage.foldername(name))[1] = 'chambers' AND (
          (storage.foldername(name))[2] = auth.uid()::text
       OR (storage.foldername(name))[2] = (SELECT p.firm_id::text FROM public.profiles p WHERE p.id = auth.uid())
       OR EXISTS (SELECT 1 FROM public.firm_members fm
                   WHERE fm.owner_id::text = (storage.foldername(name))[2]
                     AND fm.member_id = auth.uid() AND fm.status = 'accepted')))));
CREATE POLICY "chat_attachments_insert" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'chat-attachments' AND (
    ((storage.foldername(name))[1] = 'dms'
      AND EXISTS (SELECT 1 FROM public.direct_conversations d WHERE d.id::text = (storage.foldername(name))[2]))
    OR ((storage.foldername(name))[1] = 'chambers' AND (
          (storage.foldername(name))[2] = auth.uid()::text
       OR (storage.foldername(name))[2] = (SELECT p.firm_id::text FROM public.profiles p WHERE p.id = auth.uid())
       OR EXISTS (SELECT 1 FROM public.firm_members fm
                   WHERE fm.owner_id::text = (storage.foldername(name))[2]
                     AND fm.member_id = auth.uid() AND fm.status = 'accepted')))));
-- Only the uploader may delete a chat file.
CREATE POLICY "chat_attachments_delete" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'chat-attachments' AND owner_id = auth.uid()::text);

-- commission-evidence / commission-sketches / commission-witnesses
DROP POLICY IF EXISTS "commission_evidence_select" ON storage.objects;
DROP POLICY IF EXISTS "commission_evidence_upload" ON storage.objects;
DROP POLICY IF EXISTS "commission_evidence_delete" ON storage.objects;
DROP POLICY IF EXISTS "sketch_select" ON storage.objects;
DROP POLICY IF EXISTS "sketch_upload" ON storage.objects;
DROP POLICY IF EXISTS "sketch_delete" ON storage.objects;
DROP POLICY IF EXISTS "witness_select" ON storage.objects;
DROP POLICY IF EXISTS "witness_upload" ON storage.objects;
DROP POLICY IF EXISTS "witness_delete" ON storage.objects;
DROP POLICY IF EXISTS "commission_files_select" ON storage.objects;
DROP POLICY IF EXISTS "commission_files_insert" ON storage.objects;
DROP POLICY IF EXISTS "commission_files_delete" ON storage.objects;
CREATE POLICY "commission_files_select" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id IN ('commission-evidence', 'commission-sketches', 'commission-witnesses')
         AND EXISTS (SELECT 1 FROM public.commissions c WHERE c.id::text = (storage.foldername(name))[1]));
CREATE POLICY "commission_files_insert" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id IN ('commission-evidence', 'commission-sketches', 'commission-witnesses')
              AND EXISTS (SELECT 1 FROM public.commissions c WHERE c.id::text = (storage.foldername(name))[1]));
CREATE POLICY "commission_files_delete" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id IN ('commission-evidence', 'commission-sketches', 'commission-witnesses')
         AND EXISTS (SELECT 1 FROM public.commissions c WHERE c.id::text = (storage.foldername(name))[1]));

-- bare_acts / legal_templates buckets: public read stays, uploads admin-only
DROP POLICY IF EXISTS "Authenticated users can upload bare act PDFs" ON storage.objects;
DROP POLICY IF EXISTS "Auth upload for legal template files" ON storage.objects;
DROP POLICY IF EXISTS "Admins upload content files" ON storage.objects;
CREATE POLICY "Admins upload content files" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id IN ('bare_acts', 'legal_templates')
              AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_admin));
