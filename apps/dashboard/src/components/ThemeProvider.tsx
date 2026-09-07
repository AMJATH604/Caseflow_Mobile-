import { ThemeProvider as NextThemesProvider } from "next-themes";
import type { ReactNode } from "react";

/**
 * Enables the dark theme.
 *
 * The `.dark` token block and `darkMode: ["class"]` have both existed in this
 * app for a long time, but nothing ever added the class — so the dark theme was
 * fully written and completely unreachable. This is the missing piece.
 *
 * `attribute="class"` is required: Tailwind is configured for class-based dark
 * mode, not the `data-theme` attribute next-themes uses by default.
 */
export function ThemeProvider({ children }: { children: ReactNode }) {
  return (
    <NextThemesProvider
      attribute="class"
      defaultTheme="system"
      enableSystem
      disableTransitionOnChange
      storageKey="caseflow-theme"
    >
      {children}
    </NextThemesProvider>
  );
}
