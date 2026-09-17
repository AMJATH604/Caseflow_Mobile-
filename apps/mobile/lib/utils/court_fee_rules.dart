/// Court-fee rules that are worth testing on their own, kept out of the
/// calculator widget so the arithmetic can be verified without pumping a
/// screen. These figures are paid at a filing counter, so a rounding slip is
/// a real-money slip.
library;

/// Court fee on a complaint under §138 of the Negotiable Instruments Act,
/// in Tamil Nadu.
///
/// The NI Act itself prescribes no fee — it defines the offence, the 30-day
/// notice and the one-month limitation. Court fees are a State subject, which
/// is why the answer lives in the Tamil Nadu Court-Fees and Suits Valuation
/// Act, 1955, and differs in every other state.
///
/// A §138 complaint has its own entry — **Schedule II, Article 20** — and
/// Schedule II is the fixed/slab schedule for criminal complaints. It is not
/// Schedule I, whose 3% ad-valorem rate applies to civil suits. The
/// calculator charged that 3% until this was corrected, quoting a ₹5,00,000
/// cheque complaint at ₹15,000.
///
/// Article 20 has been through two forms:
///
///  * **2003–2017** — "Twenty five rupees for every rupees fifty thousand
///    subject to a maximum of one thousand rupees."
///  * **2017 onwards** — substituted by the Tamil Nadu Court-Fees and Suits
///    Valuation (Amendment) Act, 2017 with "Half per cent ad valorem,
///    subject to a maximum of rupees ten thousand."
///
/// Both are kept: [forAmount] is current law, [legacyForAmount] the earlier
/// slab, so the calculator can show them side by side. An advocate checking a
/// filing made before 2017 needs the old figure, and the two columns are also
/// what makes the change visible rather than silent.
class NiActComplaintFee {
  const NiActComplaintFee._();

  // ─── Current — Article 20 as substituted in 2017 ──────────

  /// Half of one per cent of the cheque amount.
  static const double defaultRate = 0.005;

  /// "subject to a maximum of rupees ten thousand" — reached at a cheque of
  /// ₹20,00,000, above which every complaint pays the same.
  static const int defaultMaximumFee = 10000;

  // ─── Pre-2017 — Article 20 as it stood from 2003 ──────────

  static const int legacySlabSize = 50000;
  static const int legacyPerSlab = 25;
  static const int legacyMaximumFee = 1000;

  /// Fee payable today on a cheque of [chequeAmount] rupees.
  ///
  /// Rounded **up** to the whole rupee, as §21-A of the Act requires: "any
  /// fraction of a rupee be rounded off to one rupee" (substituted by s.3 of
  /// the 2017 Amendment Act). Half a per cent rarely lands on a whole rupee —
  /// a ₹33,333 cheque computes to ₹166.665 and is payable as ₹167.
  static int forAmount(
    double chequeAmount, {
    double rate = defaultRate,
    int? maximumFee = defaultMaximumFee,
  }) {
    if (chequeAmount <= 0) return 0;
    var fee = (chequeAmount * rate).ceil();
    if (maximumFee != null && fee > maximumFee) fee = maximumFee;
    return fee;
  }

  /// Fee under Article 20 as it stood before the 2017 amendment.
  ///
  /// The slab count rounds **up**: the entry read "for every rupees fifty
  /// thousand", so ₹60,000 is two slabs, not 1.2. A cheque of exactly
  /// ₹50,000 is one slab — the boundary belongs to the lower slab.
  static int legacyForAmount(
    double chequeAmount, {
    int slabSize = legacySlabSize,
    int perSlab = legacyPerSlab,
    int? maximumFee = legacyMaximumFee,
  }) {
    if (chequeAmount <= 0) return 0;

    // Whole-rupee integer arithmetic throughout: dividing doubles and calling
    // ceil() would let a floating-point remainder tip an exact slab boundary
    // into the next slab, doubling the fee on every round-number cheque.
    final rupees = chequeAmount.ceil();
    final slabs = (rupees + slabSize - 1) ~/ slabSize;
    var fee = slabs * perSlab;

    if (maximumFee != null && fee > maximumFee) fee = maximumFee;
    return fee;
  }

  /// One-line statement of the rule in force, shown as the legal basis and
  /// copied into the fee memo.
  static String basis({
    double rate = defaultRate,
    int? maximumFee = defaultMaximumFee,
  }) {
    final percent = _trimZeros(rate * 100);
    final rule =
        'NI Act §138 complaint — TN Court-Fees Act, Schedule II, Art. 20 '
        '(as amended 2017): $percent% of the cheque amount';
    return maximumFee == null ? rule : '$rule, max ₹${_grouped(maximumFee)}';
  }

  /// The same, for the pre-2017 entry.
  static String legacyBasis({
    int slabSize = legacySlabSize,
    int perSlab = legacyPerSlab,
    int? maximumFee = legacyMaximumFee,
  }) {
    final rule =
        'Schedule II, Art. 20 before the 2017 amendment: ₹$perSlab per '
        '₹${_grouped(slabSize)} (or part) of cheque amount';
    return maximumFee == null ? rule : '$rule, max ₹${_grouped(maximumFee)}';
  }

  /// 0.5 → "0.5", 1.0 → "1" — so the basis never reads "1.0%".
  static String _trimZeros(double value) {
    final s = value.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  /// ₹50000 → "50,000", in the Indian grouping the rest of the app uses.
  static String _grouped(int value) {
    final digits = value.toString();
    if (digits.length <= 3) return digits;
    final head = digits.substring(0, digits.length - 3);
    final tail = digits.substring(digits.length - 3);
    final buffer = StringBuffer();
    for (var i = 0; i < head.length; i++) {
      // After the last three digits, Indian grouping breaks every two.
      if (i > 0 && (head.length - i).isEven) buffer.write(',');
      buffer.write(head[i]);
    }
    return '$buffer,$tail';
  }
}
