import { useMemo, useState } from 'react';
import { BadgeCheck, Clock, IndianRupee, Plus, TriangleAlert } from 'lucide-react';
import { toast } from 'sonner';

import { PageHeader } from '@/components/PageHeader';
import { EmptyState, ErrorState, TableSkeleton } from '@/components/states';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select';
import { useAssociation, useCurrentAdmin, useMembers } from '@/hooks/useBarDesk';
import { useSaveStipend, useStipends } from '@/hooks/useBarOperations';

/**
 * The stipend register.
 *
 * In June 2024 the Madras High Court directed the Bar Council to circular
 * every association: a senior employing a junior pays at least ₹20,000 a
 * month in Chennai, Coimbatore and Madurai, and ₹15,000 elsewhere. The
 * circular arrived; associations had no way to answer it, because nobody
 * held a list of who employs whom.
 *
 * The junior's own confirmation is what makes an entry worth anything — a
 * declaration nobody countersigns is just a number the senior typed.
 */
export default function StipendPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id ?? '';
  const { data: association } = useAssociation(associationId);
  const { data: rows, isLoading, error } = useStipends(associationId);
  const { data: members } = useMembers(associationId);
  const save = useSaveStipend(associationId);

  const floor = Number(association?.junior_stipend_floor ?? 15000);
  const [open, setOpen] = useState(false);
  const [seniorId, setSeniorId] = useState('');
  const [juniorName, setJuniorName] = useState('');
  const [juniorMobile, setJuniorMobile] = useState('');
  const [amount, setAmount] = useState(String(floor));
  const [from, setFrom] = useState(new Date().toISOString().slice(0, 10));

  const stats = useMemo(() => {
    const live = (rows ?? []).filter((r) => !r.effective_to);
    return {
      total: live.length,
      confirmed: live.filter((r) => r.confirmed_by_junior).length,
      belowFloor: live.filter((r) => Number(r.monthly_stipend) < floor).length,
    };
  }, [rows, floor]);

  const advocates = (members ?? []).filter((m) => m.member_class !== 'clerk' && !m.is_deceased);

  async function submit() {
    if (!seniorId || !juniorName.trim()) {
      toast.error('Select the senior and name the junior');
      return;
    }
    try {
      await save.mutateAsync({
        senior_member_id: seniorId,
        junior_name: juniorName.trim(),
        junior_mobile: juniorMobile.trim() || null,
        monthly_stipend: Number(amount),
        effective_from: from,
      });
      toast.success('Declaration recorded');
      setOpen(false);
      setSeniorId(''); setJuniorName(''); setJuniorMobile(''); setAmount(String(floor));
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not save');
    }
  }

  if (isLoading) return <TableSkeleton />;
  if (error) return <ErrorState error={error} />;

  return (
    <div className="space-y-6">
      <PageHeader
        title="Stipend register"
        description="Which seniors employ juniors, and what they pay. The record the Bar Council circular asks for."
        actions={
          <Button onClick={() => setOpen(true)}>
            <Plus className="mr-1.5 h-4 w-4" /> Declare
          </Button>
        }
      />

      <Card className="border-border bg-muted/30">
        <CardContent className="flex flex-wrap items-center gap-3 p-4">
          <IndianRupee className="h-4 w-4 shrink-0 text-muted-foreground" />
          <p className="flex-1 text-sm text-muted-foreground">
            Minimum for <span className="font-medium text-foreground">{association?.district}</span> is{' '}
            <span className="font-mono font-semibold text-foreground">₹{floor.toLocaleString('en-IN')}</span> a
            month — Madras High Court, June 2024. ₹20,000 applies in Chennai, Coimbatore and Madurai.
          </p>
        </CardContent>
      </Card>

      <div className="grid grid-cols-3 gap-3">
        <div className="rounded-xl border border-border bg-card p-4">
          <p className="font-mono text-2xl font-semibold tabular-nums">{stats.total}</p>
          <p className="mt-0.5 text-2xs font-medium uppercase tracking-wide text-muted-foreground">Declared</p>
        </div>
        <div className="rounded-xl border border-border bg-card p-4">
          <p className="font-mono text-2xl font-semibold tabular-nums">{stats.confirmed}</p>
          <p className="mt-0.5 text-2xs font-medium uppercase tracking-wide text-muted-foreground">Confirmed by junior</p>
        </div>
        <div className={`rounded-xl border p-4 ${
          stats.belowFloor > 0 ? 'border-destructive/30 bg-destructive/[0.04]' : 'border-border bg-card'
        }`}>
          <p className="font-mono text-2xl font-semibold tabular-nums">{stats.belowFloor}</p>
          <p className="mt-0.5 text-2xs font-medium uppercase tracking-wide text-muted-foreground">Below the floor</p>
        </div>
      </div>

      {(rows ?? []).length === 0 ? (
        <EmptyState
          icon={IndianRupee}
          title="Nothing declared yet"
          description="Record which members employ juniors and what they pay, so the association can answer the Bar Council without asking around."
        />
      ) : (
        <Card>
          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[720px] text-sm">
                <thead>
                  <tr className="border-b border-border bg-muted/40 text-2xs uppercase tracking-wider text-muted-foreground">
                    <th className="px-4 py-3 text-left font-semibold">Senior</th>
                    <th className="px-4 py-3 text-left font-semibold">Junior</th>
                    <th className="px-4 py-3 text-right font-semibold">Monthly</th>
                    <th className="px-4 py-3 text-left font-semibold">From</th>
                    <th className="px-4 py-3 text-left font-semibold">Confirmed</th>
                  </tr>
                </thead>
                <tbody>
                  {rows!.map((r) => {
                    const below = Number(r.monthly_stipend) < floor;
                    return (
                      <tr key={r.id} className="border-b border-border/60 last:border-0 hover:bg-muted/30">
                        <td className="px-4 py-3">
                          <p className="font-medium">{r.senior?.name ?? '—'}</p>
                          <p className="font-mono text-xs text-muted-foreground">
                            {r.senior?.enrollment_number ?? ''}
                          </p>
                        </td>
                        <td className="px-4 py-3">
                          <p className="text-foreground">{r.junior_name}</p>
                          {r.junior_mobile && (
                            <p className="text-xs text-muted-foreground">{r.junior_mobile}</p>
                          )}
                        </td>
                        <td className="px-4 py-3 text-right">
                          <span className={`font-mono tabular-nums ${
                            below ? 'font-semibold text-destructive' : 'text-foreground'
                          }`}>
                            ₹{Number(r.monthly_stipend).toLocaleString('en-IN')}
                          </span>
                          {below && (
                            <span className="ml-1.5 inline-flex items-center">
                              <TriangleAlert className="h-3 w-3 text-destructive" />
                            </span>
                          )}
                        </td>
                        <td className="px-4 py-3 text-muted-foreground">
                          {new Date(r.effective_from).toLocaleDateString('en-IN', {
                            day: '2-digit', month: 'short', year: 'numeric',
                          })}
                        </td>
                        <td className="px-4 py-3">
                          {r.confirmed_by_junior ? (
                            <Badge variant="outline" className="border-emerald-500/25 bg-emerald-500/10 text-emerald-600">
                              <BadgeCheck className="mr-1 h-3 w-3" /> Confirmed
                            </Badge>
                          ) : (
                            <Badge variant="outline" className="border-border bg-muted text-muted-foreground">
                              <Clock className="mr-1 h-3 w-3" /> Awaiting junior
                            </Badge>
                          )}
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

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Declare a stipend</DialogTitle>
            <DialogDescription>
              The junior confirms this from their own CaseFlow app, which is what makes the
              record stand up.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-1.5">
              <Label>Senior advocate</Label>
              <Select value={seniorId} onValueChange={setSeniorId}>
                <SelectTrigger><SelectValue placeholder="Select member" /></SelectTrigger>
                <SelectContent>
                  {advocates.map((a) => (
                    <SelectItem key={a.id} value={a.id}>
                      {a.name}{a.enrollment_number ? ` · ${a.enrollment_number}` : ''}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="sp-jn">Junior's name</Label>
              <Input id="sp-jn" value={juniorName} onChange={(e) => setJuniorName(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="sp-jm">Junior's mobile</Label>
              <Input id="sp-jm" value={juniorMobile} onChange={(e) => setJuniorMobile(e.target.value)} />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label htmlFor="sp-amt">Monthly stipend (₹)</Label>
                <Input id="sp-amt" type="number" value={amount} onChange={(e) => setAmount(e.target.value)} />
                {Number(amount) < floor && (
                  <p className="text-xs text-destructive">
                    Below the ₹{floor.toLocaleString('en-IN')} floor for this district.
                  </p>
                )}
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="sp-from">Effective from</Label>
                <Input id="sp-from" type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
            <Button onClick={submit} disabled={save.isPending}>Record</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
