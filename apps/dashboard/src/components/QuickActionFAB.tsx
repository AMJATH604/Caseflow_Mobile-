import { useState } from "react";
import { Plus, Briefcase, Users, CalendarClock } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchCases, fetchClients, fetchHearings, createCase, createClient, adjournHearing } from "@/lib/supabase-helpers";
import { useToast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";
import { format } from "date-fns";

type ActiveDialog = null | "new-case" | "add-client" | "quick-adjourn";

export function QuickActionFAB() {
    const navigate = useNavigate();
    const { toast } = useToast();
    const qc = useQueryClient();
    const [expanded, setExpanded] = useState(false);
    const [activeDialog, setActiveDialog] = useState<ActiveDialog>(null);

    // Data queries
    const { data: cases = [] } = useQuery({ queryKey: ["cases"], queryFn: fetchCases });
    const { data: clients = [] } = useQuery({ queryKey: ["clients"], queryFn: fetchClients });
    const { data: hearingsData } = useQuery({ queryKey: ["hearings"], queryFn: () => fetchHearings() });
    const hearings = (hearingsData || []) as any[];

    // Forms
    const [caseForm, setCaseForm] = useState({ client_id: "", case_title: "", case_number: "", case_type: "", court_name: "", filing_date: "" });
    const [clientForm, setClientForm] = useState({ name: "", phone: "", email: "", address: "" });
    const [adjournForm, setAdjournForm] = useState({ hearing_id: "", notes: "", next_date: "", next_stage: "" });

    // Mutations
    const createCaseMut = useMutation({
        mutationFn: () => createCase(caseForm),
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: ["cases"] });
            setActiveDialog(null);
            setCaseForm({ client_id: "", case_title: "", case_number: "", case_type: "", court_name: "", filing_date: "" });
            toast({ title: "Case created successfully" });
        },
        onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
    });

    const createClientMut = useMutation({
        mutationFn: () => createClient(clientForm),
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: ["clients"] });
            setActiveDialog(null);
            setClientForm({ name: "", phone: "", email: "", address: "" });
            toast({ title: "Client added successfully" });
        },
        onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
    });

    const adjournMut = useMutation({
        mutationFn: () => {
            const hearing = hearings.find((h: any) => h.id === adjournForm.hearing_id);
            if (!hearing) throw new Error("Select a hearing");
            return adjournHearing(hearing.id, {
                current_notes: adjournForm.notes,
                next_date: adjournForm.next_date,
                next_stage: adjournForm.next_stage,
                case_id: hearing.case_id,
            });
        },
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: ["hearings"] });
            qc.invalidateQueries({ queryKey: ["cases"] });
            setActiveDialog(null);
            setAdjournForm({ hearing_id: "", notes: "", next_date: "", next_stage: "" });
            toast({ title: "Diary updated", description: "Case adjourned and next date set." });
        },
        onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
    });

    const openAction = (action: ActiveDialog) => {
        setExpanded(false);
        setActiveDialog(action);
    };

    const actions = [
        { title: "New Case", icon: Briefcase, color: "bg-blue-500", action: () => openAction("new-case") },
        { title: "Add Client", icon: Users, color: "bg-emerald-500", action: () => openAction("add-client") },
        { title: "Quick Adjourn", icon: CalendarClock, color: "bg-amber-500", action: () => openAction("quick-adjourn") },
    ];

    // Get pending hearings for quick adjourn
    const pendingHearings = hearings.filter((h: any) => {
        try { return new Date(h.hearing_date) >= new Date(new Date().toDateString()); } catch { return false; }
    });

    return (
        <div className="md:hidden">
            {/* Expanded action items */}
            {expanded && (
                <>
                    <div className="fixed inset-0 z-[59] bg-black/20" onClick={() => setExpanded(false)} />
                    <div className="fixed bottom-20 right-4 z-[61] flex flex-col gap-3">
                        {actions.map((action, i) => (
                            <button
                                key={action.title}
                                onClick={action.action}
                                className="flex items-center gap-3 animate-in slide-in-from-bottom-2 fade-in"
                                style={{ animationDelay: `${i * 50}ms`, animationFillMode: 'backwards' }}
                            >
                                <span className="bg-card text-foreground text-xs font-semibold px-3 py-2 rounded-lg shadow-lg border border-border/30 whitespace-nowrap">
                                    {action.title}
                                </span>
                                <div className={cn("w-10 h-10 rounded-full flex items-center justify-center shadow-lg", action.color)}>
                                    <action.icon className="h-4 w-4 text-white" />
                                </div>
                            </button>
                        ))}
                    </div>
                </>
            )}

            {/* Main FAB */}
            <div className="fixed bottom-20 right-4 z-[60]">
                <Button
                    size="icon"
                    onClick={() => setExpanded(!expanded)}
                    className={cn(
                        "h-14 w-14 rounded-full shadow-2xl transition-all duration-300 border-2 border-white/80",
                        expanded ? "bg-muted-foreground rotate-45" : "bg-primary hover:bg-primary/90"
                    )}
                >
                    <Plus className="h-6 w-6 stroke-[2.5] text-primary-foreground" />
                </Button>
            </div>

            {/* ═══ NEW CASE DIALOG ═══ */}
            <Dialog open={activeDialog === "new-case"} onOpenChange={(o) => !o && setActiveDialog(null)}>
                <DialogContent className="max-w-[95vw] rounded-2xl">
                    <DialogHeader><DialogTitle>New Case</DialogTitle></DialogHeader>
                    <form onSubmit={(e) => { e.preventDefault(); createCaseMut.mutate(); }} className="space-y-4">
                        <div className="space-y-2">
                            <Label>Client *</Label>
                            <Select value={caseForm.client_id} onValueChange={(v) => setCaseForm({ ...caseForm, client_id: v })}>
                                <SelectTrigger><SelectValue placeholder="Select client" /></SelectTrigger>
                                <SelectContent>{clients.map((c: any) => <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>)}</SelectContent>
                            </Select>
                        </div>
                        <div className="space-y-2"><Label>Case Title *</Label><Input value={caseForm.case_title} onChange={(e) => setCaseForm({ ...caseForm, case_title: e.target.value })} required /></div>
                        <div className="grid grid-cols-2 gap-3">
                            <div className="space-y-2"><Label>Case No.</Label><Input value={caseForm.case_number} onChange={(e) => setCaseForm({ ...caseForm, case_number: e.target.value })} /></div>
                            <div className="space-y-2"><Label>Case Type</Label><Input value={caseForm.case_type} onChange={(e) => setCaseForm({ ...caseForm, case_type: e.target.value })} placeholder="Civil, Criminal..." /></div>
                        </div>
                        <div className="grid grid-cols-2 gap-3">
                            <div className="space-y-2"><Label>Court Name</Label><Input value={caseForm.court_name} onChange={(e) => setCaseForm({ ...caseForm, court_name: e.target.value })} /></div>
                            <div className="space-y-2"><Label>Filing Date</Label><Input type="date" value={caseForm.filing_date} onChange={(e) => setCaseForm({ ...caseForm, filing_date: e.target.value })} /></div>
                        </div>
                        <Button type="submit" className="w-full" disabled={createCaseMut.isPending}>{createCaseMut.isPending ? "Creating..." : "Create Case"}</Button>
                    </form>
                </DialogContent>
            </Dialog>

            {/* ═══ ADD CLIENT DIALOG ═══ */}
            <Dialog open={activeDialog === "add-client"} onOpenChange={(o) => !o && setActiveDialog(null)}>
                <DialogContent className="max-w-[95vw] rounded-2xl">
                    <DialogHeader><DialogTitle>Add Client</DialogTitle></DialogHeader>
                    <form onSubmit={(e) => { e.preventDefault(); createClientMut.mutate(); }} className="space-y-4">
                        <div className="space-y-2"><Label>Name *</Label><Input value={clientForm.name} onChange={(e) => setClientForm({ ...clientForm, name: e.target.value })} required /></div>
                        <div className="space-y-2"><Label>Phone</Label><Input value={clientForm.phone} onChange={(e) => setClientForm({ ...clientForm, phone: e.target.value })} type="tel" /></div>
                        <div className="space-y-2"><Label>Email</Label><Input type="email" value={clientForm.email} onChange={(e) => setClientForm({ ...clientForm, email: e.target.value })} /></div>
                        <div className="space-y-2"><Label>Address</Label><Input value={clientForm.address} onChange={(e) => setClientForm({ ...clientForm, address: e.target.value })} /></div>
                        <Button type="submit" className="w-full" disabled={createClientMut.isPending}>{createClientMut.isPending ? "Adding..." : "Add Client"}</Button>
                    </form>
                </DialogContent>
            </Dialog>

            {/* ═══ QUICK ADJOURN DIALOG ═══ */}
            <Dialog open={activeDialog === "quick-adjourn"} onOpenChange={(o) => !o && setActiveDialog(null)}>
                <DialogContent className="max-w-[95vw] rounded-2xl">
                    <DialogHeader>
                        <DialogTitle className="flex items-center gap-2">
                            <CalendarClock className="h-5 w-5 text-amber-500" /> Quick Adjourn
                        </DialogTitle>
                    </DialogHeader>
                    <form onSubmit={(e) => { e.preventDefault(); adjournMut.mutate(); }} className="space-y-4">
                        <div className="space-y-2">
                            <Label>Select Hearing *</Label>
                            <Select value={adjournForm.hearing_id} onValueChange={(v) => setAdjournForm({ ...adjournForm, hearing_id: v })}>
                                <SelectTrigger><SelectValue placeholder="Pick a pending hearing" /></SelectTrigger>
                                <SelectContent>
                                    {pendingHearings.length === 0 ? (
                                        <SelectItem value="__none" disabled>No pending hearings</SelectItem>
                                    ) : (
                                        pendingHearings.map((h: any) => (
                                            <SelectItem key={h.id} value={h.id}>
                                                {(h.cases as any)?.case_title} — {format(new Date(h.hearing_date), "dd MMM")}
                                            </SelectItem>
                                        ))
                                    )}
                                </SelectContent>
                            </Select>
                        </div>
                        <div className="space-y-2">
                            <Label>Today's Notes</Label>
                            <Textarea
                                placeholder="e.g., Arguments heard, adjourned for orders..."
                                value={adjournForm.notes}
                                onChange={(e) => setAdjournForm({ ...adjournForm, notes: e.target.value })}
                                className="min-h-[70px]"
                            />
                        </div>
                        <div className="grid grid-cols-2 gap-3">
                            <div className="space-y-2">
                                <Label>Next Date *</Label>
                                <Input type="date" value={adjournForm.next_date} onChange={(e) => setAdjournForm({ ...adjournForm, next_date: e.target.value })} required />
                            </div>
                            <div className="space-y-2">
                                <Label>Next Stage</Label>
                                <Input value={adjournForm.next_stage} onChange={(e) => setAdjournForm({ ...adjournForm, next_stage: e.target.value })} placeholder="Evidence, Args..." />
                            </div>
                        </div>
                        <Button type="submit" className="w-full" disabled={adjournMut.isPending}>
                            {adjournMut.isPending ? "Updating..." : "Update Diary"}
                        </Button>
                    </form>
                </DialogContent>
            </Dialog>
        </div>
    );
}
