import { useState } from "react";
import { useMutation, useQueryClient, useQuery } from "@tanstack/react-query";
import { format, parseISO } from "date-fns";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger, DialogFooter } from "@/components/ui/dialog";
import { useToast } from "@/hooks/use-toast";
import { Plus, Trash2, ClipboardList, Search, CheckCircle2, AlertCircle, Package, Calendar, Clock, ArrowRight } from "lucide-react";
import { fetchCertifiedCopies, createCertifiedCopy, updateCertifiedCopy, deleteCertifiedCopy, fetchCases } from "@/lib/supabase-helpers";
import { useRealtimeQuery } from "@/hooks/useRealtimeQuery";
import { cn } from "@/lib/utils";

const STAGES = [
  { id: "box_drop", label: "Box Drop", color: "bg-blue-500", textColor: "text-blue-600", bgLight: "bg-blue-50", icon: Package, dateField: "box_drop_date" },
  { id: "memo_received", label: "Memo", color: "bg-amber-500", textColor: "text-amber-600", bgLight: "bg-amber-50", icon: AlertCircle, dateField: "memo_date" },
  { id: "ready", label: "CC Ready", color: "bg-emerald-500", textColor: "text-emerald-600", bgLight: "bg-emerald-50", icon: CheckCircle2, dateField: "ready_date" },
  { id: "delivered", label: "Collected", color: "bg-slate-500", textColor: "text-slate-600", bgLight: "bg-slate-50", icon: ClipboardList, dateField: "collected_date" },
];

export default function CertifiedCopies() {
  const [open, setOpen] = useState(false);
  const [statusDialog, setStatusDialog] = useState<{ open: boolean; copy: any; nextStage: any } | null>(null);
  const [statusDate, setStatusDate] = useState(format(new Date(), "yyyy-MM-dd"));
  const [search, setSearch] = useState("");
  const [filterStage, setFilterStage] = useState("all");
  const [form, setForm] = useState({ case_id: "", ca_number: "", status: "box_drop", box_drop_date: format(new Date(), "yyyy-MM-dd") });

  const { toast } = useToast();
  const qc = useQueryClient();

  const { data: copies = [], isLoading } = useRealtimeQuery({
    queryKey: ["certified-copies"],
    queryFn: fetchCertifiedCopies,
    table: "certified_copies"
  });

  const { data: cases = [] } = useQuery({ queryKey: ["cases"], queryFn: fetchCases });

  const createMut = useMutation({
    mutationFn: () => createCertifiedCopy(form),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["certified-copies"] }); setOpen(false); toast({ title: "CC Entry Logged" }); },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  const updateMut = useMutation({
    mutationFn: ({ id, updates }: { id: string; updates: any }) => updateCertifiedCopy(id, updates),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["certified-copies"] }); setStatusDialog(null); toast({ title: "Status updated" }); },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  const deleteMut = useMutation({
    mutationFn: deleteCertifiedCopy,
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["certified-copies"] }); toast({ title: "Entry deleted" }); },
  });

  const handleStageChange = (copy: any, newStageId: string) => {
    const stage = STAGES.find(s => s.id === newStageId);
    if (!stage) return;
    setStatusDate(format(new Date(), "yyyy-MM-dd"));
    setStatusDialog({ open: true, copy, nextStage: stage });
  };

  const confirmStageUpdate = () => {
    if (!statusDialog) return;
    const { copy, nextStage } = statusDialog;
    const updates: any = { status: nextStage.id };
    updates[nextStage.dateField] = statusDate;
    updateMut.mutate({ id: copy.id, updates });
  };

  const getCurrentStageIndex = (status: string) => STAGES.findIndex(s => s.id === status);

  const filtered = copies.filter((c: any) => {
    const matchSearch = !search ||
      (c.cases as any)?.case_title?.toLowerCase().includes(search.toLowerCase()) ||
      c.ca_number?.toLowerCase().includes(search.toLowerCase());
    const matchStage = filterStage === "all" || c.status === filterStage;
    return matchSearch && matchStage;
  });

  return (
    <div className="space-y-8">
      {/* Header Section */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-serif font-bold text-foreground">CC Registry</h1>
          <p className="text-sm text-muted-foreground mt-1">Track certified copy applications & procurement timeline</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="relative flex-1 md:w-64">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground/50" />
            <Input 
              placeholder="Search CA no. or case..." 
              value={search} 
              onChange={(e) => setSearch(e.target.value)} 
              className="pl-9 bg-card border-border/40 h-10 rounded-xl"
            />
          </div>
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button className="h-10 px-6 rounded-xl shadow-sm"><Plus className="h-4 w-4 mr-2" /> Log Application</Button>
            </DialogTrigger>
            <DialogContent className="max-w-[95vw] md:max-w-md rounded-2xl">
              <DialogHeader><DialogTitle>New CC Application</DialogTitle></DialogHeader>
              <form onSubmit={(e) => { e.preventDefault(); createMut.mutate(); }} className="space-y-4 pt-4">
                <div className="space-y-2">
                  <Label>Case *</Label>
                  <Select value={form.case_id} onValueChange={(v) => setForm({ ...form, case_id: v })}>
                    <SelectTrigger className="rounded-xl"><SelectValue placeholder="Select case" /></SelectTrigger>
                    <SelectContent>{cases.map((c: any) => <SelectItem key={c.id} value={c.id}>{c.case_title}</SelectItem>)}</SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>CA No. (Serial Number)</Label>
                  <Input 
                    value={form.ca_number} 
                    onChange={(e) => setForm({ ...form, ca_number: e.target.value })} 
                    placeholder="e.g. 1234/2024" 
                    className="rounded-xl placeholder:text-muted-foreground/30"
                  />
                </div>
                <div className="space-y-2">
                  <Label>Box Drop Date *</Label>
                  <Input type="date" value={form.box_drop_date} onChange={(e) => setForm({ ...form, box_drop_date: e.target.value })} className="rounded-xl" />
                </div>
                <Button type="submit" className="w-full h-11 rounded-xl" disabled={createMut.isPending}>
                  {createMut.isPending ? "Logging..." : "Create Log Entry"}
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* Stage Summary Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {STAGES.map(s => {
          const count = copies.filter((c: any) => c.status === s.id).length;
          return (
            <button 
              key={s.id} 
              onClick={() => setFilterStage(filterStage === s.id ? "all" : s.id)}
              className={cn(
                "p-4 rounded-2xl border transition-all text-left group",
                filterStage === s.id ? "border-primary bg-primary/5 shadow-sm" : "border-border/40 bg-card hover:border-primary/20"
              )}
            >
              <div className={cn("p-2 rounded-lg w-fit mb-3 transition-colors", s.bgLight, s.textColor)}>
                <s.icon className="h-4 w-4" />
              </div>
              <p className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground/60">{s.label}</p>
              <p className="text-2xl font-black text-foreground mt-0.5">{count}</p>
            </button>
          );
        })}
      </div>

      {/* Main Content: Registry Grid */}
      {isLoading ? (
        <div className="py-20 text-center"><p className="text-muted-foreground animate-pulse font-medium">Fetching registry...</p></div>
      ) : filtered.length === 0 ? (
        <div className="py-20 text-center border-2 border-dashed border-border/40 rounded-3xl">
          <div className="bg-muted w-16 h-16 rounded-full flex items-center justify-center mx-auto opacity-30 mb-4">
            <ClipboardList className="h-8 w-8" />
          </div>
          <h3 className="font-serif font-bold text-lg">{search ? "No matches found" : "Registry Empty"}</h3>
          <p className="text-sm text-muted-foreground">Start by logging your first certified copy application.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {filtered.map((c: any) => {
            const currentStage = STAGES.find(s => s.id === c.status);
            const stageIndex = getCurrentStageIndex(c.status);

            return (
              <div key={c.id} className="group relative bg-card border border-border/50 rounded-3xl overflow-hidden hover:shadow-xl hover:shadow-primary/5 transition-all duration-300">
                <div className={cn("absolute left-0 top-0 bottom-0 w-1.5", currentStage?.color)} />
                
                <div className="p-6 md:p-8">
                  <div className="flex justify-between items-start mb-6">
                    <div>
                      <h3 className="text-xl font-serif font-bold text-foreground group-hover:text-primary transition-colors cursor-pointer" onClick={() => navigate(`/cases/${c.case_id}`)}>
                        {(c.cases as any)?.case_title}
                      </h3>
                      <div className="flex items-center gap-3 mt-2">
                        <span className="px-2.5 py-0.5 bg-muted rounded-md text-[10px] font-bold text-muted-foreground tracking-widest uppercase">
                          CA: {c.ca_number || "Awaiting"}
                        </span>
                        <span className="w-1.5 h-1.5 rounded-full bg-border" />
                        <span className="flex items-center gap-1 text-[11px] font-medium text-muted-foreground/60">
                          <Calendar className="h-3 w-3" /> Logged {format(parseISO(c.created_at), "dd MMM")}
                        </span>
                      </div>
                    </div>
                    
                    <div className="flex items-center gap-2">
                      <div className={cn("px-4 py-1.5 rounded-full text-[10px] font-black uppercase tracking-widest text-white shadow-sm", currentStage?.color)}>
                        {currentStage?.label}
                      </div>
                      <Button 
                        variant="ghost" 
                        size="icon" 
                        className="h-8 w-8 text-muted-foreground/20 hover:text-destructive hover:bg-destructive/5 transition-all rounded-full"
                        onClick={() => { if (window.confirm("Delete this registry entry?")) deleteMut.mutate(c.id); }}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>

                  {/* Visual Timeline / Stepper */}
                  <div className="relative flex items-center justify-between gap-2 px-1 py-4 mb-6">
                    {STAGES.map((stage, i) => {
                      const isCompleted = i <= stageIndex;
                      const isLast = i === STAGES.length - 1;
                      const dateValue = c[stage.dateField];

                      return (
                        <div key={stage.id} className="flex-1 flex flex-col items-center">
                          <div className="relative w-full flex items-center justify-center">
                            {/* Horizontal Line Connector */}
                            {!isLast && (
                              <div className={cn(
                                "absolute left-1/2 right-[-50%] h-[2px] top-[10px] transition-all",
                                i < stageIndex ? stage.color : "bg-border/30"
                              )} />
                            )}
                            {/* Circular Node */}
                            <div className={cn(
                              "relative z-10 w-5 h-5 rounded-full border-2 bg-white flex items-center justify-center transition-all",
                              isCompleted ? `${stage.color} border-transparent` : "border-border/40"
                            )}>
                              {isCompleted && <CheckCircle2 className="h-3 w-3 text-white" />}
                            </div>
                          </div>
                          
                          <span className={cn(
                            "mt-3 text-[10px] font-black uppercase tracking-tighter transition-colors",
                            isCompleted ? stage.textColor : "text-muted-foreground/30"
                          )}>
                            {stage.label}
                          </span>
                          
                          <div className="min-h-[14px] mt-1 text-center">
                            {dateValue ? (
                              <span className="text-[10px] font-bold text-muted-foreground/60 bg-muted/30 px-1.5 py-0.5 rounded">
                                {format(parseISO(dateValue), "dd MMM")}
                              </span>
                            ) : (
                              <span className="text-[10px] text-muted-foreground/20 italic">—</span>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>

                  {/* Bottom Action Footer */}
                  <div className="flex items-center justify-between pt-6 border-t border-border/30">
                    <div className="flex items-center gap-2">
                       <Clock className="h-3.5 w-3.5 text-muted-foreground/40" />
                       <span className="text-[10px] font-bold text-muted-foreground/40 uppercase">
                         {c.ready_date ? "Procured" : "In Progress"}
                       </span>
                    </div>
                    {stageIndex < STAGES.length - 1 ? (
                      <Button
                        size="sm"
                        variant="ghost"
                        className={cn("h-9 md:h-10 text-xs font-bold gap-2 rounded-xl border border-border/40 hover:border-primary transition-all", currentStage?.textColor)}
                        onClick={() => handleStageChange(c, STAGES[stageIndex + 1].id)}
                      >
                        PROMOTE TO {STAGES[stageIndex + 1].label.toUpperCase()} <ArrowRight className="h-3.5 w-3.5" />
                      </Button>
                    ) : (
                      <div className="flex items-center gap-2 px-4 py-2 bg-emerald-50 rounded-xl">
                        <CheckCircle2 className="h-4 w-4 text-emerald-600" />
                        <span className="text-[11px] font-black text-emerald-600 uppercase tracking-widest">Procurement Complete</span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Date Confirmation Dialog */}
      <Dialog open={statusDialog?.open || false} onOpenChange={(o) => !o && setStatusDialog(null)}>
        <DialogContent className="max-w-[95vw] md:max-w-sm rounded-2xl">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              {statusDialog?.nextStage && (
                <>
                  <div className={cn("p-2 rounded-lg", statusDialog.nextStage.bgLight, statusDialog.nextStage.textColor)}>
                    <statusDialog.nextStage.icon className="h-5 w-5" />
                  </div>
                  <span>Confirm {statusDialog.nextStage.label}</span>
                </>
              )}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4 pt-4">
            <div className="p-4 bg-muted/30 rounded-2xl border border-border/20">
              <p className="text-xs font-bold text-muted-foreground uppercase tracking-widest mb-1">Target Milestone</p>
              <p className="text-sm font-medium text-foreground italic">"{(statusDialog?.copy?.cases as any)?.case_title}"</p>
            </div>
            <div className="space-y-2">
              <Label className="text-[10px] font-black uppercase tracking-widest text-muted-foreground/70">Completion Date</Label>
              <Input type="date" value={statusDate} onChange={(e) => setStatusDate(e.target.value)} className="rounded-xl h-11" />
            </div>
          </div>
          <DialogFooter className="mt-6 gap-2 sm:gap-0">
            <Button variant="ghost" onClick={() => setStatusDialog(null)} className="flex-1 rounded-xl">Cancel</Button>
            <Button onClick={confirmStageUpdate} disabled={updateMut.isPending} className="flex-1 rounded-xl bg-primary text-primary-foreground shadow-lg shadow-primary/20">
              {updateMut.isPending ? "Updating..." : "Update Milestone"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
