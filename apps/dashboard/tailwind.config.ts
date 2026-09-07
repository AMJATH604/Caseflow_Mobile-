import type { Config } from "tailwindcss";
import designSystem from "../../packages/design-system/tailwind.preset";

/**
 * Colours, typography, radius, shadows and animation all come from the shared
 * design system preset so this app and apps/bardesk stay in step. Only
 * app-specific concerns belong below.
 */
export default {
  presets: [designSystem],
  content: [
    "./pages/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./app/**/*.{ts,tsx}",
    "./src/**/*.{ts,tsx}",
  ],
  prefix: "",
  plugins: [require("tailwindcss-animate")],
} satisfies Config;
