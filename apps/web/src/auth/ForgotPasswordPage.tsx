import { useState } from "react";
import { useForm } from "react-hook-form";
import { useTranslation } from "react-i18next";
import { Link } from "react-router-dom";
import { ArrowLeft, Loader2 } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Field, FormNotice } from "@/components/Field";
import { AuthLayout } from "./AuthLayout";
import { classifyAuthError } from "./authErrors";

export function ForgotPasswordPage() {
  const { t } = useTranslation();
  const [sent, setSent] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const { register, handleSubmit, formState } = useForm<{ email: string }>();

  const onSubmit = async ({ email }: { email: string }) => {
    setFailure(null);
    const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), {
      redirectTo: `${window.location.origin}/reset-password`,
    });
    // The same confirmation whether or not the account exists: saying "no
    // such account" would let anyone test which emails are registered.
    if (error) {
      const { key, detail } = classifyAuthError(error);
      if (key === "auth.err_network") return setFailure(t(key));
      if (!/rate limit|too many/i.test(detail)) return setSent(true);
      return setFailure(detail);
    }
    setSent(true);
  };

  return (
    <AuthLayout title={t("auth.reset_title")} subtitle={t("auth.reset_sub")}>
      {sent ? (
        <div className="space-y-6">
          <FormNotice tone="success">{t("auth.link_sent")}</FormNotice>
          <BackToSignIn />
        </div>
      ) : (
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
          {failure ? <FormNotice tone="error">{failure}</FormNotice> : null}
          <Field label={t("auth.email")} error={formState.errors.email?.message}>
            {(p) => (
              <Input
                {...p}
                type="email"
                autoComplete="email"
                autoFocus
                className="h-10"
                {...register("email", {
                  required: t("auth.required"),
                  pattern: { value: /^\S+@\S+\.\S+$/, message: t("auth.invalid_email") },
                })}
              />
            )}
          </Field>
          <Button type="submit" className="h-10 w-full" disabled={formState.isSubmitting}>
            {formState.isSubmitting ? <Loader2 className="h-4 w-4 animate-spin" /> : t("auth.send_link")}
          </Button>
          <BackToSignIn />
        </form>
      )}
    </AuthLayout>
  );
}

function BackToSignIn() {
  const { t } = useTranslation();
  return (
    <Link to="/login" className="flex items-center justify-center gap-1.5 text-sm font-medium text-muted-foreground hover:text-foreground">
      <ArrowLeft className="h-4 w-4" /> {t("auth.back_to_sign_in")}
    </Link>
  );
}
