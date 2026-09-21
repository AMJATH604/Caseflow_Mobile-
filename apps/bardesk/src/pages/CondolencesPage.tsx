import { useState } from 'react';
import { Flower2, Plus, Users } from 'lucide-react';
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
import { Switch } from '@/components/ui/switch';
import { Textarea } from '@/components/ui/textarea';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select';
import { useCurrentAdmin, useMembers } from '@/hooks/useBarDesk';
import { useCondolences, usePublishCondolence } from '@/hooks/useBarOperations';

/**
 * Publishing a death.
 *
 * Kept apart from notices because the shape is fixed, the urgency is
 * different, and the association keeps it as a record. By convention the bar
 * does not take up work that day, so the time of the meeting matters as much
 * as the fact — an advocate setting out from a taluk at 8am needs to know
 * before they leave, not from another advocate at the court gate.
 *
 * Publishing also marks the member deceased, which is what stops a renewal
 * reminder later going to someone who has died.
 */
export default function CondolencesPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id ?? '';
  const { data: rows, isLoading, error } = useCondolences(associationId);
  const { data: members } = useMembers(associationId);
  const publish = usePublishCondolence(associationId);

  const [open, setOpen] = useState(false);
  const [memberId, setMemberId] = useState<string>('');
  const [name, setName] = useState('');
  const [enrolment, setEnrolment] = useState('');
  const [dod, setDod] = useState(new Date().toISOString().slice(0, 10));
  const [age, setAge] = useState('');
  const [meetingAt, setMeetingAt] = useState('');
  const [venue, setVenue] = useState('');
  const [noWork, setNoWork] = useState(true);
  const [message, setMessage] = useState('');

  function pickMember(id: string) {
    setMemberId(id);
    const m = members?.find((x) => x.id === id);
    if (m) {
      setName(m.name);
      setEnrolment(m.enrollment_number ?? '');
      if (m.date_of_birth) {
        const years = new Date().getFullYear() - new Date(m.date_of_birth).getFullYear();
        setAge(String(years));
      }
    }
  }

  function reset() {
    setMemberId(''); setName(''); setEnrolment(''); setAge('');
    setDod(new Date().toISOString().slice(0, 10));
    setMeetingAt(''); setVenue(''); setNoWork(true); setMessage('');
  }

  async function submit() {
    if (!name.trim()) { toast.error('Enter the name'); return; }
    try {
      await publish.mutateAsync({
        member_id: memberId || null,
        deceased_name: name.trim(),
        enrolment_number: enrolment.trim() || null,
        date_of_death: dod,
        age: age ? Number(age) : null,
        meeting_at: meetingAt ? new Date(meetingAt).toISOString() : null,
        meeting_venue: venue.trim() || null,
        no_work_resolution: noWork,
        message: message.trim() || null,
      });
      toast.success('Published — every member has been notified');
      setOpen(false);
      reset();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Could not publish');
    }
  }

  if (isLoading) return <TableSkeleton />;
  if (error) return <ErrorState error={error} />;

  return (
    <div className="space-y-6">
      <PageHeader
        title="Condolences"
        description="Announce a passing and call the condolence meeting. Reaches every member's phone at once."
        actions={
          <Button onClick={() => setOpen(true)}>
            <Plus className="mr-1.5 h-4 w-4" />
            Publish
          </Button>
        }
      />

      {(rows ?? []).length === 0 ? (
        <EmptyState
          icon={Flower2}
          title="No condolences published"
          description="When a member passes, publishing here notifies the whole bar immediately and records the meeting."
        />
      ) : (
        <div className="space-y-3">
          {rows!.map((c) => (
            <Card key={c.id}>
              <CardContent className="p-5">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="font-display text-lg font-semibold text-foreground">
                      {c.deceased_name}
                    </p>
                    <p className="mt-0.5 text-sm text-muted-foreground">
                      {c.enrolment_number && <span className="font-mono">{c.enrolment_number} · </span>}
                      {c.age ? `Aged ${c.age} · ` : ''}
                      {new Date(c.date_of_death).toLocaleDateString('en-IN', {
                        day: '2-digit', month: 'long', year: 'numeric',
                      })}
                    </p>
                  </div>
                  {c.no_work_resolution && (
                    <Badge variant="outline" className="border-destructive/25 bg-destructive/10 text-destructive">
                      No work resolved
                    </Badge>
                  )}
                </div>

                {c.message && (
                  <p className="mt-3 border-l-2 border-border pl-3 text-sm leading-relaxed text-muted-foreground">
                    {c.message}
                  </p>
                )}

                {c.meeting_at && (
                  <div className="mt-4 flex flex-wrap items-center gap-2 rounded-lg bg-muted/50 px-3 py-2 text-sm">
                    <Users className="h-3.5 w-3.5 text-muted-foreground" />
                    <span className="font-medium text-foreground">Condolence meeting</span>
                    <span className="text-muted-foreground">
                      {new Date(c.meeting_at).toLocaleString('en-IN', {
                        day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit',
                      })}
                      {c.meeting_venue ? ` · ${c.meeting_venue}` : ''}
                    </span>
                  </div>
                )}
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>Publish a condolence</DialogTitle>
            <DialogDescription>
              This notifies every member immediately and marks the member deceased on the roll,
              so no renewal reminder is ever sent to them.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <div className="space-y-1.5">
              <Label>Member on the roll</Label>
              <Select value={memberId} onValueChange={pickMember}>
                <SelectTrigger><SelectValue placeholder="Select, or leave blank if not a member" /></SelectTrigger>
                <SelectContent>
                  {(members ?? []).filter((m) => !m.is_deceased).map((m) => (
                    <SelectItem key={m.id} value={m.id}>
                      {m.name}{m.enrollment_number ? ` · ${m.enrollment_number}` : ''}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="col-span-2 space-y-1.5">
                <Label htmlFor="cd-name">Name</Label>
                <Input id="cd-name" value={name} onChange={(e) => setName(e.target.value)} />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="cd-enr">Enrolment no.</Label>
                <Input id="cd-enr" value={enrolment} onChange={(e) => setEnrolment(e.target.value)} />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="cd-age">Age</Label>
                <Input id="cd-age" type="number" value={age} onChange={(e) => setAge(e.target.value)} />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="cd-dod">Date of death</Label>
                <Input id="cd-dod" type="date" value={dod} onChange={(e) => setDod(e.target.value)} />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="cd-meet">Meeting at</Label>
                <Input id="cd-meet" type="datetime-local" value={meetingAt} onChange={(e) => setMeetingAt(e.target.value)} />
              </div>
              <div className="col-span-2 space-y-1.5">
                <Label htmlFor="cd-venue">Venue</Label>
                <Input id="cd-venue" placeholder="Bar Association Hall" value={venue} onChange={(e) => setVenue(e.target.value)} />
              </div>
            </div>

            <div className="flex items-center justify-between rounded-lg border border-border p-3">
              <div>
                <p className="text-sm font-medium">No work resolution</p>
                <p className="text-xs text-muted-foreground">The bar does not take up work that day</p>
              </div>
              <Switch checked={noWork} onCheckedChange={setNoWork} />
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="cd-msg">Message</Label>
              <Textarea id="cd-msg" rows={3} value={message} onChange={(e) => setMessage(e.target.value)} />
            </div>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
            <Button onClick={submit} disabled={publish.isPending}>
              {publish.isPending ? 'Publishing…' : 'Publish & notify'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
