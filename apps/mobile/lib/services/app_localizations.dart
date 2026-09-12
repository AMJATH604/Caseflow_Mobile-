/// CaseFlow Localization Service
///
/// Offered in Settings: English (default) and Tamil.
/// The `hi` and `te` maps below predate the Settings picker and remain
/// partial — they are not listed in [LocaleService.supported], so they are
/// not reachable yet. Complete them and add an entry there to offer them.
///
/// Architecture: simple key-value maps per locale, no heavy dependency.
///
/// **Deliberately not translated** — legal terms of art, statute names and
/// citations stay in English, because that is how they are used in Indian
/// practice and how they appear in the record: "Section 138 NI Act", "CNR",
/// "vakalat", "caveat", "ex-parte". Translating them would make the app
/// harder to use, not easier.
library;

import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('hi'), // Hindi   — partial, not yet offered
    Locale('ta'), // Tamil
    Locale('te'), // Telugu  — partial, not yet offered
  ];

  /// Locale codes that have a map below.
  static const List<String> _known = ['en', 'hi', 'ta', 'te'];

  /// Get a translated string by key. Falls back to English, then the key.
  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  // Shorthand
  String get(String key) => translate(key);

  /// Every key defined in English — the canonical key set.
  static List<String> get englishKeys =>
      (_localizedValues['en'] ?? const {}).keys.toList();

  /// Keys present in English but missing from [code]. Used by tests to stop
  /// coverage regressing silently — [translate] falls back quietly, so a
  /// missing key is otherwise invisible until a user reports it.
  static List<String> missingKeys(String code) {
    final en = _localizedValues['en'] ?? const {};
    final other = _localizedValues[code] ?? const {};
    return en.keys.where((k) => !other.containsKey(k)).toList();
  }

  // ─── Localized Strings ─────────────────────────────────

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // ── Navigation ──
      'nav_home': 'Home',
      'nav_dashboard': 'Dashboard',
      'nav_cases': 'Cases',
      'nav_hearings': 'Hearings',
      'nav_tools': 'Tools',
      'nav_more': 'More',

      // ── Dashboard ──
      'dashboard_title': 'Dashboard',
      'greeting_advocate': 'Hello, Advocate',
      'online': 'Online',
      'active_cases': 'Active Cases',
      'total_cases': 'Total Cases',
      'todays_hearings': "Today's Hearings",
      'upcoming_hearings': 'Upcoming Hearings',
      'total_clients': 'Total Clients',
      'disposed': 'Disposed',
      'dismissed': 'Dismissed',
      'payments': 'Payments',
      'no_hearings_today': 'No Hearings Today',
      'jump_to': 'Jump To',
      'quick_actions': 'Quick Actions',
      'new_case': 'New Case',
      'new_client': 'New Client',
      'new_hearing': 'New Hearing',
      'log_ca': 'Log C.A',
      'invitations': 'Invitations',
      'court_diary': 'Court Diary',
      'daily_tasks': 'Daily Tasks',
      'no_tasks_yet': 'No tasks yet',
      'clients': 'Clients',
      'filings': 'Filings',

      // ── Cases ──
      'cases_title': 'Cases',
      'add_case': 'Add Case',
      'case_number': 'Case Number',
      'case_title': 'Case Title',
      'case_status': 'Status',
      'case_type': 'Case Type',
      'case_court': 'Court',
      'case_stage': 'Stage',
      'active': 'Active',
      'archived': 'Archived',
      'next_hearing': 'Next Hearing',

      // ── Hearings ──
      'hearings_title': 'Hearings',
      'add_hearing': 'Add Hearing',
      'hearing_date': 'Hearing Date',
      'no_hearings': 'No hearings scheduled',

      // ── AI Chat ──
      'ai_title': 'CaseFlow AI',
      'ai_subtitle': 'Your Legal Assistant',
      'ai_placeholder': 'Ask a legal question...',
      'ai_clear': 'Clear Chat',

      // ── Settings: sections ──
      'settings_title': 'Settings',
      'section_notifications': 'Notifications',
      'section_appearance': 'Appearance',
      'section_privacy': 'Privacy',
      'section_data': 'Data & Storage',
      'section_help': 'Help & Feedback',
      'section_about': 'About',

      // ── Settings: notifications ──
      'direct_messages': 'Direct Messages',
      'direct_messages_sub': 'Get notified for new DM conversations',
      'chamber_messages': 'Chamber Messages',
      'chamber_messages_sub': 'Notifications for firm chamber discussions',
      'hearing_reminders': 'Hearing Reminders',
      'hearing_reminders_sub': 'Receive reminders before upcoming hearings',
      'notification_sound': 'Notification Sound',
      'notification_sound_sub': 'Play a sound for incoming notifications',
      'vibration': 'Vibration',
      'vibration_sub': 'Vibrate on notification',

      // ── Settings: appearance ──
      'light_mode': 'Light Mode',
      'light_mode_sub': 'Switch to dark theme',
      'dark_mode': 'Dark Mode',
      'dark_mode_sub': 'Switch to light theme',
      'language': 'Language',
      'choose_language': 'Choose Language',
      'language_sheet_note':
          'The app will switch immediately. Legal terms and statute names stay in English.',

      // ── Settings: privacy ──
      'public_directory': 'Public Directory',
      'public_directory_sub': 'Show your profile in the advocate directory',

      // ── Settings: data ──
      'clear_image_cache': 'Clear Image Cache',
      'clear_image_cache_sub': 'Free up space by clearing cached images',
      'refresh_all_data': 'Refresh All Data',
      'refresh_all_data_sub': 'Force re-sync all data from server',

      // ── Settings: help ──
      'send_feedback': 'Send Feedback',
      'send_feedback_sub': 'Share suggestions, ideas or general feedback',
      'report_bug': 'Report a Bug',
      'report_bug_sub': 'Found something broken? Let us know',
      'help_center': 'Help Center',
      'help_center_sub': 'FAQs and getting started guide',

      // ── Settings: about ──
      'app_version': 'App Version',
      'terms': 'Terms & Conditions',
      'terms_sub': 'Read our terms of service',
      'privacy_policy': 'Privacy Policy',
      'privacy_policy_sub': 'Read our privacy policy',
      'rate_app': 'Rate CaseFlow',
      'rate_app_sub': 'Help us improve with your feedback',
      'sign_out': 'Sign Out',

      // ── Common ──
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'search': 'Search',
      'loading': 'Loading...',
      'error': 'Error',
      'retry': 'Retry',
      'no_data': 'No data available',
      'done': 'Done',
      'close': 'Close',
      'offline_mode': 'Offline Mode',
      'offline_message': 'Showing cached data. Connect to internet to sync.',
    },

    'ta': {
      // ── Navigation ──
      'nav_home': 'முகப்பு',
      'nav_dashboard': 'கட்டுப்பாட்டகம்',
      'nav_cases': 'வழக்குகள்',
      'nav_hearings': 'விசாரணைகள்',
      'nav_tools': 'கருவிகள்',
      'nav_more': 'மேலும்',

      // ── Dashboard ──
      'dashboard_title': 'கட்டுப்பாட்டகம்',
      'greeting_advocate': 'வணக்கம், வழக்கறிஞர்',
      'online': 'இணைப்பில்',
      'active_cases': 'நடப்பு வழக்குகள்',
      'total_cases': 'மொத்த வழக்குகள்',
      'todays_hearings': 'இன்றைய விசாரணைகள்',
      'upcoming_hearings': 'வரவிருக்கும் விசாரணைகள்',
      'total_clients': 'மொத்த கட்சிக்காரர்கள்',
      'disposed': 'தீர்க்கப்பட்டது',
      'dismissed': 'தள்ளுபடி',
      'payments': 'கட்டணங்கள்',
      'no_hearings_today': 'இன்று விசாரணை இல்லை',
      'jump_to': 'விரைவு இணைப்பு',
      'quick_actions': 'விரைவு செயல்கள்',
      'new_case': 'புதிய வழக்கு',
      'new_client': 'புதிய கட்சிக்காரர்',
      'new_hearing': 'புதிய விசாரணை',
      'log_ca': 'நகல் பதிவு',
      'invitations': 'அழைப்புகள்',
      'court_diary': 'நீதிமன்ற நாட்குறிப்பு',
      'daily_tasks': 'அன்றாடப் பணிகள்',
      'no_tasks_yet': 'பணிகள் எதுவும் இல்லை',
      'clients': 'கட்சிக்காரர்கள்',
      'filings': 'தாக்கல்கள்',

      // ── Cases ──
      'cases_title': 'வழக்குகள்',
      'add_case': 'வழக்கு சேர்',
      'case_number': 'வழக்கு எண்',
      'case_title': 'வழக்குத் தலைப்பு',
      'case_status': 'நிலை',
      'case_type': 'வழக்கு வகை',
      'case_court': 'நீதிமன்றம்',
      'case_stage': 'கட்டம்',
      'active': 'நடப்பில்',
      'archived': 'காப்பகம்',
      'next_hearing': 'அடுத்த விசாரணை',

      // ── Hearings ──
      'hearings_title': 'விசாரணைகள்',
      'add_hearing': 'விசாரணை சேர்',
      'hearing_date': 'விசாரணை தேதி',
      'no_hearings': 'விசாரணை எதுவும் நிர்ணயிக்கப்படவில்லை',

      // ── AI Chat ──
      'ai_title': 'CaseFlow AI',
      'ai_subtitle': 'உங்கள் சட்ட உதவியாளர்',
      'ai_placeholder': 'சட்டக் கேள்வியைக் கேளுங்கள்...',
      'ai_clear': 'உரையாடலை அழி',

      // ── Settings: sections ──
      'settings_title': 'அமைப்புகள்',
      'section_notifications': 'அறிவிப்புகள்',
      'section_appearance': 'தோற்றம்',
      'section_privacy': 'தனியுரிமை',
      'section_data': 'தரவு மற்றும் சேமிப்பு',
      'section_help': 'உதவி மற்றும் கருத்து',
      'section_about': 'செயலி பற்றி',

      // ── Settings: notifications ──
      'direct_messages': 'நேரடி செய்திகள்',
      'direct_messages_sub': 'புதிய நேரடி உரையாடல்களுக்கு அறிவிப்பு பெறவும்',
      'chamber_messages': 'அறை செய்திகள்',
      'chamber_messages_sub': 'நிறுவன அறை கலந்துரையாடல் அறிவிப்புகள்',
      'hearing_reminders': 'விசாரணை நினைவூட்டல்கள்',
      'hearing_reminders_sub':
          'வரவிருக்கும் விசாரணைகளுக்கு முன் நினைவூட்டல் பெறவும்',
      'notification_sound': 'அறிவிப்பு ஒலி',
      'notification_sound_sub': 'வரும் அறிவிப்புகளுக்கு ஒலி இயக்கவும்',
      'vibration': 'அதிர்வு',
      'vibration_sub': 'அறிவிப்பின்போது அதிரவைக்கவும்',

      // ── Settings: appearance ──
      'light_mode': 'ஒளி பயன்முறை',
      'light_mode_sub': 'இருள் தோற்றத்திற்கு மாறவும்',
      'dark_mode': 'இருள் பயன்முறை',
      'dark_mode_sub': 'ஒளி தோற்றத்திற்கு மாறவும்',
      'language': 'மொழி',
      'choose_language': 'மொழியைத் தேர்ந்தெடுக்கவும்',
      'language_sheet_note':
          'செயலி உடனடியாக மாறும். சட்டச் சொற்கள் மற்றும் சட்டப் பெயர்கள் ஆங்கிலத்திலேயே இருக்கும்.',

      // ── Settings: privacy ──
      'public_directory': 'பொது அடைவு',
      'public_directory_sub':
          'வழக்கறிஞர் அடைவில் உங்கள் சுயவிவரத்தைக் காட்டவும்',

      // ── Settings: data ──
      'clear_image_cache': 'படத் தேக்ககத்தை அழி',
      'clear_image_cache_sub': 'சேமித்த படங்களை அழித்து இடத்தைக் காலி செய்யவும்',
      'refresh_all_data': 'அனைத்துத் தரவையும் புதுப்பி',
      'refresh_all_data_sub': 'சேவையகத்திலிருந்து அனைத்தையும் மீண்டும் ஒத்திசைக்கவும்',

      // ── Settings: help ──
      'send_feedback': 'கருத்து அனுப்பு',
      'send_feedback_sub': 'பரிந்துரைகள், யோசனைகள் அல்லது கருத்துகளைப் பகிரவும்',
      'report_bug': 'பிழையைத் தெரிவி',
      'report_bug_sub': 'ஏதேனும் சரியாக இயங்கவில்லையா? எங்களிடம் தெரிவிக்கவும்',
      'help_center': 'உதவி மையம்',
      'help_center_sub': 'அடிக்கடி கேட்கப்படும் கேள்விகள் மற்றும் தொடக்க வழிகாட்டி',

      // ── Settings: about ──
      'app_version': 'செயலி பதிப்பு',
      'terms': 'விதிமுறைகள் மற்றும் நிபந்தனைகள்',
      'terms_sub': 'எங்கள் சேவை விதிமுறைகளைப் படிக்கவும்',
      'privacy_policy': 'தனியுரிமைக் கொள்கை',
      'privacy_policy_sub': 'எங்கள் தனியுரிமைக் கொள்கையைப் படிக்கவும்',
      'rate_app': 'CaseFlow-க்கு மதிப்பீடு',
      'rate_app_sub': 'உங்கள் கருத்து எங்களை மேம்படுத்த உதவும்',
      'sign_out': 'வெளியேறு',

      // ── Common ──
      'save': 'சேமி',
      'cancel': 'ரத்து',
      'delete': 'நீக்கு',
      'edit': 'திருத்து',
      'search': 'தேடு',
      'loading': 'ஏற்றுகிறது...',
      'error': 'பிழை',
      'retry': 'மீண்டும் முயற்சி',
      'no_data': 'தரவு இல்லை',
      'done': 'முடிந்தது',
      'close': 'மூடு',
      'offline_mode': 'ஆஃப்லைன் பயன்முறை',
      'offline_message':
          'தேக்கக தரவைக் காட்டுகிறது. ஒத்திசைக்க இணையத்தை இணைக்கவும்.',
    },

    // ─── Partial, not yet offered in Settings ─────────────
    'hi': {
      'nav_dashboard': 'डैशबोर्ड',
      'nav_cases': 'मुकदमे',
      'nav_hearings': 'सुनवाई',
      'nav_tools': 'उपकरण',
      'nav_more': 'अधिक',
      'dashboard_title': 'डैशबोर्ड',
      'active_cases': 'सक्रिय मुकदमे',
      'total_cases': 'कुल मुकदमे',
      'upcoming_hearings': 'आगामी सुनवाई',
      'clients': 'मुवक्किल',
      'filings': 'दाखिल',
      'cases_title': 'मुकदमे',
      'add_case': 'मुकदमा जोड़ें',
      'case_number': 'मुकदमा संख्या',
      'case_title': 'मुकदमा शीर्षक',
      'case_status': 'स्थिति',
      'case_type': 'मुकदमा प्रकार',
      'case_court': 'न्यायालय',
      'case_stage': 'चरण',
      'active': 'सक्रिय',
      'disposed': 'निपटान',
      'archived': 'संग्रहीत',
      'hearings_title': 'सुनवाई',
      'add_hearing': 'सुनवाई जोड़ें',
      'hearing_date': 'सुनवाई तिथि',
      'next_hearing': 'अगली सुनवाई',
      'no_hearings': 'कोई सुनवाई निर्धारित नहीं',
      'ai_title': 'केसफ्लो AI',
      'ai_subtitle': 'आपका कानूनी सहायक',
      'ai_placeholder': 'कानूनी प्रश्न पूछें...',
      'ai_clear': 'चैट साफ़ करें',
      'save': 'सहेजें',
      'cancel': 'रद्द करें',
      'delete': 'हटाएं',
      'edit': 'संपादित करें',
      'search': 'खोजें',
      'loading': 'लोड हो रहा है...',
      'error': 'त्रुटि',
      'retry': 'पुनः प्रयास',
      'no_data': 'कोई डेटा उपलब्ध नहीं',
      'offline_mode': 'ऑफ़लाइन मोड',
      'offline_message':
          'कैश्ड डेटा दिखा रहा है। सिंक करने के लिए इंटरनेट से कनेक्ट करें।',
    },

    'te': {
      'nav_dashboard': 'డ్యాష్‌బోర్డ్',
      'nav_cases': 'కేసులు',
      'nav_hearings': 'విచారణలు',
      'nav_tools': 'సాధనాలు',
      'nav_more': 'మరింత',
      'dashboard_title': 'డ్యాష్‌బోర్డ్',
      'active_cases': 'యాక్టివ్ కేసులు',
      'total_cases': 'మొత్తం కేసులు',
      'upcoming_hearings': 'రాబోయే విచారణలు',
      'clients': 'క్లయింట్లు',
      'filings': 'దాఖలులు',
      'cases_title': 'కేసులు',
      'add_case': 'కేసు జోడించు',
      'case_number': 'కేసు నంబర్',
      'case_title': 'కేసు శీర్షిక',
      'case_status': 'స్థితి',
      'case_type': 'కేసు రకం',
      'case_court': 'కోర్టు',
      'case_stage': 'దశ',
      'active': 'యాక్టివ్',
      'disposed': 'పరిష్కారం',
      'archived': 'ఆర్కైవ్',
      'save': 'సేవ్',
      'cancel': 'రద్దు',
      'delete': 'తొలగించు',
      'edit': 'సవరించు',
      'search': 'వెతుకు',
      'loading': 'లోడ్ అవుతోంది...',
      'error': 'లోపం',
      'retry': 'మళ్ళీ ప్రయత్నించు',
      'no_data': 'డేటా అందుబాటులో లేదు',
      'offline_mode': 'ఆఫ్‌లైన్ మోడ్',
      'offline_message':
          'కాష్ చేసిన డేటా చూపుతోంది. సింక్ చేయడానికి ఇంటర్నెట్‌కు కనెక్ట్ చేయండి.',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations._known.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
