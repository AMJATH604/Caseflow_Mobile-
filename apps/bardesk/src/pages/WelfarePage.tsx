import { useMemo, useState } from 'react';
import { HeartHandshake, Plus, Stamp, TriangleAlert } from 'lucide-react';
import { toast } from 'sonner';

import { PageHeader } from '@/components/PageHeader';
import { EmptyState, ErrorState, TableSkeleton } from '@/components/states';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import {
  Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select';
import { useCurrentAdmin, useMembers } from '@/hooks/useBarDesk';
import {
  stampBalance, useRecordStamps, useSaveWelfareClaim, useWelfareClaims, useWelfareStamps,
} from '@/hooks/useBarOperations';
import type { BarWelfareClaim, WelfareClaimStatus } from '@/types/bardesk.types';

/**
 * Welfare fund work.
 *
 * Two things live here because they are the same fund seen from two ends.
 *
 * Claims follow the path the Bar Council actually puts them through —
 * submitted, returned with a defect, resubmitted, sanctioned. A member
 * currently learns where theirs is by telephoning the bar office, and the
 * office finds out by telephoning someone else.
 *
 * Stamps are the counter side: every vakalat carries one, associations buy
 * them in books and sell them across the desk, and the reconciliation is
 * usually from memory. The balance here is derived from the ledger rather
 * than stored, so it cannot drift from the entries that produced it.
 */
const STATUS_META: Record<WelfareClaimStatus, { label: string; cls: string }> = {
  draft: { label: 'Draft', cls: 'bg-muted text-muted-foreground border-border' },
  submitted: { label: 'Submitted', cls: 'bg-sky-500/10 text-sky-600 border-sky-500/25' },
  defect: { label: 'Defect raised', cls: 'bg-destructive/12 text-destructive border-destructive/25' },
  resubmitted: { label: 'Resubmitted', cls: 'bg-amber-500/12 text-amber-600 border-amber-500/25' },
  sanctioned: { label: 'Sanctioned', cls: 'bg-emerald-500/10 text-emerald-600 border-emerald-500/25' },
  rejected: { label: 'Rejected', cls: 'bg-muted text-muted-foreground border-border' },
};

const CLAIM_TYPES = [
  { v: 'death', l: 'Death benefit' },
  { v: 'retirement', l: 'Retirement benefit' },
  { v: 'medical', l: 'Medical assistance' },
  { v: 'disability', l: 'Disability' },
  { v: 'other', l: 'Other' },
];

export default function WelfarePage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id ?? '';
  const { data: claims, isLoading, error } = useWelfareClaims(associationId);
  const { data: stamps } = useWelfareStamps(associationId);
  const { data: members } = useMembers(associationId);
  const saveClaim = useSaveWelfareClaim(associationId);
  const recordStamps = useRecordStamps(associationId);

  const [claimOpen, setClaimOpen] = useState(false);
  const [editing, setEditing] = useState<BarWelfareClaim | null>(null);
  const [stampOpen, setStampOpen] = useState(false);

  const balance = useMemo(() => stampBalance(stamps), [stamps]);
  const stuck = (claims ?? []).filter((c) => c.status === 'defect').length;
  const open = (claims ?? []).filter((c) =>
    ['submitted', 'defect', 'resubmitted'].includes(c.status)).length;

  if (isLoading) return <TableSkeleton />;
  if (error) return <ErrorState error={error} />;

  return (
    <div className="space-y-6">
      <PageHeader
        title="Welfare"
        description="Advocates Welfare Fund claims and the welfare stamp ledger."
      />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatTile label="Open claims" value={open} />
        <StatTile label="Held for defect" value={stuck} tone={stuck > 0 ? 'warn' : undefined} />
        <StatTile label="Sanctioned" value={(claims ?? []).filter((c) => c.status === 'sanctioned').length} />
        <StatTile label="Stamps in hand" value={balance} tone={balance <= 20 ? 'warn' : undefined} />
      </div>

      {stuck > 0 && (
        <Card className="border-destructive/30 bg-destructive/[0.04]">
          <CardContent className="flex items-center gap-3 p-4">
            <TriangleAlert className="h-4 w-4 shrink-0 text-destructive" />
            <p className="text-sm">
              <span className="font-semibold">{stuck} claim{stuck === 1 ? '' : 's'}</span> returned
              for a defect. These sit still until somebody acts on the note.
            </p>
          </CardContent>
        </Card>
      )}

      <Tabs defaultValue="claims">
        <TabsList>
          <TabsTrigger value="claims">Claims</TabsTrigger>
          <TabsTrigger value="stamps">Stamps</TabsTrigger>
        </TabsList>

        <TabsContent value="claims" className="mt-4 space-y-4">
          <div className="flex justify-end">
            <Button onClick={() => { setEditing(null); setClaimOpen(true); }}>
              <Plus className="mr-1.5 h-4 w-4" /> New claim
            </Button>
          </div>

          {(claims ?? []).length === 0 ? (
            <EmptyState
              icon={HeartHandshake}
              title="No claims recorded"
              description="Track a welfare fund application from submission to sanction, including any defect the Bar Council raises."
            />
          ) : (
            <Card>
              <CardContent className="p-0">
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[760px] text-sm">
                    <thead>
                      <tr className="border-b border-border bg-muted/40 text-2xs uppercase tracking-wider text-muted-foreground">
                        <th className="px-4 py-3 text-left font-semibold">Member</th>
                        <th className="px-4 py-3 text-left font-semibold">Type</th>
                        <th className="px-4 py-3 text-left font-semibold">Claimant</th>
                        <th className="px-4 py-3 text-right font-semibold">Amount</th>
                        <th className="px-4 py-3 text-left font-semibold">Status</th>
                        <th className="px-4 py-3 text-right font-semibold" />
                      </tr>
                    </thead>
                    <tbody>
                      {claims!.map((c) => (
                        <tr key={c.id} className="border-b border-border/60 last:border-0 hover:bg-muted/30">
                          <td className="px-4 py-3">
                            <p className="font-medium">{c.bar_members?.name ?? '—'}</p>
                            {c.reference_number && (
                              <p className="font-mono text-xs text-muted-foreground">{c.reference_number}</p>
                            )}
                          </td>
                          <td className="px-4 py-3 text-muted-foreground">
                            {CLAIM_TYPES.find((t) => t.v === c.claim_type)?.l ?? c.claim_type}
                          </td>
                          <td className="px-4 py-3 text-muted-foreground">
                            {c.claimant_name ?? '—'}
                            {c.claimant_relation && (
                              <span className="text-xs"> ({c.claimant_relation})</span>
                            )}
                          </td>
                          <td className="px-4 py-3 text-right font-mono tabular-nums">
                            {c.amount ? `₹${Number(c.amount).toLocaleString('en-IN')}` : '—'}
                          </td>
                          <td className="px-4 py-3">
                            <Badge variant="outline" className={STATUS_META[c.status].cls}>
                              {STATUS_META[c.status].label}
                            </Badge>
                            {c.status === 'defect' && c.defect_notes && (
                              <p className="mt-1 max-w-[220px] text-xs text-destructive">{c.defect_notes}</p>
                            )}
                          </td>
                          <td className="px-4 py-3 text-right">
                            <Button size="sm" variant="outline"
                              onClick={() => { setEditing(c); setClaimOpen(true); }}>
                              Update
                            </Button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </CardContent>
            </Card>
          )}
        </TabsContent>

        <TabsContent value="stamps" className="mt-4 space-y-4">
          <div className="flex items-center justify-between">
            <p className="text-sm text-muted-foreground">
              Balance in hand: <span className="font-mono font-semibold text-foreground">{balance}</span> stamps
            </p>
            <Button onClick={() => setStampOpen(true)}>
              <Plus className="mr-1.5 h-4 w-4" /> Record
            </Button>
          </div>

          {(stamps ?? []).length === 0 ? (
            <EmptyState
              icon={Stamp}
              title="No stamp movements"
              description="Record stock received from the Bar Council and stamps sold across the counter. The balance is worked out from these entries."
            />
          ) : (
            <Card>
              <CardContent className="p-0">
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[560px] text-sm">
                    <thead>
                      <tr className="border-b border-border bg-muted/40 text-2xs uppercase tracking-wider text-muted-foreground">
                        <th className="px-4 py-3 text-left font-semibold">Date</th>
                        <th className="px-4 py-3 text-left font-semibold">Movement</th>
                        <th className="px-4 py-3 text-right font-semibold">Qty</th>
                        <th className="px-4 py-3 text-left font-semibold">Sold to</th>
                      </tr>
                    </thead>
                    <tbody>
                      {stamps!.map((s) => (
                        <tr key={s.id} className="border-b border-border/60 last:border-0">
                          <td className="px-4 py-3 text-muted-foreground">
                            {new Date(s.recorded_at).toLocaleDateString('en-IN', {
                              day: '2-digit', month: 'short', year: 'numeric',
                            })}
                          </td>
                          <td className="px-4 py-3">
                            <Badge variant="outline" className={
                              s.txn_type === 'sold'
                                ? 'border-amber-500/25 bg-amber-500/10 text-amber-600'
                                : 'border-emerald-500/25 bg-emerald-500/10 text-emerald-600'
                            }>
                              {s.txn_type}
                            </Badge>
                          </td>
                          <td className={`px-4 py-3 text-right font-mono tabular-nums ${
                            s.txn_type === 'sold' ? 'text-amber-600' : 'text-emerald-600'
                          }`}>
                            {s.txn_type === 'sold' ? '−' : '+'}{s.quantity}
                          </td>
                          <td className="px-4 py-3 text-muted-foreground">
                            {s.bar_members?.name ?? '—'}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </CardContent>
            </Card>
          )}
        </TabsContent>
      </Tabs>

      <ClaimDialog
        open={claimOpen}
        onOpenChange={setClaimOpen}
        editing={editing}
        members={members ?? []}
        onSave={async (payload) => {
          try {
            await saveClaim.mutateAsync(payload);
            toast.success('Claim saved');
            setClaimOpen(false);
          } catch (e) {
            toast.error(e instanceof Error ? e.message : 'Could not save');
          }
        }}
      />

      <StampDialog
        open={stampOpen}
        onOpenChange={setStampOpen}
        members={members ?? []}
        onSave={async (payload) => {
          try {
            await recordStamps.mutateAsync(payload);
            toast.success('Recorded');
            setStampOpen(false);
          } catch (e) {
            toast.error(e instanceof Error ? e.message : 'Could not record');
          }
        }}
      />
    </div>
  );
}

function StatTile({ label, value, tone }: { label: string; value: number; tone?: 'warn' }) {
  return (
    <div className={`rounded-xl border p-4 ${
      tone === 'warn' ? 'border-amber-500/30 bg-amber-500/[0.04]' : 'border-border bg-card'
    }`}>
      <p className="font-mono text-2xl font-semibold tabular-nums">{value}</p>
      <p className="mt-0.5 text-2xs font-medium uppercase tracking-wide text-muted-foreground">{label}</p>
    </div>
  );
}

function ClaimDialog({
  open, onOpenChange, editing, members, onSave,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  editing: BarWelfareClaim | null;
  members: { id: string; name: string; enrollment_number: string | null }[];
  onSave: (payload: Partial<BarWelfareClaim> & { id?: string }) => Promise<void>;
}) {
  const [form, setForm] = useState<Partial<BarWelfareClaim>>({});
  const merged = { ...editing, ...form } as Partial<BarWelfareClaim>;

  // Reset the overlay whenever a different claim is opened.
  const key = editing?.id ?? 'new';

  return (
    <Dialog open={open} onOpenChange={(v) => { onOpenChange(v); if (!v) setForm({}); }}>
      <DialogContent key={key} className="max-h-[90vh] overflow-y-auto sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{editing ? 'Update claim' : 'New welfare claim'}</DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <div className="space-y-1.5">
            <Label>Member</Label>
            <Select
              value={merged.member_id ?? ''}
              onValueChange={(v) => setForm((f) => ({ ...f, member_id: v }))}
            >
              <SelectTrigger><SelectValue placeholder="Select member" /></SelectTrigger>
              <SelectContent>
                {members.map((m) => (
                  <SelectItem key={m.id} value={m.id}>
                    {m.name}{m.enrollment_number ? ` · ${m.enrollment_number}` : ''}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label>Claim type</Label>
              <Select
                value={merged.claim_type ?? 'death'}
                onValueChange={(v) => setForm((f) => ({ ...f, claim_type: v as never }))}
              >
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {CLAIM_TYPES.map((t) => <SelectItem key={t.v} value={t.v}>{t.l}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Status</Label>
              <Select
                value={merged.status ?? 'draft'}
                onValueChange={(v) => setForm((f) => ({ ...f, status: v as WelfareClaimStatus }))}
              >
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {(Object.keys(STATUS_META) as WelfareClaimStatus[]).map((s) => (
                    <SelectItem key={s} value={s}>{STATUS_META[s].label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="wc-claimant">Claimant</Label>
              <Input id="wc-claimant" value={merged.claimant_name ?? ''}
                onChange={(e) => setForm((f) => ({ ...f, claimant_name: e.target.value }))} />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="wc-rel">Relation</Label>
              <Input id="wc-rel" placeholder="Wife, son…" value={merged.claimant_relation ?? ''}
                onChange={(e) => setForm((f) => ({ ...f, claimant_relation: e.target.value }))} />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="wc-amt">Amount (₹)</Label>
              <Input id="wc-amt" type="number" value={merged.amount ?? ''}
                onChange={(e) => setForm((f) => ({ ...f, amount: Number(e.target.value) }))} />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="wc-ref">Reference no.</Label>
              <Input id="wc-ref" value={merged.reference_number ?? ''}
                onChange={(e) => setForm((f) => ({ ...f, reference_number: e.target.value }))} />
            </div>
          </div>

          {/* The defect note is the whole reason a claim sits still. */}
          <div className="space-y-1.5">
            <Label htmlFor="wc-def">Defect raised by the Bar Council</Label>
            <Textarea id="wc-def" rows={2}
              placeholder="What was returned, and what is needed to cure it"
              value={merged.defect_notes ?? ''}
              onChange={(e) => setForm((f) => ({ ...f, defect_notes: e.target.value }))} />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Cancel</Button>
          <Button onClick={() => onSave({ ...merged, id: editing?.id })}>Save</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function StampDialog({
  open, onOpenChange, members, onSave,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  members: { id: string; name: string }[];
  onSave: (payload: Record<string, unknown>) => Promise<void>;
}) {
  const [type, setType] = useState('received');
  const [qty, setQty] = useState('');
  const [memberId, setMemberId] = useState('');

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-sm">
        <DialogHeader><DialogTitle>Record stamp movement</DialogTitle></DialogHeader>
        <div className="space-y-4">
          <div className="space-y-1.5">
            <Label>Movement</Label>
            <Select value={type} onValueChange={setType}>
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="received">Received from Bar Council</SelectItem>
                <SelectItem value="sold">Sold to member</SelectItem>
                <SelectItem value="returned">Returned to stock</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="st-qty">Quantity</Label>
            <Input id="st-qty" type="number" min={1} value={qty} onChange={(e) => setQty(e.target.value)} />
          </div>
          {type === 'sold' && (
            <div className="space-y-1.5">
              <Label>Sold to</Label>
              <Select value={memberId} onValueChange={setMemberId}>
                <SelectTrigger><SelectValue placeholder="Select member" /></SelectTrigger>
                <SelectContent>
                  {members.map((m) => <SelectItem key={m.id} value={m.id}>{m.name}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
          )}
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Cancel</Button>
          <Button
            disabled={!qty || Number(qty) < 1}
            onClick={() => onSave({
              txn_type: type,
              quantity: Number(qty),
              member_id: type === 'sold' && memberId ? memberId : null,
            })}
          >
            Record
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
