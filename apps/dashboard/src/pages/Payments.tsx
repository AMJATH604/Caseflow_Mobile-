import { useRealtimeQuery } from "@/hooks/useRealtimeQuery";
import { usePaginatedQuery } from "@/hooks/usePaginatedQuery";
import { fetchPayments, createPayment, fetchCases, deletePayment } from "@/lib/supabase-helpers";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { CreditCard, Plus, Trash2, IndianRupee, Calendar, Banknote, LucideIndianRupee, ChevronLeft, ChevronRight } from "lucide-react";
import { format } from "date-fns";
import { useNavigate } from "react-router-dom";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { cn } from "@/lib/utils";

export default function Payments() {
  const { data: allPayments = [] } = useRealtimeQuery({ queryKey: ["payments-all"], queryFn: () => fetchPayments(), table: "payments" });
  const { data: payments = [], page, totalPages, totalCount, nextPage, prevPage, isLoading, isTransitioning } = usePaginatedQuery({
    queryKey: ["payments-list"],
    queryFn: ({ page, pageSize }) => fetchPayments(undefined, { page, pageSize }),
    pageSize: 25,
    table: "payments",
  });
  const { data: cases = [] } = useRealtimeQuery({ queryKey: ["cases-list"], queryFn: () => fetchCases(), table: "cases" });
  const [open, setOpen] = useState(false);
  const [caseId, setCaseId] = useState("");
  const [totalFee, setTotalFee] = useState("");
  const [paidAmount, setPaidAmount] = useState("");
  const [mode, setMode] = useState<any>("upi");
  const [date, setDate] = useState(format(new Date(), "yyyy-MM-dd"));
  const [type, setType] = useState<'revenue' | 'expense'>('revenue');
  const [notes, setNotes] = useState("");

  const navigate = useNavigate();
  const { toast } = useToast();
  const qc = useQueryClient();

  const mutation = useMutation({
    mutationFn: (data: any) => createPayment(data),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["payments-all"] });
      qc.invalidateQueries({ queryKey: ["payments-list", "paginated"] });
      setOpen(false);
      resetForm();
      toast({ title: "Ledger entry recorded successfully" });
    },
    onError: (err: any) => {
      toast({ title: "Error recording entry", description: err.message, variant: "destructive" });
    }
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => deletePayment(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["payments-all"] });
      qc.invalidateQueries({ queryKey: ["payments-list", "paginated"] });
      toast({ title: "Entry deleted successfully" });
    },
    onError: (err: any) => {
      toast({ title: "Error deleting entry", description: err.message, variant: "destructive" });
    }
  });

  const handleDelete = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    if (window.confirm("Are you sure you want to delete this ledger record?")) {
      deleteMutation.mutate(id);
    }
  };

  const resetForm = () => {
    setCaseId("");
    setTotalFee("");
    setPaidAmount("");
    setMode("upi");
    setDate(format(new Date(), "yyyy-MM-dd"));
    setType('revenue');
    setNotes("");
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!caseId || !totalFee) return;
    
    mutation.mutate({
      case_id: caseId,
      total_fee: Number(totalFee),
      paid_amount: Number(paidAmount || 0),
      balance_amount: 0, 
      payment_mode: mode,
      paid_date: date,
      transaction_type: type,
      notes: notes
    });
  };

  // Grouping payments by Case for a Ledger view
  const groupedPayments = payments.reduce((acc: any, p: any) => {
    const caseTitle = p.cases?.case_title || "Unknown Case";
    if (!acc[caseTitle]) acc[caseTitle] = [];
    acc[caseTitle].push(p);
    return acc;
  }, {});

  const totalRevenue = allPayments.filter((p: any) => (p.transaction_type || 'revenue') === 'revenue')
    .reduce((sum: number, p: any) => sum + Number(p.paid_amount), 0);
  
  const totalExpenses = allPayments.filter((p: any) => p.transaction_type === 'expense')
    .reduce((sum: number, p: any) => sum + Number(p.paid_amount), 0);

  const stats = [
    { label: "Total Revenue", value: `₹${totalRevenue.toLocaleString()}`, color: "text-emerald-600", bg: "bg-emerald-50", icon: Banknote },
    { label: "Case Expenses", value: `₹${totalExpenses.toLocaleString()}`, color: "text-rose-600", bg: "bg-rose-50", icon: LucideIndianRupee },
    { label: "Net Collection", value: `₹${(totalRevenue - totalExpenses).toLocaleString()}`, color: "text-blue-600", bg: "bg-blue-50", icon: CreditCard },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-serif font-bold text-foreground">Financial Ledger</h1>
          <p className="text-sm text-muted-foreground mt-1">Registry of case revenues and expenses</p>
        </div>
        <div className="flex items-center gap-2">
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm" className="md:h-10 md:px-4 flex items-center gap-2">
                <Plus className="h-4 w-4" /> <span className="hidden xs:inline">Add Entry</span><span className="xs:hidden">Add</span>
              </Button>
            </DialogTrigger>
            <DialogContent className="max-w-[95vw] md:max-w-md rounded-2xl">
              <DialogHeader>
                <DialogTitle>Record Ledger Entry</DialogTitle>
              </DialogHeader>
              <form onSubmit={handleSubmit} className="space-y-4 pt-4">
                <div className="flex p-1 bg-muted rounded-lg">
                  <button 
                    type="button"
                    onClick={() => setType('revenue')}
                    className={cn("flex-1 py-1.5 text-xs font-bold rounded-md transition-all", type === 'revenue' ? "bg-white shadow-sm text-emerald-600" : "text-muted-foreground")}
                  >
                    REVENUE
                  </button>
                  <button 
                    type="button"
                    onClick={() => setType('expense')}
                    className={cn("flex-1 py-1.5 text-xs font-bold rounded-md transition-all", type === 'expense' ? "bg-white shadow-sm text-rose-600" : "text-muted-foreground")}
                  >
                    EXPENSE
                  </button>
                </div>

                <div className="space-y-2">
                  <Label>Select Case</Label>
                  <Select value={caseId} onValueChange={setCaseId} required>
                    <SelectTrigger>
                      <SelectValue placeholder="Select a case" />
                    </SelectTrigger>
                    <SelectContent>
                      {cases.map((c: any) => (
                        <SelectItem key={c.id} value={c.id}>{c.case_title}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label>{type === 'revenue' ? 'Total Fee (₹)' : 'Case Fee (₹)'}</Label>
                    <Input type="number" value={totalFee} onChange={(e) => setTotalFee(e.target.value)} required />
                  </div>
                  <div className="space-y-2">
                    <Label>{type === 'revenue' ? 'Payment (₹)' : 'Expense (₹)'}</Label>
                    <Input type="number" value={paidAmount} onChange={(e) => setPaidAmount(e.target.value)} required />
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label>Mode</Label>
                    <Select value={mode} onValueChange={setMode}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="cash">Cash</SelectItem>
                        <SelectItem value="upi">UPI</SelectItem>
                        <SelectItem value="bank_transfer">Bank Transfer</SelectItem>
                        <SelectItem value="cheque">Cheque</SelectItem>
                        <SelectItem value="online">Online</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-2">
                    <Label>Date</Label>
                    <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
                  </div>
                </div>
                <div className="space-y-2">
                  <Label>Notes (Optional)</Label>
                  <Input value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="e.g. Court fee, Process fee, etc." />
                </div>
                <Button type="submit" className={cn("w-full h-11", type === 'revenue' ? "bg-emerald-600 hover:bg-emerald-700" : "bg-rose-600 hover:bg-rose-700")} disabled={mutation.isPending}>
                  {mutation.isPending ? "Recording..." : `Confirm ${type === 'revenue' ? 'Revenue' : 'Expense'}`}
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {stats.map((stat, i) => (
          <div key={i} className={cn("p-5 rounded-2xl border border-border/50 flex items-center justify-between shadow-sm", stat.bg)}>
            <div>
              <p className="text-xs font-bold text-muted-foreground/60 uppercase tracking-wider">{stat.label}</p>
              <p className={cn("text-2xl font-black mt-1", stat.color)}>{stat.value}</p>
            </div>
            <stat.icon className={cn("h-8 w-8 opacity-20", stat.color)} />
          </div>
        ))}
      </div>

      <div className="space-y-8">
        {Object.entries(groupedPayments).map(([caseTitle, trans]: [string, any]) => {
          const caseId = trans[0].case_id;
          const baseFee = Number(trans[0].total_fee || 0);
          const totalPaid = trans.filter((p: any) => (p.transaction_type || 'revenue') === 'revenue')
                               .reduce((sum: number, p: any) => sum + Number(p.paid_amount), 0);
          const totalExp = trans.filter((p: any) => p.transaction_type === 'expense')
                               .reduce((sum: number, p: any) => sum + Number(p.paid_amount), 0);
          const balance = (baseFee + totalExp) - totalPaid;

          return (
            <div key={caseId} className="space-y-3">
              <div className="flex items-end justify-between px-1">
                <div>
                  <h3 className="font-serif font-bold text-lg text-foreground/90">{caseTitle}</h3>
                  <div className="flex items-center gap-3 mt-1">
                    <span className="text-[10px] font-bold text-muted-foreground/50 uppercase tracking-tighter">Balance: ₹{balance.toLocaleString()}</span>
                    <span className="w-1 h-1 rounded-full bg-border" />
                    <span className="text-[10px] font-bold text-muted-foreground/50 uppercase tracking-tighter">Expenses: ₹{totalExp.toLocaleString()}</span>
                  </div>
                </div>
                <Button variant="ghost" size="sm" className="text-xs h-7 text-muted-foreground" onClick={() => navigate(`/cases/${caseId}`)}>
                  View Statement →
                </Button>
              </div>

              <div className="grid grid-cols-1 gap-2">
                {trans.map((p: any) => {
                  const isExp = p.transaction_type === 'expense';
                  return (
                    <div key={p.id} className="flex items-center justify-between p-4 bg-card rounded-xl border border-border/40 hover:border-primary/20 transition-colors shadow-sm">
                      <div className="flex items-center gap-4">
                        <div className={cn("p-2.5 rounded-full", isExp ? "bg-rose-50 text-rose-600" : "bg-emerald-50 text-emerald-600")}>
                          {isExp ? <LucideIndianRupee className="h-4 w-4" /> : <Banknote className="h-4 w-4" />}
                        </div>
                        <div>
                          <p className="font-bold text-sm">{p.notes || (isExp ? "General Expense" : "Client Payment")}</p>
                          <div className="flex items-center gap-2 mt-0.5">
                            <span className="text-[10px] font-medium text-muted-foreground">{p.paid_date ? format(new Date(p.paid_date), "dd MMM yyyy") : "—"}</span>
                            <span className="text-[10px] font-bold text-muted-foreground/30 capitalize">• {p.payment_mode || 'Cash'}</span>
                          </div>
                        </div>
                      </div>
                      <div className="flex items-center gap-4">
                        <div className="text-right">
                          <p className={cn("font-black text-sm", isExp ? "text-rose-600" : "text-emerald-600")}>
                            {isExp ? "+" : "-"} ₹{p.paid_amount?.toLocaleString()}
                          </p>
                          <p className="text-[9px] font-bold text-muted-foreground/40 uppercase">
                            {isExp ? "Added to Fee" : "Settled"}
                          </p>
                        </div>
                        <Button variant="ghost" size="icon" className="h-8 w-8 text-muted-foreground/30 hover:text-destructive transition-colors" onClick={(e) => handleDelete(e, p.id)}>
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}

        {payments.length === 0 && (
          <div className="py-20 text-center space-y-4">
            <div className="bg-muted w-16 h-16 rounded-full flex items-center justify-center mx-auto opacity-50">
              <CreditCard className="h-8 w-8 text-muted-foreground" />
            </div>
            <div>
              <h3 className="font-bold text-muted-foreground">No Ledger Entries</h3>
              <p className="text-sm text-muted-foreground/60">Start by recording your first case revenue or expense.</p>
            </div>
          </div>
        )}

        {totalPages > 1 && (
          <div className="flex items-center justify-between pt-4 border-t">
            <p className="text-xs text-muted-foreground">
              Showing page {page} of {totalPages} ({totalCount} total)
            </p>
            <div className="flex items-center gap-2">
              <Button variant="outline" size="sm" className="h-8 text-xs" onClick={prevPage} disabled={page <= 1 || isTransitioning}>
                <ChevronLeft className="h-3 w-3 mr-1" /> Previous
              </Button>
              <Button variant="outline" size="sm" className="h-8 text-xs" onClick={nextPage} disabled={page >= totalPages || isTransitioning}>
                Next <ChevronRight className="h-3 w-3 ml-1" />
              </Button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
