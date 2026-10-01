/**
 * Court fee on a §138 NI Act complaint in Tamil Nadu — a port of
 * NiActComplaintFee in apps/mobile/lib/utils/court_fee_rules.dart.
 *
 * Both are checked against packages/legal-fixtures/ni_act_court_fee.json;
 * change the fixture first, then both implementations. See that file's README.
 *
 * TN Court-Fees and Suits Valuation Act, 1955, Schedule II, Article 20:
 *   current (2017 amendment): ½% ad valorem, maximum ₹10,000
 *   legacy (2003–2017):       ₹25 per ₹50,000 or part, maximum ₹1,000
 */
export const NI_ACT_RATE = 0.005;
export const NI_ACT_MAX_FEE = 10_000;
export const LEGACY_SLAB = 50_000;
export const LEGACY_PER_SLAB = 25;
export const LEGACY_MAX_FEE = 1_000;

/**
 * Fee payable today. Rounded UP to the rupee, as §21-A requires — ₹33,333
 * computes to ₹166.665 and is payable as ₹167. JavaScript numbers are the same
 * IEEE-754 doubles as Dart's, so `amount * rate` and its ceiling agree with
 * the mobile app bit for bit.
 */
export function niActFee(amount: number, rate = NI_ACT_RATE, maxFee: number | null = NI_ACT_MAX_FEE): number {
  if (!(amount > 0)) return 0;
  let fee = Math.ceil(amount * rate);
  if (maxFee !== null && fee > maxFee) fee = maxFee;
  return fee;
}

/**
 * Fee under Article 20 before 2017. Integer arithmetic on whole rupees, so a
 * floating-point remainder can never tip an exact slab boundary into the next
 * slab — ₹50,000 is one slab, ₹50,000.01 is two.
 */
export function niActLegacyFee(
  amount: number,
  slab = LEGACY_SLAB,
  perSlab = LEGACY_PER_SLAB,
  maxFee: number | null = LEGACY_MAX_FEE,
): number {
  if (!(amount > 0)) return 0;
  const rupees = Math.ceil(amount);
  const slabs = Math.floor((rupees + slab - 1) / slab);
  let fee = slabs * perSlab;
  if (maxFee !== null && fee > maxFee) fee = maxFee;
  return fee;
}
