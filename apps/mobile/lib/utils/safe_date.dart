/// Date parsing for values arriving from the database.
///
/// Models build themselves from rows inside an unguarded `.map()`, so a single
/// unparseable date thrown by `DateTime.parse` fails the *entire* list query
/// rather than the one bad record — one malformed row makes a whole screen
/// stop loading until the database is edited by hand.
///
/// These helpers degrade instead of throwing, and go one step further: a value
/// in the `DD-MM-YYYY` / `DD/MM/YYYY` form the eCourts import and older backups
/// produce is *recovered* rather than discarded, so rows already written
/// unnormalised still read correctly.
///
/// Kept free of imports on purpose. `BaseRepository` owns the equivalent
/// normaliser for the write path, but it imports the models, so depending on
/// it here would close an import cycle.
library;

/// Matches `DD-MM-YYYY` and `DD/MM/YYYY`, with or without leading zeros.
final RegExp _dayFirstDate = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$');

/// Parses a database date value, returning null when it cannot be read.
DateTime? parseDateOrNull(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  // ISO-8601, which is what a correctly written row holds.
  final direct = DateTime.tryParse(raw);
  if (direct != null) return direct;

  // Recover a day-first date rather than dropping it: these reach the database
  // from eCourts imports and restored backups written before the write path
  // normalised them.
  final match = _dayFirstDate.firstMatch(raw);
  if (match != null) {
    final day = match.group(1)!.padLeft(2, '0');
    final month = match.group(2)!.padLeft(2, '0');
    final year = match.group(3)!;
    return DateTime.tryParse('$year-$month-$day');
  }

  return null;
}

/// Parses a database date value, falling back when it cannot be read.
///
/// For the non-nullable fields that previously wrote
/// `DateTime.parse(json['x'] ?? DateTime.now().toIso8601String())` — same
/// intent, except a value that is present but malformed now also reaches the
/// fallback instead of throwing.
DateTime parseDateOr(dynamic value, DateTime fallback) =>
    parseDateOrNull(value) ?? fallback;
