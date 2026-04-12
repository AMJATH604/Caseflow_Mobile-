import { useRealtimeQuery } from "@/hooks/useRealtimeQuery";
import { fetchEfilingRecords, createEfilingRecord, fetchCases } from "@/lib/supabase-helpers";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { StatusBadge } from "@/components/StatusBadge";
import { Progress } from "@/components/ui/progress";
import { FileText, Plus, ChevronRight, Layout } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";
import { useMutation, useQueryClient } from "@tanstack/react-query";

const filingSteps = ["drafting", "review", "signature_pending", "filed", "accepted"];

export default function EFiling() {
  const { data: records = [], isLoading } = useRealtimeQuery({ queryKey: ["efiling-all"], queryFn: () => fetchEfilingRecords(), table: "efiling_records" });
  const { data: cases = [] } = useRealtimeQuery({ queryKey: ["cases-list"], queryFn: () => fetchCases(), table: "cases" });
  const [open, setOpen] = useState(false);
  const [caseId, setCaseId] = useState("");
  const [docType, setDocType] = useState<any>("plaint");
  const [status, setStatus] = useState<any>("drafting");
  const navigate = useNavigate();
  const { toast } = useToast();
  const qc = useQueryClient();

  const mutation = useMutation({
    mutationFn: (data: any) => createEfilingRecord(data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["efiling-all"] });
      setOpen(false);
      resetForm();
      toast({ title: "E-Filing record created" });
    },
    onError: (err: any) => {
      toast({ title: "Error creating record", description: err.message, variant: "destructive" });
    }
  });

  const resetForm = () => {
    setCaseId("");
    setDocType("plaint");
    setStatus("drafting");
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!caseId) return;
    mutation.mutate({ case_id: caseId, document_type: docType, status });
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-serif font-bold text-foreground">E-Filing</h1>
          <p className="text-sm text-muted-foreground mt-1">Track filing progress</p>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button size="sm" className="md:h-10 md:px-4 flex items-center gap-2">
              <Plus className="h-4 w-4" /> <span className="hidden xs:inline">New Filing</span><span className="xs:hidden">New</span>
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>New E-Filing Record</DialogTitle>
            </DialogHeader>
            <form onSubmit={handleSubmit} className="space-y-4 pt-4">
              <div className="space-y-2">
                <Label>Select Case</Label>
                <Select value={caseId} onValueChange={setCaseId} required>
                  <SelectTrigger>
                    <SelectValue placeholder="Select a case" />
                  </SelectTrigger>
                  <SelectContent>
                    {cases.map((c: any) => (
                      <SelectItem key={c.id} value={c.id}>{c.case_title} ({c.case_number})</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Document Type</Label>
                  <Select value={docType} onValueChange={setDocType}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="plaint">Plaint</SelectItem>
                      <SelectItem value="affidavit">Affidavit</SelectItem>
                      <SelectItem value="vakalat">Vakalat</SelectItem>
                      <SelectItem value="order">Order</SelectItem>
                      <SelectItem value="judgment">Judgment</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>Status</Label>
                  <Select value={status} onValueChange={setStatus}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="drafting">Drafting</SelectItem>
                      <SelectItem value="review">Review</SelectItem>
                      <SelectItem value="signature_pending">Signature Pending</SelectItem>
                      <SelectItem value="filed">Filed</SelectItem>
                      <SelectItem value="defect">Defect</SelectItem>
                      <SelectItem value="accepted">Accepted</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <Button type="submit" className="w-full" disabled={mutation.isPending}>
                {mutation.isPending ? "Creating..." : "Create Record"}
              </Button>
            </form>
          </DialogContent>
        </Dialog>
      </div>
      <Card>
        <CardHeader className="pb-3"><CardTitle className="text-lg flex items-center gap-2"><FileText className="h-5 w-5" /> All Filings</CardTitle></CardHeader>
        <CardContent>
          {isLoading ? <p className="text-sm text-muted-foreground">Loading...</p> : records.length === 0 ? (
            <p className="text-sm text-muted-foreground py-8 text-center">No e-filing records.</p>
          ) : (
            <div className="space-y-4">
              {/* Desktop View Table */}
              <div className="hidden md:block">
                <Table>
                  <TableHeader><TableRow><TableHead>Case</TableHead><TableHead>Document</TableHead><TableHead>Status</TableHead><TableHead>Progress</TableHead><TableHead>Defect Notes</TableHead></TableRow></TableHeader>
                  <TableBody>
                    {records.map((r: any) => {
                      const stepIndex = filingSteps.indexOf(r.status);
                      const progress = r.status === "defect" ? 0 : ((stepIndex + 1) / filingSteps.length) * 100;
                      return (
                        <TableRow key={r.id} className="cursor-pointer hover:bg-muted/50" onClick={() => navigate(`/cases/${r.case_id}`)}>
                          <TableCell className="font-medium">{(r.cases as any)?.case_title}</TableCell>
                          <TableCell className="capitalize">{r.document_type}</TableCell>
                          <TableCell><StatusBadge status={r.status} /></TableCell>
                          <TableCell className="w-32"><Progress value={progress} className="h-2" /></TableCell>
                          <TableCell className="text-xs text-destructive max-w-xs truncate">{r.defect_notes || "—"}</TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              </div>
              {/* Mobile View Cards */}
              <div className="md:hidden space-y-4">
                {records.map((r: any) => {
                  const stepIndex = filingSteps.indexOf(r.status);
                  const progress = r.status === "defect" ? 0 : ((stepIndex + 1) / filingSteps.length) * 100;
                  return (
                    <div
                      key={r.id}
                      className="p-4 bg-muted/20 rounded-xl border border-border space-y-4 active:bg-muted/40 transition-colors"
                      onClick={() => navigate(`/cases/${r.case_id}`)}
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0 flex-1">
                          <h3 className="font-bold text-base truncate">{(r.cases as any)?.case_title}</h3>
                          <div className="flex items-center gap-1.5 mt-1 text-muted-foreground uppercase text-[10px] font-semibold tracking-wider">
                            <Layout className="h-3 w-3" />
                            <span>{r.document_type}</span>
                          </div>
                        </div>
                        <StatusBadge status={r.status} />
                      </div>

                      <div className="space-y-2">
                        <div className="flex justify-between items-center text-[10px] uppercase font-bold text-muted-foreground/70">
                          <span>Progress</span>
                          <span>{Math.round(progress)}%</span>
                        </div>
                        <Progress value={progress} className="h-2" />
                      </div>

                      {r.defect_notes && (
                        <div className="p-2 bg-destructive/10 border border-destructive/20 rounded-md">
                          <p className="text-[10px] text-destructive font-bold uppercase mb-1">Defect Notes</p>
                          <p className="text-xs text-destructive leading-tight">{r.defect_notes}</p>
                        </div>
                      )}

                      <div className="flex items-center justify-end text-[10px] font-bold uppercase tracking-widest text-muted-foreground pt-1 opacity-60">
                        Details <ChevronRight className="h-3 w-3" />
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
