import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Checks if the app needs a forced update by comparing the current version
/// against a minimum version stored in Supabase `app_config` table.
///
/// Table schema (create once in Supabase SQL editor):
/// ```sql
/// CREATE TABLE IF NOT EXISTS app_config (
///   key TEXT PRIMARY KEY,
///   value TEXT NOT NULL,
///   updated_at TIMESTAMPTZ DEFAULT NOW()
/// );
/// INSERT INTO app_config (key, value) VALUES ('min_version', '2.1.0')
/// ON CONFLICT (key) DO NOTHING;
/// INSERT INTO app_config (key, value) VALUES ('play_store_url', 'https://play.google.com/store/apps/details?id=com.caseflow.app')
/// ON CONFLICT (key) DO NOTHING;
/// ```
class ForceUpdateService {
  /// The current app version — update on each release.
  static const String currentVersion = '2.1.0';

  /// Check if the current app version meets the minimum requirement.
  /// Returns true if an update is required.
  static Future<bool> isUpdateRequired() async {
    try {
      final response = await Supabase.instance.client
          .from('app_config')
          .select('value')
          .eq('key', 'min_version')
          .maybeSingle();

      if (response == null) return false;

      final minVersion = response['value'] as String;
      return _isVersionLower(currentVersion, minVersion);
    } catch (e) {
      debugPrint('Force update check failed: $e');
      return false; // Don't block the app if the check fails
    }
  }

  /// Compare two semantic version strings.
  /// Returns true if [current] is lower than [minimum].
  static bool _isVersionLower(String current, String minimum) {
    final currentParts = current.split('.').map(int.tryParse).toList();
    final minimumParts = minimum.split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final c = (i < currentParts.length ? currentParts[i] : 0) ?? 0;
      final m = (i < minimumParts.length ? minimumParts[i] : 0) ?? 0;
      if (c < m) return true;
      if (c > m) return false;
    }
    return false; // Equal versions
  }

  /// Show a blocking "Update Required" dialog.
  /// The user cannot dismiss it — they must update.
  static Future<void> showUpdateDialog(BuildContext context) async {
    String storeUrl = 'https://play.google.com/store/apps/details?id=com.caseflow.app';

    try {
      final response = await Supabase.instance.client
          .from('app_config')
          .select('value')
          .eq('key', 'play_store_url')
          .maybeSingle();
      if (response != null) {
        storeUrl = response['value'] as String;
      }
    } catch (_) {}

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.system_update, size: 48, color: Color(0xFF1a237e)),
          title: const Text('Update Required'),
          content: const Text(
            'A new version of CaseFlow is available with important updates and bug fixes. '
            'Please update to continue using the app.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton.icon(
              onPressed: () async {
                final uri = Uri.parse(storeUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Update Now'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1a237e),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
