import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react-swc";
import path from "node:path";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
      // Worked examples shared with the Flutter tests. Both platforms must
      // agree on every one, so a legal rule cannot drift between them.
      "@fixtures": path.resolve(__dirname, "../../packages/legal-fixtures"),
    },
  },
  build: {
    rollupOptions: {
      output: {
        // Libraries change rarely and the app changes often; separate files
        // let a returning user's browser keep the libraries cached and fetch
        // only the app code a release actually changed.
        manualChunks: {
          react: ["react", "react-dom", "react-router-dom"],
          supabase: ["@supabase/supabase-js"],
          query: ["@tanstack/react-query"],
          i18n: ["i18next", "react-i18next"],
          radix: [
            "@radix-ui/react-dialog",
            "@radix-ui/react-dropdown-menu",
            "@radix-ui/react-tooltip",
            "@radix-ui/react-scroll-area",
            "cmdk",
          ],
        },
      },
    },
  },
  server: {
    // The fixtures live outside this app's folder.
    fs: { allow: [path.resolve(__dirname, "../..")] },
  },
  test: {
    globals: true,
    environment: "jsdom",
    setupFiles: ["./src/test/setup.ts"],
  },
});
