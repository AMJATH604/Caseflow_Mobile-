import { supabase } from "./supabase";

/**
 * Who can see which records — a line-for-line port of
 * `BaseRepository.buildVisibilityFilter` / `buildCaseVisibilityFilter` in
 * apps/mobile/lib/services/repositories/base_repository.dart.
 *
 * Keep the two in step. If the web scoped cases differently from the phone,
 * an advocate would see a different case list on each — or a junior would
 * see a case on one and not the other.
 *
 * The rule, from the project notes: `firm_id = auth.uid()` means "I am the
 * firm owner". A solo advocate's records carry their own id as firm_id; a
 * junior who has joined a firm carries that firm's id on their profile.
 */
export interface VisibilityProfile {
  id: string;
  firm_id: string | null;
}

export function buildVisibilityFilter(
  profile: VisibilityProfile,
  userId: string,
  userField = "assigned_to",
): string {
  let filter = `${userField}.eq.${userId}`;
  if (profile.firm_id) filter += `,firm_id.eq.${profile.firm_id}`;
  // Mobile: `isFirmOwner => firmId == null`.
  if (!profile.firm_id) filter += `,firm_id.eq.${userId}`;
  return filter;
}

/**
 * The case filter: own and firm cases, plus every case shared through an
 * accepted collaboration. Hearings, payments and e-filing scope themselves to
 * case ids, so a shared case missing here would hide its hearings too.
 */
export async function buildCaseVisibilityFilter(
  profile: VisibilityProfile,
  userId: string,
  email: string | null | undefined,
): Promise<string> {
  const base = buildVisibilityFilter(profile, userId);

  const parts = [`collaborator_id.eq.${userId}`];
  if (email) parts.push(`collaborator_email.eq.${email}`);
  const { data, error } = await supabase
    .from("case_collaborations")
    .select("case_id")
    .or(parts.join(","))
    .eq("status", "accepted");
  if (error) throw error;

  const ids = (data ?? []).map((r) => r.case_id).filter(Boolean);
  // One `in.(…)` term, not one `id.eq.` per collaboration, so the filter
  // does not grow with the number of shared cases.
  return ids.length ? `${base},id.in.(${ids.join(",")})` : base;
}

/**
 * Makes user text safe inside a PostgREST `or()` — a comma or parenthesis
 * would otherwise add a filter term and widen what the query can see.
 * Port of `BaseRepository.sanitizeFilterValue`.
 */
export function sanitizeFilterValue(value: string, maxLength = 100): string {
  const cleaned = value
    .replace(/[,()"\\.%_*]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return cleaned.length > maxLength ? cleaned.slice(0, maxLength) : cleaned;
}
