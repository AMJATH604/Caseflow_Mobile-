import { useState } from "react";
import { useForm } from "react-hook-form";
import { useTranslation } from "react-i18next";
import { useNavigate } from "react-router-dom";
import { Loader2 } from "lucide-react";
import { toast } from "sonner";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Field, FormNotice } from "@/components/Field";
import { AuthLayout } from "./AuthLayout";
import { PasswordChecklist } from "./PasswordChecklist";
import { passwordOk } from "./passwordPolicy";

interface Form {
  password: string;
  confirm: string;
}

/**
 * Where the emailed reset link lands. Supabase puts a recovery session in the
 * URL; the client picks it up (detectSessionInUrl), and updateUser then sets
 * the new password on that session.
 */
export function ResetPasswordPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [failure, setFailure] = useState<string | null>(null);
  const { register, handleSubmit, watch, formState } = useForm<Form>();
  const password = watch("password") ?? "";

  const onSubmit = async ({ password }: Form) => {
    setFailure(null);
    const { error } = await supabase.auth.updateUser({ password });
    if (error) return setFailure(error.message);
    toast.success(t("auth.password_updated"));
    navigate("/", { replace: true });
  };

  return (
    <AuthLayout title={t("auth.set_password")} subtitle={t("auth.pw_rules")}>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5" noValidate>
        {failure ? <FormNotice tone="error">{failure}</FormNotice> : null}
        <Field label={t("auth.new_password")} error={formState.errors.password?.message} hint={<PasswordChecklist value={password} />}>
          {(p) => (
            <Input
              {...p}
              type="password"
              autoComplete="new-password"
              autoFocus
              className="h-10"
              {...register("password", { validate: (v) => passwordOk(v) || t("auth.pw_rules") })}
            />
          )}
        </Field>
        <Field label={t("auth.confirm_password")} error={formState.errors.confirm?.message}>
          {(p) => (
            <Input
              {...p}
              type="password"
              autoComplete="new-password"
              className="h-10"
              {...register("confirm", { validate: (v) => v === password || t("auth.mismatch") })}
            />
          )}
        </Field>
        <Button type="submit" className="h-10 w-full" disabled={formState.isSubmitting}>
          {formState.isSubmitting ? <Loader2 className="h-4 w-4 animate-spin" /> : t("auth.set_password")}
        </Button>
      </form>
    </AuthLayout>
  );
}
