/// Court-fee rules that are worth testing on their own, kept out of the
/// calculator widget so the arithmetic can be verified without pumping a
/// screen. These figures are paid at a filing counter, so a rounding slip is
/// a real-money slip.
library;

/// Court fee on a complaint under §138 of the Negotiable Instruments Act.
///
/// A §138 complaint is a **criminal** complaint before a Judicial Magistrate
/// (§200 CrPC / §223 BNSS). It is charged under Schedule II as a slab on the
/// cheque amount — *not* the Schedule I ad-valorem 3% that applies to a civil
/// suit for recovery of the same money. The calculator charged 3% until now,
/// which over-stated a ₹5,00,000 cheque complaint as ₹15,000 instead of ₹250.
///
/// The two proceedings are separate and an advocate often files both:
///   * §138 complaint (criminal, Magistrate)      → this slab
///   * Order XXXVII CPC summary suit (civil)      → Schedule I, 3%
///
/// The rule is expressed as parameters rather than inline numbers because the
/// exact Schedule II entry is still to be confirmed against the Tamil Nadu
/// fee table. Whether a floor or a ceiling applies is unknown, so both are
/// supported and currently left off; confirming them is a change to the
/// defaults below, not to the logic.
class NiActComplaintFee {
  const NiActComplaintFee._();

  /// One unit of fee falls due per this much cheque value, "or part thereof".
  static const int defaultSlabSize = 50000;

  /// Fee charged for each such slab.
  static const int defaultPerSlab = 25;

  /// Floor and ceiling, if the schedule prescribes them. `null` means the fee
  /// runs linearly with no floor / no cap.
  ///
  /// No floor: a small cheque costs one slab, ₹25. The ceiling bites at 40
  /// slabs — every cheque of ₹20,00,000 or more pays the same ₹1,000.
  static const int? defaultMinimumFee = null;
  static const int? defaultMaximumFee = 1000;

  /// Fee payable on a cheque of [chequeAmount] rupees.
  ///
  /// The slab count rounds **up**: fee schedules read "for every ₹50,000 or
  /// part thereof", so ₹60,000 is two slabs, not 1.2. A cheque of exactly
  /// ₹50,000 is one slab — the boundary belongs to the lower slab.
  static int forAmount(
    double chequeAmount, {
    int slabSize = defaultSlabSize,
    int perSlab = defaultPerSlab,
    int? minimumFee = defaultMinimumFee,
    int? maximumFee = defaultMaximumFee,
  }) {
    if (chequeAmount <= 0) return 0;

    // Whole-rupee integer arithmetic throughout: dividing doubles and calling
    // ceil() would let a floating-point remainder tip an exact slab boundary
    // into the next slab, doubling the fee on every round-number cheque.
    final rupees = chequeAmount.ceil();
    final slabs = (rupees + slabSize - 1) ~/ slabSize;
    var fee = slabs * perSlab;

    if (minimumFee != null && fee < minimumFee) fee = minimumFee;
    if (maximumFee != null && fee > maximumFee) fee = maximumFee;
    return fee;
  }

  /// One-line statement of the rule applied, shown to the user as the legal
  /// basis and copied into the fee memo.
  static String basis({
    int slabSize = defaultSlabSize,
    int perSlab = defaultPerSlab,
    int? maximumFee = defaultMaximumFee,
  }) {
    final rule =
        'NI Act §138 complaint — Schedule II slab: ₹$perSlab per '
        '₹${_grouped(slabSize)} (or part) of cheque amount';
    return maximumFee == null ? rule : '$rule, max ₹${_grouped(maximumFee)}';
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
