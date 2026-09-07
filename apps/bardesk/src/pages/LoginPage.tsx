import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Scale, AlertTriangle } from "lucide-react";

import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export default function LoginPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    try {
      const { error: authError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });
      if (authError) throw authError;

      // Signing in is not enough — BarDesk is only for association
      // office-bearers, so the account must also appear in bar_admins.
      const {
        data: { user },
      } = await supabase.auth.getUser();
      const { data: admin } = await supabase
        .from("bar_admins")
        .select("id")
        .eq("user_id", user?.id)
        .maybeSingle();

      if (!admin) {
        await supabase.auth.signOut();
        throw new Error(
          "This account is not registered as an association office-bearer.",
        );
      }

      navigate("/");
    } catch (err: any) {
      setError(err.message || "Sign in failed. Please check your details.");
    } finally {
      setLoading(false);
    }
  };

  return (
    // The login screen commits to the dark brand ground in both themes —
    // it is a doorway, not part of the working interface.
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-sidebar p-4">
      <div className="pointer-events-none absolute inset-0" aria-hidden>
        <div className="absolute -right-40 -top-40 h-80 w-80 rounded-full bg-accent/10 blur-3xl" />
        <div className="absolute -bottom-40 -left-40 h-96 w-96 rounded-full bg-primary/20 blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">
        <div className="mb-8 text-center">
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl border border-sidebar-primary/20 bg-sidebar-primary/10">
            <Scale className="h-8 w-8 text-sidebar-primary" />
          </div>
          <h1 className="font-serif text-3xl font-bold tracking-tight text-sidebar-accent-foreground">
            BarDesk
          </h1>
          <p className="mt-1.5 text-sm text-sidebar-foreground/70">
            Bar Association Management Portal
          </p>
        </div>

        <div className="rounded-2xl border border-sidebar-border bg-sidebar-accent/40 p-7 shadow-lg backdrop-blur-xl">
          <h2 className="font-display text-lg font-semibold text-sidebar-accent-foreground">
            Office-bearer sign in
          </h2>
          <p className="mt-1 text-sm text-sidebar-foreground/60">
            For the secretary, president or treasurer of your association.
          </p>

          {error && (
            <div
              role="alert"
              className="mt-5 flex items-start gap-2.5 rounded-lg border border-destructive/30 bg-destructive/10 p-3 text-sm text-destructive"
            >
              <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleLogin} className="mt-6 space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="email" className="text-sidebar-foreground/80">
                Email
              </Label>
              <Input
                id="email"
                type="email"
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                placeholder="secretary@barcouncil.in"
                className="border-sidebar-border bg-sidebar/60 text-sidebar-accent-foreground placeholder:text-sidebar-foreground/40"
              />
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="password" className="text-sidebar-foreground/80">
                Password
              </Label>
              <Input
                id="password"
                type="password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                placeholder="••••••••"
                className="border-sidebar-border bg-sidebar/60 text-sidebar-accent-foreground placeholder:text-sidebar-foreground/40"
              />
            </div>

            <Button
              type="submit"
              disabled={loading}
              className="w-full bg-accent text-accent-foreground hover:bg-accent/90"
            >
              {loading ? "Signing in…" : "Sign in"}
            </Button>
          </form>
        </div>

        <p className="mt-6 text-center text-2xs text-sidebar-foreground/50">
          Powered by CaseFlow · Access is limited to authorised office-bearers
        </p>
      </div>
    </div>
  );
}
