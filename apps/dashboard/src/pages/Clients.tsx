import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useRealtimeQuery } from "@/hooks/useRealtimeQuery";
import { usePaginatedQuery } from "@/hooks/usePaginatedQuery";
import { fetchClients, createClient, deleteClient } from "@/lib/supabase-helpers";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { useToast } from "@/hooks/use-toast";
import { Plus, Trash2, Users, Phone, Mail, Calendar, Search, ChevronLeft, ChevronRight } from "lucide-react";
import { format } from "date-fns";
import { cn } from "@/lib/utils";

export default function Clients() {
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState("");
  const [form, setForm] = useState({ name: "", phone: "", email: "", address: "" });
  const { toast } = useToast();
  const qc = useQueryClient();

  const { data: clients = [], page, totalPages, totalCount, nextPage, prevPage, isLoading, isTransitioning } = usePaginatedQuery({
    queryKey: ["clients"],
    queryFn: ({ page, pageSize }) => fetchClients({ page, pageSize }),
    pageSize: 25,
    table: "clients",
  });

  const createMut = useMutation({
    mutationFn: () => createClient(form),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["clients", "paginated"] }); setOpen(false); setForm({ name: "", phone: "", email: "", address: "" }); toast({ title: "Client added" }); },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  const deleteMut = useMutation({
    mutationFn: deleteClient,
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["clients", "paginated"] }); toast({ title: "Client deleted" }); },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  const filteredClients = clients.filter((c: any) =>
    !search || c.name?.toLowerCase().includes(search.toLowerCase()) || c.phone?.includes(search) || c.email?.toLowerCase().includes(search.toLowerCase())
  );

  const getInitials = (name: string) => {
    return name.split(" ").map(n => n[0]).join("").toUpperCase().slice(0, 2);
  };

  const avatarColors = [
    "bg-blue-500", "bg-emerald-500", "bg-amber-500", "bg-purple-500", "bg-rose-500",
    "bg-teal-500", "bg-indigo-500", "bg-pink-500", "bg-cyan-500", "bg-orange-500"
  ];

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="hidden md:block">
          <h1 className="text-2xl font-serif font-bold text-foreground">Clients</h1>
          <p className="text-sm text-muted-foreground mt-1">Manage your client directory</p>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button size="sm" className="md:h-10 md:px-4 hidden md:flex"><Plus className="h-4 w-4 mr-2" /> Add Client</Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader><DialogTitle>Add New Client</DialogTitle></DialogHeader>
            <form onSubmit={(e) => { e.preventDefault(); createMut.mutate(); }} className="space-y-4">
              <div className="space-y-2"><Label>Name *</Label><Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required /></div>
              <div className="space-y-2"><Label>Phone</Label><Input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} /></div>
              <div className="space-y-2"><Label>Email</Label><Input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></div>
              <div className="space-y-2"><Label>Address</Label><Input value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} /></div>
              <Button type="submit" className="w-full" disabled={createMut.isPending}>{createMut.isPending ? "Adding..." : "Add Client"}</Button>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {/* Mobile Search */}
      <div className="md:hidden relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground/50" />
        <input
          type="text"
          placeholder="Search clients..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="mobile-search pl-10"
        />
      </div>

      {/* Desktop Table */}
      <Card className="hidden md:block">
        <CardHeader className="pb-3">
          <CardTitle className="text-lg flex items-center gap-2"><Users className="h-5 w-5" /> Client Directory</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading ? <p className="text-sm text-muted-foreground">Loading...</p> : clients.length === 0 ? (
            <p className="text-sm text-muted-foreground py-8 text-center">No clients yet. Add your first client.</p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Phone</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Added</TableHead>
                  <TableHead></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {clients.map((c: any) => (
                  <TableRow key={c.id}>
                    <TableCell className="font-medium">{c.name}</TableCell>
                    <TableCell>{c.phone || "—"}</TableCell>
                    <TableCell>{c.email || "—"}</TableCell>
                    <TableCell>{format(new Date(c.created_at), "dd MMM yyyy")}</TableCell>
                    <TableCell>
                      <Button variant="ghost" size="icon" onClick={() => deleteMut.mutate(c.id)}><Trash2 className="h-4 w-4 text-destructive" /></Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Pagination Controls */}
      {totalPages > 1 && (
        <div className="hidden md:flex items-center justify-between px-2">
          <p className="text-sm text-muted-foreground">
            Showing page {page} of {totalPages} ({totalCount} total)
          </p>
          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" onClick={prevPage} disabled={page <= 1 || isTransitioning}>
              <ChevronLeft className="h-4 w-4 mr-1" /> Previous
            </Button>
            <Button variant="outline" size="sm" onClick={nextPage} disabled={page >= totalPages || isTransitioning}>
              Next <ChevronRight className="h-4 w-4 ml-1" />
            </Button>
          </div>
        </div>
      )}

      {/* Mobile Contact Cards */}
      <div className="md:hidden space-y-3">
        {isLoading ? (
          <div className="py-12 text-center text-sm text-muted-foreground">Loading clients...</div>
        ) : filteredClients.length === 0 ? (
          <div className="mobile-card text-center py-8">
            <Users className="h-8 w-8 text-muted-foreground/30 mx-auto mb-2" />
            <p className="text-sm text-muted-foreground">{search ? "No clients match your search" : "No clients yet"}</p>
          </div>
        ) : (
          filteredClients.map((c: any, i: number) => (
            <div key={c.id} className="mobile-card flex items-center gap-3">
              {/* Avatar */}
              <div className={cn(
                "w-11 h-11 rounded-full flex items-center justify-center text-white text-sm font-bold flex-shrink-0",
                avatarColors[i % avatarColors.length]
              )}>
                {getInitials(c.name)}
              </div>

              {/* Info */}
              <div className="flex-1 min-w-0">
                <h3 className="font-bold text-sm truncate">{c.name}</h3>
                <p className="text-xs text-muted-foreground truncate mt-0.5">
                  {c.phone || c.email || "No contact info"}
                </p>
              </div>

              {/* Quick Actions */}
              <div className="flex items-center gap-1 flex-shrink-0">
                {c.phone && (
                  <a
                    href={`tel:${c.phone}`}
                    className="w-9 h-9 rounded-full bg-emerald-50 flex items-center justify-center active:scale-90 transition-transform"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <Phone className="h-4 w-4 text-emerald-600" />
                  </a>
                )}
                {c.email && (
                  <a
                    href={`mailto:${c.email}`}
                    className="w-9 h-9 rounded-full bg-blue-50 flex items-center justify-center active:scale-90 transition-transform"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <Mail className="h-4 w-4 text-blue-600" />
                  </a>
                )}
                <button
                  className="w-9 h-9 rounded-full bg-red-50 flex items-center justify-center active:scale-90 transition-transform"
                  onClick={() => { if (window.confirm("Delete client?")) deleteMut.mutate(c.id); }}
                >
                  <Trash2 className="h-4 w-4 text-red-500" />
                </button>
              </div>
            </div>
          ))
        )}

        {/* Mobile Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between pt-2">
            <Button variant="outline" size="sm" onClick={prevPage} disabled={page <= 1 || isTransitioning}>
              <ChevronLeft className="h-4 w-4" />
            </Button>
            <span className="text-xs text-muted-foreground">
              {page} / {totalPages}
            </span>
            <Button variant="outline" size="sm" onClick={nextPage} disabled={page >= totalPages || isTransitioning}>
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>
        )}
      </div>
    </div>
  );
}
