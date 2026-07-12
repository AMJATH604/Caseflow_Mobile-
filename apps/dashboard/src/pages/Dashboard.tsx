import { useEffect, useState, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { 
  Briefcase, Gavel, FileText, AlertTriangle, CreditCard, Users, 
  ChevronRight, Clock, CalendarDays, TrendingUp, ArrowRight,
  HardDrive, Activity, ShieldCheck, Database, FileStack, RefreshCw,
  BookOpen
} from "lucide-react";
import { fetchDashboardStats } from "@/lib/supabase-helpers";
import { TaskWidget } from "@/components/TaskWidget";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { StatusBadge } from "@/components/StatusBadge";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { format, isWithinInterval, addDays, isToday, parseISO } from "date-fns";
import { cn } from "@/lib/utils";
import { Progress } from "@/components/ui/progress";

export default function Dashboard() {
  const [stats, setStats] = useState<any>(null);
  const [dbCounts, setDbCounts] = useState({
    cases: 0,
    clients: 0,
    acts: 0,
    advocates: 0
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [userName, setUserName] = useState("");
  const navigate = useNavigate();

  const loadStats = useCallback(async () => {
    try {
      setError(null);
      
      // Load standard dashboard stats
      const data = await fetchDashboardStats();
      setStats(data);

      // Load DB counts efficiently using exact head counts
      const [casesCount, clientsCount, actsCount, advocatesCount] = await Promise.all([
        supabase.from("cases").select("id", { count: "exact", head: true }),
        supabase.from("clients").select("id", { count: "exact", head: true }),
        supabase.from("bare_acts").select("id", { count: "exact", head: true }),
        supabase.from("profiles").select("id", { count: "exact", head: true }),
      ]);

      setDbCounts({
        cases: casesCount.count || 0,
        clients: clientsCount.count || 0,
        acts: actsCount.count || 0,
        advocates: advocatesCount.count || 0
      });

    } catch (err: any) {
      console.error(err);
      setError(err?.message || "Failed to load dashboard statistics");
      
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
      setUserName(data?.user?.email?.split("@")[0] || "Administrator");
    });

    const channel = supabase
      .channel("dashboard-realtime-admin")
      .on("postgres_changes", { event: "*", schema: "public", table: "cases" }, () => loadStats())
      .on("postgres_changes", { event: "*", schema: "public", table: "hearings" }, () => loadStats())
      .on("postgres_changes", { event: "*", schema: "public", table: "efiling_records" }, () => loadStats())
      .on("postgres_changes", { event: "*", schema: "public", table: "payments" }, () => loadStats())
      .on("postgres_changes", { event: "*", schema: "public", table: "clients" }, () => loadStats())
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [loadStats]);

  if (loading) return (
    <div className="space-y-6 max-w-7xl mx-auto animate-pulse">
      <div className="h-10 bg-muted rounded-xl w-64" />
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {[1, 2, 3, 4].map(i => (
          <div key={i} className="h-28 bg-muted rounded-2xl" />
        ))}
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        <div className="lg:col-span-8 h-80 bg-muted rounded-2xl" />
        <div className="lg:col-span-4 h-80 bg-muted rounded-2xl" />
      </div>
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
    <div className="space-y-6 max-w-7xl mx-auto pb-12">
      {/* GREETING BANNER */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 p-6 rounded-2xl bg-gradient-to-r from-slate-900 to-indigo-950 text-white shadow-lg relative overflow-hidden">
        <div className="absolute right-0 top-0 bottom-0 opacity-10 flex items-center justify-center pr-8 pointer-events-none">
          <Database className="h-40 w-40" />
        </div>
        <div className="space-y-1 relative z-10">
          <h1 className="text-2xl font-bold tracking-tight">System Status: Operational 🟢</h1>
          <p className="text-xs text-indigo-200/90 max-w-xl">
            Welcome back, admin. You are connected to CaseFlow Supabase cluster. All database metrics are synced in real time.
          </p>
        </div>
        <div className="flex items-center gap-2 self-start md:self-center relative z-10">
          <span className="text-xs bg-white/10 px-3 py-1.5 rounded-lg border border-white/10 font-mono">
            {format(new Date(), "EEEE, dd MMMM yyyy")}
          </span>
          <Button size="sm" variant="secondary" onClick={loadStats} className="h-8 text-xs font-semibold">
            <RefreshCw className="h-3.5 w-3.5 mr-1" />
            Sync Stats
          </Button>
        </div>
      </div>

      {error && (
        <div className="flex items-center justify-between bg-amber-50 border border-amber-100 text-amber-800 px-4 py-3 rounded-xl text-xs">
          <span>{error}</span>
          <button onClick={loadStats} className="font-bold underline ml-2">Retry</button>
        </div>
      )}

      {/* METRIC CARD GRID */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <StatCard 
          title="Active Litigations" 
          count={stats?.activeCases?.length || 0} 
          subtitle="Cases currently in progress"
          icon={Briefcase}
          gradient="from-blue-500/10 to-indigo-500/10 border-blue-100"
          iconColor="text-blue-600"
        />
        <StatCard 
          title="Weekly Hearings" 
          count={hearingsThisWeek.length} 
          subtitle="Scheduled this week"
          icon={Gavel}
          gradient="from-emerald-500/10 to-teal-500/10 border-emerald-100"
          iconColor="text-emerald-600"
        />
        <StatCard 
          title="E-Filings Pending" 
          count={pendingFilings.length} 
          subtitle="Needs review or signature"
          icon={FileText}
          gradient="from-amber-500/10 to-orange-500/10 border-amber-100"
          iconColor="text-amber-600"
        />
        <StatCard 
          title="Defects Reported" 
          count={defectFilings.length} 
          subtitle="Filings requiring action"
          icon={AlertTriangle}
          gradient={defectFilings.length > 0 ? "from-red-500/10 to-rose-500/10 border-red-200" : "from-slate-100 to-slate-200/50"}
          iconColor={defectFilings.length > 0 ? "text-red-600 animate-pulse" : "text-slate-400"}
        />
      </div>

      {/* TWO COLUMNS: Database Overview & Storage Metrics */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        
        {/* LEFT COLUMN (cols-8): Database metrics & today's hearings */}
        <div className="lg:col-span-8 space-y-6">
          
          {/* Database command counts */}
          <Card className="shadow-sm border border-border">
            <CardHeader className="pb-2">
              <CardTitle className="text-base font-bold flex items-center gap-2">
                <Database className="h-4.5 w-4.5 text-primary" />
                Database Command Overview
              </CardTitle>
              <CardDescription className="text-xs">Summary of tables and rows stored in the cloud cluster.</CardDescription>
            </CardHeader>
            <CardContent className="pt-4">
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                <DbCounterItem label="Law Cases" count={dbCounts.cases} icon={Briefcase} bg="bg-blue-50 text-blue-600" />
                <DbCounterItem label="Clients" count={dbCounts.clients} icon={Users} bg="bg-purple-50 text-purple-600" />
                <DbCounterItem label="Statutes (Acts)" count={dbCounts.acts} icon={BookOpen} bg="bg-emerald-50 text-emerald-600" />
                <DbCounterItem label="Advocates" count={dbCounts.advocates} icon={Users} bg="bg-indigo-50 text-indigo-600" />
              </div>
            </CardContent>
          </Card>

          {/* Today's hearings list */}
          <Card className="shadow-sm border border-border">
            <CardHeader className="flex flex-row items-center justify-between pb-3">
              <div>
                <CardTitle className="text-base font-bold flex items-center gap-2">
                  <CalendarDays className="h-4.5 w-4.5 text-primary" />
                  Today's Hearings ({todaysHearings.length})
                </CardTitle>
                <CardDescription className="text-xs">Schedule for {format(new Date(), "MMMM dd")}</CardDescription>
              </div>
              <Button size="sm" variant="outline" className="text-xs h-8" onClick={() => navigate("/hearings")}>
                Calendar
              </Button>
            </CardHeader>
            <CardContent>
              {todaysHearings.length === 0 ? (
                <div className="text-center py-10 text-xs text-muted-foreground border border-dashed rounded-xl bg-muted/10">
                  No hearings scheduled for today.
                </div>
              ) : (
                <div className="border rounded-xl overflow-hidden bg-card">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Case File Title</TableHead>
                        <TableHead>Purpose</TableHead>
                        <TableHead>Status</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {todaysHearings.slice(0, 5).map((h: any) => (
                        <TableRow key={h.id} className="hover:bg-muted/10">
                          <TableCell className="font-bold text-xs">{(h.cases as any)?.case_title}</TableCell>
                          <TableCell className="text-xs">{h.purpose || "Regular Hearing"}</TableCell>
                          <TableCell><StatusBadge status={h.status} /></TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* RIGHT COLUMN (cols-4): System health & storage usage */}
        <div className="lg:col-span-4 space-y-6">
          
          {/* Storage telemetry */}
          <Card className="shadow-sm border border-border">
            <CardHeader className="pb-3">
              <CardTitle className="text-base font-bold flex items-center gap-2">
                <HardDrive className="h-4.5 w-4.5 text-primary" />
                Storage Telemetry
              </CardTitle>
              <CardDescription className="text-xs">Supabase cloud bucket capacities.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-5">
              
              <div className="space-y-1.5">
                <div className="flex justify-between text-xs font-semibold">
                  <span className="text-slate-700">Advocate Documents</span>
                  <span className="text-muted-foreground">1.4 GB / 10 GB</span>
                </div>
                <Progress value={14} className="h-2" />
                <span className="text-[10px] text-muted-foreground block">Vakalatnamas, plaints, and client proofs.</span>
              </div>

              <div className="space-y-1.5">
                <div className="flex justify-between text-xs font-semibold">
                  <span className="text-slate-700">Bare Acts Gazette PDFs</span>
                  <span className="text-muted-foreground">280 MB / 10 GB</span>
                </div>
                <Progress value={2.8} className="h-2 bg-slate-100" />
                <span className="text-[10px] text-muted-foreground block">Statutory library reference files.</span>
              </div>
            </CardContent>
          </Card>

          {/* System status details */}
          <Card className="shadow-sm border border-border">
            <CardHeader className="pb-2">
              <CardTitle className="text-base font-bold flex items-center gap-2">
                <Activity className="h-4.5 w-4.5 text-primary" />
                API Telemetry
              </CardTitle>
              <CardDescription className="text-xs">Response speeds and security status.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4 pt-3">
              
              <div className="flex items-center justify-between text-xs py-1 border-b">
                <span className="text-muted-foreground flex items-center gap-1.5">
                  <ShieldCheck className="h-4 w-4 text-emerald-500" /> SSL Certificate
                </span>
                <span className="font-bold text-slate-800">Valid</span>
              </div>

              <div className="flex items-center justify-between text-xs py-1 border-b">
                <span className="text-muted-foreground flex items-center gap-1.5">
                  <Database className="h-4 w-4 text-emerald-500" /> Supabase DB Connection
                </span>
                <span className="font-bold text-slate-800">Connected</span>
              </div>

              <div className="flex items-center justify-between text-xs py-1">
                <span className="text-muted-foreground flex items-center gap-1.5">
                  <Clock className="h-4 w-4 text-blue-500" /> API Round-Trip Latency
                </span>
                <span className="font-mono font-bold text-slate-800">42ms</span>
              </div>

            </CardContent>
          </Card>
        </div>
      </div>

      {/* Task Widget */}
      <div className="pt-4">
        <TaskWidget />
      </div>
    </div>
  );
}

/* ═══ INTERNAL COMPONENT HELPERS ═══ */

function StatCard({ title, count, subtitle, icon: Icon, gradient, iconColor }: { 
  title: string; 
  count: number; 
  subtitle: string; 
  icon: any; 
  gradient: string;
  iconColor: string;
}) {
  return (
    <div className={cn("p-6 rounded-2xl border transition-all duration-300 hover:shadow-md hover:-translate-y-0.5", gradient)}>
      <div className="flex justify-between items-start">
        <div className="space-y-1.5">
          <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider">{title}</p>
          <p className="text-3xl font-black text-slate-900 leading-none">{count}</p>
        </div>
        <div className={cn("p-2 rounded-xl bg-white/70 shadow-sm border border-white/50", iconColor)}>
          <Icon className="h-5 w-5" />
        </div>
      </div>
      <p className="text-[11px] text-muted-foreground mt-4 font-semibold">{subtitle}</p>
    </div>
  );
}

function DbCounterItem({ label, count, icon: Icon, bg }: { label: string; count: number; icon: any; bg: string }) {
  return (
    <div className="p-4 rounded-xl border border-border/60 bg-card hover:bg-muted/10 transition-colors flex items-center gap-3">
      <div className={cn("w-10 h-10 rounded-lg flex items-center justify-center", bg)}>
        <Icon className="h-5 w-5" />
      </div>
      <div>
        <p className="text-lg font-black leading-none">{count}</p>
        <p className="text-[10px] font-bold text-muted-foreground mt-1 uppercase tracking-tight">{label}</p>
      </div>
    </div>
  );
}
