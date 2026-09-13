import { useNavigate } from "react-router-dom";
import { format, parseISO } from "date-fns";
import { DashboardLayout } from "@/components/DashboardLayout";
import { PageHeader } from "@/components/PageHeader";
import { ErrorState, StatSkeleton } from "@/components/states";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useAdminOverview } from "@/hooks/useAdminMetrics";
import { Users, Briefcase, CalendarDays, BellOff, MessageSquare, TrendingUp } from "lucide-react";

/**
 * Platform health at a glance.
 *
 * Everything here is an aggregate served by the `admin-metrics` edge function.
 * The console holds no cross-user query of its own, and nothing on this page
 * reveals what any case or client record contains.
 */

function Stat({
  label, value, sub, icon: Icon,
}: { label: string; value: number | string; sub?: string; icon: React.ElementType }) {
  return (
    <Card>
      <CardContent className="pt-5">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="text-sm text-muted-foreground">{label}</p>
            <p className="mt-1 font-display text-3xl font-semibold tabular-nums">{value}</p>
            {sub && <p className="mt-1 text-xs text-muted-foreground">{sub}</p>}
          </div>
          <Icon className="h-5 w-5 shrink-0 text-muted-foreground" />
        </div>
      </CardContent>
    </Card>
  );
}

/** Bar chart of weekly signups. Inline SVG — no library for twelve bars. */
function SignupChart({ data }: { data: Array<{ week: string; count: number }> }) {
  const max = Math.max(1, ...data.map((d) => d.count));
  return (
    <div className="flex h-32 items-end gap-1.5" role="img" aria-label="Weekly signups, last 12 weeks">
      {data.map((d) => (
        <div key={d.week} className="group flex flex-1 flex-col items-center gap-1.5">
          <div className="relative flex w-full flex-1 items-end">
            <div
              className="w-full rounded-sm bg-primary/80 transition-colors group-hover:bg-primary"
              style={{ height: `${Math.max(3, (d.count / max) * 100)}%` }}
              title={`${d.count} signup${d.count === 1 ? "" : "s"} — week of ${format(parseISO(d.week), "d MMM")}`}
            />
            {d.count > 0 && (
              <span className="absolute -top-5 left-1/2 -translate-x-1/2 text-[11px] font-medium tabular-nums text-muted-foreground">
                {d.count}
              </span>
            )}
          </div>
          <span className="text-[10px] text-muted-foreground">
            {format(parseISO(d.week), "d/M")}
          </span>
        </div>
      ))}
    </div>
  );
}

/** A gap worth acting on — count, what it means, where to look. */
function Gap({ n, total, label, detail }: { n: number; total: number; label: string; detail: string }) {
  const pct = total > 0 ? Math.round((n / total) * 100) : 0;
  return (
    <div className="flex items-baseline justify-between gap-4 border-b border-border py-2.5 last:border-0">
      <div className="min-w-0">
        <p className="text-sm font-medium text-foreground">{label}</p>
        <p className="text-xs text-muted-foreground">{detail}</p>
      </div>
      <div className="shrink-0 text-right">
        <span className="font-display text-lg font-semibold tabular-nums">{n}</span>
        <span className="ml-1 text-xs text-muted-foreground">of {total}</span>
        <div className="text-xs tabular-nums text-muted-foreground">{pct}%</div>
      </div>
    </div>
  );
}

export default function Overview() {
  const navigate = useNavigate();
  const { data, isLoading, error, refetch } = useAdminOverview();

  if (error) {
    return (
      <DashboardLayout>
        <PageHeader title="Overview" />
        <ErrorState error={error} onRetry={() => refetch()} />
      </DashboardLayout>
    );
  }

  if (isLoading || !data) {
    return (
      <DashboardLayout>
        <PageHeader title="Overview" description="Platform health across all CaseFlow users." />
        <StatSkeleton count={4} />
      </DashboardLayout>
    );
  }

  const { users, records, adoption, delivery, feedback, signups, subscriptions } = data;

  return (
    <DashboardLayout>
      <PageHeader
        title="Overview"
        description="Platform health across all CaseFlow users. Aggregates only — no case or client contents."
        actions={
          <Button variant="outline" size="sm" onClick={() => refetch()}>
            Refresh
          </Button>
        }
      />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Stat
          label="Registered users"
          value={users.total}
          sub={`${users.advocates} advocates · ${users.citizens} citizens`}
          icon={Users}
        />
        <Stat
          label="Active this week"
          value={users.active_7d}
          sub={`${users.active_1d} today · ${users.active_30d} this month`}
          icon={TrendingUp}
        />
        <Stat
          label="Cases"
          value={records.cases}
          sub={`${records.cases_7d} added in 7 days`}
          icon={Briefcase}
        />
        <Stat
          label="Hearings"
          value={records.hearings}
          sub={`${records.hearings_7d} added in 7 days`}
          icon={CalendarDays}
        />
      </div>

      <div className="mt-6 grid gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader className="pb-3">
            <CardTitle className="font-display text-md font-semibold">Signups</CardTitle>
            <CardDescription className="text-sm">New accounts per week, last 12 weeks</CardDescription>
          </CardHeader>
          <CardContent className="pt-2">
            <SignupChart data={signups} />
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="font-display text-md font-semibold">Where adoption leaks</CardTitle>
            <CardDescription className="text-sm">Registered, but not really using it</CardDescription>
          </CardHeader>
          <CardContent className="pt-0">
            <Gap
              n={adoption.no_cases}
              total={users.total}
              label="Never created a case"
              detail="Signed up but never got started"
            />
            <Gap
              n={adoption.inactive_30d}
              total={users.total}
              label="Inactive 30 days"
              detail="No sign-in in the last month"
            />
            <Gap
              n={adoption.no_push_token}
              total={users.total}
              label="No push token"
              detail="Cannot receive any notification"
            />
            <Button
              variant="ghost"
              size="sm"
              className="mt-3 -ml-2"
              onClick={() => navigate("/users")}
            >
              View users
            </Button>
          </CardContent>
        </Card>
      </div>

      <div className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="font-display text-md font-semibold">Notification delivery</CardTitle>
          </CardHeader>
          <CardContent className="space-y-1.5 text-sm">
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Users reachable</span>
              <span className="tabular-nums font-medium">
                {delivery.users_with_token} / {users.total}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Devices registered</span>
              <span className="tabular-nums font-medium">{delivery.tokens}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Sent in 7 days</span>
              <span className="tabular-nums font-medium">{delivery.notifications_7d}</span>
            </div>
            {delivery.users_with_token < users.total && (
              <p className="flex items-start gap-1.5 pt-2 text-xs text-warning">
                <BellOff className="mt-0.5 h-3.5 w-3.5 shrink-0" />
                {users.total - delivery.users_with_token} users cannot receive notifications.
              </p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="font-display text-md font-semibold">Plans</CardTitle>
          </CardHeader>
          <CardContent className="space-y-1.5 text-sm">
            {Object.entries(subscriptions).map(([tier, n]) => (
              <div key={tier} className="flex items-center justify-between">
                <span className="capitalize text-muted-foreground">{tier}</span>
                <span className="tabular-nums font-medium">{n}</span>
              </div>
            ))}
            <p className="pt-2 text-xs text-muted-foreground">
              Revenue reporting needs the billing schema and Razorpay webhooks — not built yet.
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="font-display text-md font-semibold">Feedback</CardTitle>
          </CardHeader>
          <CardContent className="space-y-1.5 text-sm">
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Awaiting triage</span>
              <span className="tabular-nums font-medium">{feedback.open}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-muted-foreground">Total received</span>
              <span className="tabular-nums font-medium">{feedback.total}</span>
            </div>
            {feedback.open > 0 && (
              <p className="flex items-start gap-1.5 pt-2 text-xs text-muted-foreground">
                <MessageSquare className="mt-0.5 h-3.5 w-3.5 shrink-0" />
                The Feedback screen arrives in a later phase.
              </p>
            )}
          </CardContent>
        </Card>
      </div>

      <p className="mt-6 text-xs text-muted-foreground">
        Generated {format(new Date(data.generated_at), "d MMM yyyy, HH:mm")}
      </p>
    </DashboardLayout>
  );
}
