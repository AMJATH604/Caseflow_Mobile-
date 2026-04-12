import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/integrations/supabase/client";
import { Briefcase, Gavel, FileText, CreditCard, Clock, Bell } from "lucide-react";
import { format, formatDistanceToNow, parseISO } from "date-fns";
import { cn } from "@/lib/utils";

interface ActivityItem {
    id: string;
    type: "case" | "hearing" | "filing" | "payment";
    title: string;
    description: string;
    timestamp: string;
}

const typeConfig = {
    case: { icon: Briefcase, color: "bg-blue-500", label: "Case" },
    hearing: { icon: Gavel, color: "bg-amber-500", label: "Hearing" },
    filing: { icon: FileText, color: "bg-emerald-500", label: "E-Filing" },
    payment: { icon: CreditCard, color: "bg-purple-500", label: "Payment" },
};

export default function Notifications() {
    const [activities, setActivities] = useState<ActivityItem[]>([]);
    const [loading, setLoading] = useState(true);

    const loadActivities = useCallback(async () => {
        try {
            const [casesRes, hearingsRes, efilingRes, paymentsRes] = await Promise.all([
                supabase.from("cases").select("id, case_title, status, created_at").order("created_at", { ascending: false }).limit(10),
                supabase.from("hearings").select("id, purpose, status, hearing_date, cases(case_title)").order("created_at", { ascending: false }).limit(10),
                supabase.from("efiling_records").select("id, status, efiling_number, created_at").order("created_at", { ascending: false }).limit(10),
                supabase.from("payments").select("id, amount, payment_type, created_at").order("created_at", { ascending: false }).limit(10),
            ]);

            const items: ActivityItem[] = [];

            (casesRes.data || []).forEach((c: any) => {
                items.push({
                    id: `case-${c.id}`,
                    type: "case",
                    title: c.case_title,
                    description: `Status: ${c.status}`,
                    timestamp: c.created_at,
                });
            });

            (hearingsRes.data || []).forEach((h: any) => {
                items.push({
                    id: `hearing-${h.id}`,
                    type: "hearing",
                    title: (h.cases as any)?.case_title || "Hearing",
                    description: `${h.purpose || "Hearing"} · ${h.status}`,
                    timestamp: h.hearing_date,
                });
            });

            (efilingRes.data || []).forEach((e: any) => {
                items.push({
                    id: `filing-${e.id}`,
                    type: "filing",
                    title: e.efiling_number || "E-Filing",
                    description: `Status: ${e.status}`,
                    timestamp: e.created_at,
                });
            });

            (paymentsRes.data || []).forEach((p: any) => {
                items.push({
                    id: `payment-${p.id}`,
                    type: "payment",
                    title: `₹${p.amount?.toLocaleString() || 0}`,
                    description: p.payment_type || "Payment",
                    timestamp: p.created_at,
                });
            });

            // Sort by timestamp descending
            items.sort((a, b) => {
                if (!a.timestamp || !b.timestamp) return 0;
                return new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime();
            });
            setActivities(items);
        } catch (err) {
            console.error("Error loading activities:", err);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        loadActivities();
    }, [loadActivities]);

    if (loading) {
        return <div className="flex items-center justify-center h-64 text-muted-foreground text-sm">Loading updates...</div>;
    }

    // Group by date
    const grouped = activities.reduce((acc: Record<string, ActivityItem[]>, item) => {
        if (!item.timestamp) return acc;
        const dateKey = format(parseISO(item.timestamp), "yyyy-MM-dd");
        if (!acc[dateKey]) acc[dateKey] = [];
        acc[dateKey].push(item);
        return acc;
    }, {});

    return (
        <div className="space-y-6 max-w-2xl mx-auto">
            <div className="hidden md:block">
                <h1 className="text-2xl font-serif font-bold text-foreground">Updates</h1>
                <p className="text-sm text-muted-foreground mt-1">Recent activity across your practice</p>
            </div>

            {activities.length === 0 ? (
                <div className="mobile-card text-center py-12">
                    <Bell className="h-10 w-10 text-muted-foreground/20 mx-auto mb-3" />
                    <p className="text-sm text-muted-foreground">No recent activity</p>
                </div>
            ) : (
                Object.entries(grouped).map(([dateKey, items]) => (
                    <div key={dateKey} className="space-y-2">
                        {/* Date Header */}
                        <div className="flex items-center gap-3 px-1">
                            <span className="text-xs font-bold text-muted-foreground uppercase tracking-wider">
                                {format(parseISO(dateKey), "dd MMM yyyy")}
                            </span>
                            <div className="flex-1 h-px bg-border/40" />
                        </div>

                        {/* Activity Items */}
                        <div className="space-y-2">
                            {items.map((item) => {
                                const config = typeConfig[item.type];
                                const Icon = config.icon;
                                return (
                                    <div key={item.id} className="mobile-card flex items-center gap-3">
                                        <div className={cn("w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0", config.color)}>
                                            <Icon className="h-4 w-4 text-white" />
                                        </div>
                                        <div className="flex-1 min-w-0">
                                            <h3 className="text-sm font-bold truncate">{item.title}</h3>
                                            <p className="text-xs text-muted-foreground truncate">{item.description}</p>
                                        </div>
                                        <div className="flex-shrink-0 text-right">
                                            <span className="text-[10px] text-muted-foreground/70 font-medium">
                                                {item.timestamp ? formatDistanceToNow(parseISO(item.timestamp), { addSuffix: true }) : ""}
                                            </span>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                ))
            )}
        </div>
    );
}
