import { useNavigate } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Languages, LogOut, Monitor, Moon, Sun } from "lucide-react";
import {
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
  CommandShortcut,
} from "@/components/ui/command";
import { useAuth } from "@/auth/AuthProvider";
import { useTheme } from "@/lib/theme";
import { setLanguage } from "@/lib/i18n";
import { NAV, UTILITY, BUILT_PHASE, visibleTo } from "./nav";

/**
 * Ctrl/⌘+K: jump to any page, switch theme or language, sign out. Matches on
 * the label in both languages and on extra keywords, so "court fee",
 * "adjourn" or "நாட்குறிப்பு" all land somewhere sensible. Case search joins
 * this in Phase 2.
 */
export function CommandPalette({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const { t, i18n } = useTranslation();
  const navigate = useNavigate();
  const { role, signOut } = useAuth();
  const { setChoice } = useTheme();
  const en = i18n.getFixedT("en");
  const ta = i18n.getFixedT("ta");

  const run = (fn: () => void) => {
    onOpenChange(false);
    fn();
  };

  return (
    <CommandDialog open={open} onOpenChange={onOpenChange}>
      <CommandInput placeholder={t("shell.command_placeholder")} />
      <CommandList>
        <CommandEmpty>{t("shell.no_results")}</CommandEmpty>
        {[...NAV, { id: "utility", label: "shell.preferences", items: UTILITY }].map((group) => {
          const items = group.items.filter(visibleTo(role));
          if (!items.length) return null;
          return (
            <CommandGroup key={group.id} heading={t(group.label)}>
              {items.map((item) => (
                <CommandItem
                  key={item.id}
                  value={[en(item.label), ta(item.label), ...(item.keywords ?? [])].join(" ")}
                  onSelect={() => run(() => navigate(item.path))}
                >
                  <item.icon className="mr-2 h-4 w-4 text-muted-foreground" />
                  {t(item.label)}
                  {item.phase > BUILT_PHASE ? (
                    <CommandShortcut className="normal-case tracking-normal">{t("soon.phase", { n: item.phase })}</CommandShortcut>
                  ) : null}
                </CommandItem>
              ))}
            </CommandGroup>
          );
        })}
        <CommandSeparator />
        <CommandGroup heading={t("shell.preferences")}>
          <CommandItem value="theme light ஒளி" onSelect={() => run(() => setChoice("light"))}>
            <Sun className="mr-2 h-4 w-4 text-muted-foreground" /> {t("shell.theme_light")}
          </CommandItem>
          <CommandItem value="theme dark இருள்" onSelect={() => run(() => setChoice("dark"))}>
            <Moon className="mr-2 h-4 w-4 text-muted-foreground" /> {t("shell.theme_dark")}
          </CommandItem>
          <CommandItem value="theme system" onSelect={() => run(() => setChoice("system"))}>
            <Monitor className="mr-2 h-4 w-4 text-muted-foreground" /> {t("shell.theme_system")}
          </CommandItem>
          <CommandItem value="language english" onSelect={() => run(() => setLanguage("en"))}>
            <Languages className="mr-2 h-4 w-4 text-muted-foreground" /> English
          </CommandItem>
          <CommandItem value="language tamil தமிழ்" onSelect={() => run(() => setLanguage("ta"))}>
            <Languages className="mr-2 h-4 w-4 text-muted-foreground" /> தமிழ்
          </CommandItem>
          <CommandItem value="sign out logout வெளியேறு" onSelect={() => run(() => void signOut())}>
            <LogOut className="mr-2 h-4 w-4 text-muted-foreground" /> {t("sign_out")}
          </CommandItem>
        </CommandGroup>
      </CommandList>
    </CommandDialog>
  );
}
