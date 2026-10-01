import type { Config } from "tailwindcss";
import animate from "tailwindcss-animate";
import designSystem from "../../packages/design-system/tailwind.preset";

export default {
  presets: [designSystem],
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        // Tamil glyphs are not in Inter or Outfit; without Noto Sans Tamil
        // in the stack the browser falls back to whatever the OS has, and
        // the Tamil UI renders in a mismatched face.
        display: ["Outfit", "Inter", "Noto Sans Tamil", "system-ui", "sans-serif"],
        sans: ["Inter", "Noto Sans Tamil", "system-ui", "sans-serif"],
      },
    },
  },
  plugins: [animate],
} satisfies Config;
