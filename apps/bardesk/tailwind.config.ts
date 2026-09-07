import type { Config } from "tailwindcss";
import designSystem from "../../packages/design-system/tailwind.preset";

/**
 * BarDesk shares CaseFlow's visual language. Colours, typography, radius,
 * shadows and animation all come from the design system preset — the cyan
 * "brand" palette that used to live here was unrelated to the rest of the
 * product and could not respond to a theme.
 */
export default {
  presets: [designSystem],
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  plugins: [require("tailwindcss-animate")],
} satisfies Config;
