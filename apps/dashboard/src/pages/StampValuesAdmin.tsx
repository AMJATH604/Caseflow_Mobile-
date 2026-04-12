import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Textarea } from "@/components/ui/textarea";
import { supabase } from "@/integrations/supabase/client";
import { Receipt, Plus, Upload, Trash2, Edit, Search, Save, X } from "lucide-react";
import { toast } from "sonner";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

const CATEGORIES = ["Civil", "Criminal", "Documents", "Appeals"];
const ICONS = [
  { name: "event_busy", label: "Event Busy" },
  { name: "edit_document", label: "Edit Doc" },
  { name: "description", label: "Description" },
  { name: "shield", label: "Shield" },
  { name: "reply_all", label: "Reply" },
  { name: "find_replace", label: "Review" },
  { name: "restore", label: "Restore" },
  { name: "pause_circle", label: "Pause" },
  { name: "swap_horiz", label: "Swap" },
  { name: "gavel", label: "Gavel" },
  { name: "play_arrow", label: "Play" },
  { name: "rate_review", label: "Rate Review" },
  { name: "assignment", label: "Assignment" },
  { name: "lock_open", label: "Lock Open" },
  { name: "security", label: "Security" },
  { name: "cancel", label: "Cancel" },
  { name: "report", label: "Report" },
  { name: "access_time", label: "Clock" },
  { name: "folder_special", label: "Folder" },
  { name: "person_pin", label: "Person" },
  { name: "content_copy", label: "Copy" },
  { name: "bolt", label: "Bolt" },
  { name: "verified", label: "Verified" },
  { name: "receipt_long", label: "Receipt" },
  { name: "fact_check", label: "Fact Check" },
  { name: "account_balance", label: "Bank" },
  { name: "approval", label: "Approval" },
  { name: "file_copy", label: "File Copy" },
  { name: "balance", label: "Balance" },
  { name: "upload", label: "Upload" },
  { name: "copyright", label: "Copyright" },
];

export default function StampValuesAdmin() {
  const [stamps, setStamps] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [formData, setFormData] = useState({
    name: "",
    value: "",
    category: "Civil",
    icon_name: "description",
    state_id: "TN"
  });
  const [bulkJson, setBulkJson] = useState("");

  useEffect(() => {
    fetchStamps();
  }, []);

  const fetchStamps = async () => {
    setLoading(true);
    const { data, error } = await supabase.from("stamp_values").select("*").order("category").order("name");
    if (error) {
      toast.error("Failed to fetch stamp values: " + error.message);
    } else {
      setStamps(data || []);
    }
    setLoading(false);
  };

  const handleCreateOrUpdate = async () => {
    if (!formData.name || !formData.value) {
      toast.error("Please fill in both name and value");
      return;
    }

    if (editingId) {
      const { error } = await supabase.from("stamp_values").update(formData).eq("id", editingId);
      if (error) {
        toast.error("Update failed: " + error.message);
      } else {
        toast.success("Stamp value updated");
        setEditingId(null);
        setIsDialogOpen(false);
        fetchStamps();
      }
    } else {
      const { error } = await supabase.from("stamp_values").insert([formData]);
      if (error) {
        toast.error("Creation failed: " + error.message);
      } else {
        toast.success("Stamp value created");
        setIsDialogOpen(false);
        fetchStamps();
      }
    }
    setFormData({ name: "", value: "", category: "Civil", icon_name: "description", state_id: "TN" });
  };

  const deleteStamp = async (id: string) => {
    if (!confirm("Are you sure you want to delete this stamp value?")) return;
    const { error } = await supabase.from("stamp_values").delete().eq("id", id);
    if (error) {
      toast.error("Delete failed: " + error.message);
    } else {
      toast.success("Stamp value deleted");
      fetchStamps();
    }
  };

  const startEdit = (stamp: any) => {
    setFormData({
      name: stamp.name,
      value: stamp.value,
      category: stamp.category,
      icon_name: stamp.icon_name || "description",
      state_id: stamp.state_id || "TN"
    });
    setEditingId(stamp.id);
    setIsDialogOpen(true);
  };

  const handleBulkUpload = async () => {
    try {
      const data = JSON.parse(bulkJson);
      if (!Array.isArray(data)) throw new Error("Input must be a JSON array");
      
      const { error } = await supabase.from("stamp_values").insert(data);
      if (error) throw error;

      toast.success(`Successfully uploaded ${data.length} items`);
      setBulkJson("");
      fetchStamps();
    } catch (err: any) {
      toast.error("Bulk upload failed: " + err.message);
    }
  };

  const filteredStamps = stamps.filter(s =>
    s.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    s.category.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="space-y-6 max-w-6xl mx-auto pb-12">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold flex items-center gap-2">
            <Receipt className="h-6 w-6 text-primary" />
            Stamp Values Admin
          </h1>
          <p className="text-muted-foreground text-sm">Manage court petition stamp values for the mobile app</p>
        </div>

        <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
          <DialogTrigger asChild>
            <Button className="bg-primary hover:bg-primary/90" onClick={() => {
              setEditingId(null);
              setFormData({ name: "", value: "", category: "Civil", icon_name: "description", state_id: "TN" });
            }}>
              <Plus className="h-4 w-4 mr-2" />
              New Stamp Value
            </Button>
          </DialogTrigger>
          <DialogContent className="max-w-md">
            <DialogHeader>
              <DialogTitle>{editingId ? "Edit Stamp Value" : "Add New Stamp Value"}</DialogTitle>
              <DialogDescription>Enter the petition name and its corresponding stamp value.</DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <label className="text-sm font-medium">Petition/Document Name</label>
                <Input
                  placeholder="e.g. Adjournment Petition"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <label className="text-sm font-medium">Value (e.g. ₹20)</label>
                <Input
                  placeholder="₹20"
                  value={formData.value}
                  onChange={(e) => setFormData({ ...formData, value: e.target.value })}
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <label className="text-sm font-medium">Category</label>
                  <Select value={formData.category} onValueChange={(val) => setFormData({ ...formData, category: val })}>
                    <SelectTrigger>
                      <SelectValue placeholder="Select Category" />
                    </SelectTrigger>
                    <SelectContent>
                      {CATEGORIES.map(cat => (
                        <SelectItem key={cat} value={cat}>{cat}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <label className="text-sm font-medium">Icon</label>
                  <Select value={formData.icon_name} onValueChange={(val) => setFormData({ ...formData, icon_name: val })}>
                    <SelectTrigger>
                      <SelectValue placeholder="Select Icon" />
                    </SelectTrigger>
                    <SelectContent>
                      {ICONS.map(icon => (
                        <SelectItem key={icon.name} value={icon.name}>{icon.label}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setIsDialogOpen(false)}>Cancel</Button>
              <Button onClick={handleCreateOrUpdate}>{editingId ? "Save Changes" : "Add Stamp"}</Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      <div className="flex items-center gap-2 bg-card p-3 rounded-xl border border-border shadow-sm">
        <Search className="h-4 w-4 text-muted-foreground ml-2" />
        <Input
          className="border-none bg-transparent focus-visible:ring-0"
          placeholder="Search by name or category..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
        />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Petition Stamp List</CardTitle>
          <CardDescription>All values listed here are instantly available to users in the mobile app.</CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Category</TableHead>
                <TableHead>Petition Name</TableHead>
                <TableHead>Stamp Value</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading ? (
                <TableRow><TableCell colSpan={4} className="text-center py-8">Loading values...</TableCell></TableRow>
              ) : filteredStamps.length === 0 ? (
                <TableRow><TableCell colSpan={4} className="text-center py-8">No values found.</TableCell></TableRow>
              ) : (
                filteredStamps.map((stamp) => (
                  <TableRow key={stamp.id}>
                    <TableCell>
                      <span className={`px-2 py-1 rounded-full text-[10px] font-bold uppercase ${
                        stamp.category === 'Civil' ? 'bg-blue-100 text-blue-700' :
                        stamp.category === 'Criminal' ? 'bg-red-100 text-red-700' :
                        stamp.category === 'Documents' ? 'bg-green-100 text-green-700' :
                        'bg-purple-100 text-purple-700'
                      }`}>
                        {stamp.category}
                      </span>
                    </TableCell>
                    <TableCell className="font-medium">{stamp.name}</TableCell>
                    <TableCell><span className="font-mono bg-muted px-2 py-1 rounded text-sm">{stamp.value}</span></TableCell>
                    <TableCell className="text-right space-x-2">
                      <Button variant="ghost" size="sm" onClick={() => startEdit(stamp)}>
                        <Edit className="h-4 w-4" />
                      </Button>
                      <Button variant="ghost" size="sm" className="text-destructive hover:bg-destructive/10" onClick={() => deleteStamp(stamp.id)}>
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <Card className="border-2 border-primary/20 bg-muted/30">
        <CardHeader>
          <CardTitle className="text-lg">Bulk Upload (JSON)</CardTitle>
          <CardDescription>Paste an array of stamp objects to quickly update the library.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <Textarea
            className="font-mono text-xs min-h-[150px]"
            placeholder='[{"name": "...", "value": "...", "category": "...", "icon_name": "..."}]'
            value={bulkJson}
            onChange={(e) => setBulkJson(e.target.value)}
          />
          <div className="flex justify-end">
            <Button onClick={handleBulkUpload} disabled={!bulkJson}>
              <Upload className="h-4 w-4 mr-2" />
              Upload Batch
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
