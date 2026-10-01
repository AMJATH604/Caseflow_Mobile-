import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import "@/lib/i18n";
import { ThemeProvider } from "@/lib/theme";
import { AuthProvider } from "@/auth/AuthProvider";
import { Toaster } from "@/components/ui/sonner";
import App from "./App";
import "./index.css";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      // A refetch of the same query keeps its current data on screen until
      // the new data lands (isFetching, not isLoading) — so no dashboard-wide
      // spinner flash like the one the mobile app had. Deliberately NOT a
      // global placeholderData: that would show the previous case's details
      // under the next case's title while it loads.
      refetchOnWindowFocus: true,
      retry: 1,
    },
  },
});

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>
        <BrowserRouter>
          <AuthProvider>
            <App />
            <Toaster />
          </AuthProvider>
        </BrowserRouter>
      </ThemeProvider>
    </QueryClientProvider>
  </StrictMode>,
);
