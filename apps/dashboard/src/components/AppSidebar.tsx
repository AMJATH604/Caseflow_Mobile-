import { Scale, LayoutDashboard, Users, Briefcase, FileText, Gavel, CreditCard, LogOut, Wrench, BookOpen, FileStack, Receipt, Sparkles } from "lucide-react";
import { NavLink } from "@/components/NavLink";
import { useAuth } from "@/hooks/useAuth";
import {
  Sidebar, SidebarContent, SidebarGroup, SidebarGroupContent, SidebarGroupLabel,
  SidebarMenu, SidebarMenuButton, SidebarMenuItem, SidebarFooter, SidebarHeader,
} from "@/components/ui/sidebar";

const navItems = [
  { title: "Dashboard", url: "/", icon: LayoutDashboard },
  { title: "AI Assistant", url: "/ai-chat", icon: Sparkles },
  { title: "Clients", url: "/clients", icon: Users },
  { title: "Cases", url: "/cases", icon: Briefcase },
  { title: "E-Filing", url: "/efiling", icon: FileText },
  { title: "Court Diary", url: "/hearings", icon: BookOpen },
  { title: "Certified Copies", url: "/certified-copies", icon: FileStack },
  { title: "Payments", url: "/payments", icon: CreditCard },
  { title: "Bare Acts", url: "/bare-acts", icon: BookOpen },
  { title: "Stamp Values", url: "/stamp-values", icon: Receipt },
  { title: "Legal Templates", url: "/legal-templates", icon: FileText },
  { title: "Advocate Directory", url: "/advocates", icon: Users },
  { title: "Tools", url: "/tools", icon: Wrench },
];

export function AppSidebar() {
  const { signOut } = useAuth();

  return (
    <Sidebar>
      <SidebarHeader className="p-4 border-b border-sidebar-border">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-lg bg-sidebar-primary flex items-center justify-center">
            <Scale className="h-5 w-5 text-sidebar-primary-foreground" />
          </div>
          <div>
            <h2 className="text-sm font-semibold text-sidebar-foreground">AI Advocate</h2>
            <p className="text-xs text-sidebar-foreground/60">E-Filing Dashboard</p>
          </div>
        </div>
      </SidebarHeader>
      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel className="text-sidebar-foreground/50 text-xs uppercase tracking-wider">Navigation</SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              {navItems.map((item) => (
                <SidebarMenuItem key={item.title}>
                  <SidebarMenuButton asChild>
                    <NavLink to={item.url} end={item.url === "/"} className="flex items-center gap-3 px-3 py-2 rounded-md text-sidebar-foreground/80 hover:bg-sidebar-accent hover:text-sidebar-accent-foreground transition-colors" activeClassName="bg-sidebar-accent text-sidebar-primary font-medium">
                      <item.icon className="h-4 w-4" />
                      <span>{item.title}</span>
                    </NavLink>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              ))}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>
      <SidebarFooter className="p-3 border-t border-sidebar-border">
        <button onClick={signOut} className="flex items-center gap-3 px-3 py-2 w-full rounded-md text-sidebar-foreground/60 hover:bg-sidebar-accent hover:text-destructive transition-colors text-sm">
          <LogOut className="h-4 w-4" />
          <span>Sign Out</span>
        </button>
      </SidebarFooter>
    </Sidebar>
  );
}
