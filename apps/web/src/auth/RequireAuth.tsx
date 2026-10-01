import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Logo } from "@/components/Logo";
import { useAuth } from "./AuthProvider";

export function Splash() {
  return (
    <div className="grid h-screen place-items-center bg-background">
      <div className="flex flex-col items-center gap-5">
        <Logo />
        <div className="h-0.5 w-24 overflow-hidden rounded-full bg-muted">
          <div className="h-full w-1/2 animate-[shimmer_1.2s_ease-in-out_infinite] rounded-full bg-primary" />
        </div>
      </div>
    </div>
  );
}

/** Gate for every signed-in route: no session → login, remembering where to come back to. */
export function RequireAuth() {
  const { t } = useTranslation();
  const { session, role, initialising, profileLoading, profileError } = useAuth();
  const location = useLocation();
  const qc = useQueryClient();

  if (initialising) return <Splash />;
  if (!session) return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  if (profileLoading) return <Splash />;
  if (!role) {
    // Signed in, but the profile could not be loaded — say so and offer a retry
    // rather than showing an empty app that looks like "no data".
    return (
      <div className="grid h-screen place-items-center bg-background px-6 text-center">
        <div className="max-w-sm space-y-4">
          <p className="font-display text-lg font-semibold text-foreground">{t("error")}</p>
          <p className="text-sm text-muted-foreground">{profileError instanceof Error ? profileError.message : String(profileError ?? "")}</p>
          <Button onClick={() => void qc.invalidateQueries({ queryKey: ["me"] })}>{t("retry")}</Button>
        </div>
      </div>
    );
  }
  return <Outlet />;
}
