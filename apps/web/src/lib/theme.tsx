import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";

export type ThemeChoice = "light" | "dark" | "system";
const STORAGE_KEY = "cf-theme";

interface ThemeState {
  choice: ThemeChoice;
  resolved: "light" | "dark";
  setChoice: (c: ThemeChoice) => void;
}

const ThemeContext = createContext<ThemeState | null>(null);

function readChoice(): ThemeChoice {
  try {
    const v = localStorage.getItem(STORAGE_KEY);
    if (v === "light" || v === "dark") return v;
  } catch {
    /* private mode */
  }
  return "system";
}

const systemDark = () => window.matchMedia("(prefers-color-scheme: dark)").matches;

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [choice, setChoiceState] = useState<ThemeChoice>(readChoice);
  const [sysDark, setSysDark] = useState(systemDark);

  // Follow the OS while the user has not picked a side.
  useEffect(() => {
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => setSysDark(mq.matches);
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, []);

  const resolved = choice === "system" ? (sysDark ? "dark" : "light") : choice;

  useEffect(() => {
    document.documentElement.classList.toggle("dark", resolved === "dark");
  }, [resolved]);

  const setChoice = useCallback((c: ThemeChoice) => {
    setChoiceState(c);
    try {
      if (c === "system") localStorage.removeItem(STORAGE_KEY);
      else localStorage.setItem(STORAGE_KEY, c);
    } catch {
      /* ignore */
    }
  }, []);

  return <ThemeContext.Provider value={{ choice, resolved, setChoice }}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used inside ThemeProvider");
  return ctx;
}
