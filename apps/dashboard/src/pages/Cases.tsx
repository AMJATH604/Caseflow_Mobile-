import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useRealtimeQuery } from "@/hooks/useRealtimeQuery";
import { fetchCases, fetchClients, createCase } from "@/lib/supabase-helpers";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { StatusBadge } from "@/components/StatusBadge";
import { useToast } from "@/hooks/use-toast";
import { Plus, Briefcase, ChevronRight, Scale, Search } from "lucide-react";
import { cn } from "@/lib/utils";

export default function Cases() {
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [form, setForm] = useState({
    client_id: "",
    case_title: "",
    case_number: "",
    case_type: "",
    court_name: "",
    filing_date: "",
    representation_type: "petitioner",
    opposing_party: "",
    opposing_advocate: "",
    opposing_advocate_phone: ""
  });
  const { toast } = useToast();
  const qc = useQueryClient();
  const navigate = useNavigate();

  const { data: cases = [], isLoading } = useRealtimeQuery({ queryKey: ["cases"], queryFn: fetchCases, table: "cases" });
  const { data: clients = [] } = useRealtimeQuery({ queryKey: ["clients"], queryFn: fetchClients, table: "clients" });

  const createMut = useMutation({
    mutationFn: () => createCase(form),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["cases"] }); setOpen(false); toast({ title: "Case created" }); },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  // Filter cases
  const filteredCases = cases.filter((c: any) => {
    const matchesSearch = !search ||
      c.case_title?.toLowerCase().includes(search.toLowerCase()) ||
      c.case_number?.toLowerCase().includes(search.toLowerCase()) ||
      (c.clients as any)?.name?.toLowerCase().includes(search.toLowerCase());
    const matchesStatus = statusFilter === "all" || c.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const getStatusAccent = (status: string) => {
    switch (status) {
      case "active": return "accent-green";
      case "closed": return "accent-blue";
      case "pending": return "accent-amber";
      default: return "accent-purple";
    }
  };

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="hidden md:block">
          <h1 className="text-2xl font-serif font-bold text-foreground">Cases</h1>
          <p className="text-sm text-muted-foreground mt-1">Manage all legal cases</p>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button size="sm" className="md:h-10 md:px-4 hidden md:flex"><Plus className="h-4 w-4 mr-2" /> New Case</Button>
          </DialogTrigger>
          <DialogContent className="max-w-lg">
            <DialogHeader><DialogTitle>Create New Case</DialogTitle></DialogHeader>
            <form onSubmit={(e) => { e.preventDefault(); createMut.mutate(); }} className="space-y-4">
              <div className="space-y-2">
                <Label>Client *</Label>
                <Select value={form.client_id} onValueChange={(v) => setForm({ ...form, client_id: v })}>
                  <SelectTrigger><SelectValue placeholder="Select client" /></SelectTrigger>
                  <SelectContent>{clients.map((c: any) => <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>)}</SelectContent>
                </Select>
              </div>
              <div className="space-y-2"><Label>Case Title *</Label><Input value={form.case_title} onChange={(e) => setForm({ ...form, case_title: e.target.value })} required /></div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2"><Label>Case Number</Label><Input value={form.case_number} onChange={(e) => setForm({ ...form, case_number: e.target.value })} /></div>
                <div className="space-y-2"><Label>Case Type</Label><Input value={form.case_type} onChange={(e) => setForm({ ...form, case_type: e.target.value })} placeholder="Civil, Criminal..." /></div>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="space-y-2"><Label>Court Name</Label><Input value={form.court_name} onChange={(e) => setForm({ ...form, court_name: e.target.value })} /></div>
                <div className="space-y-2"><Label>Filing Date</Label><Input type="date" value={form.filing_date} onChange={(e) => setForm({ ...form, filing_date: e.target.value })} /></div>
              </div>

              <div className="space-y-4 pt-2 border-t mt-4">
                <p className="text-sm font-semibold">Party Details</p>
                <div className="space-y-2">
                  <Label>Our Representation</Label>
                  <Select value={form.representation_type} onValueChange={(v) => setForm({ ...form, representation_type: v })}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="petitioner">Petitioner / Plaintiff</SelectItem>
                      <SelectItem value="respondent">Respondent / Defendant</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>{form.representation_type === 'petitioner' ? 'Respondent Name' : 'Petitioner Name'}</Label>
                  <Input value={form.opposing_party} onChange={(e) => setForm({ ...form, opposing_party: e.target.value })} placeholder="Opposing Party Name" />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2"><Label>Opposing Advocate</Label><Input value={form.opposing_advocate} onChange={(e) => setForm({ ...form, opposing_advocate: e.target.value })} /></div>
                  <div className="space-y-2"><Label>Advocate Phone</Label><Input value={form.opposing_advocate_phone} onChange={(e) => setForm({ ...form, opposing_advocate_phone: e.target.value })} /></div>
                </div>
              </div>

              <Button type="submit" className="w-full" disabled={createMut.isPending}>{createMut.isPending ? "Creating..." : "Create Case"}</Button>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {/* Mobile Search & Filters */}
      <div className="md:hidden space-y-3">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground/50" />
          <input
            type="text"
            placeholder="Search cases..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="mobile-search pl-10"
          />
        </div>
        <div className="flex gap-2 overflow-x-auto pb-1">
          {["all", "active", "closed", "pending"].map(s => (
            <button
              key={s}
              onClick={() => setStatusFilter(s)}
              className={cn("filter-chip", statusFilter === s && "active")}
            >
              {s === "all" ? "All" : s.charAt(0).toUpperCase() + s.slice(1)}
              {s !== "all" && (
                <span className="ml-1.5 tabular-nums">
                  {cases.filter((c: any) => c.status === s).length}
                </span>
              )}
            </button>
          ))}
        </div>
      </div>

      {/* Desktop Table */}
      <Card className="hidden md:block">
        <CardHeader className="pb-3"><CardTitle className="text-lg flex items-center gap-2"><Briefcase className="h-5 w-5" /> All Cases</CardTitle></CardHeader>
        <CardContent>
          {isLoading ? <p className="text-sm text-muted-foreground">Loading...</p> : cases.length === 0 ? (
            <p className="text-sm text-muted-foreground py-8 text-center">No cases yet. Create your first case.</p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Case Title</TableHead>
                  <TableHead>Case No.</TableHead>
                  <TableHead>Client</TableHead>
                  <TableHead>Court</TableHead>
                  <TableHead>Status</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {cases.map((c: any) => (
                  <TableRow key={c.id} className="cursor-pointer hover:bg-muted/50" onClick={() => navigate(`/cases/${c.id}`)}>
                    <TableCell className="font-medium">{c.case_title}</TableCell>
                    <TableCell>{c.case_number || "—"}</TableCell>
                    <TableCell>{(c.clients as any)?.name}</TableCell>
                    <TableCell>{c.court_name || "—"}</TableCell>
                    <TableCell><StatusBadge status={c.status} /></TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Mobile Cards */}
      <div className="md:hidden space-y-3">
        {isLoading ? (
          <div className="text-center py-12 text-muted-foreground text-sm">Loading cases...</div>
        ) : filteredCases.length === 0 ? (
          <div className="mobile-card text-center py-8">
            <Briefcase className="h-8 w-8 text-muted-foreground/30 mx-auto mb-2" />
            <p className="text-sm text-muted-foreground">{search ? "No cases match your search" : "No cases yet"}</p>
          </div>
        ) : (
          filteredCases.map((c: any) => (
            <div
              key={c.id}
              className={cn("mobile-card mobile-card-accent pl-5 cursor-pointer", getStatusAccent(c.status))}
              onClick={() => navigate(`/cases/${c.id}`)}
            >
              <div className="flex items-start justify-between gap-2 mb-2">
                <div className="min-w-0 flex-1">
                  <h3 className="font-bold text-sm truncate">{c.case_title}</h3>
                  <p className="text-xs text-muted-foreground mt-0.5">{c.case_number || "No Number"}</p>
                </div>
                <StatusBadge status={c.status} />
              </div>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3 text-xs text-muted-foreground">
                  <span className="flex items-center gap-1">
                    <Scale className="h-3 w-3" />
                    <span className="truncate max-w-[80px]">{c.court_name || "—"}</span>
                  </span>
                  <span className="flex items-center gap-1">
                    <Briefcase className="h-3 w-3" />
                    <span className="truncate max-w-[80px]">{(c.clients as any)?.name || "—"}</span>
                  </span>
                </div>
                <ChevronRight className="h-4 w-4 text-muted-foreground/30" />
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
