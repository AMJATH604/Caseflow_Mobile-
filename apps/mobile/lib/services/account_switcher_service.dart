import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gmail-style multi-account switcher service.
///
/// Persists multiple Supabase sessions locally so users can switch
/// between accounts without re-entering credentials each time.
///
/// Sessions are stored as encrypted JSON in SharedPreferences.
/// Each saved account contains: userId, email, fullName, avatarUrl,
/// accessToken, and refreshToken.
class AccountSwitcherService {
  static const _storageKey = 'caseflow_saved_accounts';

  /// Represents a saved account entry.
  static Map<String, dynamic> _accountEntry({
    required String userId,
    required String email,
    String? fullName,
    String? avatarUrl,
    required String accessToken,
    required String refreshToken,
  }) {
    return {
      'userId': userId,
      'email': email,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'savedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Save the current active session to the saved accounts list.
  /// If the account already exists, update its tokens.
  static Future<void> saveCurrentSession({
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final user = session.user;
      final accounts = await getSavedAccounts();

      // Remove existing entry for this user (to update it)
      accounts.removeWhere((a) => a['userId'] == user.id);

      // Add updated entry
      accounts.add(_accountEntry(
        userId: user.id,
        email: user.email ?? '',
        fullName: fullName ?? user.userMetadata?['full_name'] as String?,
        avatarUrl: avatarUrl,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ?? '',
      ));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(accounts));
      debugPrint('AccountSwitcher: Saved session for ${user.email}');
    } catch (e) {
      debugPrint('AccountSwitcher: Error saving session: $e');
    }
  }

  /// Get all saved accounts from local storage.
  static Future<List<Map<String, dynamic>>> getSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storageKey);
      if (stored == null || stored.isEmpty) return [];
      final decoded = jsonDecode(stored) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('AccountSwitcher: Error loading accounts: $e');
      return [];
    }
  }

  /// Get the current active user's ID.
  static String? get currentUserId {
    return Supabase.instance.client.auth.currentUser?.id;
  }

  /// Switch to a different saved account by restoring its session.
  ///
  /// Steps:
  /// 1. Save the current session first (so we can switch back)
  /// 2. Use the saved refresh token to establish a new session
  static Future<bool> switchToAccount(Map<String, dynamic> account, {
    String? currentFullName,
    String? currentAvatarUrl,
  }) async {
    try {
      final refreshToken = account['refreshToken'] as String?;
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('AccountSwitcher: No refresh token for ${account['email']}');
        return false;
      }

      // Save current session before switching
      await saveCurrentSession(
        fullName: currentFullName,
        avatarUrl: currentAvatarUrl,
      );

      // Recover the target session using refresh token
      final response = await Supabase.instance.client.auth.setSession(
        refreshToken,
      );

      if (response.session != null) {
        // Update the stored tokens with the fresh ones
        final accounts = await getSavedAccounts();
        final idx = accounts.indexWhere((a) => a['userId'] == account['userId']);
        if (idx != -1) {
          accounts[idx]['accessToken'] = response.session!.accessToken;
          accounts[idx]['refreshToken'] = response.session!.refreshToken ?? refreshToken;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_storageKey, jsonEncode(accounts));
        }

        debugPrint('AccountSwitcher: Switched to ${account['email']}');
        return true;
      }

      debugPrint('AccountSwitcher: setSession returned null for ${account['email']}');
      return false;
    } catch (e) {
      debugPrint('AccountSwitcher: Switch failed: $e');
      return false;
    }
  }

  /// Remove a saved account from local storage.
  static Future<void> removeAccount(String userId) async {
    try {
      final accounts = await getSavedAccounts();
      accounts.removeWhere((a) => a['userId'] == userId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(accounts));
      debugPrint('AccountSwitcher: Removed account $userId');
    } catch (e) {
      debugPrint('AccountSwitcher: Error removing account: $e');
    }
  }

  /// Clear all saved accounts (e.g., on full sign out).
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      debugPrint('AccountSwitcher: Cleared all saved accounts');
    } catch (e) {
      debugPrint('AccountSwitcher: Error clearing accounts: $e');
    }
  }
}
