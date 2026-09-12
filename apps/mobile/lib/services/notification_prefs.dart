import 'package:shared_preferences/shared_preferences.dart';

/// The user's notification switches from Settings → Notifications.
///
/// Those switches used to be decoration. `settings_screen.dart` wrote these
/// five keys and read them back to draw the switch, and **nothing else in the
/// app ever looked at them** — turning DMs off changed nothing. This is the
/// missing half: [FcmService.showRichNotification] consults it before
/// rendering anything.
///
/// Suppressing on the device is genuinely sufficient here. CaseFlow's pushes
/// are data-only — there is no top-level `notification` block, so Android
/// displays nothing by itself and the app draws every notification. Skip the
/// draw and nothing appears. The handset still wakes for the silent data
/// message; stopping that would need the preference on the server.
class NotificationPrefs {
  static const dmKey = 'settings_dm_notif';
  static const chamberKey = 'settings_chamber_notif';
  static const hearingKey = 'settings_hearing_reminders';
  static const soundKey = 'settings_notif_sound';
  static const vibrationKey = 'settings_notif_vibration';

  final bool dm;
  final bool chambers;
  final bool hearings;
  final bool sound;
  final bool vibration;

  const NotificationPrefs({
    this.dm = true,
    this.chambers = true,
    this.hearings = true,
    this.sound = true,
    this.vibration = true,
  });

  /// Reads all five switches.
  ///
  /// `reload()` is not optional. `showRichNotification` also runs in the
  /// background isolate, which holds its own SharedPreferences cache and would
  /// otherwise keep serving whatever the values were when that isolate spawned
  /// — so a toggle flipped in Settings would not take effect until the app was
  /// killed. Everything defaults to on, so a read failure never silently
  /// swallows a notification.
  static Future<NotificationPrefs> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {
        // reload() is unsupported on some platforms — cached values still work.
      }
      return NotificationPrefs(
        dm: prefs.getBool(dmKey) ?? true,
        chambers: prefs.getBool(chamberKey) ?? true,
        hearings: prefs.getBool(hearingKey) ?? true,
        sound: prefs.getBool(soundKey) ?? true,
        vibration: prefs.getBool(vibrationKey) ?? true,
      );
    } catch (_) {
      return const NotificationPrefs();
    }
  }

  /// Whether a push of this FCM `type` may be shown.
  ///
  /// Only the three categories that actually have a switch are gated. Anything
  /// else — invitations, invitation responses, case updates, caveat expiry —
  /// always shows: the user has no control to turn those off, so silently
  /// dropping them would lose information with no way to get it back.
  bool allows(String type) {
    switch (type) {
      case 'dm_message':
        return dm;
      case 'chat_message':
        return chambers;
      case 'hearing_reminder':
      case 'court_diary':
        return hearings;
      default:
        return true;
    }
  }

  /// Android fixes sound and vibration onto a channel when it is first
  /// created and ignores later changes, so honouring these toggles means
  /// routing to a different channel rather than changing the current one.
  ///
  /// Returns a suffix identifying the (sound, vibration) pair. Empty for the
  /// default pair so existing channels — and their user customisations — are
  /// left exactly as they are.
  String get channelSuffix {
    if (sound && vibration) return '';
    if (!sound && vibration) return '_silent';
    if (sound && !vibration) return '_novibe';
    return '_quiet';
  }

  /// Human-readable qualifier shown next to the channel name in Android's
  /// notification settings, so the extra entries are self-explanatory.
  String get channelLabel {
    if (sound && vibration) return '';
    if (!sound && vibration) return ' (Silent)';
    if (sound && !vibration) return ' (No Vibration)';
    return ' (Quiet)';
  }
}
