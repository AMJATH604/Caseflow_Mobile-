import { useEffect } from "react";

const typingIn = (el: EventTarget | null) => {
  if (!(el instanceof HTMLElement)) return false;
  return el.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(el.tagName);
};

/**
 * Global shortcuts. Single-key shortcuts ("/", "[") never fire while the user
 * is typing in a field — a clerk entering a case number must be able to type
 * a slash. Ctrl/⌘+K works everywhere, as it does in every tool that has it.
 */
export function useHotkeys(map: Record<string, () => void>) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const mod = e.ctrlKey || e.metaKey;
      const key = (mod ? "mod+" : "") + e.key.toLowerCase();
      const fn = map[key];
      if (!fn) return;
      if (!mod && typingIn(e.target)) return;
      e.preventDefault();
      fn();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [map]);
}

export const isMac = typeof navigator !== "undefined" && /Mac|iPhone|iPad/.test(navigator.platform);
export const modKey = isMac ? "⌘" : "Ctrl";
