import { useState, useRef } from "react";
import { useParams } from "react-router-dom";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useRealtimeQuery } from "@/hooks/useRealtimeQuery";
import { fetchCaseById, updateCase, fetchHearings, createHearing, fetchDocuments, uploadDocument, getSignedUrl, fetchEfilingRecords, createEfilingRecord, updateEfilingRecord, fetchPayments, createPayment, fetchCasePaymentSummary } from "@/lib/supabase-helpers";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { StatusBadge } from "@/components/StatusBadge";
import { useToast } from "@/hooks/use-toast";
import { format } from "date-fns";
import { FileUp, Plus, ExternalLink, Gavel, FileText, CreditCard } from "lucide-react";
import { Progress } from "@/components/ui/progress";
import { cn } from "@/lib/utils";

const filingSteps = ["drafting", "review", "signature_pending", "filed", "accepted"];

export default function CaseDetail() {
  const { id } = useParams<{ id: string }>();
  const { toast } = useToast();
  const qc = useQueryClient();
  const fileRef = useRef<HTMLInputElement>(null);

  const { data: caseData, isLoading } = useRealtimeQuery({ queryKey: ["case", id!], queryFn: () => fetchCaseById(id!), table: "cases" });
  const { data: hearings = [] } = useRealtimeQuery({ queryKey: ["hearings", id!], queryFn: () => fetchHearings(id!), table: "hearings" });
  const { data: documents = [] } = useRealtimeQuery({ queryKey: ["documents", id!], queryFn: () => fetchDocuments(id!), table: "documents" });
  const { data: efilingRecords = [] } = useRealtimeQuery({ queryKey: ["efiling", id!], queryFn: () => fetchEfilingRecords(id!), table: "efiling_records" });
  const { data: payments = [] } = useRealtimeQuery({ queryKey: ["payments", id!], queryFn: () => fetchPayments(id!), table: "payments" });
  const { data: financialSummary } = useRealtimeQuery({ 
    queryKey: ["case-financial-summary", id!], 
    queryFn: () => fetchCasePaymentSummary(id!), 
    table: "payments" 
  });

  // Hearing form
  const [hearingOpen, setHearingOpen] = useState(false);
  const [hearingForm, setHearingForm] = useState({ hearing_date: "", stage: "", notes: "", next_action: "" });
  const createHearingMut = useMutation({
    mutationFn: () => createHearing({ ...hearingForm, case_id: id! }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["hearings", id] }); setHearingOpen(false); toast({ title: "Hearing added" }); },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  // Document upload
  const [docType, setDocType] = useState("plaint");
  const uploadMut = useMutation({
    mutationFn: (file: File) => uploadDocument(id!, file, docType),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["documents", id] }); toast({ title: "Document uploaded" }); },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  // E-Filing form
  const [efilingOpen, setEfilingOpen] = useState(false);
  const [efilingForm, setEfilingForm] = useState({ document_type: "plaint", filing_date: "" });
  const createEfilingMut = useMutation({
    mutationFn: () => createEfilingRecord({ ...efilingForm, case_id: id! }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["efiling", id] }); setEfilingOpen(false); toast({ title: "E-Filing record created" }); },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  // Ledger form
  const [paymentOpen, setPaymentOpen] = useState(false);
  const [paymentForm, setPaymentForm] = useState({ total_fee: "", paid_amount: "", payment_mode: "upi", paid_date: "", transaction_type: "revenue" as const, notes: "" });
  const createPaymentMut = useMutation({
    mutationFn: () => {
      return createPayment({ 
        case_id: id!, 
        total_fee: Number(paymentForm.total_fee || caseData?.total_fee || 0), 
        paid_amount: Number(paymentForm.paid_amount), 
        balance_amount: 0, 
        payment_mode: paymentForm.payment_mode, 
        paid_date: paymentForm.paid_date || undefined,
        transaction_type: paymentForm.transaction_type,
        notes: paymentForm.notes
      });
    },
    onSuccess: () => { 
      qc.invalidateQueries({ queryKey: ["payments", id] }); 
      qc.invalidateQueries({ queryKey: ["case-financial-summary", id] });
      setPaymentOpen(false); 
      setPaymentForm({ ...paymentForm, paid_amount: "", notes: "" });
      toast({ title: "Ledger entry added" }); 
    },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  // Update case stage/status
  const updateCaseMut = useMutation({
    mutationFn: (updates: Record<string, any>) => updateCase(id!, updates),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["case", id] }); toast({ title: "Case updated" }); },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  // Update efiling status
  const updateEfilingMut = useMutation({
    mutationFn: ({ recordId, updates }: { recordId: string; updates: Record<string, any> }) => updateEfilingRecord(recordId, updates),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["efiling", id] }); toast({ title: "E-Filing updated" }); },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  const openFile = async (filePath: string) => {
    try {
      const url = await getSignedUrl(filePath);
      window.open(url, "_blank");
    } catch (e: any) {
      toast({ title: "Error", description: e.message, variant: "destructive" });
    }
  };

  if (isLoading) return <div className="flex items-center justify-center h-64 text-muted-foreground">Loading case...</div>;
  if (!caseData) return <div className="text-center py-8 text-muted-foreground">Case not found.</div>;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-serif font-bold text-foreground">{caseData.case_title}</h1>
        <p className="text-sm text-muted-foreground mt-1">
          {caseData.case_number && `${caseData.case_number} • `}{caseData.court_name || "No court"} • Client: {(caseData.clients as any)?.name}
        </p>
      </div>

      <Tabs defaultValue="overview">
        <TabsList>
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="documents">Documents</TabsTrigger>
          <TabsTrigger value="hearings">Hearings</TabsTrigger>
          <TabsTrigger value="efiling">E-Filing</TabsTrigger>
          <TabsTrigger value="payments">Payments</TabsTrigger>
        </TabsList>

        {/* OVERVIEW */}
        <TabsContent value="overview">
          <Card>
            <CardContent className="pt-6 space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* FINANCIAL QUICK VIEW */}
                <Card className="bg-muted/30 border-dashed">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm font-bold flex items-center gap-2">
                      <CreditCard className="h-4 w-4 text-primary" />
                      Financial Summary
                    </CardTitle>
                    <CardDescription className="text-[10px] uppercase">Ledger Statement Overview</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <p className="text-[10px] font-bold text-muted-foreground uppercase">Base Fee</p>
                        <p className="text-lg font-black text-foreground">₹{financialSummary?.total_fee?.toLocaleString() || "0"}</p>
                      </div>
                      <div>
                        <p className="text-[10px] font-bold text-muted-foreground uppercase">Total Expenses</p>
                        <p className="text-lg font-black text-rose-600">₹{financialSummary?.total_expenses?.toLocaleString() || "0"}</p>
                      </div>
                    </div>
                    <div className="pt-2 border-t border-border/50">
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="text-[10px] font-bold text-muted-foreground uppercase">Total Paid</p>
                          <p className="text-xl font-black text-emerald-600">₹{financialSummary?.total_paid?.toLocaleString() || "0"}</p>
                        </div>
                        <div className="text-right">
                          <p className="text-[10px] font-bold text-muted-foreground uppercase">Outstanding Balance</p>
                          <p className={cn("text-xl font-black", (financialSummary?.balance ?? 0) > 0 ? "text-destructive" : "text-emerald-600")}>
                            ₹{financialSummary?.balance?.toLocaleString() || "0"}
                          </p>
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>

                {/* CASE INFO */}
                <div className="space-y-4">
                  <p className="text-sm font-semibold border-b pb-2">Case Registry & Status</p>
                  <div className="grid grid-cols-2 gap-4">
                    <div><p className="text-xs text-muted-foreground">App Stage</p><StatusBadge status={caseData.stage} /></div>
                    <div><p className="text-xs text-muted-foreground">Case Status</p><StatusBadge status={caseData.status} /></div>
                    <div><p className="text-xs text-muted-foreground">Type</p><p className="text-sm font-medium">{caseData.case_type || "—"}</p></div>
                    <div><p className="text-xs text-muted-foreground">Filing Date</p><p className="text-sm font-medium">{caseData.filing_date ? format(new Date(caseData.filing_date), "dd MMM yyyy") : "—"}</p></div>
                  </div>
                  <div className="flex gap-3">
                    <Select defaultValue={caseData.stage} onValueChange={(v) => updateCaseMut.mutate({ stage: v })}>
                      <SelectTrigger className="w-full h-9 rounded-xl"><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {["filing", "evidence", "argument", "judgment"].map((s) => <SelectItem key={s} value={s}>{s}</SelectItem>)}
                      </SelectContent>
                    </Select>
                    <Select defaultValue={caseData.status} onValueChange={(v) => updateCaseMut.mutate({ status: v })}>
                      <SelectTrigger className="w-full h-9 rounded-xl"><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {["active", "closed", "appeal"].map((s) => <SelectItem key={s} value={s}>{s}</SelectItem>)}
                      </SelectContent>
                    </Select>
                  </div>
                </div>
              </div>

              <div className="space-y-4">
                <p className="text-sm font-semibold border-b pb-2">Party Details</p>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="space-y-4">
                    <div className="space-y-2">
                      <Label className="text-xs text-muted-foreground">Our Representation</Label>
                      <Select defaultValue={caseData.representation_type} onValueChange={(v) => updateCaseMut.mutate({ representation_type: v })}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          <SelectItem value="petitioner">Petitioner / Plaintiff</SelectItem>
                          <SelectItem value="respondent">Respondent / Defendant</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                    <div className="space-y-2">
                      <Label className="text-xs text-muted-foreground">{caseData.representation_type === 'petitioner' ? 'Respondent Name' : 'Petitioner Name'}</Label>
                      <Input
                        defaultValue={caseData.opposing_party}
                        placeholder="Opposing Party Name"
                        onBlur={(e) => {
                          if (e.target.value !== caseData.opposing_party) {
                            updateCaseMut.mutate({ opposing_party: e.target.value });
                          }
                        }}
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    <div className="space-y-2">
                      <Label className="text-xs text-muted-foreground">Opposing Advocate</Label>
                      <Input
                        defaultValue={caseData.opposing_advocate}
                        onBlur={(e) => {
                          if (e.target.value !== caseData.opposing_advocate) {
                            updateCaseMut.mutate({ opposing_advocate: e.target.value });
                          }
                        }}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label className="text-xs text-muted-foreground">Advocate Phone</Label>
                      <Input
                        defaultValue={caseData.opposing_advocate_phone}
                        onBlur={(e) => {
                          if (e.target.value !== caseData.opposing_advocate_phone) {
                            updateCaseMut.mutate({ opposing_advocate_phone: e.target.value });
                          }
                        }}
                      />
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* DOCUMENTS */}
        <TabsContent value="documents">
          <Card>
            <CardHeader className="pb-3 flex flex-row items-center justify-between">
              <CardTitle className="text-lg">Documents</CardTitle>
              <div className="flex items-center gap-2">
                <Select value={docType} onValueChange={setDocType}>
                  <SelectTrigger className="w-32"><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {["plaint", "affidavit", "vakalat", "order", "judgment"].map((t) => <SelectItem key={t} value={t}>{t}</SelectItem>)}
                  </SelectContent>
                </Select>
                <input ref={fileRef} type="file" accept=".pdf" className="hidden" onChange={(e) => { if (e.target.files?.[0]) uploadMut.mutate(e.target.files[0]); }} />
                <Button size="sm" onClick={() => fileRef.current?.click()} disabled={uploadMut.isPending}>
                  <FileUp className="h-4 w-4 mr-2" /> {uploadMut.isPending ? "Uploading..." : "Upload PDF"}
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              {documents.length === 0 ? <p className="text-sm text-muted-foreground py-4">No documents uploaded.</p> : (
                <Table>
                  <TableHeader><TableRow><TableHead>Type</TableHead><TableHead>Version</TableHead><TableHead>Uploaded</TableHead><TableHead></TableHead></TableRow></TableHeader>
                  <TableBody>
                    {documents.map((d: any) => (
                      <TableRow key={d.id}>
                        <TableCell><StatusBadge status={d.document_type} /></TableCell>
                        <TableCell>v{d.version}</TableCell>
                        <TableCell>{format(new Date(d.uploaded_at), "dd MMM yyyy")}</TableCell>
                        <TableCell><Button variant="ghost" size="icon" onClick={() => openFile(d.file_url)}><ExternalLink className="h-4 w-4" /></Button></TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* HEARINGS */}
        <TabsContent value="hearings">
          <Card>
            <CardHeader className="pb-3 flex flex-row items-center justify-between">
              <CardTitle className="text-lg flex items-center gap-2"><Gavel className="h-5 w-5" /> Hearings</CardTitle>
              <Dialog open={hearingOpen} onOpenChange={setHearingOpen}>
                <DialogTrigger asChild><Button size="sm"><Plus className="h-4 w-4 mr-2" /> Add Hearing</Button></DialogTrigger>
                <DialogContent>
                  <DialogHeader><DialogTitle>Add Hearing</DialogTitle></DialogHeader>
                  <form onSubmit={(e) => { e.preventDefault(); createHearingMut.mutate(); }} className="space-y-4">
                    <div className="space-y-2"><Label>Hearing Date *</Label><Input type="date" value={hearingForm.hearing_date} onChange={(e) => setHearingForm({ ...hearingForm, hearing_date: e.target.value })} required /></div>
                    <div className="space-y-2"><Label>Stage</Label><Input value={hearingForm.stage} onChange={(e) => setHearingForm({ ...hearingForm, stage: e.target.value })} /></div>
                    <div className="space-y-2"><Label>Notes</Label><Textarea value={hearingForm.notes} onChange={(e) => setHearingForm({ ...hearingForm, notes: e.target.value })} /></div>
                    <div className="space-y-2"><Label>Next Action</Label><Input value={hearingForm.next_action} onChange={(e) => setHearingForm({ ...hearingForm, next_action: e.target.value })} /></div>
                    <Button type="submit" className="w-full" disabled={createHearingMut.isPending}>Add Hearing</Button>
                  </form>
                </DialogContent>
              </Dialog>
            </CardHeader>
            <CardContent>
              {hearings.length === 0 ? <p className="text-sm text-muted-foreground py-4">No hearings recorded.</p> : (
                <Table>
                  <TableHeader><TableRow><TableHead>Date</TableHead><TableHead>Stage</TableHead><TableHead>Notes</TableHead><TableHead>Next Action</TableHead></TableRow></TableHeader>
                  <TableBody>
                    {hearings.map((h: any) => {
                      const isUrgent = new Date(h.hearing_date) <= new Date(Date.now() + 2 * 86400000);
                      return (
                        <TableRow key={h.id} className={isUrgent ? "bg-destructive/5" : ""}>
                          <TableCell className={`font-medium ${isUrgent ? "text-destructive" : ""}`}>{format(new Date(h.hearing_date), "dd MMM yyyy")}</TableCell>
                          <TableCell>{h.stage || "—"}</TableCell>
                          <TableCell className="max-w-xs truncate">{h.notes || "—"}</TableCell>
                          <TableCell>{h.next_action || "—"}</TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* E-FILING */}
        <TabsContent value="efiling">
          <Card>
            <CardHeader className="pb-3 flex flex-row items-center justify-between">
              <CardTitle className="text-lg flex items-center gap-2"><FileText className="h-5 w-5" /> E-Filing Status</CardTitle>
              <Dialog open={efilingOpen} onOpenChange={setEfilingOpen}>
                <DialogTrigger asChild><Button size="sm"><Plus className="h-4 w-4 mr-2" /> New Filing</Button></DialogTrigger>
                <DialogContent>
                  <DialogHeader><DialogTitle>Create E-Filing Record</DialogTitle></DialogHeader>
                  <form onSubmit={(e) => { e.preventDefault(); createEfilingMut.mutate(); }} className="space-y-4">
                    <div className="space-y-2">
                      <Label>Document Type</Label>
                      <Select value={efilingForm.document_type} onValueChange={(v) => setEfilingForm({ ...efilingForm, document_type: v })}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>{["plaint", "affidavit", "vakalat", "order", "judgment"].map((t) => <SelectItem key={t} value={t}>{t}</SelectItem>)}</SelectContent>
                      </Select>
                    </div>
                    <div className="space-y-2"><Label>Filing Date</Label><Input type="date" value={efilingForm.filing_date} onChange={(e) => setEfilingForm({ ...efilingForm, filing_date: e.target.value })} /></div>
                    <Button type="submit" className="w-full" disabled={createEfilingMut.isPending}>Create Record</Button>
                  </form>
                </DialogContent>
              </Dialog>
            </CardHeader>
            <CardContent className="space-y-4">
              {efilingRecords.length === 0 ? <p className="text-sm text-muted-foreground py-4">No e-filing records.</p> :
                efilingRecords.map((e: any) => {
                  const stepIndex = filingSteps.indexOf(e.status);
                  const progress = ((stepIndex + 1) / filingSteps.length) * 100;
                  return (
                    <div key={e.id} className="border border-border rounded-lg p-4 space-y-3">
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="font-medium text-sm">{e.document_type}</p>
                          <StatusBadge status={e.status} />
                        </div>
                        <Select defaultValue={e.status} onValueChange={(v) => updateEfilingMut.mutate({ recordId: e.id, updates: { status: v } })}>
                          <SelectTrigger className="w-44"><SelectValue /></SelectTrigger>
                          <SelectContent>{["drafting", "review", "signature_pending", "filed", "defect", "accepted"].map((s) => <SelectItem key={s} value={s}>{s.replace(/_/g, " ")}</SelectItem>)}</SelectContent>
                        </Select>
                      </div>
                      <Progress value={e.status === "defect" ? 0 : progress} className="h-2" />
                      {e.defect_notes && <p className="text-xs text-destructive">Defect: {e.defect_notes}</p>}
                    </div>
                  );
                })
              }
            </CardContent>
          </Card>
        </TabsContent>

        {/* PAYMENTS */}
        <TabsContent value="payments">
          <Card>
            <CardHeader className="pb-3 flex flex-row items-center justify-between">
              <CardTitle className="text-lg flex items-center gap-2"><CreditCard className="h-5 w-5" /> Payments</CardTitle>
              <Dialog open={paymentOpen} onOpenChange={setPaymentOpen}>
                <DialogTrigger asChild><Button size="sm"><Plus className="h-4 w-4 mr-2" /> Add Payment</Button></DialogTrigger>
                <DialogContent>
                  <DialogHeader><DialogTitle>Add Ledger Entry</DialogTitle></DialogHeader>
                  <form onSubmit={(e) => { e.preventDefault(); createPaymentMut.mutate(); }} className="space-y-4 pt-4">
                    <div className="flex p-1 bg-muted rounded-lg">
                      <button 
                        type="button"
                        onClick={() => setPaymentForm({ ...paymentForm, transaction_type: 'revenue' })}
                        className={cn("flex-1 py-1.5 text-[10px] font-bold rounded-md transition-all", paymentForm.transaction_type === 'revenue' ? "bg-white shadow-sm text-emerald-600" : "text-muted-foreground")}
                      >
                        REVENUE
                      </button>
                      <button 
                        type="button"
                        onClick={() => setPaymentForm({ ...paymentForm, transaction_type: 'expense' })}
                        className={cn("flex-1 py-1.5 text-[10px] font-bold rounded-md transition-all", paymentForm.transaction_type === 'expense' ? "bg-white shadow-sm text-rose-600" : "text-muted-foreground")}
                      >
                        EXPENSE
                      </button>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label>{paymentForm.transaction_type === 'revenue' ? 'Payment (₹)' : 'Expense (₹)'}</Label>
                        <Input type="number" value={paymentForm.paid_amount} onChange={(e) => setPaymentForm({ ...paymentForm, paid_amount: e.target.value })} required />
                      </div>
                      <div className="space-y-2">
                        <Label>Date</Label>
                        <Input type="date" value={paymentForm.paid_date} onChange={(e) => setPaymentForm({ ...paymentForm, paid_date: e.target.value })} />
                      </div>
                    </div>
                    <div className="space-y-2">
                      <Label>Payment Mode</Label>
                      <Select value={paymentForm.payment_mode} onValueChange={(v) => setPaymentForm({ ...paymentForm, payment_mode: v })}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>{["cash", "upi", "bank_transfer", "cheque", "online"].map((m) => <SelectItem key={m} value={m}>{m.replace(/_/g, " ")}</SelectItem>)}</SelectContent>
                      </Select>
                    </div>
                    <div className="space-y-2">
                      <Label>Notes (e.g. Court fee, Second installment)</Label>
                      <Input value={paymentForm.notes} onChange={(e) => setPaymentForm({ ...paymentForm, notes: e.target.value })} placeholder="Optional description" />
                    </div>
                    <Button type="submit" className={cn("w-full h-11", paymentForm.transaction_type === 'revenue' ? "bg-emerald-600 hover:bg-emerald-700" : "bg-rose-600 hover:bg-rose-700")} disabled={createPaymentMut.isPending}>
                      {createPaymentMut.isPending ? "Recording..." : `Confirm ${paymentForm.transaction_type === 'revenue' ? 'Revenue' : 'Expense'}`}
                    </Button>
                  </form>
                </DialogContent>
              </Dialog>
            </CardHeader>
            <CardContent>
              {payments.length === 0 ? <p className="text-sm text-muted-foreground py-4">No entries recorded.</p> : (
                <Table>
                  <TableHeader><TableRow><TableHead>Type</TableHead><TableHead>Description</TableHead><TableHead>Amount</TableHead><TableHead>Mode</TableHead><TableHead>Date</TableHead></TableRow></TableHeader>
                  <TableBody>
                    {payments.map((p: any) => {
                      const isExp = p.transaction_type === 'expense';
                      return (
                        <TableRow key={p.id}>
                          <TableCell>
                            <span className={cn("px-2 py-0.5 rounded text-[10px] font-bold uppercase", isExp ? "bg-rose-50 text-rose-600" : "bg-emerald-50 text-emerald-600")}>
                              {p.transaction_type || 'Revenue'}
                            </span>
                          </TableCell>
                          <TableCell className="text-sm">{p.notes || "—"}</TableCell>
                          <TableCell className={cn("font-bold", isExp ? "text-rose-600" : "text-emerald-600 font-black")}>
                            {isExp ? "+" : "-"} ₹{p.paid_amount?.toLocaleString()}
                          </TableCell>
                          <TableCell className="text-muted-foreground text-xs">{p.payment_mode || "—"}</TableCell>
                          <TableCell className="text-xs">{p.paid_date ? format(new Date(p.paid_date), "dd MMM yyyy") : "—"}</TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
