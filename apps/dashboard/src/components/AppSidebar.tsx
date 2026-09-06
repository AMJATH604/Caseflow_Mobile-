import { Scale, LayoutDashboard, Users, Briefcase, FileText, Gavel, CreditCard, LogOut, Wrench, BookOpen, FileStack, Receipt, Sparkles } from "lucide-react";
import { NavLink } from "@/components/NavLink";
import { useAuth } from "@/hooks/useAuth";
import {
  Sidebar, SidebarContent, SidebarGroup, SidebarGroupContent, SidebarGroupLabel,
  SidebarMenu, SidebarMenuButton, SidebarMenuItem, SidebarFooter, SidebarHeader,
} from "@/components/ui/sidebar";

const navGroups = [
  {
    label: "Practice Hub",
    items: [
      { title: "Dashboard", url: "/", icon: LayoutDashboard },
      { title: "AI Assistant", url: "/ai-chat", icon: Sparkles },
      { title: "Clients", url: "/clients", icon: Users },
      { title: "Advocates", url: "/advocates", icon: Users },
    ],
  },
  {
    label: "Management",
    items: [
      { title: "Cases", url: "/cases", icon: Briefcase },
      { title: "Court Diary", url: "/hearings", icon: BookOpen },
      { title: "E-Filing", url: "/efiling", icon: FileText },
      { title: "Certified Copies", url: "/certified-copies", icon: FileStack },
      { title: "Payments", url: "/payments", icon: CreditCard },
    ],
  },
  {
    label: "Statutory Library",
    items: [
      { title: "Bare Acts", url: "/bare-acts", icon: BookOpen },
      { title: "Stamp Values", url: "/stamp-values", icon: Receipt },
      { title: "Legal Templates", url: "/legal-templates", icon: FileText },
    ],
  },
  {
    label: "System & Tools",
    items: [
      { title: "Utilities & Calculators", url: "/tools", icon: Wrench },
    ],
  },
];

export function AppSidebar() {
  const { signOut } = useAuth();

  return (
    <Sidebar className="border-r border-sidebar-border bg-sidebar-background">
      <SidebarHeader className="p-5 border-b border-sidebar-border/50">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-sidebar-primary/10 border border-sidebar-primary/20 flex items-center justify-center shadow-inner">
            <Scale className="h-5 w-5 text-sidebar-primary" />
          </div>
          <div>
            <h2 className="text-sm font-bold tracking-tight text-white font-sans">CaseFlow Admin</h2>
            <p className="text-[10px] uppercase font-bold tracking-wider text-sidebar-primary">System Control</p>
          </div>
        </div>
      </SidebarHeader>
      <SidebarContent className="py-4 px-2 space-y-4">
        {navGroups.map((group) => (
          <SidebarGroup key={group.label} className="p-0">
            <SidebarGroupLabel className="text-sidebar-foreground/40 text-[10px] font-extrabold uppercase tracking-wider px-3 mb-1">{group.label}</SidebarGroupLabel>
            <SidebarGroupContent>
              <SidebarMenu>
                {group.items.map((item) => (
                  <SidebarMenuItem key={item.title}>
                    <SidebarMenuButton asChild>
                      <NavLink 
                        to={item.url} 
                        end={item.url === "/"} 
                        className="flex items-center gap-3 px-3 py-2 rounded-lg text-sidebar-foreground/75 hover:bg-sidebar-accent hover:text-white transition-all duration-200 text-xs" 
                        activeClassName="bg-sidebar-accent text-white font-semibold border-l-2 border-sidebar-primary"
                      >
                        <item.icon className="h-4 w-4 text-sidebar-primary" />
                        <span>{item.title}</span>
                      </NavLink>
                    </SidebarMenuButton>
                  </SidebarMenuItem>
                ))}
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
        ))}
      </SidebarContent>
      <SidebarFooter className="p-4 border-t border-sidebar-border/50">
        <button onClick={signOut} className="flex items-center gap-3 px-3 py-2.5 w-full rounded-lg text-sidebar-foreground/50 hover:bg-red-500/10 hover:text-red-400 transition-all duration-200 text-xs font-semibold">
          <LogOut className="h-4 w-4" />
          <span>Sign Out</span>
        </button>
      </SidebarFooter>
    </Sidebar>
  );
}
