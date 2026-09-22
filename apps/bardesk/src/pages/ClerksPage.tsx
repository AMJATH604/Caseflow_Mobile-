import { useState } from 'react';
import { Briefcase, Plus } from 'lucide-react';
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
import { useAddMember, useCurrentAdmin, useMembers } from '@/hooks/useBarDesk';
import { useClerks } from '@/hooks/useBarOperations';

/**
 * Advocates' clerks.
 *
 * Clerks file the papers, collect the certified copies and chase the dates,
 * and they have their own welfare fund with its own claims — but they were
 * nowhere on the roll, so when a clerk died the family's claim went down a
 * completely separate paper track.
 *
 * They sit on the same table as advocates, distinguished by member_class and
 * attached to the advocate they work under, so everything already built for
 * members — welfare, renewals, ID cards — applies to them without a second
 * implementation of each.
 */
export default function ClerksPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id ?? '';
  const { data: clerks, isLoading, error } = useClerks(associationId);
  const { data: allMembers } = useMembers(associationId);
  const addMember = useAddMember(associationId);

  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');
  const [mobile, setMobile] = useState('');
  const [worksUnder, setWorksUnder] = useState('');
  const [welfareNo, setWelfareNo] = useState('');

  const advocates = (allMembers ?? []).filter((m) => m.member_class !== 'clerk' && !m.is_deceased);
  const nameOf = (id: string | null) =>
    id ? advocates.find((a) => a.id === id)?.name ?? '—' : '—';

  async function submit() {
    if (!name.trim() || !mobile.trim()) {
      toast.error('Name and mobile are required');
      return;
    }
    try {
      await addMember.mutateAsync({
        name: name.trim(),
        mobile: mobile.trim(),
        member_class: 'clerk',
        works_under_member_id: worksUnder || null,
        welfare_fund_number: welfareNo.trim() || null,
        status: 'active',
      });
      toast.success('Clerk added to the roll');
      setOpen(false);
      setName(''); setMobile(''); setWorksUnder(''); setWelfareNo('');
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not add');
    }
  }

  if (isLoading) return <TableSkeleton />;
  if (error) return <ErrorState error={error} />;

  return (
    <div className="space-y-6">
      <PageHeader
        title="Clerks"
        description="Advocates' clerks on the roll, with their own welfare fund standing."
        actions={
          <Button onClick={() => setOpen(true)}>
            <Plus className="mr-1.5 h-4 w-4" /> Add clerk
          </Button>
        }
      />

      {(clerks ?? []).length === 0 ? (
        <EmptyState
          icon={Briefcase}
          title="No clerks on the roll"
          description="Adding clerks here brings them into welfare, renewals and ID cards alongside advocates, instead of a separate paper file."
        />
      ) : (
        <Card>
          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[640px] text-sm">
                <thead>
                  <tr className="border-b border-border bg-muted/40 text-2xs uppercase tracking-wider text-muted-foreground">
                    <th className="px-4 py-3 text-left font-semibold">Clerk</th>
                    <th className="px-4 py-3 text-left font-semibold">Works under</th>
                    <th className="px-4 py-3 text-left font-semibold">Welfare fund</th>
                    <th className="px-4 py-3 text-left font-semibold">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {clerks!.map((c) => (
                    <tr key={c.id} className="border-b border-border/60 last:border-0 hover:bg-muted/30">
                      <td className="px-4 py-3">
                        <p className="font-medium">{c.name}</p>
                        <p className="text-xs text-muted-foreground">{c.mobile}</p>
                      </td>
                      <td className="px-4 py-3 text-muted-foreground">
                        {nameOf(c.works_under_member_id)}
                      </td>
                      <td className="px-4 py-3 font-mono text-xs text-muted-foreground">
                        {c.welfare_fund_number ?? '—'}
                      </td>
                      <td className="px-4 py-3">
                        <Badge variant="outline" className={
                          c.status === 'active'
                            ? 'border-emerald-500/25 bg-emerald-500/10 text-emerald-600'
                            : 'border-border bg-muted text-muted-foreground'
                        }>
                          {c.status ?? 'unknown'}
                        </Badge>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Add a clerk</DialogTitle>
            <DialogDescription>
              Clerks join the same roll as advocates, so welfare and ID cards work the same way.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="ck-name">Name</Label>
              <Input id="ck-name" value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="ck-mob">Mobile</Label>
              <Input id="ck-mob" value={mobile} onChange={(e) => setMobile(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label>Works under</Label>
              <Select value={worksUnder} onValueChange={setWorksUnder}>
                <SelectTrigger><SelectValue placeholder="Select advocate" /></SelectTrigger>
                <SelectContent>
                  {advocates.map((a) => (
                    <SelectItem key={a.id} value={a.id}>{a.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="ck-wf">Clerks' welfare fund no.</Label>
              <Input id="ck-wf" value={welfareNo} onChange={(e) => setWelfareNo(e.target.value)} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
            <Button onClick={submit} disabled={addMember.isPending}>Add</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
