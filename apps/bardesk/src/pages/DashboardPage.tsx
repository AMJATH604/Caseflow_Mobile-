import { useNavigate } from "react-router-dom";
import {
  Users,
  Receipt,
  Megaphone,
  BellRing,
  Flower2,
  ArrowRight,
  Pin,
  UserPlus,
  CalendarPlus,
  Send,
} from "lucide-react";

import {
  useDashboardStats,
  useCurrentAdmin,
  useNotices,
  useFeePayments,
} from "@/hooks/useBarDesk";
import { formatCurrency, formatDate, getInitials } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { KpiCard } from "@/components/KpiCard";
import { EmptyState, StatSkeleton } from "@/components/states";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

/** Category accent for a notice, drawn from tokens so it follows the theme. */
const noticeTone: Record<string, string> = {
  urgent: "bg-destructive",
  election: "bg-chart-4",
  event: "bg-info",
  holiday: "bg-warning",
  general: "bg-chart-1",
};

export default function DashboardPage() {
  const navigate = useNavigate();
  const { data: admin, isLoading: adminLoading } = useCurrentAdmin();
  const associationId = admin?.association_id || "";
  const associationName =
    (admin as any)?.bar_associations?.name || "Bar Association";

  const { data: stats, isLoading } = useDashboardStats(associationId);
  const { data: notices } = useNotices(associationId);
  const { data: payments } = useFeePayments(associationId);

  const currentYear = new Date().getFullYear();

  if (adminLoading || isLoading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-9 w-56" />
        <StatSkeleton />
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <Skeleton className="h-72 rounded-xl" />
          <Skeleton className="h-72 rounded-xl" />
        </div>
      </div>
    );
  }

  const recentNotices = (notices || []).slice(0, 5);
  const recentPayments = (payments || []).filter((p) => p.status === "paid").slice(0, 5);

  const totalMembers = stats?.totalMembers ?? 0;
  const activeMembers = stats?.activeMembers ?? 0;
  const inactiveMembers = Math.max(totalMembers - activeMembers, 0);
  const activeShare = totalMembers > 0 ? Math.round((activeMembers / totalMembers) * 100) : 0;

  return (
    <div>
      <PageHeader
        title="Dashboard"
        description={`${associationName} · ${currentYear}–${currentYear + 1}`}
      />

      <div className="space-y-6">
        {/* ── Headline figures ───────────────────────────────── */}
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <KpiCard
            title="Total members"
            value={totalMembers}
            icon={Users}
            hint={`${activeMembers} active${inactiveMembers ? ` · ${inactiveMembers} suspended` : ""}`}
            onClick={() => navigate("/members")}
          />
          {/* Lapses lead, because a lapsed membership is why a welfare
              claim gets refused — it is the one figure that costs a family
              money if nobody looks at it. */}
          <KpiCard
            title="Renewals due"
            value={(stats?.expiringSoon ?? 0) + (stats?.lapsed ?? 0)}
            icon={BellRing}
            color={stats?.lapsed ? "destructive" : stats?.expiringSoon ? "warning" : "success"}
            hint={
              stats?.lapsed
                ? `${stats.lapsed} already lapsed`
                : stats?.expiringSoon
                  ? `${stats.expiringSoon} within 60 days`
                  : "Everyone current"
            }
            onClick={() => navigate("/renewals")}
          />
          <KpiCard
            title="Fees collected"
            value={formatCurrency(stats?.feesCollected || 0)}
            icon={Receipt}
            color="success"
            hint="This membership year"
            onClick={() => navigate("/fees")}
          />
          <KpiCard
            title="Welfare claims"
            value={stats?.openClaims ?? 0}
            icon={Megaphone}
            color={stats?.openClaims ? "info" : "default"}
            hint={stats?.openClaims ? "Awaiting the Bar Council" : "Nothing outstanding"}
            onClick={() => navigate("/welfare")}
          />
        </div>

        {/* ── Membership health ──────────────────────────────── */}
        {totalMembers > 0 && (
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="font-display text-md font-semibold">
                Membership
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex items-baseline justify-between">
                <p data-numeric className="font-display text-2xl font-semibold text-foreground">
                  {activeShare}%
                </p>
                <p className="text-sm text-muted-foreground">
                  {activeMembers} of {totalMembers} active
                </p>
              </div>
              <div
                className="mt-3 h-2 w-full overflow-hidden rounded-full bg-muted"
                role="progressbar"
                aria-valuenow={activeShare}
                aria-valuemin={0}
                aria-valuemax={100}
                aria-label="Share of members currently active"
              >
                <div
                  className="h-full rounded-full bg-success transition-all duration-500"
                  style={{ width: `${activeShare}%` }}
                />
              </div>
            </CardContent>
          </Card>
        )}

        {/* ── Two columns ────────────────────────────────────── */}
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
              <CardTitle className="font-display text-md font-semibold">
                Recent notices
              </CardTitle>
              <Button
                variant="ghost"
                size="sm"
                className="-mr-2 gap-1.5 text-sm"
                onClick={() => navigate("/notices")}
              >
                View all
                <ArrowRight className="h-3.5 w-3.5" />
              </Button>
            </CardHeader>
            <CardContent>
              {recentNotices.length === 0 ? (
                <EmptyState
                  icon={Megaphone}
                  title="No notices yet"
                  description="Published notices appear here and are pushed to members."
                  action={
                    <Button size="sm" onClick={() => navigate("/notices")}>
                      Publish a notice
                    </Button>
                  }
                  className="border-0 py-8"
                />
              ) : (
                <ul className="divide-y divide-border">
                  {recentNotices.map((notice) => (
                    <li key={notice.id} className="flex items-start gap-3 py-3 first:pt-0 last:pb-0">
                      <span
                        className={cn(
                          "mt-1.5 h-2 w-2 shrink-0 rounded-full",
                          noticeTone[notice.category ?? "general"] ?? "bg-muted-foreground",
                        )}
                        aria-hidden
                      />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-medium text-foreground">
                          {notice.title}
                        </p>
                        <p className="mt-0.5 text-sm text-muted-foreground">
                          {notice.published_at ? formatDate(notice.published_at) : "Unpublished"} · {notice.read_count ?? 0} read
                        </p>
                      </div>
                      {notice.is_pinned && (
                        <Pin className="h-3.5 w-3.5 shrink-0 text-accent" aria-label="Pinned" />
                      )}
                    </li>
                  ))}
                </ul>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
              <CardTitle className="font-display text-md font-semibold">
                Recent payments
              </CardTitle>
              <Button
                variant="ghost"
                size="sm"
                className="-mr-2 gap-1.5 text-sm"
                onClick={() => navigate("/fees")}
              >
                View all
                <ArrowRight className="h-3.5 w-3.5" />
              </Button>
            </CardHeader>
            <CardContent>
              {recentPayments.length === 0 ? (
                <EmptyState
                  icon={Receipt}
                  title="No payments recorded"
                  description="Fee payments appear here once members have paid."
                  className="border-0 py-8"
                />
              ) : (
                <ul className="divide-y divide-border">
                  {recentPayments.map((payment) => (
                    <li key={payment.id} className="flex items-center gap-3 py-3 first:pt-0 last:pb-0">
                      <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-muted text-2xs font-semibold text-muted-foreground">
                        {getInitials((payment.member as any)?.name || "??")}
                      </span>
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-sm font-medium text-foreground">
                          {(payment.member as any)?.name || "Member"}
                        </p>
                        <p className="mt-0.5 truncate text-sm text-muted-foreground">
                          {payment.receipt_number}
                          {payment.paid_at ? ` · ${formatDate(payment.paid_at)}` : ""}
                        </p>
                      </div>
                      <span data-numeric className="shrink-0 text-sm font-semibold text-success">
                        {formatCurrency(payment.amount)}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </CardContent>
          </Card>
        </div>

        {/* ── Quick actions ──────────────────────────────────── */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="font-display text-md font-semibold">
              Quick actions
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex flex-wrap gap-2">
              {/* Emoji replaced with real icons — they rendered
                  inconsistently across platforms and carried no label. */}
              <QuickAction icon={Send} label="Send notice" onClick={() => navigate("/notices")} />
              <QuickAction icon={UserPlus} label="Add member" onClick={() => navigate("/members")} />
              <QuickAction icon={Receipt} label="Pending fees" onClick={() => navigate("/fees")} />
              <QuickAction icon={Flower2} label="Condolence" onClick={() => navigate("/condolences")} />
              <QuickAction icon={CalendarPlus} label="Add event" onClick={() => navigate("/events")} />
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function QuickAction({
  icon: Icon,
  label,
  onClick,
}: {
  icon: typeof Users;
  label: string;
  onClick: () => void;
}) {
  return (
    <Button variant="outline" size="sm" className="gap-2" onClick={onClick}>
      <Icon className="h-4 w-4 text-muted-foreground" />
      {label}
    </Button>
  );
}
