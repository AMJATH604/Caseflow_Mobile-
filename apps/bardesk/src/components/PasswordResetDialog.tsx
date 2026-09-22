import { useState } from "react";
import { KeyRound, MailCheck } from "lucide-react";

import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

/**
 * Password recovery for office-bearers.
 *
 * BarDesk had none: the only auth call on the login page was
 * signInWithPassword, so a secretary who forgot their password was locked
 * out until somebody with Supabase access rescued them. That is survivable
 * while the only admin is the person who built it, and not survivable once
 * an association in another district is using it.
 *
 * Mirrors the mobile app's flow — email, six-digit code, new password —
 * including its wording. resetPasswordForEmail succeeds whether or not the
 * account exists, on purpose, so the copy promises a condition rather than
 * claiming a mail was sent; saying "no such user" would let anyone probe
 * which advocates are registered.
 */
type Step = "email" | "code" | "done";

const MIN_PASSWORD = 8;

export function PasswordResetDialog({
  open,
  onOpenChange,
  initialEmail = "",
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  initialEmail?: string;
}) {
  const [step, setStep] = useState<Step>("email");
  const [email, setEmail] = useState(initialEmail);
  const [code, setCode] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  function reset() {
    setStep("email");
    setCode("");
    setPassword("");
    setConfirm("");
    setError("");
  }

  async function sendCode() {
    if (!/^[\w.-]+@[\w.-]+\.\w{2,}$/.test(email.trim())) {
      setError("Enter a valid email address.");
      return;
    }
    setBusy(true);
    setError("");
    try {
      await supabase.auth.resetPasswordForEmail(email.trim());
      setStep("code");
    } catch (e) {
      const message = e instanceof Error ? e.message.toLowerCase() : "";
      setError(
        message.includes("rate limit")
          ? "Too many requests. Wait a minute and try again."
          : "Could not send the code. Check the address and try again.",
      );
    } finally {
      setBusy(false);
    }
  }

  async function verifyAndSet() {
    if (code.trim().length < 6) {
      setError("Enter the six-digit code from the email.");
      return;
    }
    if (password.length < MIN_PASSWORD) {
      setError(`Use at least ${MIN_PASSWORD} characters.`);
      return;
    }
    if (password !== confirm) {
      setError("The two passwords do not match.");
      return;
    }

    setBusy(true);
    setError("");
    try {
      const { data, error: otpError } = await supabase.auth.verifyOtp({
        email: email.trim(),
        token: code.trim(),
        type: "recovery",
      });
      if (otpError) throw otpError;
      if (!data.session && !data.user) throw new Error("invalid code");

      const { error: updateError } = await supabase.auth.updateUser({ password });
      if (updateError) throw updateError;

      // Signed in as a side effect of the recovery; BarDesk decides access
      // by bar_admins, so leave the session closed and let them log in.
      await supabase.auth.signOut();
      setStep("done");
    } catch {
      // A wrong code and an address with no account are indistinguishable
      // here, and naming only the first would mislead someone who never
      // registered.
      setError(
        "That code is invalid or expired — or there is no BarDesk account for this email.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(v) => {
        onOpenChange(v);
        if (!v) reset();
      }}
    >
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            {step === "done" ? (
              <MailCheck className="h-4 w-4 text-success" />
            ) : (
              <KeyRound className="h-4 w-4 text-primary" />
            )}
            {step === "done" ? "Password changed" : "Reset your password"}
          </DialogTitle>
          <DialogDescription>
            {step === "email" &&
              "We will email a six-digit code to your office-bearer address."}
            {step === "code" &&
              `If an account exists for ${email}, a code is on its way. No code arriving may mean there is no account for that address.`}
            {step === "done" &&
              "Sign in with your new password."}
          </DialogDescription>
        </DialogHeader>

        {step === "email" && (
          <div className="space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="pr-email">Email</Label>
              <Input
                id="pr-email"
                type="email"
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
          </div>
        )}

        {step === "code" && (
          <div className="space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="pr-code">Six-digit code</Label>
              <Input
                id="pr-code"
                inputMode="numeric"
                maxLength={8}
                className="text-center font-mono text-lg tracking-[0.4em]"
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="pr-pass">New password</Label>
              <Input
                id="pr-pass"
                type="password"
                autoComplete="new-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="pr-confirm">Confirm password</Label>
              <Input
                id="pr-confirm"
                type="password"
                autoComplete="new-password"
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
              />
            </div>
          </div>
        )}

        {error && (
          <p className="rounded-lg border border-destructive/25 bg-destructive/[0.06] px-3 py-2 text-sm text-destructive">
            {error}
          </p>
        )}

        <DialogFooter>
          {step === "email" && (
            <>
              <Button variant="outline" onClick={() => onOpenChange(false)}>
                Cancel
              </Button>
              <Button onClick={sendCode} disabled={busy}>
                {busy ? "Sending…" : "Send code"}
              </Button>
            </>
          )}
          {step === "code" && (
            <>
              <Button variant="outline" onClick={() => setStep("email")}>
                Change email
              </Button>
              <Button onClick={verifyAndSet} disabled={busy}>
                {busy ? "Saving…" : "Set password"}
              </Button>
            </>
          )}
          {step === "done" && (
            <Button onClick={() => onOpenChange(false)}>Back to sign in</Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
