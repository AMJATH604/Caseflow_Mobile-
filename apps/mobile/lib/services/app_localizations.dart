/// CaseFlow Localization Service
///
/// Supports: English (default), Hindi, Tamil, Telugu
/// Architecture: Simple key-value maps per locale, no heavy dependency.
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
    Locale('hi'), // Hindi
    Locale('ta'), // Tamil
    Locale('te'), // Telugu
  ];

  /// Get a translated string by key. Falls back to English.
  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  // Shorthand
  String get(String key) => translate(key);

  // ─── Localized Strings ─────────────────────────────────

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Navigation
      'nav_dashboard': 'Dashboard',
      'nav_cases': 'Cases',
      'nav_hearings': 'Hearings',
      'nav_tools': 'Tools',
      'nav_more': 'More',

      // Dashboard
      'dashboard_title': 'Dashboard',
      'active_cases': 'Active Cases',
      'total_cases': 'Total Cases',
      'upcoming_hearings': 'Upcoming Hearings',
      'today_hearings': "Today's Hearings",
      'clients': 'Clients',
      'filings': 'Filings',

      // Cases
      'cases_title': 'Cases',
      'add_case': 'Add Case',
      'case_number': 'Case Number',
      'case_title': 'Case Title',
      'case_status': 'Status',
      'case_type': 'Case Type',
      'case_court': 'Court',
      'case_stage': 'Stage',
      'active': 'Active',
      'disposed': 'Disposed',
      'archived': 'Archived',

      // Hearings
      'hearings_title': 'Hearings',
      'add_hearing': 'Add Hearing',
      'hearing_date': 'Hearing Date',
      'next_hearing': 'Next Hearing',
      'no_hearings': 'No hearings scheduled',

      // AI Chat
      'ai_title': 'CaseFlow AI',
      'ai_subtitle': 'Your Legal Assistant',
      'ai_placeholder': 'Ask a legal question...',
      'ai_clear': 'Clear Chat',

      // Common
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'search': 'Search',
      'loading': 'Loading...',
      'error': 'Error',
      'retry': 'Retry',
      'no_data': 'No data available',
      'offline_mode': 'Offline Mode',
      'offline_message': 'Showing cached data. Connect to internet to sync.',
    },

    'hi': {
      // Navigation
      'nav_dashboard': 'डैशबोर्ड',
      'nav_cases': 'मुकदमे',
      'nav_hearings': 'सुनवाई',
      'nav_tools': 'उपकरण',
      'nav_more': 'अधिक',

      // Dashboard
      'dashboard_title': 'डैशबोर्ड',
      'active_cases': 'सक्रिय मुकदमे',
      'total_cases': 'कुल मुकदमे',
      'upcoming_hearings': 'आगामी सुनवाई',
      'today_hearings': 'आज की सुनवाई',
      'clients': 'मुवक्किल',
      'filings': 'दाखिल',

      // Cases
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

      // Hearings
      'hearings_title': 'सुनवाई',
      'add_hearing': 'सुनवाई जोड़ें',
      'hearing_date': 'सुनवाई तिथि',
      'next_hearing': 'अगली सुनवाई',
      'no_hearings': 'कोई सुनवाई निर्धारित नहीं',

      // AI Chat
      'ai_title': 'केसफ्लो AI',
      'ai_subtitle': 'आपका कानूनी सहायक',
      'ai_placeholder': 'कानूनी प्रश्न पूछें...',
      'ai_clear': 'चैट साफ़ करें',

      // Common
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

    'ta': {
      // Navigation
      'nav_dashboard': 'டாஷ்போர்டு',
      'nav_cases': 'வழக்குகள்',
      'nav_hearings': 'விசாரணைகள்',
      'nav_tools': 'கருவிகள்',
      'nav_more': 'மேலும்',

      // Dashboard
      'dashboard_title': 'டாஷ்போர்டு',
      'active_cases': 'செயலில் உள்ள வழக்குகள்',
      'total_cases': 'மொத்த வழக்குகள்',
      'upcoming_hearings': 'வரவிருக்கும் விசாரணைகள்',
      'today_hearings': 'இன்றைய விசாரணைகள்',
      'clients': 'வாடிக்கையாளர்கள்',
      'filings': 'தாக்கல்கள்',

      // Cases
      'cases_title': 'வழக்குகள்',
      'add_case': 'வழக்கு சேர்',
      'case_number': 'வழக்கு எண்',
      'case_title': 'வழக்கு தலைப்பு',
      'case_status': 'நிலை',
      'case_type': 'வழக்கு வகை',
      'case_court': 'நீதிமன்றம்',
      'case_stage': 'நிலை',
      'active': 'செயலில்',
      'disposed': 'தீர்வு',
      'archived': 'காப்பகம்',

      // Common
      'save': 'சேமி',
      'cancel': 'ரத்து',
      'delete': 'நீக்கு',
      'edit': 'திருத்து',
      'search': 'தேடு',
      'loading': 'ஏற்றுகிறது...',
      'error': 'பிழை',
      'retry': 'மீண்டும் முயற்சி',
      'no_data': 'தரவு இல்லை',
      'offline_mode': 'ஆஃப்லைன் பயன்முறை',
      'offline_message':
          'தேக்கக தரவைக் காட்டுகிறது. ஒத்திசைக்க இணையத்தை இணைக்கவும்.',
    },

    'te': {
      // Navigation
      'nav_dashboard': 'డ్యాష్‌బోర్డ్',
      'nav_cases': 'కేసులు',
      'nav_hearings': 'విచారణలు',
      'nav_tools': 'సాధనాలు',
      'nav_more': 'మరింత',

      // Dashboard
      'dashboard_title': 'డ్యాష్‌బోర్డ్',
      'active_cases': 'యాక్టివ్ కేసులు',
      'total_cases': 'మొత్తం కేసులు',
      'upcoming_hearings': 'రాబోయే విచారణలు',
      'today_hearings': 'నేటి విచారణలు',
      'clients': 'క్లయింట్లు',
      'filings': 'దాఖలులు',

      // Cases
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

      // Common
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
      ['en', 'hi', 'ta', 'te'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
