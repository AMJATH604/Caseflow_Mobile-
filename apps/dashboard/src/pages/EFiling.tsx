import { useRealtimeQuery } from "@/hooks/useRealtimeQuery";
import { fetchEfilingRecords, fetchCases } from "@/lib/supabase-helpers";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { StatusBadge } from "@/components/StatusBadge";
import { Progress } from "@/components/ui/progress";
import { 
  FileText, Plus, ChevronRight, Layout, Kanban, List, 
  AlertTriangle, CheckCircle, Edit, ArrowRight, ArrowLeft, Loader2 
} from "lucide-react";
import { useNavigate } from "react-router-dom";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger, DialogFooter, DialogDescription } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { toast } from "sonner";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

const FILING_STEPS = ["drafting", "review", "signature_pending", "filed", "defect", "accepted"];

const COLUMN_CONFIG = {
  drafting: { title: "Drafting", color: "border-t-slate-400 bg-slate-50/50" },
  review: { title: "In Review", color: "border-t-blue-400 bg-blue-50/30" },
  signature_pending: { title: "Sign Pending", color: "border-t-amber-400 bg-amber-50/30" },
  filed: { title: "Filed", color: "border-t-indigo-400 bg-indigo-50/30" },
  defect: { title: "Defect Raised", color: "border-t-red-400 bg-red-50/30" },
  accepted: { title: "Accepted", color: "border-t-emerald-400 bg-emerald-50/30" }
};

export default function EFiling() {
  const { data: records = [], isLoading } = useRealtimeQuery({ 
    queryKey: ["efiling-all"], 
    queryFn: () => fetchEfilingRecords(), 
    table: "efiling_records" 
  });
  const { data: cases = [] } = useRealtimeQuery({ 
    queryKey: ["cases-list"], 
    queryFn: () => fetchCases(), 
    table: "cases" 
  });
  
  const [viewMode, setViewMode] = useState<"kanban" | "table">("kanban");
  const [open, setOpen] = useState(false);
  const [caseId, setCaseId] = useState("");
  const [docType, setDocType] = useState<any>("plaint");
  const [status, setStatus] = useState<any>("drafting");

  // Defect Modal State
  const [defectModalOpen, setDefectModalOpen] = useState(false);
  const [selectedRecord, setSelectedRecord] = useState<any>(null);
  const [defectNotes, setDefectNotes] = useState("");

  const navigate = useNavigate();
  const qc = useQueryClient();

  // Create record mutation
  const createMutation = useMutation({
    mutationFn: async (data: any) => {
      const { data: newRec, error } = await supabase
        .from("efiling_records")
        .insert([{
          case_id: data.case_id,
          document_type: data.document_type,
          status: data.status,
          created_by: (await supabase.auth.getUser()).data.user?.id || ""
        }])
        .select();
      if (error) throw error;
      return newRec;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["efiling-all"] });
      setOpen(false);
      resetForm();
      toast.success("E-Filing record created successfully");
    },
    onError: (err: any) => {
      toast.error("Error creating record: " + err.message);
    }
  });

  // Update status/defect mutation
  const updateMutation = useMutation({
    mutationFn: async (data: { id: string; status: string; defect_notes?: string | null }) => {
      const { error } = await supabase
        .from("efiling_records")
        .update({ status: data.status, defect_notes: data.defect_notes })
        .eq("id", data.id);
      if (error) throw error;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["efiling-all"] });
      setDefectModalOpen(false);
      toast.success("Filing record updated");
    },
    onError: (err: any) => {
      toast.error("Update failed: " + err.message);
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
    createMutation.mutate({ case_id: caseId, document_type: docType, status });
  };

  const handleMoveStatus = (record: any, direction: "next" | "prev") => {
    const currentIndex = FILING_STEPS.indexOf(record.status);
    let nextIndex = currentIndex;
    
    if (direction === "next" && currentIndex < FILING_STEPS.length - 1) {
      nextIndex = currentIndex + 1;
    } else if (direction === "prev" && currentIndex > 0) {
      nextIndex = currentIndex - 1;
    }

    if (nextIndex !== currentIndex) {
      const nextStatus = FILING_STEPS[nextIndex];
      // If moving to defect status, open defect details modal instead of direct move
      if (nextStatus === "defect") {
        openDefectModal(record);
      } else {
        updateMutation.mutate({ id: record.id, status: nextStatus, defect_notes: null });
      }
    }
  };

  const openDefectModal = (record: any) => {
    setSelectedRecord(record);
    setDefectNotes(record.defect_notes || "");
    setDefectModalOpen(true);
  };

  const submitDefectNotes = () => {
    updateMutation.mutate({ 
      id: selectedRecord.id, 
      status: "defect", 
      defect_notes: defectNotes.trim() || null 
    });
  };

  return (
    <div className="space-y-6 max-w-7xl mx-auto pb-12">
      {/* HEADER SECTION */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight flex items-center gap-2">
            <FileText className="h-6 w-6 text-primary" />
            E-Filing Oversight Portal
          </h1>
          <p className="text-xs text-muted-foreground">Manage statute filings, defect corrections, and approvals.</p>
        </div>

        <div className="flex items-center gap-2 self-start md:self-center">
          {/* View Toggles */}
          <div className="flex items-center border border-border rounded-xl p-1 bg-card">
            <Button 
              size="sm" 
              variant={viewMode === "kanban" ? "secondary" : "ghost"} 
              className="text-xs px-3 h-8"
              onClick={() => setViewMode("kanban")}
            >
              <Kanban className="h-3.5 w-3.5 mr-1" />
              Kanban Board
            </Button>
            <Button 
              size="sm" 
              variant={viewMode === "table" ? "secondary" : "ghost"} 
              className="text-xs px-3 h-8"
              onClick={() => setViewMode("table")}
            >
              <List className="h-3.5 w-3.5 mr-1" />
              Table View
            </Button>
          </div>

          {/* New Filing */}
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm" className="bg-primary hover:bg-primary/95 text-xs h-9">
                <Plus className="h-4 w-4 mr-1" /> New Filing
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>New E-Filing Record</DialogTitle>
              </DialogHeader>
              <form onSubmit={handleSubmit} className="space-y-4 pt-3">
                <div className="space-y-1.5">
                  <Label className="text-xs font-semibold">Select Case File</Label>
                  <Select value={caseId} onValueChange={setCaseId} required>
                    <SelectTrigger className="text-xs">
                      <SelectValue placeholder="Select active case..." />
                    </SelectTrigger>
                    <SelectContent>
                      {cases.map((c: any) => (
                        <SelectItem key={c.id} value={c.id} className="text-xs">
                          {c.case_title} ({c.case_number || "No Case Code"})
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-1.5">
                    <Label className="text-xs font-semibold">Document Type</Label>
                    <Select value={docType} onValueChange={setDocType}>
                      <SelectTrigger className="text-xs">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="plaint" className="text-xs">Plaint</SelectItem>
                        <SelectItem value="affidavit" className="text-xs">Affidavit</SelectItem>
                        <SelectItem value="vakalat" className="text-xs">Vakalat</SelectItem>
                        <SelectItem value="order" className="text-xs">Order</SelectItem>
                        <SelectItem value="judgment" className="text-xs">Judgment</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-1.5">
                    <Label className="text-xs font-semibold">Starting Status</Label>
                    <Select value={status} onValueChange={setStatus}>
                      <SelectTrigger className="text-xs">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="drafting" className="text-xs">Drafting</SelectItem>
                        <SelectItem value="review" className="text-xs">Review</SelectItem>
                        <SelectItem value="signature_pending" className="text-xs">Sign Pending</SelectItem>
                        <SelectItem value="filed" className="text-xs">Filed</SelectItem>
                        <SelectItem value="defect" className="text-xs">Defect</SelectItem>
                        <SelectItem value="accepted" className="text-xs">Accepted</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
                <Button type="submit" className="w-full text-xs h-9 mt-2" disabled={createMutation.isPending}>
                  {createMutation.isPending ? <><Loader2 className="h-4 w-4 mr-2 animate-spin" /> Saving...</> : "Create Record"}
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* VIEW MODES */}
      {isLoading ? (
        <div className="flex flex-col items-center justify-center py-24 gap-3 text-muted-foreground bg-card border rounded-2xl">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
          <span className="text-xs">Fetching filing records...</span>
        </div>
      ) : records.length === 0 ? (
        <div className="text-center py-20 text-xs text-muted-foreground border border-dashed rounded-2xl bg-card">
          No e-filing records currently uploaded in the system.
        </div>
      ) : viewMode === "kanban" ? (
        /* KANBAN BOARD VIEW */
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4 overflow-x-auto pb-4">
          {(Object.keys(COLUMN_CONFIG) as Array<keyof typeof COLUMN_CONFIG>).map((colKey) => {
            const colRecords = records.filter(r => r.status === colKey);
            const config = COLUMN_CONFIG[colKey];
            
            return (
              <div key={colKey} className={`flex flex-col min-w-[200px] border border-border rounded-xl p-3 h-[600px] shadow-sm ${config.color}`}>
                <div className="flex items-center justify-between border-b pb-2 mb-3 border-border/60">
                  <h3 className="font-bold text-xs text-foreground uppercase tracking-wider">{config.title}</h3>
                  <span className="text-[10px] bg-card border px-2 py-0.5 rounded-full font-bold text-muted-foreground">
                    {colRecords.length}
                  </span>
                </div>

                <div className="flex-1 overflow-y-auto space-y-3 pr-1">
                  {colRecords.map((r: any) => {
                    const stepIndex = FILING_STEPS.indexOf(r.status);
                    const progress = r.status === "defect" ? 0 : ((stepIndex + 1) / FILING_STEPS.length) * 100;
                    
                    return (
                      <div 
                        key={r.id} 
                        className="p-3 bg-card border border-border rounded-lg shadow-sm hover:shadow-md transition-shadow duration-200 space-y-3"
                      >
                        <div>
                          <span className="text-[9px] uppercase font-black px-1.5 py-0.5 bg-slate-100 text-slate-700 rounded">
                            {r.document_type}
                          </span>
                          <h4 
                            className="font-bold text-xs text-slate-800 line-clamp-2 mt-1.5 hover:underline cursor-pointer"
                            onClick={() => navigate(`/cases/${r.case_id}`)}
                          >
                            {(r.cases as any)?.case_title}
                          </h4>
                          <span className="text-[9px] text-muted-foreground mt-0.5 block truncate">
                            ID: {r.id.substring(0, 8)}...
                          </span>
                        </div>

                        {/* Progress slider */}
                        <div className="space-y-1">
                          <Progress value={progress} className="h-1" />
                        </div>

                        {/* Defect preview */}
                        {r.defect_notes && (
                          <div className="p-1.5 bg-red-50 border border-red-100 rounded text-[9px] text-red-700 leading-normal flex items-start gap-1">
                            <AlertTriangle className="h-3 w-3 shrink-0 text-red-500 mt-0.5" />
                            <p className="line-clamp-2">{r.defect_notes}</p>
                          </div>
                        )}

                        {/* Controls */}
                        <div className="flex items-center justify-between border-t border-border/40 pt-2 text-[10px]">
                          <Button 
                            variant="ghost" 
                            size="sm" 
                            disabled={stepIndex === 0} 
                            onClick={() => handleMoveStatus(r, "prev")}
                            className="h-6 w-6 p-0"
                          >
                            <ArrowLeft className="h-3.5 w-3.5 text-muted-foreground" />
                          </Button>
                          
                          {colKey === "defect" ? (
                            <Button 
                              variant="outline" 
                              size="sm" 
                              onClick={() => openDefectModal(r)}
                              className="h-6 px-1.5 text-[9px] font-bold border-red-200 text-red-600 hover:bg-red-50"
                            >
                              <Edit className="h-3 w-3 mr-0.5" /> Notes
                            </Button>
                          ) : (
                            <span className="text-[9px] font-bold text-muted-foreground opacity-60">Status</span>
                          )}

                          <Button 
                            variant="ghost" 
                            size="sm" 
                            disabled={stepIndex === FILING_STEPS.length - 1} 
                            onClick={() => handleMoveStatus(r, "next")}
                            className="h-6 w-6 p-0"
                          >
                            <ArrowRight className="h-3.5 w-3.5 text-muted-foreground" />
                          </Button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        /* STANDARD TABLE VIEW */
        <Card className="border border-border rounded-2xl shadow-sm">
          <CardContent className="pt-6">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Case File Title</TableHead>
                  <TableHead>Filing ID</TableHead>
                  <TableHead>Document Type</TableHead>
                  <TableHead>Status Code</TableHead>
                  <TableHead>Progress</TableHead>
                  <TableHead>Oversight / Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {records.map((r: any) => {
                  const stepIndex = FILING_STEPS.indexOf(r.status);
                  const progress = r.status === "defect" ? 0 : ((stepIndex + 1) / FILING_STEPS.length) * 100;
                  return (
                    <TableRow key={r.id} className="hover:bg-muted/10">
                      <TableCell className="font-bold text-xs">{(r.cases as any)?.case_title}</TableCell>
                      <TableCell className="font-mono text-xs text-muted-foreground">{r.id.substring(0, 8)}...</TableCell>
                      <TableCell className="capitalize text-xs font-semibold">{r.document_type}</TableCell>
                      <TableCell><StatusBadge status={r.status} /></TableCell>
                      <TableCell className="w-40">
                        <div className="flex items-center gap-2">
                          <Progress value={progress} className="h-2 flex-1" />
                          <span className="text-[10px] font-bold text-muted-foreground">{Math.round(progress)}%</span>
                        </div>
                      </TableCell>
                      <TableCell className="space-x-2">
                        <Button variant="outline" size="sm" className="text-xs h-8" onClick={() => navigate(`/cases/${r.case_id}`)}>
                          View Case
                        </Button>
                        {r.status === "defect" && (
                          <Button variant="outline" size="sm" className="text-xs h-8 border-red-200 text-red-600 hover:bg-red-50" onClick={() => openDefectModal(r)}>
                            Edit Defects
                          </Button>
                        )}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}

      {/* DEFECT NOTES LOG DIALOG */}
      <Dialog open={defectModalOpen} onOpenChange={setDefectModalOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Register/Edit Defect Details</DialogTitle>
            <DialogDescription>Attach defect notifications. Advocates will view this inside their mobile portal.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-3">
            <div className="p-3 bg-red-50 border border-red-100 rounded-xl text-xs text-red-800 flex items-start gap-2">
              <AlertTriangle className="h-4 w-4 shrink-0 text-red-500 mt-0.5" />
              <div className="space-y-0.5">
                <span className="font-bold block">Status flag is forced to "Defect"</span>
                <span className="leading-snug block">Saving this modal sets the current stage to "Defect" and displays notes to the advocate.</span>
              </div>
            </div>

            <div className="space-y-1.5">
              <Label className="text-xs font-semibold">Defect Instructions</Label>
              <Textarea 
                placeholder="e.g. Signature missing on page 4, Vakalatnama stamp value incorrect..."
                className="text-xs min-h-[100px]"
                value={defectNotes}
                onChange={(e) => setDefectNotes(e.target.value)}
              />
            </div>
          </div>
          <DialogFooter>
            <Button size="sm" variant="ghost" onClick={() => setDefectModalOpen(false)} className="text-xs">
              Cancel
            </Button>
            <Button size="sm" className="bg-red-600 hover:bg-red-700 text-white text-xs h-9" onClick={submitDefectNotes} disabled={updateMutation.isPending}>
              {updateMutation.isPending ? <><Loader2 className="h-4 w-4 mr-2 animate-spin" /> Saving...</> : "Publish Defect & Notify"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
