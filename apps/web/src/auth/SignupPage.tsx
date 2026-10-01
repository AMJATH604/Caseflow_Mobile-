import { useState } from "react";
import { useForm } from "react-hook-form";
import { useTranslation } from "react-i18next";
import { Link } from "react-router-dom";
import { Loader2 } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Field, FormNotice } from "@/components/Field";
import geo from "@/lib/geo.json";
import { AuthLayout } from "./AuthLayout";
import { PasswordChecklist } from "./PasswordChecklist";
import { passwordOk } from "./passwordPolicy";
import { classifyAuthError } from "./authErrors";

const STATES = geo as Record<string, string[]>;

interface Form {
  full_name: string;
  email: string;
  mobile: string;
  reg_no: string;
  state: string;
  district: string;
  office_address: string;
  password: string;
}

/**
 * Advocate registration. Sends the same user-metadata keys as the mobile
 * sign-up (login_screen.dart), so the database trigger that builds the
 * profile from them treats a web sign-up exactly like a phone one.
 *
 * Only advocates register here. Juniors and clerks get their access through
 * their advocate's invitation, and citizens use the mobile app.
 */
export function SignupPage() {
  const { t } = useTranslation();
  const [done, setDone] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const { register, handleSubmit, watch, formState, setValue } = useForm<Form>({
    defaultValues: { state: "Tamil Nadu", district: "" },
  });
  const state = watch("state");
  const password = watch("password") ?? "";
  const e = formState.errors;

  const onSubmit = async (f: Form) => {
    setFailure(null);
    const { error } = await supabase.auth.signUp({
      email: f.email.trim(),
      password: f.password, // not trimmed — see LoginPage
      options: {
        emailRedirectTo: `${window.location.origin}/login`,
        data: {
          full_name: f.full_name.trim(),
          mobile_number: f.mobile.trim(),
          registration_number: f.reg_no.trim(),
          practice_state: f.state,
          practice_district: f.district,
          office_address: f.office_address.trim(),
          is_public_directory_enabled: true,
          user_role: "advocate",
        },
      },
    });
    if (error) {
      const { key, detail } = classifyAuthError(error);
      return setFailure(key ? t(key) : detail);
    }
    setDone(true);
  };

  if (done) {
    return (
      <AuthLayout title={t("auth.signup_title")}>
        <div className="space-y-6">
          <FormNotice tone="success">{t("auth.check_email")}</FormNotice>
          <Button asChild className="h-10 w-full">
            <Link to="/login">{t("auth.sign_in")}</Link>
          </Button>
        </div>
      </AuthLayout>
    );
  }

  return (
    <AuthLayout title={t("auth.signup_title")} subtitle={t("auth.signup_sub")}>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4" noValidate>
        {failure ? <FormNotice tone="error">{failure}</FormNotice> : null}

        <Field label={t("auth.full_name")} error={e.full_name?.message}>
          {(p) => <Input {...p} autoComplete="name" autoFocus className="h-10" {...register("full_name", { required: t("auth.required") })} />}
        </Field>

        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("auth.email")} error={e.email?.message}>
            {(p) => (
              <Input
                {...p}
                type="email"
                autoComplete="email"
                className="h-10"
                {...register("email", {
                  required: t("auth.required"),
                  pattern: { value: /^\S+@\S+\.\S+$/, message: t("auth.invalid_email") },
                })}
              />
            )}
          </Field>
          <Field label={t("auth.mobile")} error={e.mobile?.message}>
            {(p) => (
              <Input
                {...p}
                type="tel"
                inputMode="numeric"
                autoComplete="tel-national"
                className="h-10"
                {...register("mobile", {
                  required: t("auth.required"),
                  pattern: { value: /^[6-9]\d{9}$/, message: t("auth.invalid_mobile") },
                })}
              />
            )}
          </Field>
        </div>

        <Field label={t("auth.reg_no")} error={e.reg_no?.message}>
          {(p) => <Input {...p} placeholder="MS/1234/2015" className="h-10" {...register("reg_no", { required: t("auth.required") })} />}
        </Field>

        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("auth.state")} error={e.state?.message}>
            {(p) => (
              <select
                {...p}
                className="flex h-10 w-full rounded-md border border-input bg-background px-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                {...register("state", {
                  required: t("auth.required"),
                  onChange: () => setValue("district", ""),
                })}
              >
                {Object.keys(STATES).map((s) => (
                  <option key={s} value={s}>
                    {s}
                  </option>
                ))}
              </select>
            )}
          </Field>
          <Field label={t("auth.district")} error={e.district?.message}>
            {(p) => (
              <select
                {...p}
                className="flex h-10 w-full rounded-md border border-input bg-background px-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                {...register("district", { required: t("auth.required") })}
              >
                <option value="">{t("auth.select")}</option>
                {(STATES[state] ?? []).map((d) => (
                  <option key={d} value={d}>
                    {d}
                  </option>
                ))}
              </select>
            )}
          </Field>
        </div>

        <Field label={t("auth.office_address")}>
          {(p) => <Textarea {...p} rows={2} autoComplete="street-address" {...register("office_address")} />}
        </Field>

        <Field label={t("auth.password")} error={e.password?.message} hint={<PasswordChecklist value={password} />}>
          {(p) => (
            <Input
              {...p}
              type="password"
              autoComplete="new-password"
              className="h-10"
              {...register("password", { validate: (v) => passwordOk(v) || t("auth.pw_rules") })}
            />
          )}
        </Field>

        <Button type="submit" className="h-10 w-full" disabled={formState.isSubmitting}>
          {formState.isSubmitting ? <Loader2 className="h-4 w-4 animate-spin" /> : t("auth.create_account")}
        </Button>

        <p className="pt-1 text-center text-sm text-muted-foreground">
          {t("auth.have_account")}{" "}
          <Link to="/login" className="font-medium text-primary hover:underline">
            {t("auth.sign_in")}
          </Link>
        </p>
      </form>
    </AuthLayout>
  );
}
