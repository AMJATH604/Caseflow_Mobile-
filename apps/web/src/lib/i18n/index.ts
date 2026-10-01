import i18n from "i18next";
import { initReactI18next } from "react-i18next";

// Two layers per language:
//   en.json / ta.json      — extracted verbatim from the mobile app
//                            (apps/mobile/lib/services/app_localizations.dart),
//                            so a phrase reads the same on the phone and the web.
//                            Regenerate rather than editing by hand.
//   web.en.json / web.ta.json — wording only the web has (sidebar, login,
//                            command bar).
//
// As on mobile, legal terms of art stay in English in Tamil too — "caveat",
// "CNR", "vakalat", "Section 138" — because that is how they appear in the
// record and how advocates use them.
import en from "./en.json";
import ta from "./ta.json";
import webEn from "./web.en.json";
import webTa from "./web.ta.json";

export const LANGUAGES = [
  { code: "en", label: "English" },
  { code: "ta", label: "தமிழ்" },
] as const;
export type Language = (typeof LANGUAGES)[number]["code"];

const STORAGE_KEY = "cf-lang";

function initialLanguage(): Language {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === "en" || saved === "ta") return saved;
  } catch {
    /* private mode — fall through */
  }
  return "en";
}

void i18n.use(initReactI18next).init({
  resources: {
    en: { translation: { ...en, ...webEn } },
    ta: { translation: { ...ta, ...webTa } },
  },
  lng: initialLanguage(),
  fallbackLng: "en",
  interpolation: { escapeValue: false }, // React already escapes
  returnNull: false,
});

export function setLanguage(lang: Language) {
  void i18n.changeLanguage(lang);
  document.documentElement.lang = lang;
  try {
    localStorage.setItem(STORAGE_KEY, lang);
  } catch {
    /* ignore */
  }
}

export default i18n;
