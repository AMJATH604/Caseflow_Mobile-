import {
  Bell,
  BookUser,
  Briefcase,
  Building2,
  Calculator,
  CalendarDays,
  ClipboardList,
  Download,
  FileStack,
  FileText,
  FlaskConical,
  Gavel,
  Handshake,
  Landmark,
  LayoutDashboard,
  Mail,
  MessageCircle,
  MessagesSquare,
  Newspaper,
  Scale,
  ScanSearch,
  Settings,
  ShieldAlert,
  Sparkles,
  Users,
  Wallet,
  type LucideIcon,
} from "lucide-react";
import type { FirmRole } from "@/auth/AuthProvider";

/**
 * Every destination in the web app, in one list. The sidebar, the command
 * palette and the router all read it, and PARITY.md maps each entry back to
 * the Flutter screen it reproduces — so a mobile feature cannot be quietly
 * left out: it is either here, or listed there as deliberately excluded.
 *
 * `phase` is when the screen is built (see PARITY.md). Until then the route
 * shows a "coming in phase N" page rather than not existing, so the shape of
 * the whole product is visible from day one.
 */
export interface NavItem {
  id: string;
  /** i18n key */
  label: string;
  path: string;
  icon: LucideIcon;
  phase: number;
  /** The Flutter route(s) this replaces — for the parity checklist. */
  mobile: string[];
  /** Who sees it. Omitted = everyone. */
  roles?: FirmRole[];
  /** Extra words the command palette matches on. */
  keywords?: string[];
}

export interface NavGroup {
  id: string;
  label: string;
  items: NavItem[];
}

export const NAV: NavGroup[] = [
  {
    id: "practice",
    label: "nav.group_practice",
    items: [
      { id: "dashboard", label: "nav_dashboard", path: "/", icon: LayoutDashboard, phase: 2, mobile: ["/"], keywords: ["home", "today"] },
      { id: "diary", label: "nav.court_diary", path: "/diary", icon: CalendarDays, phase: 2, mobile: ["/ (Court Diary section)"], keywords: ["calendar", "board", "today"] },
      { id: "cases", label: "nav_cases", path: "/cases", icon: Briefcase, phase: 2, mobile: ["/cases", "/cases/:id"], keywords: ["legal repository", "dossier", "suit"] },
      { id: "hearings", label: "nav_hearings", path: "/hearings", icon: Gavel, phase: 2, mobile: ["/hearings"], keywords: ["adjourn", "schedule", "vaaitha"] },
      { id: "clients", label: "clients", path: "/clients", icon: Users, phase: 2, mobile: ["/clients"], keywords: ["directory", "party"] },
    ],
  },
  {
    id: "office",
    label: "nav.group_office",
    items: [
      { id: "import", label: "nav.import_export", path: "/import", icon: Download, phase: 3, mobile: ["/tools (Import / Export)"], keywords: ["ecourts", "export", "backup", "cnr"] },
      { id: "payments", label: "payments", path: "/payments", icon: Wallet, phase: 3, mobile: ["/payments"], roles: ["advocate", "junior"], keywords: ["fees", "ledger", "expense"] },
      { id: "caveats", label: "nav.caveats", path: "/caveats", icon: ShieldAlert, phase: 3, mobile: ["/caveats"] },
      { id: "certified", label: "nav.certified_copies", path: "/certified-copies", icon: FileStack, phase: 3, mobile: ["/certified-copies"], keywords: ["c.a", "copy application"] },
      { id: "portals", label: "nav.portals", path: "/portals", icon: Landmark, phase: 3, mobile: ["/portals"], keywords: ["ecourts", "epay", "efiling"] },
    ],
  },
  {
    id: "toolkit",
    label: "nav.group_toolkit",
    items: [
      { id: "tools", label: "nav.legal_tools", path: "/tools", icon: Calculator, phase: 4, mobile: ["/tools (Legal Tools)"], keywords: ["court fee", "limitation", "partition", "stamp", "mact", "interest", "maintenance", "bare acts", "dictionary"] },
      { id: "documents", label: "nav.document_tools", path: "/documents", icon: FileText, phase: 6, mobile: ["/tools (Document Tools, Convert & OCR)"], keywords: ["pdf", "merge", "split", "ocr", "efiling"] },
      { id: "ai", label: "nav.ai", path: "/ai", icon: Sparkles, phase: 6, mobile: ["/ai-chat"], keywords: ["assistant", "chat"] },
      { id: "pulse", label: "nav.legal_pulse", path: "/legal-pulse", icon: Newspaper, phase: 6, mobile: ["/legal-pulse"], keywords: ["news", "judgments"] },
      { id: "cross", label: "nav.cross_exam", path: "/cross-exam", icon: ScanSearch, phase: 5, mobile: ["/cross-exam"], keywords: ["witness", "questions"] },
      { id: "evidence", label: "nav.evidence", path: "/evidence", icon: FlaskConical, phase: 5, mobile: ["evidence_lab_screen"], keywords: ["exhibits", "witness notes"] },
      { id: "commissions", label: "nav.commissions", path: "/commissions", icon: ClipboardList, phase: 5, mobile: ["/commissions", "/commissions/:id"], keywords: ["advocate commissioner", "field visit", "sketch"] },
    ],
  },
  {
    id: "team",
    label: "nav.group_team",
    items: [
      { id: "firm", label: "nav.firm", path: "/firm", icon: Building2, phase: 5, mobile: ["/firm"], roles: ["advocate"], keywords: ["juniors", "clerks", "team"] },
      { id: "chambers", label: "nav.chambers", path: "/chambers", icon: MessageCircle, phase: 5, mobile: ["/chambers-chat"], keywords: ["chat", "discussion"] },
      { id: "messages", label: "nav.messages", path: "/messages", icon: MessagesSquare, phase: 5, mobile: ["/chat-hub", "/dm/:conversationId"], keywords: ["dm", "direct"] },
      { id: "invitations", label: "invitations", path: "/invitations", icon: Mail, phase: 5, mobile: ["/collaborator-invitations"] },
      { id: "directory", label: "nav.directory", path: "/directory", icon: BookUser, phase: 5, mobile: ["/advocate-directory"] },
      { id: "recruit", label: "nav.recruit", path: "/recruit", icon: Handshake, phase: 5, mobile: ["/tools (Recruit Associate)"], roles: ["advocate"] },
    ],
  },
  {
    id: "bar",
    label: "nav.group_bar",
    items: [
      { id: "bar", label: "nav.my_bar", path: "/bar", icon: Scale, phase: 6, mobile: ["/bar-association", "/bar-notices", "/bar-fees", "/bar-membership", "/bar-events"] },
    ],
  },
];

/** Not in the sidebar's groups: reached from the top bar / user menu. */
export const UTILITY: NavItem[] = [
  { id: "notifications", label: "nav.notifications", path: "/notifications", icon: Bell, phase: 3, mobile: ["/notifications"] },
  { id: "settings", label: "settings_title", path: "/settings", icon: Settings, phase: 6, mobile: ["/settings", "/upgrade"], keywords: ["language", "theme", "plan", "subscription"] },
];

export const ALL_ITEMS: NavItem[] = [...NAV.flatMap((g) => g.items), ...UTILITY];

export const visibleTo = (role: FirmRole | null) => (item: NavItem) => !item.roles || (role !== null && item.roles.includes(role));

/** The phase this build has reached. Bump as phases land. */
export const BUILT_PHASE = 1;
