import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useRealtimeQuery } from "@/hooks/useRealtimeQuery";
import { fetchAdvocates, createAdvocate, deleteAdvocate } from "@/lib/supabase-helpers";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Search, MapPin, Phone, Award, Users, Plus, Trash2, Mail } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";
import { states, getDistrictsForState } from "@/lib/geo-data";

export default function Advocates() {
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState("");
  const [selectedState, setSelectedState] = useState("All");
  const [selectedDistrict, setSelectedDistrict] = useState("All");
  const { toast } = useToast();
  const qc = useQueryClient();

  const [form, setForm] = useState({
    full_name: "",
    email: "",
    mobile_number: "",
    registration_number: "",
    practice_state: "",
    practice_district: "",
    office_address: ""
  });

  const { data: advocates = [], isLoading } = useRealtimeQuery({ 
    queryKey: ["advocates"], 
    queryFn: fetchAdvocates, 
    table: "profiles" 
  });

  const createMut = useMutation({
    mutationFn: () => createAdvocate(form),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["advocates"] });
      setOpen(false);
      setForm({ full_name: "", email: "", mobile_number: "", registration_number: "", practice_state: "", practice_district: "", office_address: "" });
      toast({ title: "Advocate Added", description: "The professional has been added to the directory." });
    },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });
  
  const deleteMut = useMutation({
    mutationFn: (id: string) => deleteAdvocate(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["advocates"] });
      toast({ title: "Advocate Removed", description: "The professional has been removed from the directory." });
    },
    onError: (e: any) => toast({ title: "Error", description: e.message, variant: "destructive" }),
  });

  const districts = getDistrictsForState(selectedState);
  const formDistricts = getDistrictsForState(form.practice_state);

  const filteredAdvocates = advocates.filter((a: any) => {
    const matchesSearch = !search || 
      a.full_name?.toLowerCase().includes(search.toLowerCase()) ||
      a.registration_number?.toLowerCase().includes(search.toLowerCase());
    const matchesState = selectedState === "All" || a.practice_state === selectedState;
    const matchesDistrict = selectedDistrict === "All" || a.practice_district === selectedDistrict;
    return matchesSearch && matchesState && matchesDistrict;
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-serif font-bold text-foreground">National Advocate Directory</h1>
          <p className="text-sm text-muted-foreground mt-1">Connect with legal professionals across the country</p>
        </div>
        
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button className="hidden md:flex gap-2">
              <Plus className="h-4 w-4" /> Add Advocate
            </Button>
          </DialogTrigger>
          <DialogContent className="max-w-md">
            <DialogHeader>
              <DialogTitle>Add Manual Entry</DialogTitle>
            </DialogHeader>
            <form onSubmit={(e) => { e.preventDefault(); createMut.mutate(); }} className="space-y-4 pt-4">
              <div className="space-y-2">
                <Label>Full Name *</Label>
                <Input value={form.full_name} onChange={e => setForm({...form, full_name: e.target.value})} required placeholder="Advocate Name" />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Registration No.</Label>
                  <Input value={form.registration_number} onChange={e => setForm({...form, registration_number: e.target.value})} placeholder="e.g. MS/123/2023" />
                </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Email (Gmail ID)</Label>
                  <Input value={form.email} onChange={e => setForm({...form, email: e.target.value})} placeholder="advocate@gmail.com" />
                </div>
                <div className="space-y-2">
                  <Label>Mobile Number</Label>
                  <Input value={form.mobile_number} onChange={e => setForm({...form, mobile_number: e.target.value})} placeholder="10-digit mobile" />
                </div>
              </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>State</Label>
                  <Select value={form.practice_state} onValueChange={v => setForm({...form, practice_state: v, practice_district: "All"})}>
                    <SelectTrigger><SelectValue placeholder="Select State" /></SelectTrigger>
                    <SelectContent>
                      {states.filter(s => s !== "All").map(s => <SelectItem key={s} value={s}>{s}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>District</Label>
                  <Select value={form.practice_district} onValueChange={v => setForm({...form, practice_district: v})}>
                    <SelectTrigger><SelectValue placeholder="Select District" /></SelectTrigger>
                    <SelectContent>
                      {formDistricts.map(d => <SelectItem key={d} value={d}>{d}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="space-y-2">
                <Label>Office Address</Label>
                <Input value={form.office_address} onChange={e => setForm({...form, office_address: e.target.value})} placeholder="Detailed address" />
              </div>
              <Button type="submit" className="w-full" disabled={createMut.isPending}>
                {createMut.isPending ? "Adding..." : "Confirm & Add"}
              </Button>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      {/* Filters */}
      <Card className="border-none shadow-sm bg-muted/30">
        <CardContent className="p-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground/50" />
              <Input 
                placeholder="Search name or registration..." 
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="pl-10"
              />
            </div>
            <Select value={selectedState} onValueChange={(v) => { setSelectedState(v); setSelectedDistrict("All"); }}>
              <SelectTrigger>
                <SelectValue placeholder="Select State" />
              </SelectTrigger>
              <SelectContent>
                {states.map(s => <SelectItem key={s} value={s}>{s}</SelectItem>)}
              </SelectContent>
            </Select>
            <Select value={selectedDistrict} onValueChange={setSelectedDistrict}>
              <SelectTrigger>
                <SelectValue placeholder="Select District" />
              </SelectTrigger>
              <SelectContent>
                {districts.map(d => <SelectItem key={d} value={d}>{d}</SelectItem>)}
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      {/* Grid */}
      {isLoading ? (
        <div className="flex items-center justify-center py-20">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
        </div>
      ) : filteredAdvocates.length === 0 ? (
        <div className="text-center py-20 bg-muted/10 rounded-xl border border-dashed">
          <Users className="h-10 w-10 text-muted-foreground/20 mx-auto mb-4" />
          <h3 className="text-lg font-medium">No Advocates Found</h3>
          <p className="text-sm text-muted-foreground mt-1">Try adjusting your search or filters</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredAdvocates.map((advocate: any) => (
            <Card key={advocate.id} className="hover:shadow-md transition-shadow group">
              <CardHeader className="pb-3">
                <div className="flex items-start justify-between">
                  <div>
                    <CardTitle className="text-base font-bold group-hover:text-primary transition-colors">
                      {advocate.full_name}
                    </CardTitle>
                    <div className="flex items-center gap-1.5 text-xs text-muted-foreground mt-1">
                      <Award className="h-3 w-3" />
                      {advocate.registration_number || "Not Registered"}
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <button 
                      onClick={() => { if(confirm("Remove this advocate from directory?")) deleteMut.mutate(advocate.id); }}
                      className="p-1.5 text-muted-foreground hover:text-destructive transition-colors"
                      title="Delete Advocate"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                    <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold">
                      {advocate.full_name?.charAt(0)}
                    </div>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex items-start gap-2 text-sm">
                  <MapPin className="h-4 w-4 text-muted-foreground mt-0.5" />
                  <div className="flex-1">
                    <p className="font-medium text-xs">
                      {advocate.practice_district}, {advocate.practice_state}
                    </p>
                    <p className="text-xs text-muted-foreground mt-0.5 line-clamp-1">
                      {advocate.office_address || "No office address listed"}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-2 text-sm">
                  <Mail className="h-4 w-4 text-muted-foreground" />
                  <span className="text-xs font-medium">{advocate.email || "No email provided"}</span>
                </div>
                <div className="flex items-center gap-2 text-sm">
                  <Phone className="h-4 w-4 text-muted-foreground" />
                  <span className="text-xs font-medium">{advocate.mobile_number || "—"}</span>
                </div>
                <div className="pt-2">
                  <button className="w-full py-2 bg-secondary text-secondary-foreground text-xs font-semibold rounded-lg hover:bg-secondary/80 transition-colors">
                    View Profile
                  </button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
