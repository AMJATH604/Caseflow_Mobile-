/// What the two sides of a case are actually called.
///
/// The import flow offered only "Petitioner" and "Respondent", which is right
/// for a writ or an appeal and wrong everywhere else: a civil suit has a
/// plaintiff and a defendant, and a criminal complaint has a complainant and
/// an accused. An advocate asked to mark themselves "petitioner" on a cheque
/// complaint has to translate in their head, and translating is where the
/// wrong side gets picked.
///
/// The side is derived from the case-number prefix, which is the only clue
/// available in an eCourts export. When the prefix is unrecognised the labels
/// fall back to Petitioner/Respondent — the same behaviour as before, so an
/// unknown code is never worse than it used to be.
class PartyLabels {
  /// The party who brings the matter.
  final String first;

  /// The party who answers it.
  final String second;

  const PartyLabels(this.first, this.second);

  static const petitionerRespondent = PartyLabels('Petitioner', 'Respondent');
  static const plaintiffDefendant = PartyLabels('Plaintiff', 'Defendant');
  static const complainantAccused = PartyLabels('Complainant', 'Accused');

  /// Civil suits — the parties are plaintiff and defendant.
  ///
  /// OS original suit · AS appeal suit · SA second appeal · RCS regular civil
  /// suit · SC small cause · EP execution petition · IA interlocutory
  /// application · OP original petition.
  static const _civil = {
    'OS', 'AS', 'SA', 'RCS', 'SCS', 'EP', 'IA', 'OP', 'TOS', 'CS',
  };

  /// Criminal matters — complainant and accused.
  ///
  /// CC calendar case · STC summary trial case · SC sessions case · CRLMP
  /// criminal miscellaneous petition · NIA/NI Act cheque complaints.
  static const _criminal = {
    'CC', 'STC', 'CRLMP', 'CRMP', 'CRLOP', 'NI', 'NIACT', 'PRC', 'MC',
  };

  /// Labels for a case, from its case number (or explicit case type).
  ///
  /// `"O.S. 448/2022"`, `"OS/448/2022"` and `"os448of2022"` all resolve the
  /// same way — punctuation and spacing vary a great deal between courts and
  /// between the eCourts export and what an advocate types.
  static PartyLabels forCase({String? caseNumber, String? caseType}) {
    final prefix = _prefixOf(caseType) ?? _prefixOf(caseNumber);
    if (prefix == null) return petitionerRespondent;
    if (_criminal.contains(prefix)) return complainantAccused;
    if (_civil.contains(prefix)) return plaintiffDefendant;
    return petitionerRespondent;
  }

  /// The leading letters of a case number, uppercased with punctuation and
  /// spacing removed: `"O.S. 448/2022"` → `"OS"`.
  static String? _prefixOf(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.isEmpty) return null;
    final match = RegExp(r'^([A-Z]+)').firstMatch(cleaned);
    final prefix = match?.group(1);
    if (prefix == null || prefix.isEmpty) return null;
    return prefix;
  }
}
