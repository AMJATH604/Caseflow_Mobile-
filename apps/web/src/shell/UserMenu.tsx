import { useNavigate } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { ChevronsUpDown, Keyboard, LogOut, Monitor, Moon, Settings, Sun } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useAuth } from "@/auth/AuthProvider";
import { useTheme, type ThemeChoice } from "@/lib/theme";
import { cn } from "@/lib/utils";
import { LanguageToggle } from "./LanguageToggle";

export const initials = (name?: string | null) =>
  (name ?? "?")
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]!.toUpperCase())
    .join("");

export function UserMenu({ collapsed, onShowShortcuts }: { collapsed: boolean; onShowShortcuts: () => void }) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { profile, role, user, signOut } = useAuth();
  const { choice, setChoice } = useTheme();

  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        className={cn(
          "flex w-full items-center gap-2.5 rounded-lg p-2 text-left transition-colors hover:bg-sidebar-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sidebar-ring",
          collapsed && "justify-center",
        )}
      >
        <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-primary/10 text-xs font-semibold text-primary">
          {initials(profile?.full_name)}
        </span>
        {collapsed ? null : (
          <>
            <span className="min-w-0 flex-1">
              <span className="block truncate text-sm font-medium text-sidebar-accent-foreground">{profile?.full_name ?? "—"}</span>
              <span className="block truncate text-xs text-sidebar-foreground">{role ? t(`shell.role_${role}`) : ""}</span>
            </span>
            <ChevronsUpDown className="h-4 w-4 shrink-0 text-sidebar-foreground" />
          </>
        )}
      </DropdownMenuTrigger>
      <DropdownMenuContent side="top" align="start" className="w-64">
        <DropdownMenuLabel className="font-normal">
          <div className="text-xs text-muted-foreground">{t("shell.signed_in_as")}</div>
          <div className="truncate text-sm font-medium">{user?.email}</div>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <div className="flex items-center justify-between px-2 py-1.5">
          <span className="text-sm">{t("language")}</span>
          <LanguageToggle />
        </div>
        <DropdownMenuSeparator />
        <DropdownMenuLabel className="text-xs font-medium text-muted-foreground">{t("section_appearance")}</DropdownMenuLabel>
        <DropdownMenuRadioGroup value={choice} onValueChange={(v) => setChoice(v as ThemeChoice)}>
          <DropdownMenuRadioItem value="light">
            <Sun className="mr-2 h-4 w-4" /> {t("shell.theme_light")}
          </DropdownMenuRadioItem>
          <DropdownMenuRadioItem value="dark">
            <Moon className="mr-2 h-4 w-4" /> {t("shell.theme_dark")}
          </DropdownMenuRadioItem>
          <DropdownMenuRadioItem value="system">
            <Monitor className="mr-2 h-4 w-4" /> {t("shell.theme_system")}
          </DropdownMenuRadioItem>
        </DropdownMenuRadioGroup>
        <DropdownMenuSeparator />
        <DropdownMenuItem onSelect={() => navigate("/settings")}>
          <Settings className="mr-2 h-4 w-4" /> {t("settings_title")}
        </DropdownMenuItem>
        <DropdownMenuItem onSelect={onShowShortcuts}>
          <Keyboard className="mr-2 h-4 w-4" /> {t("shell.keyboard")}
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem onSelect={() => void signOut()} className="text-destructive focus:text-destructive">
          <LogOut className="mr-2 h-4 w-4" /> {t("sign_out")}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
