import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../components/mobile_bottom_nav.dart';
import '../components/app_sidebar.dart';
import '../components/global_search_delegate.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isMobile
          ? AppBar(
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              centerTitle: false,
              title: Text(
                "CaseFlow",
                style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: Color(0xFF6B7280)),
                  onPressed: () {
                    showSearch(context: context, delegate: GlobalSearchDelegate());
                  },
                ),
                const SizedBox(width: 4),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: Theme.of(context).dividerTheme.color),
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile) const AppSidebar(),
          Expanded(
            child: Column(
              children: [
                if (!isMobile)
                  Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border(bottom: BorderSide(color: Theme.of(context).dividerTheme.color ?? Colors.grey)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text(
                          "CaseFlow Registry",
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.black26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: AppTheme.cardDecoration(
                            isDark: Theme.of(context).brightness == Brightness.dark,
                            color: Theme.of(context).brightness == Brightness.dark ? AppTheme.surfaceLight : Colors.black.withValues(alpha: 0.03),
                          ),
                          child: InkWell(
                            onTap: () {
                              showSearch(context: context, delegate: GlobalSearchDelegate());
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_rounded, size: 18, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.black38),
                                const SizedBox(width: 10),
                                Text(
                                  "Search cases, clients...",
                                  style: GoogleFonts.inter(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.black38, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 0 : 24),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? const MobileBottomNav() : null,
    );
  }
}
