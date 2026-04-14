import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../components/empty_state_widget.dart';
import '../components/error_state_widget.dart';


class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(casesProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Updates", style: TextStyle(fontSize: isMobile ? 24 : 28, fontWeight: FontWeight.bold, fontFamily: 'Playfair Display')),
                    const Text("Recent activity across your practice", style: TextStyle(color: Colors.grey)),
                  ],
                ),
                IconButton(
                  onPressed: () => context.push('/notification-diagnostics'),
                  icon: Icon(Icons.troubleshoot, color: AppTheme.primary),
                  tooltip: "Notification Diagnostics",
                ),
              ],
            ),
          ),
          Expanded(
            child: casesAsync.when(
              data: (cases) => _buildActivityFeed(cases),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => ErrorStateWidget(
                error: err,
                onRetry: () => ref.invalidate(casesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed(List<CaseModel> items) {
    if (items.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.notifications_none,
        title: "No Recent Updates",
        message: "When your cases, clients, or payments are modified, the activity log will appear here.",
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: _buildIcon(item.status),
            title: Text(item.caseTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("Updated to ${item.status.name}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: Text(DateFormat('HH:mm').format(DateTime.now()), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
        );
      },
    );
  }

  Widget _buildIcon(CaseStatus status) {
    IconData icon = Icons.info_outline;
    Color color = Colors.blue;
    String statusStr = status.toString().split('.').last;

    if (statusStr == "active") {
      icon = Icons.gavel;
      color = Colors.amber;
    } else if (statusStr == "closed") {
      icon = Icons.check_circle;
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 20),
    );
  }

}

