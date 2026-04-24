import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'dialogs/reset_workspace_dialog.dart';

class MobileMoreSheet extends ConsumerWidget {
  const MobileMoreSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "More Hub",
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 22),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildMenuItem(context, Icons.people, "Clients", Colors.blue, "/clients"),
              _buildMenuItem(context, Icons.description, "E-Filing", Colors.green, "/efiling"),
              _buildMenuItem(context, Icons.copy, "CC Copies", Colors.amber, "/certified-copies"),
              _buildMenuItem(context, Icons.account_balance, "Portals", Colors.indigo, "/portals"),
              _buildMenuItem(context, Icons.credit_card, "Payments", Colors.purple, "/payments"),
              _buildMenuItem(context, Icons.handyman_rounded, "Tools", Colors.teal, "/tools"),
              _buildMenuItem(context, Icons.assignment_ind_rounded, "Commissioner", const Color(0xFF7C3AED), "/commissions"),
              _buildMenuItem(context, Icons.gavel_rounded, "Caveats", const Color(0xFFEA580C), "/caveats"),
              _buildMenuItem(context, Icons.newspaper_rounded, "Legal Pulse", const Color(0xFFDC2626), "/legal-pulse"),
              _buildMenuItem(context, Icons.notifications, "Updates", Colors.pink, "/notifications"),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          // Sign Out
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.error),
            title: const Text(
              "Sign Out",
              style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              // Pop the sheet first to avoid blank screen/navigation conflicts
              Navigator.pop(context);
              await SupabaseService.signOut();
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh_rounded, color: AppTheme.error),
            title: const Text(
              "Reset Workspace",
              style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text("Delete all cases and data", style: TextStyle(fontSize: 10)),
            onTap: () {
              Navigator.pop(context);
              showDialog(context: context, builder: (context) => const ResetWorkspaceDialog());
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String label, Color color, String route) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF1E293B), size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
