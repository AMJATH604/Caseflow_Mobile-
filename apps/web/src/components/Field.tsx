import { useId, type ReactNode } from "react";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";

/** A labelled form row with its error underneath, linked for screen readers. */
export function Field({
  label,
  error,
  hint,
  children,
  className,
}: {
  label: string;
  error?: string;
  hint?: ReactNode;
  children: (props: { id: string; "aria-invalid": boolean; "aria-describedby"?: string }) => ReactNode;
  className?: string;
}) {
  const id = useId();
  const msgId = `${id}-msg`;
  return (
    <div className={cn("space-y-1.5", className)}>
      <Label htmlFor={id} className="text-sm font-medium text-foreground">
        {label}
      </Label>
      {children({ id, "aria-invalid": !!error, "aria-describedby": error || hint ? msgId : undefined })}
      {error ? (
        <p id={msgId} className="text-xs font-medium text-destructive">
          {error}
        </p>
      ) : hint ? (
        <div id={msgId} className="text-xs text-muted-foreground">
          {hint}
        </div>
      ) : null}
    </div>
  );
}

/** A banner for a form-level message: an error, or a success notice. */
export function FormNotice({ tone, children }: { tone: "error" | "success"; children: ReactNode }) {
  return (
    <div
      role={tone === "error" ? "alert" : "status"}
      className={cn(
        "rounded-lg border px-3.5 py-3 text-sm",
        tone === "error"
          ? "border-destructive/30 bg-destructive/10 text-destructive"
          : "border-success/30 bg-success/10 text-success",
      )}
    >
      {children}
    </div>
  );
}
