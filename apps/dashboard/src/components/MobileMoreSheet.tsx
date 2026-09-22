import { useNavigate } from "react-router-dom";
import { Receipt, FileText, LogOut, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { supabase } from "@/integrations/supabase/client";

interface MobileMoreSheetProps {
    open: boolean;
    onClose: () => void;
}

// Secondary console destinations. The advocate tools previously listed here
// (Clients, E-Filing, Certified Copies, Payments, Notifications) were removed
// from the operator console.
const menuItems = [
    { title: "Stamp Values", url: "/stamp-values", icon: Receipt, color: "bg-amber-500", desc: "Reference data" },
    { title: "Legal Templates", url: "/legal-templates", icon: FileText, color: "bg-emerald-500", desc: "Template library" },
];

export function MobileMoreSheet({ open, onClose }: MobileMoreSheetProps) {
    const navigate = useNavigate();

    if (!open) return null;

    const handleNavigate = (url: string) => {
        navigate(url);
        onClose();
    };

    const handleLogout = async () => {
        await supabase.auth.signOut();
        onClose();
    };

    return (
        <>
            {/* Overlay */}
            <div className="sheet-overlay md:hidden" onClick={onClose} />

            {/* Sheet */}
            <div className="sheet-content md:hidden">
                <div className="sheet-handle" />

                {/* Header */}
                <div className="flex items-center justify-between px-6 pb-4">
                    <h2 className="text-lg font-bold text-foreground">More</h2>
                    <button
                        onClick={onClose}
                        className="w-8 h-8 rounded-full bg-muted/60 flex items-center justify-center"
                    >
                        <X className="h-4 w-4 text-muted-foreground" />
                    </button>
                </div>

                {/* Menu Grid */}
                <div className="grid grid-cols-3 gap-3 px-6 pb-6">
                    {menuItems.map((item) => (
                        <button
                            key={item.title}
                            onClick={() => handleNavigate(item.url)}
                            className="flex flex-col items-center gap-2 p-4 rounded-2xl bg-muted/30 hover:bg-muted/50 active:scale-95 transition-all duration-150"
                        >
                            <div className={cn("w-12 h-12 rounded-2xl flex items-center justify-center shadow-sm", item.color)}>
                                <item.icon className="h-5 w-5 text-white" />
                            </div>
                            <span className="text-xs font-semibold text-foreground leading-tight text-center">{item.title}</span>
                        </button>
                    ))}
                </div>

                {/* Divider */}
                <div className="h-px bg-border/40 mx-6" />

                {/* Bottom Actions */}
                <div className="px-6 py-4 space-y-1">
                    <button
                        onClick={handleLogout}
                        className="flex items-center gap-3 w-full p-3 rounded-xl hover:bg-destructive/10 active:scale-[0.98] transition-all text-destructive"
                    >
                        <LogOut className="h-5 w-5" />
                        <span className="text-sm font-semibold">Sign Out</span>
                    </button>
                </div>
            </div>
        </>
    );
}
