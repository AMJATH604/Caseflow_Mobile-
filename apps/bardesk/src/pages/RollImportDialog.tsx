import { useMemo, useState } from 'react';
import { FileSpreadsheet, TriangleAlert, Upload } from 'lucide-react';
import { toast } from 'sonner';

import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';

/**
 * Bulk import of the association's roll.
 *
 * Onboarding a bar means entering everyone it already has — 200 to 400
 * names that exist today on a printed register or in the secretary's Excel
 * file. Nobody is typing those one at a time, and if the only way in is a
 * form then the association never finishes onboarding and the whole thing
 * stalls at step one.
 *
 * Rows arrive with no user_id: they are names on a register, not accounts.
 * Each advocate later claims their own row from CaseFlow by entering the
 * association code and their enrolment number.
 */
type ParsedRow = {
  name: string;
  enrollment_number: string | null;
  mobile: string;
  line: number;
  error?: string;
};

function parse(text: string): ParsedRow[] {
  const rows: ParsedRow[] = [];
  const lines = text.split(/\r?\n/);

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i].trim();
    if (!raw) continue;

    // Comma or tab, so a paste straight out of Excel works as well as a CSV.
    const cells = raw.split(/\t|,/).map((c) => c.trim().replace(/^"|"$/g, ''));

    // Skip a header row if the file has one.
    if (i === 0 && /name/i.test(cells[0] ?? '')) continue;

    const [name, enrolment, mobile] = cells;
    const row: ParsedRow = {
      name: name ?? '',
      enrollment_number: enrolment && enrolment !== '' ? enrolment : null,
      mobile: mobile ?? '',
      line: i + 1,
    };

    if (!row.name) row.error = 'No name';
    else if (!row.enrollment_number && !row.mobile) {
      // Without one of these the advocate has nothing to claim the row with.
      row.error = 'Needs an enrolment number or a mobile';
    }

    rows.push(row);
  }
  return rows;
}

export function RollImportDialog({
  open,
  onOpenChange,
  associationId,
  onImported,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  associationId: string;
  onImported: () => void;
}) {
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);

  const rows = useMemo(() => parse(text), [text]);
  const valid = rows.filter((r) => !r.error);
  const invalid = rows.filter((r) => r.error);

  async function handleImport() {
    if (valid.length === 0) return;
    setBusy(true);
    try {
      // Inserted in chunks: a 400-row single statement is fine for Postgres
      // but a long way to fail all at once on one bad value.
      const chunks: ParsedRow[][] = [];
      for (let i = 0; i < valid.length; i += 100) chunks.push(valid.slice(i, i + 100));

      let inserted = 0;
      for (const chunk of chunks) {
        const { error } = await supabase.from('bar_members').insert(
          chunk.map((r) => ({
            association_id: associationId,
            name: r.name,
            enrollment_number: r.enrollment_number,
            mobile: r.mobile,
            status: 'active',
            member_class: 'advocate',
            is_caseflow_user: false,
          })),
        );
        if (error) throw new Error(error.message);
        inserted += chunk.length;
      }

      toast.success(`${inserted} members added to the roll`, {
        description: 'They can now claim their entry from CaseFlow.',
      });
      setText('');
      onOpenChange(false);
      onImported();
    } catch (e) {
      toast.error('Import failed', {
        description: e instanceof Error ? e.message : 'Check the data and try again.',
      });
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={(v) => { onOpenChange(v); if (!v) setText(''); }}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <FileSpreadsheet className="h-4 w-4 text-primary" />
            Import the roll
          </DialogTitle>
          <DialogDescription>
            Paste from Excel, or any comma-separated list. One member per line:
            <span className="ml-1 font-mono text-foreground">name, enrolment number, mobile</span>
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="roll-paste">Members</Label>
            <Textarea
              id="roll-paste"
              rows={10}
              className="font-mono text-xs"
              placeholder={'Fathima Begum, MS/1234/2015, 9876543210\nR. Subramanian, MS/0221/1996, 9445012345'}
              value={text}
              onChange={(e) => setText(e.target.value)}
            />
          </div>

          {rows.length > 0 && (
            <div className="grid grid-cols-2 gap-3">
              <div className="rounded-lg border border-border bg-card p-3">
                <p className="font-mono text-xl font-semibold tabular-nums">{valid.length}</p>
                <p className="text-2xs uppercase tracking-wide text-muted-foreground">Ready to import</p>
              </div>
              <div className={`rounded-lg border p-3 ${
                invalid.length > 0 ? 'border-destructive/30 bg-destructive/[0.04]' : 'border-border bg-card'
              }`}>
                <p className="font-mono text-xl font-semibold tabular-nums">{invalid.length}</p>
                <p className="text-2xs uppercase tracking-wide text-muted-foreground">Will be skipped</p>
              </div>
            </div>
          )}

          {invalid.length > 0 && (
            <div className="rounded-lg border border-destructive/25 bg-destructive/[0.04] p-3">
              <p className="mb-2 flex items-center gap-2 text-sm font-medium text-destructive">
                <TriangleAlert className="h-3.5 w-3.5" />
                These lines will not be imported
              </p>
              <ul className="space-y-1 text-xs text-muted-foreground">
                {invalid.slice(0, 6).map((r) => (
                  <li key={r.line} className="font-mono">
                    Line {r.line}: {r.error}
                  </li>
                ))}
                {invalid.length > 6 && <li>…and {invalid.length - 6} more</li>}
              </ul>
            </div>
          )}

          {valid.length > 0 && (
            <div className="rounded-lg border border-border">
              <p className="border-b border-border bg-muted/40 px-3 py-2 text-2xs font-semibold uppercase tracking-wider text-muted-foreground">
                Preview — first five
              </p>
              <table className="w-full text-xs">
                <tbody>
                  {valid.slice(0, 5).map((r) => (
                    <tr key={r.line} className="border-b border-border/50 last:border-0">
                      <td className="px-3 py-2 font-medium">{r.name}</td>
                      <td className="px-3 py-2 font-mono text-muted-foreground">
                        {r.enrollment_number ?? '—'}
                      </td>
                      <td className="px-3 py-2 text-muted-foreground">{r.mobile || '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Cancel</Button>
          <Button onClick={handleImport} disabled={busy || valid.length === 0}>
            <Upload className="mr-1.5 h-4 w-4" />
            {busy ? 'Importing…' : `Import ${valid.length}`}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
