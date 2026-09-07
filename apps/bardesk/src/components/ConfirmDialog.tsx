import { useState, type ReactNode } from "react";
import { AlertTriangle } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";

interface ConfirmDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  /** Say what will actually happen, and whether it can be undone. */
  description: ReactNode;
  confirmLabel?: string;
  onConfirm: () => Promise<void> | void;
  /** Styles the action as destructive. Defaults to true — this is mostly used for deletes. */
  destructive?: boolean;
}

/**
 * Replaces window.confirm.
 *
 * The browser dialog cannot be styled, ignores the theme, is easy to
 * dismiss by reflex, and gives no indication that the action is running —
 * which matters when the confirm is followed by a network call that can fail.
 */
export function ConfirmDialog({
  open,
  onOpenChange,
  title,
  description,
  confirmLabel = "Delete",
  onConfirm,
  destructive = true,
}: ConfirmDialogProps) {
  const [pending, setPending] = useState(false);

  const handleConfirm = async () => {
    setPending(true);
    try {
      await onConfirm();
      onOpenChange(false);
    } finally {
      // Leave the dialog open on failure so the error toast is seen in
      // context rather than over a page that looks unchanged.
      setPending(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={pending ? undefined : onOpenChange}>
      <DialogContent className="sm:max-w-sm">
        <DialogHeader>
          <div
            className={`mb-2 flex h-10 w-10 items-center justify-center rounded-full ${
              destructive ? "bg-destructive/10" : "bg-muted"
            }`}
          >
            <AlertTriangle
              className={`h-5 w-5 ${destructive ? "text-destructive" : "text-muted-foreground"}`}
            />
          </div>
          <DialogTitle className="font-display">{title}</DialogTitle>
          <DialogDescription className="text-sm">{description}</DialogDescription>
        </DialogHeader>

        <DialogFooter>
          <Button
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={pending}
          >
            Cancel
          </Button>
          <Button
            variant={destructive ? "destructive" : "default"}
            onClick={() => void handleConfirm()}
            disabled={pending}
          >
            {pending ? "Working…" : confirmLabel}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
