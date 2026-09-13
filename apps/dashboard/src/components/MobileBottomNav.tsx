import { useState } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { LayoutDashboard, Users, BookOpen, MoreHorizontal } from "lucide-react";
import { cn } from "@/lib/utils";
import { MobileMoreSheet } from "./MobileMoreSheet";

export function MobileBottomNav() {
    const navigate = useNavigate();
    const location = useLocation();
    const [moreOpen, setMoreOpen] = useState(false);

    // Operator console destinations. The advocate tools this used to point at
    // (Cases, Hearings, Tools) were removed from the console entirely.
    const navItems = [
        { title: "Overview", url: "/", icon: LayoutDashboard },
        { title: "Users", url: "/advocates", icon: Users },
        { title: "Library", url: "/bare-acts", icon: BookOpen },
    ];

    const isActive = (url: string) => {
        if (url === "/") return location.pathname === "/";
        return location.pathname.startsWith(url);
    };

    // Check if "More" pages are active
    const morePages = ["/stamp-values", "/legal-templates"];
    const isMoreActive = morePages.some(p => location.pathname.startsWith(p));

    return (
        <>
            <div className="md:hidden fixed bottom-0 left-0 right-0 z-50 safe-area-bottom">
                {/* Glass background */}
                <div className="bg-card/95 backdrop-blur-xl border-t border-border/30 shadow-[0_-4px_20px_rgba(0,0,0,0.08)]">
                    <div className="flex items-center justify-around h-16 max-w-md mx-auto px-2">
                        {navItems.map((item) => {
                            const active = isActive(item.url);
                            return (
                                <button
                                    key={item.title}
                                    onClick={() => navigate(item.url)}
                                    className={cn(
                                        "flex flex-col items-center justify-center gap-0.5 py-1 px-3 rounded-2xl transition-all duration-200 relative",
                                        active
                                            ? "text-primary"
                                            : "text-muted-foreground/70 active:scale-90"
                                    )}
                                >
                                    {active && (
                                        <div className="absolute -top-1 w-6 h-1 bg-primary rounded-full" />
                                    )}
                                    <div className={cn(
                                        "flex items-center justify-center w-8 h-8 rounded-xl transition-all duration-200",
                                        active && "bg-primary/10"
                                    )}>
                                        <item.icon className={cn("h-5 w-5", active && "stroke-[2.5]")} />
                                    </div>
                                    <span className={cn(
                                        "text-[10px] font-medium leading-none",
                                        active && "font-bold"
                                    )}>
                                        {item.title}
                                    </span>
                                </button>
                            );
                        })}

                        {/* More tab */}
                        <button
                            onClick={() => setMoreOpen(true)}
                            className={cn(
                                "flex flex-col items-center justify-center gap-0.5 py-1 px-3 rounded-2xl transition-all duration-200 relative",
                                isMoreActive
                                    ? "text-primary"
                                    : "text-muted-foreground/70 active:scale-90"
                            )}
                        >
                            {isMoreActive && (
                                <div className="absolute -top-1 w-6 h-1 bg-primary rounded-full" />
                            )}
                            <div className={cn(
                                "flex items-center justify-center w-8 h-8 rounded-xl transition-all duration-200",
                                isMoreActive && "bg-primary/10"
                            )}>
                                <MoreHorizontal className={cn("h-5 w-5", isMoreActive && "stroke-[2.5]")} />
                            </div>
                            <span className={cn(
                                "text-[10px] font-medium leading-none",
                                isMoreActive && "font-bold"
                            )}>
                                More
                            </span>
                        </button>
                    </div>
                </div>
            </div>

            <MobileMoreSheet open={moreOpen} onClose={() => setMoreOpen(false)} />
        </>
    );
}
