import { useEffect, useState, useCallback, useMemo } from "react";
import { useNavigate } from "react-router-dom";
import {
  Briefcase, Gavel, FileText, AlertTriangle, Users, CalendarDays,
  RefreshCw, BookOpen, ArrowRight,
} from "lucide-react";
import {
  Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis,
} from "recharts";
import { addDays, format, isSameDay, isToday, isWithinInterval, parseISO, startOfDay, subDays } from "date-fns";

import { fetchDashboardStats } from "@/lib/supabase-helpers";
import { supabase } from "@/integrations/supabase/client";
import { TaskWidget } from "@/components/TaskWidget";
import { PageHeader } from "@/components/PageHeader";
import { KpiCard } from "@/components/KpiCard";
import { StatusBadge } from "@/components/StatusBadge";
import { EmptyState, ErrorState, StatSkeleton } from "@/components/states";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";

const inr = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 0,
});

/**
 * Row count for a table, or null when it cannot be read.
 *
 * The cast is deliberate and narrow. `bare_acts` exists in the database but
 * not in `integrations/supabase/types.ts`, which was generated from an older
 * schema knowing only eight tables — the same drift flagged during the audit.
 * Regenerating those types is the real fix; until then this keeps the drift
 * contained to one line instead of loosening the client everywhere.
 */
async function countRows(
  table: string,
  refine?: (query: any) => any,
): Promise<number | null> {
  let query = (supabase.from as (t: string) => any)(table).select("id", {
    count: "exact",
  });
  if (refine) query = refine(query);

  const { count, error } = await query;
  if (error) {
    console.error(`Count failed for ${table}:`, error.message);
    return null;
  }
  return count ?? null;
}

interface DashboardStats {
  activeCases: any[];
  closedCases: any[];
  upcomingHearings: any[];
  efilingRecords: any[];
  payments: any[];
}

export default function Dashboard() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [counts, setCounts] = useState<{
    cases: number | null;
    clients: number | null;
    acts: number | null;
    advocates: number | null;
    newAdvocates: number | null;
  }>({ cases: null, clients: null, acts: null, advocates: null, newAdvocates: null });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);
  const navigate = useNavigate();

  const loadStats = useCallback(async () => {
    try {
      setError(null);
      const data = await fetchDashboardStats();
      setStats(data);

      // Registered advocates is the headline adoption number, so it also
      // carries a 30-day figure — a total alone says nothing about growth.
      const since = subDays(new Date(), 30).toISOString();

      const [cases, clients, acts, advocates, newAdvocates] = await Promise.all([
        countRows("cases"),
        countRows("clients"),
        countRows("bare_acts"),
        countRows("profiles"),
        countRows("profiles", (q) => q.gte("created_at", since)),
      ]);

      // Null rather than an invented number. This page previously fell back to
      // literals (|| 53, || 56, || 14) when a count came back empty, so the
      // landing screen showed figures that were never in the database.
      setCounts({ cases, clients, acts, advocates, newAdvocates });
    } catch (err) {
      console.error("Dashboard load failed:", err);
      setError(err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadStats();

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

  const hearings = stats?.upcomingHearings ?? [];
  const filings = stats?.efilingRecords ?? [];
  const payments = stats?.payments ?? [];

  const hearingsThisWeek = hearings.filter(
    (h) =>
      h.hearing_date &&
      isWithinInterval(parseISO(h.hearing_date), {
        start: startOfDay(new Date()),
        end: addDays(new Date(), 7),
      }),
  );
  const todaysHearings = hearings.filter((h) => h.hearing_date && isToday(parseISO(h.hearing_date)));
  const pendingFilings = filings.filter((f) => !["filed", "accepted"].includes(f.status));
  const defectFilings = filings.filter((f) => f.status === "defect");

  const outstanding = payments.reduce(
    (sum, p) => sum + (Number(p.balance_amount) > 0 ? Number(p.balance_amount) : 0),
    0,
  );
  const pendingPaymentCount = payments.filter((p) => Number(p.balance_amount) > 0).length;

  /** Hearing load for the next fortnight — the question this page exists to answer. */
  const hearingLoad = useMemo(() => {
    const today = startOfDay(new Date());
    return Array.from({ length: 14 }, (_, offset) => {
      const day = addDays(today, offset);
      return {
        label: format(day, "d MMM"),
        short: format(day, "EEEEE"),
        count: hearings.filter(
          (h) => h.hearing_date && isSameDay(parseISO(h.hearing_date), day),
        ).length,
      };
    });
  }, [hearings]);

  const hasHearingLoad = hearingLoad.some((d) => d.count > 0);

  if (loading) {
    return (
      <div className="mx-auto max-w-7xl space-y-6 pb-12">
        <Skeleton className="h-9 w-48" />
        <StatSkeleton count={5} />
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
          <Skeleton className="h-80 rounded-xl lg:col-span-8" />
          <Skeleton className="h-80 rounded-xl lg:col-span-4" />
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-7xl pb-12">
      <PageHeader
        title="Overview"
        description={format(new Date(), "EEEE, d MMMM yyyy")}
        actions={
          <Button variant="outline" size="sm" className="gap-2" onClick={() => void loadStats()}>
            <RefreshCw className="h-3.5 w-3.5" />
            Refresh
          </Button>
        }
      />

      {error ? (
        <ErrorState error={error} onRetry={() => void loadStats()} />
      ) : (
        <div className="space-y-6">
          {/* ── Headline figures ─────────────────────────────── */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
            <KpiCard
              title="Registered users"
              value={counts.advocates ?? "—"}
              icon={Users}
              color="accent"
              hint={
                counts.newAdvocates === null
                  ? "Advocates on CaseFlow"
                  : counts.newAdvocates === 0
                    ? "No new sign-ups in 30 days"
                    : `+${counts.newAdvocates} in the last 30 days`
              }
            />
            <KpiCard
              title="Active cases"
              value={stats?.activeCases?.length ?? 0}
              icon={Briefcase}
              hint={`${stats?.closedCases?.length ?? 0} closed`}
            />
            <KpiCard
              title="Hearings this week"
              value={hearingsThisWeek.length}
              icon={Gavel}
              color="info"
              hint={`${todaysHearings.length} today`}
            />
            <KpiCard
              title="E-filings pending"
              value={pendingFilings.length}
              icon={FileText}
              color="warning"
              hint="Awaiting review or signature"
            />
            <KpiCard
              title="Defects reported"
              value={defectFilings.length}
              icon={AlertTriangle}
              color={defectFilings.length > 0 ? "destructive" : "default"}
              hint={defectFilings.length > 0 ? "Needs action" : "Nothing outstanding"}
            />
          </div>

          <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
            {/* ── Hearing load ───────────────────────────────── */}
            <Card className="lg:col-span-8">
              <CardHeader className="pb-2">
                <CardTitle className="font-display text-md font-semibold">
                  Hearing load
                </CardTitle>
                <CardDescription className="text-sm">
                  Scheduled hearings over the next fortnight
                </CardDescription>
              </CardHeader>
              <CardContent>
                {hasHearingLoad ? (
                  <div className="h-64 w-full">
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart data={hearingLoad} margin={{ top: 8, right: 8, bottom: 0, left: -20 }}>
                        <CartesianGrid
                          strokeDasharray="3 3"
                          vertical={false}
                          stroke="hsl(var(--chart-grid))"
                        />
                        <XAxis
                          dataKey="label"
                          tickLine={false}
                          axisLine={false}
                          interval={1}
                          tick={{ fontSize: 11, fill: "hsl(var(--muted-foreground))" }}
                        />
                        <YAxis
                          allowDecimals={false}
                          tickLine={false}
                          axisLine={false}
                          tick={{ fontSize: 11, fill: "hsl(var(--muted-foreground))" }}
                        />
                        <Tooltip
                          cursor={{ fill: "hsl(var(--muted))" }}
                          contentStyle={{
                            background: "hsl(var(--popover))",
                            border: "1px solid hsl(var(--border))",
                            borderRadius: "var(--radius)",
                            fontSize: 13,
                            color: "hsl(var(--popover-foreground))",
                            boxShadow: "var(--shadow-md)",
                          }}
                          labelStyle={{ color: "hsl(var(--popover-foreground))", fontWeight: 600 }}
                          formatter={(value: number) => [
                            `${value} hearing${value === 1 ? "" : "s"}`,
                            "",
                          ]}
                        />
                        <Bar
                          dataKey="count"
                          fill="hsl(var(--chart-1))"
                          radius={[4, 4, 0, 0]}
                          maxBarSize={38}
                        />
                      </BarChart>
                    </ResponsiveContainer>
                  </div>
                ) : (
                  <EmptyState
                    icon={CalendarDays}
                    title="No hearings scheduled"
                    description="Nothing is listed for the next fortnight. Hearings appear here as they are scheduled or imported from eCourts."
                    className="border-0 py-12"
                  />
                )}
              </CardContent>
            </Card>

            {/* ── Money ──────────────────────────────────────── */}
            <div className="space-y-6 lg:col-span-4">
              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="font-display text-md font-semibold">
                    Outstanding fees
                  </CardTitle>
                  <CardDescription className="text-sm">
                    Balance owed across all matters
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <p
                    data-numeric
                    className="font-display text-3xl font-semibold tracking-tight text-foreground"
                  >
                    {inr.format(outstanding)}
                  </p>
                  <p className="mt-1.5 text-sm text-muted-foreground">
                    {pendingPaymentCount === 0
                      ? "Nothing outstanding"
                      : `${pendingPaymentCount} record${pendingPaymentCount === 1 ? "" : "s"} with a balance`}
                  </p>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="mt-4 -ml-2 gap-1.5 text-sm"
                    onClick={() => navigate("/payments")}
                  >
                    View payments
                    <ArrowRight className="h-3.5 w-3.5" />
                  </Button>
                </CardContent>
              </Card>

              {/* ── Library ──────────────────────────────────── */}
              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="font-display text-md font-semibold">
                    In the system
                  </CardTitle>
                  <CardDescription className="text-sm">Records held across the platform</CardDescription>
                </CardHeader>
                <CardContent className="space-y-1">
                  {/* Registered users is a headline KPI above, so it is not
                      repeated here. */}
                  <CountRow icon={Briefcase} label="Cases" value={counts.cases} />
                  <CountRow icon={Users} label="Clients" value={counts.clients} />
                  <CountRow icon={BookOpen} label="Statutes" value={counts.acts} />
                </CardContent>
              </Card>
            </div>
          </div>

          {/* ── Today ────────────────────────────────────────── */}
          <Card>
            <CardHeader className="flex flex-row items-start justify-between space-y-0 pb-3">
              <div>
                <CardTitle className="font-display text-md font-semibold">
                  Today in court
                </CardTitle>
                <CardDescription className="text-sm">
                  {format(new Date(), "EEEE d MMMM")}
                </CardDescription>
              </div>
              <Button variant="outline" size="sm" onClick={() => navigate("/hearings")}>
                Calendar
              </Button>
            </CardHeader>
            <CardContent>
              {todaysHearings.length === 0 ? (
                <EmptyState
                  icon={CalendarDays}
                  title="Nothing listed today"
                  description="No hearings are scheduled for today."
                  className="border-0 py-10"
                />
              ) : (
                <ul className="divide-y divide-border">
                  {todaysHearings.slice(0, 6).map((h: any) => (
                    <li
                      key={h.id}
                      className="flex items-center justify-between gap-4 py-3 first:pt-0 last:pb-0"
                    >
                      <div className="min-w-0">
                        <p className="truncate text-sm font-medium text-foreground">
                          {h.cases?.case_title ?? "Untitled matter"}
                        </p>
                        <p className="mt-0.5 truncate text-sm text-muted-foreground">
                          {h.purpose || "Regular hearing"}
                        </p>
                      </div>
                      <StatusBadge status={h.status} />
                    </li>
                  ))}
                </ul>
              )}
            </CardContent>
          </Card>

          <TaskWidget />
        </div>
      )}
    </div>
  );
}

function CountRow({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof Briefcase;
  label: string;
  value: number | null;
}) {
  return (
    <div className="flex items-center justify-between py-2">
      <span className="flex items-center gap-2.5 text-sm text-muted-foreground">
        <Icon className="h-4 w-4" />
        {label}
      </span>
      <span data-numeric className="text-md font-semibold text-foreground">
        {/* An unavailable count reads as unavailable, not as zero. */}
        {value === null ? <span className="text-muted-foreground">—</span> : value}
      </span>
    </div>
  );
}
