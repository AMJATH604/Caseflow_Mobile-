/// Lets a screen claim the hardware back press before the shell handles it.
///
/// Some screens navigate inside themselves rather than through the router —
/// Tools renders a tool by setting `_activeToolId`, Commission Detail opens a
/// visit by setting `_activeVisitId`. The router knows nothing about that, so
/// [AppShell]'s PopScope saw a top-level tab it could not pop and sent the
/// user all the way to the dashboard. Opening the Court Fee calculator and
/// pressing back lost the whole Tools screen.
///
/// A nested `PopScope` does not solve it: when an ancestor declares
/// `canPop: false`, every registered callback still fires, so the shell would
/// navigate away regardless of what the inner screen did. The shell has to
/// ask first, which is what this registry is for.
class BackInterceptors {
  BackInterceptors._();

  /// Registered innermost-last, so the most recently opened screen is asked
  /// first.
  static final List<bool Function()> _handlers = [];

  /// Registers [handler]. It should return true when it consumed the back
  /// press — closed a panel, cleared a selection — and false to let the
  /// press continue to the shell.
  static void add(bool Function() handler) => _handlers.add(handler);

  static void remove(bool Function() handler) => _handlers.remove(handler);

  /// Offers the back press to each handler, innermost first. Returns true as
  /// soon as one consumes it.
  static bool handleBackPress() {
    for (final handler in _handlers.reversed.toList(growable: false)) {
      if (handler()) return true;
    }
    return false;
  }

  /// Test seam — no production caller should need this.
  static void reset() => _handlers.clear();

  static int get count => _handlers.length;
}
