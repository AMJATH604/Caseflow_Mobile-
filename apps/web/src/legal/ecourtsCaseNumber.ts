/**
 * The case number as the court board shows it, from an eCourts export record —
 * a port of ECourtsCaseNumber in apps/mobile/lib/utils/ecourts_case_number.dart.
 * Both are checked against packages/legal-fixtures/ecourts_case_number.json.
 *
 *  - `case_no` packs type(4) + series(2) + number(5) + year(4); the number is
 *    the five digits after the series: 2317 03 00194 2014 → 194.
 *  - `reg_no` carries a series digit on older cases: 300194 → 194.
 *  - A filed-but-unregistered case (reg_no 0) shows its filing number,
 *    marked "(filed)", never "EP/0/0".
 */
type Raw = Record<string, unknown>;

const PACKED = /^\d{15}$/;

const text = (v: unknown): string | null => {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s === "" || s === "null" ? null : s;
};

const int = (v: unknown): number | null => {
  if (v === null || v === undefined) return null;
  if (typeof v === "number") return Number.isInteger(v) ? v : null;
  const s = String(v).trim();
  return /^-?\d+$/.test(s) ? Number(s) : null;
};

const join = (type: string | null, n: number, year: string) => (type ? `${type}/${n}/${year}` : `${n}/${year}`);

export function ecourtsCaseNumber(data: Raw): string | null {
  const type = text(data.type_name);

  const packed = text(data.case_no);
  if (packed && PACKED.test(packed)) {
    const n = Number(packed.slice(6, 11));
    if (n > 0) return join(type, n, packed.slice(11, 15));
  }

  const reg = int(data.reg_no);
  const regYear = int(data.reg_year);
  if (reg !== null && reg > 0 && regYear !== null && regYear > 0) {
    const n = reg >= 100_000 && reg <= 999_999 ? reg % 100_000 : reg;
    if (n > 0) return join(type, n, String(regYear));
  }

  const fil = int(data.fil_no);
  const filYear = int(data.fil_year);
  if (fil !== null && fil > 0 && filYear !== null && filYear > 0) {
    return `${join(type, fil, String(filYear))} (filed)`;
  }

  if (packed && !PACKED.test(packed)) return packed;
  return text(data.case_number);
}
