import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/fcm_service.dart';
import '../theme/app_theme.dart';

class NotificationDiagnosticScreen extends ConsumerStatefulWidget {
  const NotificationDiagnosticScreen({super.key});

  @override
  ConsumerState<NotificationDiagnosticScreen> createState() => _NotificationDiagnosticScreenState();
}

class _NotificationDiagnosticScreenState extends ConsumerState<NotificationDiagnosticScreen> {
  String? _token;
  bool _loading = false;
  String? _statusMessage;
  NotificationSettings? _settings;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _loading = true);
    try {
      final messaging = FirebaseMessaging.instance;
      _settings = await messaging.getNotificationSettings();
      _token = await messaging.getToken();
      
      // Also check DB registration
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && _token != null) {
        final response = await Supabase.instance.client
            .from('fcm_tokens')
            .select()
            .eq('user_id', user.id)
            .eq('token', _token!)
            .maybeSingle();
        
        if (response != null) {
          _statusMessage = "✅ Token registered in Database";
        } else {
          _statusMessage = "❌ Token NOT in Database";
        }
      }
    } catch (e) {
      _statusMessage = "Error: $e";
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _registerToken() async {
    setState(() => _loading = true);
    try {
      await FcmService().initialize();
      await _checkStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Token registration triggered")),
      );
    } catch (e) {
      setState(() => _statusMessage = "Registration failed: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client.functions.invoke(
        'send-hearing-reminders',
        body: {
          'reminder_type': 'test',
          'userId': user.id,
        },
      );

      if (response.status == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Test notification sent! Check your device.")),
        );
      } else {
        throw Exception("Server returned ${response.status}: ${response.data}");
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Test Failed"),
          content: Text(e.toString()),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text("Notification Diagnostics", style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.primary,
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildSection(
                title: "Permission Status",
                content: _settings?.authorizationStatus.toString() ?? "Unknown",
                icon: Icons.lock_open,
                color: _settings?.authorizationStatus == AuthorizationStatus.authorized ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: "Device Token Status",
                content: _token != null 
                    ? "${_token!.substring(0, 10)}...${_token!.substring(_token!.length - 10)}" 
                    : "No token acquired",
                icon: Icons.key,
                color: _token != null ? Colors.blue : Colors.red,
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: "Database Registration",
                content: _statusMessage ?? "Checking...",
                icon: Icons.cloud_done,
                color: _statusMessage?.contains("✅") ?? false ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _registerToken,
                icon: const Icon(Icons.refresh),
                label: const Text("Force Token Registration"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _sendTestNotification,
                icon: const Icon(Icons.send),
                label: const Text("Send Test Notification Now"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Info: This tool helps verify if your device is correctly linked to our notification server. If 'Test Notification' doesn't arrive within 30 seconds, ensure you have a stable internet connection and have allowed notifications in system settings.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
    );
  }

  Widget _buildSection({required String title, required String content, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(content, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
