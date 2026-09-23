/// The case number an advocate would read off the cause list, recovered from
/// an eCourts export.
///
/// The export carries the number three ways, and only one of them is right on
/// its own:
///
/// * `reg_no` is prefixed with a register-series digit on many older cases.
///   `OS 194/2014` arrives as `reg_no: 300194`, `SC 638/2018` as `600638`.
///   Joining type, `reg_no` and year printed `OS/300194/2014`, a number no
///   court board ever shows.
/// * `case_no` packs everything into 15 digits —
///   `2317 03 00194 2014` = type code, series, number, year — so the number is
///   exactly the five digits at positions 6–10. Every case in a real Tenkasi
///   export decodes cleanly this way, and it agrees with `reg_no` once the
///   series digit is dropped.
/// * A case that is filed but not yet registered has `reg_no: 0`,
///   `reg_year: 0` and `case_no: null`. Joining those printed `EP/0/0`. Its
///   only number is the filing number, which is shown marked as such.
class ECourtsCaseNumber {
  const ECourtsCaseNumber._();

  static final _packed = RegExp(r'^\d{15}$');

  /// `OS/194/2014`, `EP/1122/2026 (filed)`, or null when the record carries
  /// no usable number at all.
  static String? fromJson(Map<String, dynamic> data) {
    final type = _text(data['type_name']);

    // 1. The packed case_no — authoritative, series already separated out.
    final packed = _text(data['case_no']);
    if (packed != null && _packed.hasMatch(packed)) {
      final number = int.parse(packed.substring(6, 11));
      final year = packed.substring(11, 15);
      if (number > 0) return _join(type, number, year);
    }

    // 2. reg_no / reg_year, with the series digit stripped. A trial court does
    // not register six-digit case counts in a year, so a six-digit reg_no is
    // a series prefix on a five-digit number, never a real value.
    final reg = _int(data['reg_no']);
    final regYear = _int(data['reg_year']);
    if (reg != null && reg > 0 && regYear != null && regYear > 0) {
      final number = reg >= 100000 && reg <= 999999 ? reg % 100000 : reg;
      if (number > 0) return _join(type, number, '$regYear');
    }

    // 3. Filed, not yet registered: the filing number is all there is. Marked,
    // so it is never mistaken for a registered case with the same digits.
    final fil = _int(data['fil_no']);
    final filYear = _int(data['fil_year']);
    if (fil != null && fil > 0 && filYear != null && filYear > 0) {
      return '${_join(type, fil, '$filYear')} (filed)';
    }

    // 4. Some other export shape that already carries a formatted number.
    if (packed != null && !_packed.hasMatch(packed)) return packed;
    return _text(data['case_number']);
  }

  static String _join(String? type, int number, String year) =>
      type == null ? '$number/$year' : '$type/$number/$year';

  static String? _text(Object? value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty || s == 'null' ? null : s;
  }

  static int? _int(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString().trim());
  }
}
