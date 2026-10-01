import { useState } from "react";
import { useForm } from "react-hook-form";
import { useTranslation } from "react-i18next";
import { Link, Navigate, useLocation } from "react-router-dom";
import { Loader2 } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Field, FormNotice } from "@/components/Field";
import { AuthLayout } from "./AuthLayout";
import { useAuth } from "./AuthProvider";
import { classifyAuthError } from "./authErrors";

interface Form {
  email: string;
  password: string;
}

export function LoginPage() {
  const { t } = useTranslation();
  const { session, role, denied } = useAuth();
  const location = useLocation();
  const [failure, setFailure] = useState<string | null>(null);
  const { register, handleSubmit, formState } = useForm<Form>();

  const from = (location.state as { from?: string } | null)?.from ?? "/";
  if (session && role) return <Navigate to={from} replace />;

  const onSubmit = async ({ email, password }: Form) => {
    setFailure(null);
    // Email trimmed, password not: a password is an opaque credential, and
    // stripping its whitespace would make a manager-stored password that ends
    // in a space impossible to enter. Same rule as the mobile login.
    const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
    if (error) {
      const { key, detail } = classifyAuthError(error);
      setFailure(key ? t(key) : detail);
    }
  };

  const deniedMessage = denied === "admin" ? t("auth.err_admin") : denied === "citizen" ? t("auth.err_citizen") : null;

  return (
    <AuthLayout title={t("auth.welcome")} subtitle={t("auth.subtitle")}>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
        {failure || deniedMessage ? <FormNotice tone="error">{failure ?? deniedMessage}</FormNotice> : null}

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

        <Field label={t("auth.password")} error={formState.errors.password?.message}>
          {(p) => (
            <Input
              {...p}
              type="password"
              autoComplete="current-password"
              className="h-10"
              {...register("password", { required: t("auth.required") })}
            />
          )}
        </Field>

        <div className="flex justify-end">
          <Link to="/forgot-password" className="text-sm font-medium text-primary hover:underline">
            {t("auth.forgot")}
          </Link>
        </div>

        <Button type="submit" className="h-10 w-full" disabled={formState.isSubmitting}>
          {formState.isSubmitting ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" /> {t("auth.signing_in")}
            </>
          ) : (
            t("auth.sign_in")
          )}
        </Button>

        <p className="pt-2 text-center text-sm text-muted-foreground">
          {t("auth.no_account")}{" "}
          <Link to="/signup" className="font-medium text-primary hover:underline">
            {t("auth.create_account")}
          </Link>
        </p>
      </form>
    </AuthLayout>
  );
}
