import { useMemo, useState } from 'react';
import { IdCard, Printer } from 'lucide-react';
import { toast } from 'sonner';

import { PageHeader } from '@/components/PageHeader';
import { EmptyState, ErrorState, TableSkeleton } from '@/components/states';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { useAssociation, useCurrentAdmin, useMembers } from '@/hooks/useBarDesk';
import { daysUntil, useIssueIdCard } from '@/hooks/useBarOperations';
import type { BarMember } from '@/types/bardesk.types';

/**
 * Identity cards.
 *
 * Issued from the member record rather than a fresh form, so the card can
 * never disagree with the roll. The card a member carries in CaseFlow is
 * checked against the live register, which is the part a laminated card
 * cannot do: a lapsed membership shows as lapsed the moment it lapses.
 */
function cardState(m: BarMember): 'none' | 'expired' | 'expiring' | 'valid' {
  if (!m.id_card_number || !m.id_card_valid_until) return 'none';
  const d = daysUntil(m.id_card_valid_until);
  if (d === null) return 'none';
  if (d < 0) return 'expired';
  if (d <= 60) return 'expiring';
  return 'valid';
}

const STATE_META = {
  none: { label: 'Not issued', cls: 'bg-muted text-muted-foreground border-border' },
  expired: { label: 'Expired', cls: 'bg-destructive/12 text-destructive border-destructive/25' },
  expiring: { label: 'Expiring', cls: 'bg-amber-500/12 text-amber-600 border-amber-500/25' },
  valid: { label: 'Valid', cls: 'bg-emerald-500/10 text-emerald-600 border-emerald-500/25' },
} as const;

/** Sequential within the association, prefixed by district. */
function nextCardNumber(members: BarMember[], district: string): string {
  const prefix = district.slice(0, 3).toUpperCase();
  const highest = members.reduce((max, m) => {
    const n = Number(m.id_card_number?.split('-').pop());
    return Number.isFinite(n) && n > max ? n : max;
  }, 0);
  return `${prefix}-${String(highest + 1).padStart(4, '0')}`;
}

export default function IdCardsPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id ?? '';
  const { data: association } = useAssociation(associationId);
  const { data: members, isLoading, error } = useMembers(associationId);
  const issue = useIssueIdCard(associationId);
  const [query, setQuery] = useState('');

  const rows = useMemo(() => {
    const living = (members ?? []).filter((m) => !m.is_deceased);
    const q = query.trim().toLowerCase();
    const filtered = q
      ? living.filter((m) =>
          m.name.toLowerCase().includes(q) ||
          (m.enrollment_number ?? '').toLowerCase().includes(q) ||
          (m.id_card_number ?? '').toLowerCase().includes(q))
      : living;
    // Unissued and expired first — this page exists to clear that queue.
    const rank = { none: 0, expired: 1, expiring: 2, valid: 3 };
    return [...filtered].sort((a, b) => rank[cardState(a)] - rank[cardState(b)]);
  }, [members, query]);

  const counts = useMemo(() => {
    const c = { none: 0, expired: 0, expiring: 0, valid: 0 };
    for (const m of (members ?? []).filter((x) => !x.is_deceased)) c[cardState(m)]++;
    return c;
  }, [members]);

  async function handleIssue(m: BarMember) {
    const number = m.id_card_number ?? nextCardNumber(members ?? [], association?.district ?? 'BAR');
    // Three years is the usual life of a bar identity card.
    const until = new Date();
    until.setFullYear(until.getFullYear() + 3);
    try {
      await issue.mutateAsync({
        memberId: m.id,
        cardNumber: number,
        validUntil: until.toISOString().slice(0, 10),
      });
      toast.success(`${m.id_card_number ? 'Renewed' : 'Issued'} ${number} for ${m.name}`);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not issue');
    }
  }

  if (isLoading) return <TableSkeleton />;
  if (error) return <ErrorState error={error} />;

  return (
    <div className="space-y-6">
      <PageHeader
        title="ID Cards"
        description="Issue and renew association identity cards. The digital card verifies against the live roll."
        actions={
          <Button variant="outline" onClick={() => window.print()}>
            <Printer className="mr-1.5 h-4 w-4" /> Print batch
          </Button>
        }
      />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        {(['none', 'expired', 'expiring', 'valid'] as const).map((k) => (
          <div key={k} className="rounded-xl border border-border bg-card p-4">
            <p className="font-mono text-2xl font-semibold tabular-nums">{counts[k]}</p>
            <p className="mt-0.5 text-2xs font-medium uppercase tracking-wide text-muted-foreground">
              {STATE_META[k].label}
            </p>
          </div>
        ))}
      </div>

      <Input
        placeholder="Search by name, enrolment or card number"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        className="max-w-sm"
      />

      {rows.length === 0 ? (
        <EmptyState icon={IdCard} title="No members match" description="Try a different search." />
      ) : (
        <Card>
          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[720px] text-sm">
                <thead>
                  <tr className="border-b border-border bg-muted/40 text-2xs uppercase tracking-wider text-muted-foreground">
                    <th className="px-4 py-3 text-left font-semibold">Member</th>
                    <th className="px-4 py-3 text-left font-semibold">Card no.</th>
                    <th className="px-4 py-3 text-left font-semibold">Valid until</th>
                    <th className="px-4 py-3 text-left font-semibold">Status</th>
                    <th className="px-4 py-3 text-right font-semibold">Action</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((m) => {
                    const st = cardState(m);
                    return (
                      <tr key={m.id} className="border-b border-border/60 last:border-0 hover:bg-muted/30">
                        <td className="px-4 py-3">
                          <p className="font-medium">{m.name}</p>
                          <p className="font-mono text-xs text-muted-foreground">
                            {m.enrollment_number ?? '—'}
                            {m.member_class === 'clerk' && ' · clerk'}
                          </p>
                        </td>
                        <td className="px-4 py-3 font-mono text-xs">{m.id_card_number ?? '—'}</td>
                        <td className="px-4 py-3 text-muted-foreground">
                          {m.id_card_valid_until
                            ? new Date(m.id_card_valid_until).toLocaleDateString('en-IN', {
                                day: '2-digit', month: 'short', year: 'numeric',
                              })
                            : '—'}
                        </td>
                        <td className="px-4 py-3">
                          <Badge variant="outline" className={STATE_META[st].cls}>
                            {STATE_META[st].label}
                          </Badge>
                        </td>
                        <td className="px-4 py-3 text-right">
                          <Button
                            size="sm"
                            variant={st === 'valid' ? 'outline' : 'default'}
                            disabled={issue.isPending}
                            onClick={() => handleIssue(m)}
                          >
                            {st === 'none' ? 'Issue' : 'Renew'}
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

      <p className="text-xs text-muted-foreground">
        Cards run three years from issue. A member sees theirs in CaseFlow the moment it is issued.
      </p>
    </div>
  );
}
