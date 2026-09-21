import { useMemo, useState } from 'react';
import { AlertTriangle, BellRing, CalendarClock, CheckCircle2, HelpCircle } from 'lucide-react';
import { toast } from 'sonner';

import { PageHeader } from '@/components/PageHeader';
import { EmptyState, ErrorState, TableSkeleton } from '@/components/states';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { useCurrentAdmin } from '@/hooks/useBarDesk';
import { useRenewals, useRenewMember } from '@/hooks/useBarOperations';
import type { RenewalRow } from '@/types/bardesk.types';

type Bucket = 'lapsed' | 'week' | 'month' | 'quarter' | 'safe' | 'unknown';

/**
 * The lapse watch.
 *
 * Welfare compensation on an advocate's death is refused when the
 * membership had lapsed — a family loses the death benefit because a
 * renewal was missed in a year nobody was watching. The old schema stored
 * only a membership *year*, so the question "who expires next month" could
 * not be asked at all.
 */
function bucketOf(days: number | null): Bucket {
  if (days === null) return 'unknown';
  if (days < 0) return 'lapsed';
  if (days <= 7) return 'week';
  if (days <= 30) return 'month';
  if (days <= 90) return 'quarter';
  return 'safe';
}

const BUCKET_META: Record<Bucket, { label: string; cls: string }> = {
  lapsed: { label: 'Lapsed', cls: 'bg-destructive/12 text-destructive border-destructive/25' },
  week: { label: 'This week', cls: 'bg-destructive/12 text-destructive border-destructive/25' },
  month: { label: 'Within 30 days', cls: 'bg-amber-500/12 text-amber-600 border-amber-500/25' },
  quarter: { label: 'Within 90 days', cls: 'bg-amber-500/10 text-amber-600/90 border-amber-500/20' },
  safe: { label: 'Current', cls: 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20' },
  unknown: { label: 'No date on file', cls: 'bg-muted text-muted-foreground border-border' },
};

function formatDays(days: number | null) {
  if (days === null) return '—';
  if (days < 0) return `${Math.abs(days)}d ago`;
  if (days === 0) return 'Today';
  return `${days}d`;
}

/** 31 March of the next membership year — the TN bar year end. */
function nextBarYearEnd(): string {
  const now = new Date();
  const year = now.getMonth() >= 3 ? now.getFullYear() + 1 : now.getFullYear();
  return `${year}-03-31`;
}

export default function RenewalsPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id ?? '';
  const { data: rows, isLoading, error } = useRenewals(associationId);
  const renew = useRenewMember(associationId);
  const [filter, setFilter] = useState<Bucket | 'all'>('all');

  const counts = useMemo(() => {
    const c: Record<Bucket, number> = { lapsed: 0, week: 0, month: 0, quarter: 0, safe: 0, unknown: 0 };
    for (const r of rows ?? []) c[bucketOf(r.daysRemaining)]++;
    return c;
  }, [rows]);

  const visible = useMemo(() => {
    if (!rows) return [];
    if (filter === 'all') return rows;
    return rows.filter((r) => bucketOf(r.daysRemaining) === filter);
  }, [rows, filter]);

  const needsAttention = counts.lapsed + counts.week + counts.month;

  async function handleRenew(row: RenewalRow) {
    try {
      await renew.mutateAsync({ memberId: row.id, until: nextBarYearEnd() });
      toast.success(`${row.name} renewed to 31 March ${nextBarYearEnd().slice(0, 4)}`);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not record the renewal');
    }
  }

  if (isLoading) return <TableSkeleton />;
  if (error) return <ErrorState error={error} />;

  return (
    <div className="space-y-6">
      <PageHeader
        title="Renewals"
        description="Who lapses next, and when. A lapsed membership is why a welfare claim gets refused."
      />

      {needsAttention > 0 && (
        <Card className="border-destructive/30 bg-destructive/[0.04]">
          <CardContent className="flex flex-wrap items-center gap-3 p-4">
            <AlertTriangle className="h-4 w-4 shrink-0 text-destructive" />
            <p className="flex-1 text-sm text-foreground">
              <span className="font-semibold">{needsAttention} member{needsAttention === 1 ? '' : 's'}</span>{' '}
              {counts.lapsed > 0 && (
                <>have already lapsed or </>
              )}
              need renewing within 30 days. A lapsed member’s family cannot claim the welfare fund.
            </p>
          </CardContent>
        </Card>
      )}

      {/* Buckets double as filters — the count is the point, the filter is a
          convenience on top of it. */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
        {(['lapsed', 'week', 'month', 'quarter', 'safe', 'unknown'] as Bucket[]).map((b) => (
          <button
            key={b}
            type="button"
            onClick={() => setFilter(filter === b ? 'all' : b)}
            className={`rounded-xl border p-3 text-left transition-colors ${
              filter === b ? 'border-primary bg-primary/5' : 'border-border bg-card hover:bg-muted/40'
            }`}
          >
            <p className="font-mono text-2xl font-semibold tabular-nums">{counts[b]}</p>
            <p className="mt-0.5 text-2xs font-medium uppercase tracking-wide text-muted-foreground">
              {BUCKET_META[b].label}
            </p>
          </button>
        ))}
      </div>

      {visible.length === 0 ? (
        <EmptyState
          icon={CheckCircle2}
          title="Nothing in this view"
          description="No members fall into the selected window."
        />
      ) : (
        <Card>
          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[720px] text-sm">
                <thead>
                  <tr className="border-b border-border bg-muted/40 text-2xs uppercase tracking-wider text-muted-foreground">
                    <th className="px-4 py-3 text-left font-semibold">Member</th>
                    <th className="px-4 py-3 text-left font-semibold">Enrolment</th>
                    <th className="px-4 py-3 text-left font-semibold">Expires</th>
                    <th className="px-4 py-3 text-right font-semibold">Remaining</th>
                    <th className="px-4 py-3 text-left font-semibold">Status</th>
                    <th className="px-4 py-3 text-right font-semibold">Action</th>
                  </tr>
                </thead>
                <tbody>
                  {visible.map((r) => {
                    const b = bucketOf(r.daysRemaining);
                    return (
                      <tr key={r.id} className="border-b border-border/60 last:border-0 hover:bg-muted/30">
                        <td className="px-4 py-3">
                          <p className="font-medium text-foreground">{r.name}</p>
                          <p className="text-xs text-muted-foreground">{r.mobile}</p>
                        </td>
                        <td className="px-4 py-3 font-mono text-xs text-muted-foreground">
                          {r.enrollment_number ?? '—'}
                        </td>
                        <td className="px-4 py-3 text-muted-foreground">
                          {r.membership_expires_on
                            ? new Date(r.membership_expires_on).toLocaleDateString('en-IN', {
                                day: '2-digit', month: 'short', year: 'numeric',
                              })
                            : <span className="inline-flex items-center gap-1 text-xs"><HelpCircle className="h-3 w-3" /> not recorded</span>}
                        </td>
                        <td className={`px-4 py-3 text-right font-mono tabular-nums ${
                          b === 'lapsed' || b === 'week' ? 'font-semibold text-destructive' : 'text-muted-foreground'
                        }`}>
                          {formatDays(r.daysRemaining)}
                        </td>
                        <td className="px-4 py-3">
                          <Badge variant="outline" className={BUCKET_META[b].cls}>
                            {BUCKET_META[b].label}
                          </Badge>
                        </td>
                        <td className="px-4 py-3 text-right">
                          <Button
                            size="sm"
                            variant={b === 'lapsed' || b === 'week' ? 'default' : 'outline'}
                            disabled={renew.isPending}
                            onClick={() => handleRenew(r)}
                          >
                            <CalendarClock className="mr-1.5 h-3.5 w-3.5" />
                            Renew
                          </Button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      )}

      <p className="flex items-start gap-2 text-xs text-muted-foreground">
        <BellRing className="mt-0.5 h-3.5 w-3.5 shrink-0" />
        Renewing sets the membership to 31 March of the next bar year and reaches the member’s
        CaseFlow app immediately — no refresh needed on their side.
      </p>
    </div>
  );
}
