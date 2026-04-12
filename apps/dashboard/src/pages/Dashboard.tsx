import { useEffect, useState, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { Briefcase, Gavel, FileText, AlertTriangle, CreditCard, Users, ChevronRight, Clock, CalendarDays, TrendingUp, ArrowRight } from "lucide-react";
import { fetchDashboardStats } from "@/lib/supabase-helpers";
import { TaskWidget } from "@/components/TaskWidget";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { StatusBadge } from "@/components/StatusBadge";
import { supabase } from "@/integrations/supabase/client";
import { format, isWithinInterval, addDays, isToday, parseISO } from "date-fns";
import { cn } from "@/lib/utils";

const PASTEL_COLORS = {
  mint: "bg-[#E6F4F1] text-[#2D5A53]",
  teal: "bg-[#CCEDE5] text-[#1E4D44]",
  green: "bg-[#B3E6D9] text-[#144037]",
  emerald: "bg-[#80D9C2] text-[#0C332B]",
  strongEmerald: "bg-[#4DCAAB] text-[#082620]",
  lavender: "bg-[#EBEBFF] text-[#4A4A8F]",
  cream: "bg-[#FFF9E6] text-[#8F7500]",
  rose: "bg-[#FFE6E6] text-[#8F4A4A]",
};

export default function Dashboard() {
  const [stats, setStats] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [userName, setUserName] = useState("");
  const navigate = useNavigate();

  const loadStats = useCallback(async () => {
    try {
      setError(null);
      const data = await fetchDashboardStats();
      setStats(data);
    } catch (err: any) {
      console.error(err);
      setError(err?.message || "Failed to load dashboard data");
      // Still show dashboard with empty data instead of hanging
      setStats({
        activeCases: [], closedCases: [], upcomingHearings: [],
        efilingRecords: [], payments: [],
      });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadStats();
    supabase.auth.getUser().then(({ data }) => {
      setUserName(data?.user?.email?.split("@")[0] || "Advocate");
    });

    // Safety timeout: show dashboard with empty data if fetch hangs
    const timer = setTimeout(() => {
      setLoading((prev) => {
        if (prev) {
          setStats({
            activeCases: [], closedCases: [], upcomingHearings: [],
            efilingRecords: [], payments: [],
          });
          setError("Connection slow. Showing cached data.");
        }
        return false;
      });
    }, 8000);

    const channel = supabase
      .channel("dashboard-realtime")
      .on("postgres_changes", { event: "*", schema: "public", table: "cases" }, () => loadStats())
      .on("postgres_changes", { event: "*", schema: "public", table: "hearings" }, () => loadStats())
      .on("postgres_changes", { event: "*", schema: "public", table: "efiling_records" }, () => loadStats())
      .on("postgres_changes", { event: "*", schema: "public", table: "payments" }, () => loadStats())
      .on("postgres_changes", { event: "*", schema: "public", table: "clients" }, () => loadStats())
      .on("postgres_changes", { event: "*", schema: "public", table: "documents" }, () => loadStats())
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
      clearTimeout(timer);
    };
  }, [loadStats]);

  if (loading) return (
    <div className="space-y-6 max-w-5xl mx-auto animate-pulse">
      <div className="h-8 bg-muted rounded-lg w-48" />
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[1, 2, 3, 4].map(i => (
          <div key={i} className="h-20 bg-muted rounded-2xl" />
        ))}
      </div>
      <div className="h-32 bg-muted rounded-2xl" />
      <div className="h-40 bg-muted rounded-2xl" />
      <p className="text-center text-sm text-muted-foreground">Loading dashboard...</p>
    </div>
  );

  const hearingsThisWeek = (stats?.upcomingHearings || []).filter((h: any) =>
    h.hearing_date && isWithinInterval(new Date(h.hearing_date), { start: new Date(), end: addDays(new Date(), 7) })
  );
  const todaysHearings = (stats?.upcomingHearings || []).filter((h: any) => h.hearing_date && isToday(parseISO(h.hearing_date)));
  const pendingFilings = (stats?.efilingRecords || []).filter((e: any) => !["filed", "accepted"].includes(e.status));
  const defectFilings = (stats?.efilingRecords || []).filter((e: any) => e.status === "defect");
  const pendingPayments = (stats?.payments || []).filter((p: any) => p.balance_amount > 0);

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      {/* Error banner */}
      {error && (
        <div className="flex items-center justify-between bg-amber-50 border border-amber-200 text-amber-800 px-4 py-3 rounded-xl text-sm">
          <span>{error}</span>
          <button onClick={loadStats} className="font-bold text-amber-900 underline ml-2">Retry</button>
        </div>
      )}
      {/* ═══ MOBILE DASHBOARD ═══ */}
      <div className="md:hidden space-y-6">
        {/* Greeting */}
        <div className="space-y-1">
          <h1 className="text-xl font-bold text-foreground">
            Hello, {userName} 👋
          </h1>
          <p className="text-sm text-muted-foreground">
            {format(new Date(), "EEEE, dd MMMM yyyy")}
          </p>
        </div>

        {/* Stats Chip Row — Horizontally scrollable */}
        <div className="flex gap-3 overflow-x-auto pb-2 -mx-4 px-4 scrollbar-hide">
          <StatChip label="Active" value={stats?.activeCases?.length || 0} color="bg-blue-50 text-blue-700 border-blue-100" />
          <StatChip label="Hearings" value={hearingsThisWeek.length} color="bg-emerald-50 text-emerald-700 border-emerald-100" />
          <StatChip label="Filings" value={pendingFilings.length} color="bg-amber-50 text-amber-700 border-amber-100" />
          <StatChip label="Clients" value={stats?.clients?.length || 0} color="bg-purple-50 text-purple-700 border-purple-100" />
          {defectFilings.length > 0 && (
            <StatChip label="Defects" value={defectFilings.length} color="bg-red-50 text-red-700 border-red-100" />
          )}
        </div>

        {/* Quick Actions Grid */}
        <div className="grid grid-cols-4 gap-3">
          <QuickAction icon={Briefcase} label="Cases" color="bg-blue-500" onClick={() => navigate("/cases")} />
          <QuickAction icon={Users} label="Clients" color="bg-emerald-500" onClick={() => navigate("/clients")} />
          <QuickAction icon={Gavel} label="Hearings" color="bg-amber-500" onClick={() => navigate("/hearings")} />
          <QuickAction icon={CreditCard} label="Payments" color="bg-purple-500" onClick={() => navigate("/payments")} />
        </div>

        {/* Today's Hearings */}
        <section className="space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-bold text-foreground flex items-center gap-2">
              <CalendarDays className="h-4 w-4 text-primary" />
              Today's Hearings
            </h2>
            <button
              onClick={() => navigate("/hearings")}
              className="text-xs text-primary font-semibold flex items-center gap-1"
            >
              See All <ArrowRight className="h-3 w-3" />
            </button>
          </div>

          {todaysHearings.length === 0 ? (
            <div className="mobile-card text-center py-6">
              <p className="text-sm text-muted-foreground">No hearings scheduled today</p>
            </div>
          ) : (
            <div className="space-y-2">
              {todaysHearings.slice(0, 3).map((h: any) => (
                <div key={h.id} className="mobile-card mobile-card-accent accent-amber flex items-center gap-3 pl-5">
                  <div className="flex-1 min-w-0">
                    <h3 className="text-sm font-bold truncate">{(h.cases as any)?.case_title}</h3>
                    <p className="text-xs text-muted-foreground flex items-center gap-1 mt-0.5">
                      <Clock className="h-3 w-3" />
                      {h.purpose || "Hearing"}
                    </p>
                  </div>
                  <StatusBadge status={h.status} />
                </div>
              ))}
            </div>
          )}
        </section>

        {/* Pending Actions Cards */}
        <section className="space-y-3">
          <h2 className="text-base font-bold text-foreground flex items-center gap-2">
            <TrendingUp className="h-4 w-4 text-primary" />
            Pending Actions
          </h2>
          <div className="grid grid-cols-1 gap-3">
            <PendingCard
              title="Filing Pending"
              count={pendingFilings.length}
              icon={FileText}
              color={PASTEL_COLORS.cream}
              iconColor="text-[#8F7500]"
              onClick={() => navigate("/efiling")}
            />
            <PendingCard
              title="Payment Due"
              count={pendingPayments.length}
              icon={CreditCard}
              color={PASTEL_COLORS.lavender}
              iconColor="text-[#4A4A8F]"
              onClick={() => navigate("/payments")}
            />
            {defectFilings.length > 0 && (
              <PendingCard
                title="Defects"
                count={defectFilings.length}
                icon={AlertTriangle}
                color={PASTEL_COLORS.rose}
                iconColor="text-[#8F4A4A]"
                onClick={() => navigate("/efiling")}
              />
            )}
          </div>
        </section>

        {/* Tasks */}
        <TaskWidget />
      </div>

      {/* ═══ DESKTOP DASHBOARD (unchanged) ═══ */}
      <div className="hidden md:block space-y-8">
        <div>
          <h1 className="text-2xl font-serif font-bold text-foreground">Dashboard</h1>
          <p className="text-sm text-muted-foreground mt-1">Overview of your legal practice</p>
        </div>

        {/* Cases by Status */}
        <section className="space-y-4">
          <div className="flex items-center justify-between px-1">
            <h2 className="text-lg font-bold text-[#1A1A1A]">Cases by Status</h2>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
            <StatusCard title="Active" count={stats?.activeCases?.length || 0} color={PASTEL_COLORS.mint} />
            <StatusCard title="Hearing" count={hearingsThisWeek.length} color={PASTEL_COLORS.teal} />
            <StatusCard title="Filing" count={pendingFilings.length} color={PASTEL_COLORS.green} />
            <StatusCard title="Defects" count={defectFilings.length} color={PASTEL_COLORS.emerald} />
            <StatusCard title="Closed" count={stats?.closedCases?.length || 0} color={PASTEL_COLORS.strongEmerald} />
          </div>
        </section>

        {/* Pending Actions */}
        <section className="space-y-4">
          <h2 className="text-lg font-bold text-[#1A1A1A] px-1">Pending Actions</h2>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <DesktopPendingCard title="Hearing Pending" count={hearingsThisWeek.length} icon={Gavel} color={PASTEL_COLORS.lavender} iconColor="text-[#4A4A8F]" />
            <DesktopPendingCard title="Filing Pending" count={pendingFilings.length} icon={FileText} color={PASTEL_COLORS.cream} iconColor="text-[#8F7500]" />
            <DesktopPendingCard title="Payment Pending" count={pendingPayments.length} icon={CreditCard} color={PASTEL_COLORS.teal} iconColor="text-[#2D5A53]" />
          </div>
        </section>

        {/* Critical */}
        {defectFilings.length > 0 && (
          <section>
            <h2 className="text-lg font-bold text-[#1A1A1A] px-1 mb-4">Critical Attention</h2>
            <div className={cn("p-5 rounded-2xl flex items-center justify-between cursor-pointer active:scale-[0.98] transition-all", PASTEL_COLORS.rose)}>
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-xl bg-white/50 flex items-center justify-center">
                  <AlertTriangle className="h-6 w-6 text-[#8F4A4A]" />
                </div>
                <div>
                  <p className="text-2xl font-bold">{defectFilings.length}</p>
                  <p className="text-xs font-semibold opacity-80 uppercase tracking-tight">Defects in Next 30 Days</p>
                </div>
              </div>
              <ChevronRight className="h-5 w-5 opacity-40" />
            </div>
          </section>
        )}

        <div className="pt-4">
          <TaskWidget />
        </div>
      </div>
    </div>
  );
}

/* ═══ SUB-COMPONENTS ═══ */

function StatChip({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className={cn("flex items-center gap-2 px-4 py-2.5 rounded-full border whitespace-nowrap", color)}>
      <span className="text-lg font-bold leading-none">{value}</span>
      <span className="text-xs font-semibold opacity-80">{label}</span>
    </div>
  );
}

function QuickAction({ icon: Icon, label, color, onClick }: { icon: any; label: string; color: string; onClick: () => void }) {
  return (
    <button onClick={onClick} className="flex flex-col items-center gap-2 active:scale-90 transition-transform duration-150">
      <div className={cn("w-12 h-12 rounded-2xl flex items-center justify-center shadow-sm", color)}>
        <Icon className="h-5 w-5 text-white" />
      </div>
      <span className="text-[11px] font-semibold text-foreground/80">{label}</span>
    </button>
  );
}

function PendingCard({ title, count, icon: Icon, color, iconColor, onClick }: { title: string; count: number; icon: any; color: string; iconColor: string; onClick: () => void }) {
  return (
    <button onClick={onClick} className={cn("p-4 rounded-2xl flex items-center gap-4 w-full text-left active:scale-[0.97] transition-all", color)}>
      <div className={cn("w-11 h-11 rounded-xl bg-white/60 flex items-center justify-center shadow-inner", iconColor)}>
        <Icon className="h-5 w-5" />
      </div>
      <div className="flex-1">
        <p className="text-xs font-bold opacity-70 uppercase tracking-tight">{title}</p>
        <p className="text-xl font-bold leading-none mt-0.5">{count}</p>
      </div>
      <ChevronRight className="h-4 w-4 opacity-30" />
    </button>
  );
}

function StatusCard({ title, count, color }: { title: string; count: number; color: string }) {
  return (
    <div className={cn("p-4 rounded-xl transition-all duration-200 active:scale-95", color)}>
      <p className="text-xs font-semibold mb-1 opacity-90">{title}</p>
      <p className="text-2xl font-bold">{count}</p>
    </div>
  );
}

function DesktopPendingCard({ title, count, icon: Icon, color, iconColor }: { title: string; count: number; icon: any; color: string; iconColor: string }) {
  return (
    <div className={cn("p-6 rounded-2xl flex flex-col items-center justify-center gap-3 text-center transition-all active:scale-[0.97]", color)}>
      <div className={cn("w-14 h-14 rounded-2xl bg-white/60 flex items-center justify-center shadow-inner", iconColor)}>
        <Icon className="h-7 w-7" />
      </div>
      <div>
        <p className="text-2xl font-bold leading-none mb-1">{count}</p>
        <p className="text-xs font-bold opacity-80 uppercase tracking-tight">{title}</p>
      </div>
    </div>
  );
}
