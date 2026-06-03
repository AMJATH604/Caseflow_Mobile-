class AppConfig {
  static const String currency = "INR";

  // ─── Free Plan ──────────────────────────────────────
  static const String freePlanName = "Free";
  static const int freeCaseLimit = 99999;

  // ─── Pro Plan ───────────────────────────────────────
  static const String proPlanName = "CaseFlow Pro";
  static const double proMonthlyPrice = 49.0;
  static const double proYearlyPrice = 550.0;
  // Legacy alias (used by existing UpgradePlanDialog)
  static const double proPlanPrice = proYearlyPrice;

  // ─── Business Plan ─────────────────────────────────
  static const String businessPlanName = "CaseFlow Business";
  static const double businessMonthlyPrice = 99.0;
  static const double businessYearlyPrice = 1000.0;
  static const double businessPlanPrice = businessYearlyPrice;
}
