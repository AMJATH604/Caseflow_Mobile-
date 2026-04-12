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
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";
import { Plus, Trash2, Gavel, Clock, ChevronLeft, ChevronRight } from "lucide-react";
import { StatusBadge } from "@/components/StatusBadge";
import { useRealtimeQuery } from "@/hooks/useRealtimeQuery";
import { cn } from "@/lib/utils";

export default function Hearings() {
  const [date, setDate] = useState<Date>(startOfToday());
  const [view, setView] = useState<"daily" | "list" | "calendar">("daily");
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ case_id: "", hearing_date: format(new Date(), "yyyy-MM-dd"), purpose: "", status: "pending" });

  const { toast } = useToast();
  const qc = useQueryClient();

  const { data: hearings = [], isLoading } = useRealtimeQuery({ queryKey: ["hearings"], queryFn: fetchHearings, table: "hearings" });
  const { data: cases = [] } = useQuery({ queryKey: ["cases"], queryFn: fetchCases });

  const scheduleMut = useMutation({
    mutationFn: () => scheduleHearing(form),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["hearings"] }); setOpen(false); toast({ title: "Hearing scheduled" }); },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  const deleteMut = useMutation({
    mutationFn: deleteHearing,
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["hearings"] }); toast({ title: "Hearing deleted" }); },
  });

  const updateStatusMut = useMutation({
    mutationFn: ({ id, status }: { id: string; status: string }) => updateHearingStatus(id, status),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["hearings"] }); toast({ title: "Status updated" }); },
  });

  const todayHearings = hearings.filter(h => isSameDay(parseISO(h.hearing_date), date));

  // Generate date pills for mobile (7 days around selected date)
  const datePills = Array.from({ length: 7 }, (_, i) => addDays(subDays(date, 3), i));

  return (
    <div className="space-y-4">
      {/* Desktop Header */}
      <div className="hidden md:flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-serif font-bold text-foreground">Court Diary</h1>
          <p className="text-sm text-muted-foreground">Schedule and manage hearings</p>
        </div>
        <div className="flex items-center gap-2">
          <Select value={view} onValueChange={(v: any) => setView(v)}>
            <SelectTrigger className="w-32"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="daily">Daily View</SelectItem>
              <SelectItem value="list">All Hearings</SelectItem>
              <SelectItem value="calendar">Calendar</SelectItem>
            </SelectContent>
          </Select>
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild><Button size="sm" className="md:h-10"><Plus className="h-4 w-4 mr-2" /> New Hearing</Button></DialogTrigger>
            <DialogContent>
              <DialogHeader><DialogTitle>Schedule Hearing</DialogTitle></DialogHeader>
              <form onSubmit={(e) => { e.preventDefault(); scheduleMut.mutate(); }} className="space-y-4">
                <div className="space-y-2">
                  <Label>Case *</Label>
                  <Select value={form.case_id} onValueChange={(v) => setForm({ ...form, case_id: v })}>
                    <SelectTrigger><SelectValue placeholder="Select case" /></SelectTrigger>
                    <SelectContent>{cases.map((c: any) => <SelectItem key={c.id} value={c.id}>{c.case_title}</SelectItem>)}</SelectContent>
                  </Select>
                </div>
                <div className="space-y-2"><Label>Date *</Label><Input type="date" value={form.hearing_date} onChange={(e) => setForm({ ...form, hearing_date: e.target.value })} required /></div>
                <div className="space-y-2"><Label>Purpose</Label><Input value={form.purpose} onChange={(e) => setForm({ ...form, purpose: e.target.value })} placeholder="Final Arguments, Evidence..." /></div>
                <Button type="submit" className="w-full" disabled={scheduleMut.isPending}>Schedule</Button>
              </form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* ═══ MOBILE VIEW ═══ */}
      <div className="md:hidden space-y-4">
        {/* Date Selector */}
        <div className="flex items-center gap-2">
          <button
            onClick={() => setDate(d => subDays(d, 1))}
            className="w-8 h-8 rounded-full bg-muted/40 flex items-center justify-center active:scale-90 transition-transform"
          >
            <ChevronLeft className="h-4 w-4" />
          </button>
          <div className="flex-1 flex gap-1.5 overflow-x-auto scrollbar-hide">
            {datePills.map((d) => {
              const isSelected = isSameDay(d, date);
              const isToday = isSameDay(d, startOfToday());
              const dayHearings = hearings.filter(h => isSameDay(parseISO(h.hearing_date), d));
              return (
                <button
                  key={d.toISOString()}
                  onClick={() => setDate(d)}
                  className={cn(
                    "flex flex-col items-center px-3 py-2 rounded-xl min-w-[48px] transition-all duration-150",
                    isSelected
                      ? "bg-primary text-primary-foreground shadow-md"
                      : isToday
                        ? "bg-primary/10 text-primary"
                        : "bg-muted/30 text-foreground"
                  )}
                >
                  <span className="text-[10px] font-medium uppercase opacity-70">{format(d, "EEE")}</span>
                  <span className="text-base font-bold leading-none mt-0.5">{format(d, "d")}</span>
                  {dayHearings.length > 0 && (
                    <div className={cn(
                      "w-1.5 h-1.5 rounded-full mt-1",
                      isSelected ? "bg-primary-foreground" : "bg-primary"
                    )} />
                  )}
                </button>
              );
            })}
          </div>
          <button
            onClick={() => setDate(d => addDays(d, 1))}
            className="w-8 h-8 rounded-full bg-muted/40 flex items-center justify-center active:scale-90 transition-transform"
          >
            <ChevronRight className="h-4 w-4" />
          </button>
        </div>

        {/* Selected Date Label */}
        <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
          {isSameDay(date, startOfToday()) ? "Today" : format(date, "EEEE, dd MMMM")} · {todayHearings.length} hearing{todayHearings.length !== 1 ? "s" : ""}
        </p>

        {/* Hearing Cards */}
        {isLoading ? (
          <div className="py-12 text-center text-sm text-muted-foreground">Loading hearings...</div>
        ) : todayHearings.length === 0 ? (
          <div className="mobile-card text-center py-8">
            <Gavel className="h-8 w-8 text-muted-foreground/30 mx-auto mb-2" />
            <p className="text-sm text-muted-foreground">No hearings on this date</p>
          </div>
        ) : (
          <div className="space-y-3">
            {todayHearings.map((h: any) => (
              <div key={h.id} className="mobile-card space-y-3">
                <div className="flex justify-between items-start gap-3">
                  <div className="min-w-0 flex-1">
                    <h3 className="font-bold text-sm leading-tight">{(h.cases as any)?.case_title}</h3>
                    <p className="text-xs text-muted-foreground mt-1 flex items-center gap-1">
                      <Clock className="h-3 w-3" /> {h.purpose || "No Purpose Set"}
                    </p>
                  </div>
                  <StatusBadge status={h.status} />
                </div>
                <div className="flex items-center justify-between pt-2 border-t border-border/30">
                  <Select value={h.status} onValueChange={(s) => updateStatusMut.mutate({ id: h.id, status: s })}>
                    <SelectTrigger className="w-28 h-8 text-xs font-semibold"><SelectValue /></SelectTrigger>
                    <SelectContent>
                      {["pending", "completed", "adjourned", "no_show"].map(s => <SelectItem key={s} value={s}>{s}</SelectItem>)}
                    </SelectContent>
                  </Select>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-8 w-8 text-destructive"
                    onClick={() => { if (confirm("Delete hearing?")) deleteMut.mutate(h.id); }}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* ═══ DESKTOP VIEW ═══ */}
      <div className="hidden md:block">
        {view === "calendar" ? (
          <Card><CardContent className="p-0"><Calendar mode="single" selected={date} onSelect={(d) => d && setDate(d)} className="w-full" /></CardContent></Card>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
            <div className="hidden lg:block">
              <Card><CardContent className="p-0"><Calendar mode="single" selected={date} onSelect={(d) => d && setDate(d)} className="rounded-md border-0" /></CardContent></Card>
            </div>
            <div className="lg:col-span-3">
              <Card>
                <CardHeader className="pb-3 flex-row items-center justify-between">
                  <CardTitle className="text-lg font-serif flex items-center gap-2">
                    <Gavel className="h-5 w-5" /> {view === "daily" ? `Hearings: ${format(date, "dd MMM yyyy")}` : "All Hearings"}
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  {isLoading ? <p>Loading...</p> : (view === "daily" ? todayHearings : hearings).length === 0 ?
                    <p className="text-center py-12 text-muted-foreground">No hearings found for this period.</p>
                    : (
                      <Table>
                        <TableHeader>
                          <TableRow>
                            <TableHead>Case</TableHead>
                            <TableHead>Purpose</TableHead>
                            <TableHead>Status</TableHead>
                            <TableHead>Action</TableHead>
                          </TableRow>
                        </TableHeader>
                        <TableBody>
                          {(view === "daily" ? todayHearings : hearings).map((h: any) => (
                            <TableRow key={h.id}>
                              <TableCell className="font-medium">{(h.cases as any)?.case_title}</TableCell>
                              <TableCell>{h.purpose}</TableCell>
                              <TableCell>
                                <Select value={h.status} onValueChange={(s) => updateStatusMut.mutate({ id: h.id, status: s })}>
                                  <SelectTrigger className="w-32 h-8"><SelectValue /></SelectTrigger>
                                  <SelectContent>
                                    {["pending", "completed", "adjourned", "no_show"].map(s => <SelectItem key={s} value={s}>{s}</SelectItem>)}
                                  </SelectContent>
                                </Select>
                              </TableCell>
                              <TableCell>
                                <Button variant="ghost" size="icon" onClick={() => { if (confirm("Delete hearing?")) deleteMut.mutate(h.id); }}><Trash2 className="h-4 w-4 text-destructive" /></Button>
                              </TableCell>
                            </TableRow>
                          ))}
                        </TableBody>
                      </Table>
                    )
                  }
                </CardContent>
              </Card>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
