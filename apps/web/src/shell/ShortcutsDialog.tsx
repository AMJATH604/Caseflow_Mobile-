import { useTranslation } from "react-i18next";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { modKey } from "./useHotkeys";

const SHORTCUTS: [keys: string[], labelKey: string][] = [
  [[modKey, "K"], "shell.sc_jump"],
  [["/"], "shell.sc_search"],
  [["["], "shell.sc_sidebar"],
  [["?"], "shell.sc_help"],
];

export function ShortcutsDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const { t } = useTranslation();
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t("shell.keyboard")}</DialogTitle>
        </DialogHeader>
        <ul className="divide-y divide-border">
          {SHORTCUTS.map(([keys, label]) => (
            <li key={label} className="flex items-center justify-between py-2.5 text-sm">
              <span className="text-foreground">{t(label)}</span>
              <span className="flex gap-1">
                {keys.map((k) => (
                  <kbd key={k} className="min-w-6 rounded border border-border bg-muted px-1.5 py-0.5 text-center text-xs font-medium">
                    {k}
                  </kbd>
                ))}
              </span>
            </li>
          ))}
        </ul>
      </DialogContent>
    </Dialog>
  );
}
