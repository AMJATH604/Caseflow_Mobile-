import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchHearings,
  fetchCases,
  createHearing as scheduleHearing,
  deleteHearing,
  updateHearingStatus
} from "@/lib/supabase-helpers";
import { format, isSameDay, startOfToday, parseISO, addDays, subDays } from "date-fns";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";
import { Plus, Trash2, Gavel, Clock, ChevronLeft, ChevronRight, 
  CalendarDays, Search, AlertTriangle, CheckCircle, HelpCircle, 
  Briefcase, ArrowUpRight, CheckCircle2, RefreshCw, Calendar as CalendarIcon 
} from "lucide-react";
import { StatusBadge } from "@/components/StatusBadge";
import { useRealtimeQuery } from "@/hooks/useRealtimeQuery";
import { usePaginatedQuery } from "@/hooks/usePaginatedQuery";
import { cn } from "@/lib/utils";
import { useNavigate } from "react-router-dom";

export default function Hearings() {
  const [date, setDate] = useState<Date>(startOfToday());
  const [view, setView] = useState<"daily" | "list" | "calendar">("daily");
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ 
    case_id: "", 
    hearing_date: format(new Date(), "yyyy-MM-dd"), 
    purpose: "", 
    status: "pending" 
  });
  const [searchQuery, setSearchQuery] = useState("");

  const { toast } = useToast();
  const qc = useQueryClient();
  const navigate = useNavigate();

  const { data: hearings = [], isLoading } = useRealtimeQuery({ 
    queryKey: ["hearings"], 
    queryFn: fetchHearings, 
    table: "hearings" 
  });
  const { data: cases = [] } = useQuery({ 
    queryKey: ["cases"], 
    queryFn: fetchCases 
  });

  const {
    data: paginatedHearings = [],
    page,
    totalPages,
    totalCount: paginatedTotalCount,
    nextPage,
    prevPage,
    isLoading: isPaginatedLoading,
    isTransitioning,
  } = usePaginatedQuery({
    queryKey: ["hearings-list"],
    queryFn: ({ page, pageSize }) => fetchHearings(undefined, { page, pageSize }),
    pageSize: 25,
    table: "hearings",
  });

  const scheduleMut = useMutation({
    mutationFn: () => scheduleHearing(form),
    onSuccess: () => { 
      qc.invalidateQueries({ queryKey: ["hearings"] }); 
      setOpen(false); 
      setForm({ case_id: "", hearing_date: format(new Date(), "yyyy-MM-dd"), purpose: "", status: "pending" });
      toast({ title: "Hearing scheduled successfully!" }); 
    },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  const deleteMut = useMutation({
    mutationFn: deleteHearing,
    onSuccess: () => { 
      qc.invalidateQueries({ queryKey: ["hearings"] }); 
      qc.invalidateQueries({ queryKey: ["hearings-list", "paginated"] });
      toast({ title: "Hearing deleted" }); 
    },
  });

  const updateStatusMut = useMutation({
    mutationFn: ({ id, status }: { id: string; status: string }) => updateHearingStatus(id, status),
    onSuccess: () => { 
      qc.invalidateQueries({ queryKey: ["hearings"] }); 
      qc.invalidateQueries({ queryKey: ["hearings-list", "paginated"] });
      toast({ title: "Hearing status updated" }); 
    },
  });

  const todayHearings = hearings.filter(h => isSameDay(parseISO(h.hearing_date), date));
  
  // Date pills for mobile timeline (7 days around selected date)
  const datePills = Array.from({ length: 7 }, (_, i) => addDays(subDays(date, 3), i));

  // Dynamic statistics
  const totalCount = hearings.length;
  const completedCount = hearings.filter(h => h.status === "completed").length;
  const adjournedCount = hearings.filter(h => h.status === "adjourned").length;
  const pendingCount = hearings.filter(h => h.status === "pending" || !h.status).length;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.case_id) {
      toast({ title: "Please select a case", variant: "destructive" });
      return;
    }
    scheduleMut.mutate();
  };

  const filteredHearingsForList = (view === "list" ? paginatedHearings : hearings).filter((h: any) => {
    const caseTitle = (h.cases as any)?.case_title || "";
    const purpose = h.purpose || "";
    const term = searchQuery.toLowerCase();
    return caseTitle.toLowerCase().includes(term) || purpose.toLowerCase().includes(term);
  });

  return (
    <div className="space-y-6 max-w-7xl mx-auto pb-12">
      {/* HEADER SECTION */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight flex items-center gap-2">
            <CalendarIcon className="h-6 w-6 text-primary" />
            Court Diary & Schedules
          </h1>
          <p className="text-xs text-muted-foreground">Manage litigation hearings, court diaries, and status logs.</p>
        </div>
        <div className="flex items-center gap-2 self-start sm:self-center">
          <Select value={view} onValueChange={(v: any) => setView(v)}>
            <SelectTrigger className="w-36 text-xs h-9 bg-card border-border"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="daily" className="text-xs">Daily Timeline</SelectItem>
              <SelectItem value="list" className="text-xs">Master List</SelectItem>
              <SelectItem value="calendar" className="text-xs">Calendar View</SelectItem>
            </SelectContent>
          </Select>

          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm" className="bg-primary hover:bg-primary/95 text-xs h-9">
                <Plus className="h-4 w-4 mr-1" /> Schedule Hearing
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[450px]">
              <DialogHeader>
                <DialogTitle>Schedule Hearing</DialogTitle>
                <DialogDescription>Attach hearing schedules to active law cases in the database.</DialogDescription>
              </DialogHeader>
              <form onSubmit={handleSubmit} className="space-y-4 pt-3">
                <div className="space-y-1.5">
                  <Label className="text-xs font-semibold">Select Case File *</Label>
                  <Select value={form.case_id} onValueChange={(v) => setForm({ ...form, case_id: v })} required>
                    <SelectTrigger className="text-xs h-9">
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
                    <Label className="text-xs font-semibold">Hearing Date *</Label>
                    <Input 
                      type="date" 
                      value={form.hearing_date} 
                      onChange={(e) => setForm({ ...form, hearing_date: e.target.value })} 
                      className="text-xs h-9" 
                      required 
                    />
                  </div>
                  <div className="space-y-1.5">
                    <Label className="text-xs font-semibold">Initial Status</Label>
                    <Select value={form.status} onValueChange={(v) => setForm({ ...form, status: v })}>
                      <SelectTrigger className="text-xs h-9">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="pending" className="text-xs">Pending</SelectItem>
                        <SelectItem value="completed" className="text-xs">Completed</SelectItem>
                        <SelectItem value="adjourned" className="text-xs">Adjourned</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>

                <div className="space-y-1.5">
                  <Label className="text-xs font-semibold">Hearing Purpose / Stage</Label>
                  <Input 
                    value={form.purpose} 
                    onChange={(e) => setForm({ ...form, purpose: e.target.value })} 
                    placeholder="e.g. Evidence, Final Arguments, Admission..." 
                    className="text-xs h-9"
                  />
                </div>

                <Button type="submit" className="w-full text-xs h-9 mt-2" disabled={scheduleMut.isPending}>
                  {scheduleMut.isPending ? "Scheduling..." : "Schedule Session"}
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* METRICS HEADER CARDS */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <Card className="border border-border/50 shadow-sm bg-card hover:shadow-md transition-shadow">
          <CardContent className="p-4 flex items-center justify-between">
            <div>
              <span className="text-[10px] font-bold text-muted-foreground uppercase tracking-wider">Scheduled Today</span>
              <p className="text-2xl font-black text-slate-800 leading-none mt-1">{todayHearings.length}</p>
            </div>
            <div className="w-9 h-9 bg-blue-50 text-blue-600 rounded-lg flex items-center justify-center">
              <CalendarIcon className="h-4.5 w-4.5" />
            </div>
          </CardContent>
        </Card>
        
        <Card className="border border-border/50 shadow-sm bg-card hover:shadow-md transition-shadow">
          <CardContent className="p-4 flex items-center justify-between">
            <div>
              <span className="text-[10px] font-bold text-muted-foreground uppercase tracking-wider">Pending Action</span>
              <p className="text-2xl font-black text-amber-600 leading-none mt-1">{pendingCount}</p>
            </div>
            <div className="w-9 h-9 bg-amber-50 text-amber-600 rounded-lg flex items-center justify-center">
              <Clock className="h-4.5 w-4.5" />
            </div>
          </CardContent>
        </Card>

        <Card className="border border-border/50 shadow-sm bg-card hover:shadow-md transition-shadow">
          <CardContent className="p-4 flex items-center justify-between">
            <div>
              <span className="text-[10px] font-bold text-muted-foreground uppercase tracking-wider">Adjourned</span>
              <p className="text-2xl font-black text-red-600 leading-none mt-1">{adjournedCount}</p>
            </div>
            <div className="w-9 h-9 bg-red-50 text-red-600 rounded-lg flex items-center justify-center">
              <AlertTriangle className="h-4.5 w-4.5" />
            </div>
          </CardContent>
        </Card>

        <Card className="border border-border/50 shadow-sm bg-card hover:shadow-md transition-shadow">
          <CardContent className="p-4 flex items-center justify-between">
            <div>
              <span className="text-[10px] font-bold text-muted-foreground uppercase tracking-wider">Completed Total</span>
              <p className="text-2xl font-black text-emerald-600 leading-none mt-1">{completedCount}</p>
            </div>
            <div className="w-9 h-9 bg-emerald-50 text-emerald-600 rounded-lg flex items-center justify-center">
              <CheckCircle className="h-4.5 w-4.5" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* MOBILE DATE STRIP (7-day timeline scrollbar) */}
      <div className="md:hidden space-y-3">
        <div className="flex items-center justify-between">
          <button
            onClick={() => setDate(d => subDays(d, 1))}
            className="w-8 h-8 rounded-full border bg-card flex items-center justify-center active:scale-95 transition-transform"
          >
            <ChevronLeft className="h-4 w-4" />
          </button>
          
          <div className="flex-1 flex gap-2 overflow-x-auto scrollbar-hide px-2">
            {datePills.map((d) => {
              const isSelected = isSameDay(d, date);
              const isTodayDate = isSameDay(d, startOfToday());
              const countOnDay = hearings.filter(h => isSameDay(parseISO(h.hearing_date), d)).length;
              
              return (
                <button
                  key={d.toISOString()}
                  onClick={() => setDate(d)}
                  className={cn(
                    "flex flex-col items-center px-3.5 py-2 rounded-2xl min-w-[52px] border transition-all duration-200",
                    isSelected
                      ? "bg-primary text-primary-foreground border-primary shadow-md scale-105"
                      : isTodayDate
                        ? "bg-primary/5 text-primary border-primary/20"
                        : "bg-card text-slate-700 border-border"
                  )}
                >
                  <span className="text-[9px] font-bold uppercase opacity-80">{format(d, "EEE")}</span>
                  <span className="text-sm font-black leading-none mt-1">{format(d, "d")}</span>
                  {countOnDay > 0 && (
                    <div className={cn(
                      "w-1.5 h-1.5 rounded-full mt-1.5",
                      isSelected ? "bg-white" : "bg-primary"
                    )} />
                  )}
                </button>
              );
            })}
          </div>

          <button
            onClick={() => setDate(d => addDays(d, 1))}
            className="w-8 h-8 rounded-full border bg-card flex items-center justify-center active:scale-95 transition-transform"
          >
            <ChevronRight className="h-4 w-4" />
          </button>
        </div>

        {/* Selected date header details */}
        <div className="p-4 bg-muted/30 border border-border/60 rounded-2xl">
          <span className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest block">Selected Schedule</span>
          <span className="font-extrabold text-xs text-slate-800 block mt-0.5">
            {isSameDay(date, startOfToday()) ? "Today" : format(date, "EEEE, dd MMMM yyyy")}
          </span>
          <span className="text-[10px] text-indigo-600 font-bold block mt-1">
            {todayHearings.length} session{todayHearings.length !== 1 ? "s" : ""} active
          </span>
        </div>

        {/* MOBILE CARDS TIMELINE */}
        {isLoading ? (
          <div className="flex flex-col items-center py-10 gap-2 text-muted-foreground">
            <RefreshCw className="h-6 w-6 animate-spin text-primary" />
            <span className="text-xs">Fetching court diary...</span>
          </div>
        ) : todayHearings.length === 0 ? (
          <div className="text-center py-12 bg-card border rounded-2xl text-xs text-muted-foreground">
            <Gavel className="h-8 w-8 mx-auto mb-2 text-muted-foreground/35" />
            No court sessions scheduled for this date.
          </div>
        ) : (
          <div className="space-y-3">
            {todayHearings.map((h: any) => (
              <div key={h.id} className="p-4 bg-card border rounded-2xl shadow-sm space-y-4">
                <div className="flex justify-between items-start gap-3">
                  <div className="space-y-1">
                    <span className="text-[9px] uppercase font-black px-1.5 py-0.5 bg-slate-100 text-slate-600 rounded">
                      {(h.cases as any)?.case_number || "OS N/A"}
                    </span>
                    <h3 className="font-bold text-xs text-slate-800 leading-tight pt-1">{(h.cases as any)?.case_title}</h3>
                    <p className="text-[10px] text-muted-foreground font-semibold flex items-center gap-1">
                      <Clock className="h-3.5 w-3.5" /> {h.purpose || "Regular Hearing"}
                    </p>
                  </div>
                  <StatusBadge status={h.status} />
                </div>
                
                <div className="flex items-center justify-between border-t border-border/40 pt-3">
                  <Select value={h.status || "pending"} onValueChange={(s) => updateStatusMut.mutate({ id: h.id, status: s })}>
                    <SelectTrigger className="w-28 h-8 text-xs font-semibold"><SelectValue /></SelectTrigger>
                    <SelectContent>
                      {["pending", "completed", "adjourned", "no_show"].map(s => (
                        <SelectItem key={s} value={s} className="text-xs">{s}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  
                  <div className="flex items-center gap-1">
                    <Button size="sm" variant="ghost" className="h-8 w-8 text-primary" onClick={() => navigate(`/cases/${h.case_id}`)}>
                      <ArrowUpRight className="h-4.5 w-4.5" />
                    </Button>
                    <Button 
                      size="sm" 
                      variant="ghost" 
                      className="h-8 w-8 text-destructive"
                      onClick={() => { if (confirm("Delete this hearing session?")) deleteMut.mutate(h.id); }}
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* DESKTOP DIARY WORKSPACE */}
      <div className="hidden md:block">
        {view === "calendar" ? (
          <Card className="border border-border/60 rounded-2xl shadow-sm">
            <CardHeader>
              <CardTitle className="text-base font-bold flex items-center gap-2">
                <CalendarIcon className="h-5 w-5 text-primary" />
                Master Calendar Grid
              </CardTitle>
              <CardDescription className="text-xs">Click a date to display and manage hearings on that specific day.</CardDescription>
            </CardHeader>
            <CardContent className="flex justify-center p-6 border-t">
              <Calendar 
                mode="single" 
                selected={date} 
                onSelect={(d) => d && setDate(d)} 
                className="w-full max-w-2xl border rounded-2xl p-4 shadow-sm bg-card" 
              />
            </CardContent>
          </Card>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
            {/* Sidebar Calendar picker */}
            <div className="lg:col-span-4 space-y-4">
              <Card className="border border-border/60 rounded-2xl shadow-sm bg-card overflow-hidden">
                <CardHeader className="pb-3 border-b">
                  <CardTitle className="text-sm font-bold flex items-center gap-2">
                    <CalendarIcon className="h-4.5 w-4.5 text-primary" />
                    Date Selection
                  </CardTitle>
                </CardHeader>
                <CardContent className="p-3">
                  <Calendar 
                    mode="single" 
                    selected={date} 
                    onSelect={(d) => d && setDate(d)} 
                    className="border-0 w-full"
                  />
                </CardContent>
              </Card>

              {view === "list" && (
                <Card className="border border-border/60 rounded-2xl shadow-sm">
                  <CardContent className="p-4 space-y-3">
                    <Label className="text-xs font-semibold">Search Filter</Label>
                    <div className="relative">
                      <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
                      <Input 
                        placeholder="Search case title or stage..." 
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="pl-8 text-xs h-9 bg-card"
                      />
                    </div>
                  </CardContent>
                </Card>
              )}
            </div>

            {/* Main Daily Timeline or master list */}
            <div className="lg:col-span-8">
              <Card className="border border-border/60 rounded-2xl shadow-sm bg-card">
                <CardHeader className="pb-3 border-b flex-row items-center justify-between">
                  <div>
                    <CardTitle className="text-base font-bold flex items-center gap-2">
                      <Gavel className="h-5 w-5 text-primary" />
                      {view === "daily" ? `Daily Schedule: ${format(date, "dd MMMM yyyy")}` : `All Scheduled Hearings (${paginatedTotalCount})`}
                    </CardTitle>
                    <CardDescription className="text-xs">
                      {view === "daily" 
                        ? `Listing court sessions for ${format(date, "EEEE")}.` 
                        : "Comprehensive listing of all legal hearings in the system."
                      }
                    </CardDescription>
                  </div>
                  
                  {view === "daily" && (
                    <span className="text-xs font-bold text-indigo-600 bg-indigo-50 border border-indigo-100 rounded-full px-3 py-1">
                      {todayHearings.length} Active Session{todayHearings.length !== 1 ? "s" : ""}
                    </span>
                  )}
                </CardHeader>
                
                <CardContent className="pt-6">
                  {isLoading || (view === "list" && isPaginatedLoading) ? (
                    <div className="flex flex-col items-center py-12 gap-2 text-muted-foreground">
                      <RefreshCw className="h-6 w-6 animate-spin text-primary" />
                      <span className="text-xs">Loading schedules...</span>
                    </div>
                  ) : (view === "daily" ? todayHearings : filteredHearingsForList).length === 0 ? (
                    <div className="text-center py-16 text-xs text-muted-foreground border border-dashed rounded-xl bg-muted/10">
                      <Gavel className="h-8 w-8 mx-auto mb-2 text-muted-foreground/30" />
                      No scheduled sessions located for this period.
                    </div>
                  ) : view === "daily" ? (
                    /* RICH DAILY TIMELINE LIST */
                    <div className="space-y-4">
                      {todayHearings.map((h: any) => {
                        const caseTitle = (h.cases as any)?.case_title || "Unknown Case Title";
                        const caseNumber = (h.cases as any)?.case_number || "OS N/A";
                        return (
                          <div 
                            key={h.id} 
                            className="flex flex-col sm:flex-row sm:items-center justify-between p-4 bg-muted/10 hover:bg-muted/30 border rounded-xl hover:shadow-sm transition-all duration-300 gap-4"
                          >
                            <div className="flex items-start gap-3">
                              <div className="p-2.5 bg-card border text-slate-700 rounded-lg shrink-0 mt-0.5 shadow-sm">
                                <Gavel className="h-4.5 w-4.5 text-primary" />
                              </div>
                              <div className="space-y-1">
                                <h4 
                                  className="font-bold text-xs text-slate-800 hover:underline cursor-pointer flex items-center gap-1.5" 
                                  onClick={() => navigate(`/cases/${h.case_id}`)}
                                >
                                  {caseTitle}
                                </h4>
                                <div className="flex flex-wrap gap-2 text-[10px] text-muted-foreground font-semibold">
                                  <span className="font-mono bg-card border px-1.5 py-0.5 rounded text-slate-600">{caseNumber}</span>
                                  <span className="flex items-center gap-0.5"><Clock className="h-3 w-3" /> {h.purpose || "Regular Hearing"}</span>
                                </div>
                              </div>
                            </div>

                            <div className="flex items-center justify-between sm:justify-end gap-3 border-t sm:border-t-0 pt-3 sm:pt-0 border-border/40">
                              <div className="flex items-center gap-2">
                                <span className="text-[10px] font-bold text-muted-foreground uppercase tracking-wider hidden sm:inline">Status</span>
                                <Select value={h.status || "pending"} onValueChange={(s) => updateStatusMut.mutate({ id: h.id, status: s })}>
                                  <SelectTrigger className="w-28 h-8 text-xs font-semibold">
                                    <SelectValue />
                                  </SelectTrigger>
                                  <SelectContent>
                                    <SelectItem value="pending" className="text-xs">Pending</SelectItem>
                                    <SelectItem value="completed" className="text-xs">Completed</SelectItem>
                                    <SelectItem value="adjourned" className="text-xs">Adjourned</SelectItem>
                                    <SelectItem value="no_show" className="text-xs">No Show</SelectItem>
                                  </SelectContent>
                                </Select>
                              </div>

                              <div className="flex items-center gap-1">
                                <Button 
                                  variant="ghost" 
                                  size="sm" 
                                  className="h-8 w-8 p-0"
                                  onClick={() => navigate(`/cases/${h.case_id}`)}
                                  title="View Case detail"
                                >
                                  <ArrowUpRight className="h-4.5 w-4.5" />
                                </Button>
                                <Button 
                                  variant="ghost" 
                                  size="sm" 
                                  className="h-8 w-8 text-red-500 hover:text-red-600 hover:bg-red-50 p-0"
                                  onClick={() => { if (confirm("Delete this hearing session?")) deleteMut.mutate(h.id); }}
                                >
                                  <Trash2 className="h-4 w-4" />
                                </Button>
                              </div>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  ) : (
                    /* RICH MASTER TABLE VIEW */
                    <div className="border rounded-2xl overflow-hidden bg-card shadow-inner">
                      <Table>
                        <TableHeader>
                          <TableRow className="bg-slate-50/50 hover:bg-slate-50/50">
                            <TableHead className="font-bold text-xs">Date</TableHead>
                            <TableHead className="font-bold text-xs">Case File Title</TableHead>
                            <TableHead className="font-bold text-xs">Hearing Purpose</TableHead>
                            <TableHead className="font-bold text-xs">Session Status</TableHead>
                            <TableHead className="font-bold text-xs text-right">Actions</TableHead>
                          </TableRow>
                        </TableHeader>
                        <TableBody>
                          {filteredHearingsForList.map((h: any) => (
                            <TableRow key={h.id} className="hover:bg-muted/10">
                              <TableCell className="text-xs font-bold whitespace-nowrap">
                                {format(parseISO(h.hearing_date), "dd MMM yyyy")}
                              </TableCell>
                              <TableCell className="max-w-xs truncate">
                                <div className="space-y-0.5">
                                  <span className="font-bold text-xs block text-slate-800 hover:underline cursor-pointer" onClick={() => navigate(`/cases/${h.case_id}`)}>
                                    {(h.cases as any)?.case_title}
                                  </span>
                                  <span className="text-[9px] font-mono text-muted-foreground">{(h.cases as any)?.case_number || "OS N/A"}</span>
                                </div>
                              </TableCell>
                              <TableCell className="text-xs font-semibold text-slate-700">{h.purpose || "Regular Hearing"}</TableCell>
                              <TableCell>
                                <Select value={h.status || "pending"} onValueChange={(s) => updateStatusMut.mutate({ id: h.id, status: s })}>
                                  <SelectTrigger className="w-28 h-8 text-xs font-semibold"><SelectValue /></SelectTrigger>
                                  <SelectContent>
                                    {["pending", "completed", "adjourned", "no_show"].map(s => (
                                      <SelectItem key={s} value={s} className="text-xs">{s}</SelectItem>
                                    ))}
                                  </SelectContent>
                                </Select>
                              </TableCell>
                              <TableCell className="text-right space-x-1">
                                <Button 
                                  variant="ghost" 
                                  size="sm" 
                                  className="h-8 w-8 p-0"
                                  onClick={() => navigate(`/cases/${h.case_id}`)}
                                >
                                  <ArrowUpRight className="h-4 w-4" />
                                </Button>
                                <Button 
                                  variant="ghost" 
                                  size="sm" 
                                  className="h-8 w-8 text-destructive p-0"
                                  onClick={() => { if (confirm("Delete this hearing session?")) deleteMut.mutate(h.id); }}
                                >
                                  <Trash2 className="h-4 w-4" />
                                </Button>
                              </TableCell>
                            </TableRow>
                          ))}
                        </TableBody>
                      </Table>
                    </div>
                  )}

                  {view === "list" && totalPages > 1 && (
                    <div className="flex items-center justify-between pt-4 border-t mt-4">
                      <p className="text-xs text-muted-foreground">
                        Showing page {page} of {totalPages} ({paginatedTotalCount} total)
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
                </CardContent>
              </Card>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
