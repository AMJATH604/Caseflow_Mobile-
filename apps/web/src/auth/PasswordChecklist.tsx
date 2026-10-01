import { useTranslation } from "react-i18next";
import { Check, Circle } from "lucide-react";
import { cn } from "@/lib/utils";
import { passwordChecks, type PasswordRule } from "./passwordPolicy";

/** Live checklist under a new-password field: each rule ticks as it is met. */
export function PasswordChecklist({ value }: { value: string }) {
  const { t } = useTranslation();
  const checks = passwordChecks(value);
  return (
    <ul className="grid grid-cols-2 gap-x-3 gap-y-1 pt-1">
      {(Object.keys(checks) as PasswordRule[]).map((rule) => (
        <li key={rule} className={cn("flex items-center gap-1.5 text-xs", checks[rule] ? "text-success" : "text-muted-foreground")}>
          {checks[rule] ? <Check className="h-3.5 w-3.5" /> : <Circle className="h-3 w-3" />}
          {t(`auth.${rule}`)}
        </li>
      ))}
    </ul>
  );
}
