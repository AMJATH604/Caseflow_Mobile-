import { Navigate, Route, Routes } from "react-router-dom";
import { RequireAuth } from "@/auth/RequireAuth";
import { LoginPage } from "@/auth/LoginPage";
import { SignupPage } from "@/auth/SignupPage";
import { ForgotPasswordPage } from "@/auth/ForgotPasswordPage";
import { ResetPasswordPage } from "@/auth/ResetPasswordPage";
import { AppShell } from "@/shell/AppShell";
import { ALL_ITEMS, BUILT_PHASE } from "@/shell/nav";
import { ComingSoonPage } from "@/pages/ComingSoonPage";
import { HomePage } from "@/pages/HomePage";

/**
 * Routes come from the nav list, so every feature has a URL from the first
 * release. A screen not yet built renders its ComingSoonPage; as each phase
 * lands, its real page is registered in BUILT below and takes over.
 */
const BUILT: Record<string, JSX.Element> = {
  // Phase 1 has no feature screens; the home page stands in for the dashboard.
};

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/signup" element={<SignupPage />} />
      <Route path="/forgot-password" element={<ForgotPasswordPage />} />
      <Route path="/reset-password" element={<ResetPasswordPage />} />

      <Route element={<RequireAuth />}>
        <Route element={<AppShell />}>
          {ALL_ITEMS.map((item) => {
            const element =
              BUILT[item.id] ??
              (item.id === "dashboard" && BUILT_PHASE < item.phase ? <HomePage /> : <ComingSoonPage item={item} />);
            return <Route key={item.id} path={item.path === "/" ? undefined : `${item.path}/*`} index={item.path === "/"} element={element} />;
          })}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Route>
    </Routes>
  );
}
