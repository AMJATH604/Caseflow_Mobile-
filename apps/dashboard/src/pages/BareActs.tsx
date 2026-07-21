import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Textarea } from "@/components/ui/textarea";
import { supabase } from "@/integrations/supabase/client";
import { 
  Book, Plus, Upload, Trash2, Edit, ChevronRight, Search, File, 
  CheckCircle, AlertCircle, Loader2, BookOpen, Settings, 
  Layers, Copy, FileText, Type, LayoutList, Eye, X, RefreshCw
} from "lucide-react";
import { toast } from "sonner";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

// Type for a bulk row entry
interface BulkRow {
  chapter_number: string;
  chapter_title: string;
  section_number: string;
  section_title: string;
  section_text: string;
}

const emptyRow = (): BulkRow => ({
  chapter_number: "",
  chapter_title: "",
  section_number: "",
  section_title: "",
  section_text: "",
});

export default function BareActs() {
  const [acts, setActs] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedAct, setSelectedAct] = useState<any>(null);
  const [sections, setSections] = useState<any[]>([]);
  const [sectionsLoading, setSectionsLoading] = useState(false);
  const [searchSectionQuery, setSearchSectionQuery] = useState("");
  const [activeTab, setActiveTab] = useState("sections");

  // Create Statute State
  const [newAct, setNewAct] = useState({ title: "", short_title: "", description: "" });
  const [pdfFile, setPdfFile] = useState<File | null>(null);
  const [creatingAct, setCreatingAct] = useState(false);

  // Edit Section Dialog State
  const [isSectionDialogOpen, setIsSectionDialogOpen] = useState(false);
  const [editingSection, setEditingSection] = useState<any>(null);
  const [sectionForm, setSectionForm] = useState({
    chapter_number: "",
    chapter_title: "",
    section_number: "",
    section_title: "",
    section_text: "",
  });

  // ─── Bulk Add Sections State ─────────────────────────────
  const [bulkMode, setBulkMode] = useState<"form" | "text">("form");
  const [bulkRows, setBulkRows] = useState<BulkRow[]>([emptyRow()]);
  const [pastedText, setPastedText] = useState("");
  const [parsedFromText, setParsedFromText] = useState<BulkRow[]>([]);
  const [showTextPreview, setShowTextPreview] = useState(false);
  const [bulkSaving, setBulkSaving] = useState(false);
  const [bulkProgress, setBulkProgress] = useState<{ current: number; total: number; inserted: number; failed: number } | null>(null);
  const [purgeBeforeImport, setPurgeBeforeImport] = useState(false);

  useEffect(() => {
    fetchActs();
  }, []);

  useEffect(() => {
    if (selectedAct) {
      fetchSections(selectedAct.id);
    }
  }, [selectedAct]);

  const fetchActs = async () => {
    setLoading(true);
    const { data, error } = await supabase.from("bare_acts").select("*").order("title");
    if (error) {
      toast.error("Failed to fetch statutes");
    } else {
      setActs(data || []);
    }
    setLoading(false);
  };

  const fetchSections = async (actId: string) => {
    setSectionsLoading(true);
    const { data, error } = await supabase
      .from("bare_act_sections")
      .select("*")
      .eq("act_id", actId)
      .order("sequence_order");
    if (error) {
      toast.error("Failed to fetch act sections");
    } else {
      setSections(data || []);
    }
    setSectionsLoading(false);
  };

  const createAct = async () => {
    if (!newAct.title || !newAct.short_title) {
      toast.error("Please fill in both full title and short code");
      return;
    }

    setCreatingAct(true);
    let pdf_url = null;

    if (pdfFile) {
      const fileName = `${newAct.short_title.toLowerCase()}_${Date.now()}.pdf`;
      const { error: uploadError } = await supabase.storage
        .from("bare_acts")
        .upload(fileName, pdfFile);

      if (uploadError) {
        toast.error("PDF upload failed: " + uploadError.message);
        setCreatingAct(false);
        return;
      }

      const { data: urlData } = supabase.storage.from("bare_acts").getPublicUrl(fileName);
      pdf_url = urlData.publicUrl;
    }

    const { data, error } = await supabase
      .from("bare_acts")
      .insert([{ ...newAct, pdf_url }])
      .select();

    setCreatingAct(false);
    if (error) {
      toast.error("Failed to create act: " + error.message);
    } else {
      toast.success("Statute created successfully");
      fetchActs();
      setNewAct({ title: "", short_title: "", description: "" });
      setPdfFile(null);
    }
  };

  const deleteAct = async (act: any) => {
    if (!confirm(`Are you sure you want to delete "${act.title}"? This will permanently delete all its chapters and sections.`)) return;
    const { error } = await supabase.from("bare_acts").delete().eq("id", act.id);
    if (error) {
      toast.error("Failed to delete statute: " + error.message);
    } else {
      toast.success("Statute deleted successfully");
      setSelectedAct(null);
      fetchActs();
    }
  };

  // Add / Edit Section handler
  const saveSection = async () => {
    if (!sectionForm.section_number || !sectionForm.section_title || !sectionForm.section_text) {
      toast.error("Section number, title, and content are required");
      return;
    }

    const payload = {
      ...sectionForm,
      act_id: selectedAct.id,
      title: sectionForm.section_title,
      content: sectionForm.section_text,
    };

    if (editingSection) {
      // Update
      const { error } = await supabase
        .from("bare_act_sections")
        .update(payload)
        .eq("id", editingSection.id);

      if (error) {
        toast.error("Failed to update section: " + error.message);
      } else {
        toast.success("Section updated successfully");
        setIsSectionDialogOpen(false);
        fetchSections(selectedAct.id);
      }
    } else {
      // Create new
      const nextSequence = sections.length + 1;
      const { error } = await supabase
        .from("bare_act_sections")
        .insert([{ ...payload, sequence_order: nextSequence }]);

      if (error) {
        toast.error("Failed to create section: " + error.message);
      } else {
        toast.success("Section created successfully");
        setIsSectionDialogOpen(false);
        fetchSections(selectedAct.id);
      }
    }
  };

  const openNewSectionDialog = () => {
    setEditingSection(null);
    setSectionForm({
      chapter_number: "",
      chapter_title: "",
      section_number: "",
      section_title: "",
      section_text: "",
    });
    setIsSectionDialogOpen(true);
  };

  const openEditSectionDialog = (sec: any) => {
    setEditingSection(sec);
    setSectionForm({
      chapter_number: sec.chapter_number || "",
      chapter_title: sec.chapter_title || "",
      section_number: sec.section_number || "",
      section_title: sec.section_title || "",
      section_text: sec.section_text || "",
    });
    setIsSectionDialogOpen(true);
  };

  const deleteSection = async (id: string) => {
    if (!confirm("Are you sure you want to delete this section?")) return;
    const { error } = await supabase.from("bare_act_sections").delete().eq("id", id);
    if (error) {
      toast.error("Failed to delete section");
    } else {
      toast.success("Section deleted");
      fetchSections(selectedAct.id);
    }
  };

  // ─── Bulk Add: Form Builder Helpers ──────────────────────
  const addBulkRow = () => {
    setBulkRows([...bulkRows, emptyRow()]);
  };

  const duplicateBulkRow = (index: number) => {
    const source = bulkRows[index];
    const nextSectionNum = source.section_number
      ? String(parseInt(source.section_number.replace(/\D/g, '')) + 1 || '')
      : "";
    const duplicated: BulkRow = {
      ...source,
      section_number: nextSectionNum,
      section_title: "",
      section_text: "",
    };
    const newRows = [...bulkRows];
    newRows.splice(index + 1, 0, duplicated);
    setBulkRows(newRows);
  };

  const removeBulkRow = (index: number) => {
    if (bulkRows.length <= 1) {
      setBulkRows([emptyRow()]);
      return;
    }
    setBulkRows(bulkRows.filter((_, i) => i !== index));
  };

  const updateBulkRow = (index: number, field: keyof BulkRow, value: string) => {
    const updated = [...bulkRows];
    updated[index] = { ...updated[index], [field]: value };
    setBulkRows(updated);
  };

  // ─── Bulk Add: Plain Text Parser ─────────────────────────
  const parseTextImport = (text: string) => {
    if (!text.trim()) {
      setParsedFromText([]);
      setShowTextPreview(false);
      return;
    }

    const rows: BulkRow[] = [];
    let currentChapter = "";
    let currentChapterTitle = "";

    // Split on lines
    const lines = text.split('\n');
    let currentSection: BulkRow | null = null;
    let collectingContent = false;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const trimmed = line.trim();

      // Chapter delimiter: --- or === 
      if (/^[-=]{3,}$/.test(trimmed)) {
        // If we were collecting a section, save it
        if (currentSection && currentSection.section_number) {
          rows.push(currentSection);
          currentSection = null;
          collectingContent = false;
        }
        continue;
      }

      // Chapter header: "Chapter: X" or "Chapter No: X" or "Chapter X"
      const chapterMatch = trimmed.match(/^chapter\s*(?:no\.?|number)?\s*[:.]?\s*(.+)$/i);
      if (chapterMatch) {
        currentChapter = chapterMatch[1].trim();
        continue;
      }

      // Chapter title: "Chapter Title: X" or "Title: X" (only if right after a chapter line)
      const chapterTitleMatch = trimmed.match(/^(?:chapter\s+)?title\s*[:.]?\s*(.+)$/i);
      if (chapterTitleMatch) {
        currentChapterTitle = chapterTitleMatch[1].trim();
        continue;
      }

      // Section header: "Section 1: Title" or "Sec 1. Title" or "Section 1 - Title" or "Art. 1: Title"
      const sectionMatch = trimmed.match(
        /^(?:section|sec\.?|article|art\.?)\s*(\d+[a-zA-Z]?)\s*[:.–\-]\s*(.+)$/i
      );
      if (sectionMatch) {
        // Save previous section if exists
        if (currentSection && currentSection.section_number) {
          rows.push(currentSection);
        }

        currentSection = {
          chapter_number: currentChapter,
          chapter_title: currentChapterTitle,
          section_number: sectionMatch[1].trim(),
          section_title: sectionMatch[2].trim(),
          section_text: "",
        };
        collectingContent = true;
        continue;
      }

      // Content lines (body text of the current section)
      if (collectingContent && currentSection && trimmed) {
        currentSection.section_text += (currentSection.section_text ? "\n" : "") + trimmed;
      }
    }

    // Don't forget the last section
    if (currentSection && currentSection.section_number) {
      rows.push(currentSection);
    }

    setParsedFromText(rows);
    setShowTextPreview(rows.length > 0);

    if (rows.length > 0) {
      toast.success(`Parsed ${rows.length} sections from text`);
    } else {
      toast.error("Could not parse any sections. Use the format: Section 1: Title followed by content on the next lines.");
    }
  };

  // ─── Bulk Save (works for both form rows and parsed text rows) ───
  const executeBulkSave = async (rowsToSave: BulkRow[]) => {
    // Validate: at least one row with required fields
    const validRows = rowsToSave.filter(r => r.section_number && r.section_title && r.section_text);
    if (validRows.length === 0) {
      toast.error("No valid sections to save. Each section needs a number, title, and content.");
      return;
    }

    setBulkSaving(true);
    setBulkProgress(null);

    // Purge if needed
    if (purgeBeforeImport) {
      const { error: purgeError } = await supabase
        .from("bare_act_sections")
        .delete()
        .eq("act_id", selectedAct.id);

      if (purgeError) {
        toast.error("Failed to clear existing sections: " + purgeError.message);
        setBulkSaving(false);
        return;
      }
    }

    // Calculate starting sequence
    const startSequence = purgeBeforeImport ? 1 : sections.length + 1;

    // Format for DB
    const formattedData = validRows.map((row, index) => ({
      act_id: selectedAct.id,
      chapter_number: row.chapter_number || "",
      chapter_title: row.chapter_title || "",
      section_number: row.section_number,
      section_title: row.section_title,
      section_text: row.section_text,
      title: row.section_title,
      content: row.section_text,
      sequence_order: startSequence + index,
    }));

    // Insert in batches
    const BATCH_SIZE = 50;
    const totalBatches = Math.ceil(formattedData.length / BATCH_SIZE);
    let inserted = 0;
    let failed = 0;

    for (let i = 0; i < formattedData.length; i += BATCH_SIZE) {
      const batch = formattedData.slice(i, i + BATCH_SIZE);
      const batchIndex = Math.floor(i / BATCH_SIZE) + 1;

      setBulkProgress({ current: batchIndex, total: totalBatches, inserted, failed });

      const { error } = await supabase.from("bare_act_sections").insert(batch);

      if (error) {
        console.error(`Batch ${batchIndex} failed:`, error.message);
        failed += batch.length;
      } else {
        inserted += batch.length;
      }
    }

    setBulkProgress({ current: totalBatches, total: totalBatches, inserted, failed });
    setBulkSaving(false);

    if (failed > 0) {
      toast.warning(`Import done. ${inserted} imported, ${failed} failed.`);
    } else {
      toast.success(`Successfully added ${inserted} sections!`);
    }

    // Reset
    setBulkRows([emptyRow()]);
    setPastedText("");
    setParsedFromText([]);
    setShowTextPreview(false);
    setBulkProgress(null);
    fetchSections(selectedAct.id);
  };

  const filteredActs = acts.filter(a =>
    a.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
    a.short_title.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const filteredSections = sections.filter(s =>
    s.section_number.toLowerCase().includes(searchSectionQuery.toLowerCase()) ||
    s.section_title.toLowerCase().includes(searchSectionQuery.toLowerCase()) ||
    s.section_text.toLowerCase().includes(searchSectionQuery.toLowerCase())
  );

  // Count valid rows in form builder
  const validFormRowCount = bulkRows.filter(r => r.section_number && r.section_title && r.section_text).length;

  return (
    <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 max-w-7xl mx-auto pb-12">
      {/* LEFT COLUMN: Statutes List (cols-4) */}
      <div className="lg:col-span-4 space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-bold tracking-tight flex items-center gap-2">
              <Book className="h-5 w-5 text-primary" />
              Bare Acts
            </h1>
            <p className="text-xs text-muted-foreground">Mobile Statutory Library Manager</p>
          </div>

          {/* New statute dialog */}
          <Dialog>
            <DialogTrigger asChild>
              <Button size="sm" className="bg-primary hover:bg-primary/95 text-xs h-8">
                <Plus className="h-4 w-4 mr-1" />
                Add Act
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[425px]">
              <DialogHeader>
                <DialogTitle>Add New Statute</DialogTitle>
                <DialogDescription>Create the metadata shell for a new act. Sections are uploaded inside.</DialogDescription>
              </DialogHeader>
              <div className="space-y-4 py-3">
                <div className="space-y-1">
                  <label className="text-xs font-semibold">Statute Name</label>
                  <Input 
                    placeholder="e.g. Indian Penal Code, 1860" 
                    value={newAct.title} 
                    onChange={(e) => setNewAct({...newAct, title: e.target.value})}
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-xs font-semibold">Short Code / Abbreviation</label>
                  <Input 
                    placeholder="e.g. IPC" 
                    value={newAct.short_title} 
                    onChange={(e) => setNewAct({...newAct, short_title: e.target.value})}
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-xs font-semibold">Brief Description</label>
                  <Textarea 
                    placeholder="Describe context, enactment date, or status..." 
                    value={newAct.description} 
                    onChange={(e) => setNewAct({...newAct, description: e.target.value})}
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-xs font-semibold">Official Gazette PDF (Optional)</label>
                  <Input 
                    type="file" 
                    accept=".pdf" 
                    onChange={(e) => setPdfFile(e.target.files?.[0] || null)}
                  />
                </div>
              </div>
              <DialogFooter>
                <Button size="sm" onClick={createAct} disabled={creatingAct}>
                  {creatingAct ? <><Loader2 className="h-4 w-4 mr-2 animate-spin" /> Saving...</> : "Create Statute"}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        </div>

        {/* Search */}
        <div className="relative">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search statutes..."
            className="pl-9 h-9 text-xs"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>

        {/* Statutes Cards Scroll Area */}
        <div className="space-y-3 max-h-[calc(100vh-220px)] overflow-y-auto pr-1">
          {loading ? (
            <div className="flex flex-col items-center justify-center py-12 gap-3 text-muted-foreground">
              <Loader2 className="h-6 w-6 animate-spin text-primary" />
              <span className="text-xs">Fetching acts...</span>
            </div>
          ) : filteredActs.length === 0 ? (
            <div className="text-center py-8 text-xs text-muted-foreground border border-dashed rounded-xl">
              No statutes found matching query.
            </div>
          ) : (
            filteredActs.map((act) => {
              const isActive = selectedAct?.id === act.id;
              return (
                <div
                  key={act.id}
                  onClick={() => { setSelectedAct(act); setActiveTab("sections"); }}
                  className={`p-4 rounded-xl border transition-all duration-200 cursor-pointer ${
                    isActive 
                      ? 'border-primary bg-primary/5 shadow-md scale-[1.01]' 
                      : 'border-border bg-card hover:bg-muted/30 hover:border-muted-foreground/30'
                  }`}
                >
                  <div className="flex items-start justify-between">
                    <div>
                      <span className={`text-[10px] uppercase font-extrabold tracking-wider px-2 py-0.5 rounded-full ${
                        isActive ? 'bg-primary text-white' : 'bg-muted text-muted-foreground'
                      }`}>
                        {act.short_title}
                      </span>
                      <h3 className="font-bold text-sm text-foreground mt-2 leading-tight">{act.title}</h3>
                      {act.description && (
                        <p className="text-xs text-muted-foreground mt-1 line-clamp-2">{act.description}</p>
                      )}
                    </div>
                    <ChevronRight className={`h-4 w-4 text-muted-foreground transition-transform duration-200 ${isActive ? 'rotate-90 text-primary' : ''}`} />
                  </div>
                  <div className="flex items-center gap-3 mt-4 pt-3 border-t border-border/40 text-[10px] text-muted-foreground">
                    <span>Created: {new Date(act.created_at).toLocaleDateString()}</span>
                    {act.pdf_url && <span className="text-blue-500 font-bold">PDF Ready</span>}
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {/* RIGHT COLUMN: Chapters/Sections Directory, Bulk Add, Settings (cols-8) */}
      <div className="lg:col-span-8">
        {!selectedAct ? (
          <div className="h-full flex flex-col items-center justify-center text-center py-24 px-6 border border-dashed rounded-2xl bg-card">
            <BookOpen className="h-16 w-16 text-muted-foreground/30 stroke-[1.5]" />
            <h3 className="mt-4 text-lg font-bold text-foreground">No Statute Selected</h3>
            <p className="mt-1.5 text-xs text-muted-foreground max-w-sm">
              Please choose a statute from the directory sidebar to explore chapters/sections, add new content, or update settings.
            </p>
          </div>
        ) : (
          <div className="space-y-6">
            {/* Act Header Banner */}
            <div className="p-6 rounded-2xl bg-card border border-border shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-black px-2 py-0.5 rounded-md bg-accent/20 text-accent-foreground">
                    {selectedAct.short_title}
                  </span>
                  <span className="text-[10px] text-muted-foreground">Statute Database ID: {selectedAct.id.substring(0, 8)}...</span>
                </div>
                <h2 className="text-xl font-bold leading-tight">{selectedAct.title}</h2>
                {selectedAct.description && (
                  <p className="text-xs text-muted-foreground max-w-xl">{selectedAct.description}</p>
                )}
              </div>

              <div className="flex items-center gap-2 self-start sm:self-center">
                {selectedAct.pdf_url && (
                  <Button size="sm" variant="outline" className="text-xs" onClick={() => window.open(selectedAct.pdf_url, '_blank')}>
                    <File className="h-3.5 w-3.5 mr-1 text-red-500" />
                    Open PDF
                  </Button>
                )}
                <Button size="sm" variant="ghost" className="text-destructive hover:bg-destructive/10 text-xs" onClick={() => deleteAct(selectedAct)}>
                  <Trash2 className="h-3.5 w-3.5 mr-1" />
                  Delete Act
                </Button>
              </div>
            </div>

            {/* Navigation Tabs */}
            <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
              <TabsList className="grid grid-cols-3 w-full sm:w-[480px]">
                <TabsTrigger value="sections" className="text-xs flex items-center gap-2">
                  <Layers className="h-3.5 w-3.5" />
                  Sections ({sections.length})
                </TabsTrigger>
                <TabsTrigger value="bulk-add" className="text-xs flex items-center gap-2">
                  <Plus className="h-3.5 w-3.5" />
                  Bulk Add Sections
                </TabsTrigger>
                <TabsTrigger value="settings" className="text-xs flex items-center gap-2">
                  <Settings className="h-3.5 w-3.5" />
                  Statute Settings
                </TabsTrigger>
              </TabsList>

              {/* TAB 1: Sections List */}
              <TabsContent value="sections" className="mt-4 space-y-4">
                <div className="flex flex-col sm:flex-row items-center justify-between gap-3 bg-card p-4 rounded-xl border border-border shadow-sm">
                  <div className="relative w-full sm:w-72">
                    <Search className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
                    <Input
                      placeholder="Search sections by name, number, or content..."
                      className="pl-9 h-9 text-xs"
                      value={searchSectionQuery}
                      onChange={(e) => setSearchSectionQuery(e.target.value)}
                    />
                  </div>
                  <Button size="sm" className="w-full sm:w-auto text-xs" onClick={openNewSectionDialog}>
                    <Plus className="h-3.5 w-3.5 mr-1" />
                    Add Section
                  </Button>
                </div>

                {sectionsLoading ? (
                  <div className="flex flex-col items-center justify-center py-20 gap-3 text-muted-foreground bg-card rounded-xl border border-border">
                    <Loader2 className="h-8 w-8 animate-spin text-primary" />
                    <span className="text-xs">Loading section list...</span>
                  </div>
                ) : filteredSections.length === 0 ? (
                  <div className="text-center py-16 text-xs text-muted-foreground border border-dashed rounded-xl bg-card">
                    {searchSectionQuery ? "No sections match your search query." : "This statute has no sections yet. Go to Bulk Add Sections to upload them."}
                  </div>
                ) : (
                  <div className="border border-border rounded-xl bg-card overflow-hidden shadow-sm">
                    <Table>
                      <TableHeader>
                        <TableRow>
                          <TableHead className="w-20">Sec No</TableHead>
                          <TableHead className="w-40">Chapter</TableHead>
                          <TableHead>Title & Preview</TableHead>
                          <TableHead className="text-right w-24">Actions</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {filteredSections.slice(0, 100).map((sec) => (
                          <TableRow key={sec.id} className="hover:bg-muted/10">
                            <TableCell className="font-bold text-xs text-primary">{sec.section_number}</TableCell>
                            <TableCell className="text-xs">
                              {sec.chapter_number && (
                                <span className="font-semibold block text-slate-700">Ch. {sec.chapter_number}</span>
                              )}
                              <span className="text-[10px] text-muted-foreground line-clamp-1">{sec.chapter_title || "No Chapter Title"}</span>
                            </TableCell>
                            <TableCell>
                              <p className="font-semibold text-xs text-foreground leading-snug">{sec.section_title}</p>
                              <p className="text-[11px] text-muted-foreground line-clamp-1 mt-0.5">{sec.section_text}</p>
                            </TableCell>
                            <TableCell className="text-right space-x-1">
                              <Button variant="ghost" size="sm" className="h-8 w-8 p-0" onClick={() => openEditSectionDialog(sec)}>
                                <Edit className="h-3.5 w-3.5 text-slate-500" />
                              </Button>
                              <Button variant="ghost" size="sm" className="h-8 w-8 p-0 text-destructive hover:bg-destructive/10" onClick={() => deleteSection(sec.id)}>
                                <Trash2 className="h-3.5 w-3.5" />
                              </Button>
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                    {filteredSections.length > 100 && (
                      <div className="p-3 bg-muted/20 border-t border-border text-center text-xs text-muted-foreground">
                        Showing first 100 of {filteredSections.length} sections. Use search to filter results.
                      </div>
                    )}
                  </div>
                )}
              </TabsContent>

              {/* TAB 2: Bulk Add Sections */}
              <TabsContent value="bulk-add" className="mt-4 space-y-4">
                <Card>
                  <CardHeader className="pb-4">
                    <div className="flex items-center justify-between">
                      <div>
                        <CardTitle className="text-base font-bold">Bulk Add Sections</CardTitle>
                        <CardDescription className="text-xs">
                          Add multiple sections at once using a form or by pasting text.
                        </CardDescription>
                      </div>

                      {/* Mode Toggle */}
                      <div className="flex items-center bg-muted rounded-lg p-0.5">
                        <button
                          onClick={() => setBulkMode("form")}
                          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-semibold transition-all ${
                            bulkMode === "form"
                              ? "bg-white text-foreground shadow-sm"
                              : "text-muted-foreground hover:text-foreground"
                          }`}
                        >
                          <LayoutList className="h-3.5 w-3.5" />
                          Form Builder
                        </button>
                        <button
                          onClick={() => setBulkMode("text")}
                          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-semibold transition-all ${
                            bulkMode === "text"
                              ? "bg-white text-foreground shadow-sm"
                              : "text-muted-foreground hover:text-foreground"
                          }`}
                        >
                          <Type className="h-3.5 w-3.5" />
                          Paste Text
                        </button>
                      </div>
                    </div>
                  </CardHeader>

                  <CardContent className="space-y-5">
                    {/* ───── FORM BUILDER MODE ───── */}
                    {bulkMode === "form" && (
                      <div className="space-y-4 animate-in fade-in duration-200">
                        {/* Info Bar */}
                        <div className="p-3 rounded-xl bg-blue-50 border border-blue-100 flex items-start gap-3">
                          <LayoutList className="h-4 w-4 text-blue-600 shrink-0 mt-0.5" />
                          <div className="space-y-0.5">
                            <p className="text-xs font-bold text-blue-800">Fill in section details row by row</p>
                            <p className="text-[11px] text-blue-700 leading-snug">
                              Add rows, fill in the section info, and click "Save All" when done. Use "Duplicate" to quickly clone a row with the same chapter info.
                            </p>
                          </div>
                        </div>

                        {/* Section Rows */}
                        <div className="space-y-3 max-h-[480px] overflow-y-auto pr-1">
                          {bulkRows.map((row, index) => (
                            <div 
                              key={index} 
                              className="p-4 rounded-xl border border-border bg-card hover:border-primary/30 transition-colors group"
                            >
                              {/* Row header */}
                              <div className="flex items-center justify-between mb-3">
                                <span className="text-[10px] font-black uppercase tracking-widest text-muted-foreground">
                                  Section Entry #{index + 1}
                                </span>
                                <div className="flex items-center gap-1 opacity-50 group-hover:opacity-100 transition-opacity">
                                  <Button 
                                    variant="ghost" 
                                    size="sm" 
                                    className="h-7 px-2 text-[10px]" 
                                    onClick={() => duplicateBulkRow(index)}
                                    title="Duplicate this row"
                                  >
                                    <Copy className="h-3 w-3 mr-1" />
                                    Duplicate
                                  </Button>
                                  <Button 
                                    variant="ghost" 
                                    size="sm" 
                                    className="h-7 w-7 p-0 text-destructive hover:bg-destructive/10" 
                                    onClick={() => removeBulkRow(index)}
                                    title="Remove row"
                                  >
                                    <X className="h-3 w-3" />
                                  </Button>
                                </div>
                              </div>

                              {/* Chapter fields */}
                              <div className="grid grid-cols-2 gap-3 mb-3">
                                <div className="space-y-1">
                                  <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Chapter No</label>
                                  <Input
                                    placeholder="e.g. I, II, 1"
                                    value={row.chapter_number}
                                    onChange={(e) => updateBulkRow(index, "chapter_number", e.target.value)}
                                    className="text-xs h-8"
                                  />
                                </div>
                                <div className="space-y-1">
                                  <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Chapter Title</label>
                                  <Input
                                    placeholder="e.g. Preliminary"
                                    value={row.chapter_title}
                                    onChange={(e) => updateBulkRow(index, "chapter_title", e.target.value)}
                                    className="text-xs h-8"
                                  />
                                </div>
                              </div>

                              {/* Section fields */}
                              <div className="grid grid-cols-3 gap-3 mb-3">
                                <div className="space-y-1">
                                  <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Section No *</label>
                                  <Input
                                    placeholder="e.g. 1"
                                    value={row.section_number}
                                    onChange={(e) => updateBulkRow(index, "section_number", e.target.value)}
                                    className="text-xs h-8 font-bold text-primary"
                                  />
                                </div>
                                <div className="col-span-2 space-y-1">
                                  <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Section Title *</label>
                                  <Input
                                    placeholder="e.g. Short title and commencement"
                                    value={row.section_title}
                                    onChange={(e) => updateBulkRow(index, "section_title", e.target.value)}
                                    className="text-xs h-8"
                                  />
                                </div>
                              </div>

                              {/* Section text */}
                              <div className="space-y-1">
                                <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Section Content *</label>
                                <Textarea
                                  placeholder="Paste the full text of this section..."
                                  value={row.section_text}
                                  onChange={(e) => updateBulkRow(index, "section_text", e.target.value)}
                                  className="text-xs min-h-[80px]"
                                />
                              </div>
                            </div>
                          ))}
                        </div>

                        {/* Action Bar */}
                        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 p-4 rounded-xl border border-border bg-slate-50">
                          <div className="flex items-center gap-2">
                            <Button size="sm" variant="outline" className="text-xs h-8" onClick={addBulkRow}>
                              <Plus className="h-3.5 w-3.5 mr-1" />
                              Add Row
                            </Button>
                            <span className="text-[10px] text-muted-foreground">
                              {bulkRows.length} row{bulkRows.length !== 1 ? "s" : ""} • {validFormRowCount} valid
                            </span>
                          </div>

                          <div className="flex items-center gap-3">
                            <label className="flex items-center gap-2 cursor-pointer">
                              <input 
                                type="checkbox" 
                                checked={purgeBeforeImport} 
                                onChange={(e) => setPurgeBeforeImport(e.target.checked)}
                                className="rounded border-slate-300 text-primary focus:ring-primary"
                              />
                              <span className="text-[10px] text-slate-600 font-medium">Replace existing sections</span>
                            </label>
                            <Button 
                              size="sm" 
                              className="text-xs h-8 bg-emerald-600 hover:bg-emerald-700 text-white"
                              disabled={validFormRowCount === 0 || bulkSaving}
                              onClick={() => executeBulkSave(bulkRows)}
                            >
                              {bulkSaving ? (
                                <><Loader2 className="h-3.5 w-3.5 mr-1 animate-spin" /> Saving...</>
                              ) : (
                                <><CheckCircle className="h-3.5 w-3.5 mr-1" /> Save All ({validFormRowCount})</>
                              )}
                            </Button>
                          </div>
                        </div>
                      </div>
                    )}

                    {/* ───── PASTE TEXT MODE ───── */}
                    {bulkMode === "text" && (
                      <div className="space-y-4 animate-in fade-in duration-200">
                        {/* Instructions */}
                        <div className="p-3 rounded-xl bg-violet-50 border border-violet-100 flex items-start gap-3">
                          <FileText className="h-4 w-4 text-violet-600 shrink-0 mt-0.5" />
                          <div className="space-y-1">
                            <p className="text-xs font-bold text-violet-800">Paste the statute text below</p>
                            <p className="text-[11px] text-violet-700 leading-snug">
                              Use the following format. The parser auto-detects sections:
                            </p>
                            <pre className="mt-2 p-3 rounded-lg bg-slate-900 text-emerald-400 font-mono text-[10px] overflow-x-auto leading-relaxed">
{`---
Chapter: I
Title: Preliminary

Section 1: Short title and commencement
This Act may be called the Code...

Section 2: Definitions
In this Code, unless the context...

---
Chapter: II
Title: General Explanations

Section 6: Definition of offence
A person is said to commit...`}
                            </pre>
                          </div>
                        </div>

                        {/* Text Input */}
                        <div className="space-y-2">
                          <Textarea
                            placeholder="Paste your statute text here following the format shown above..."
                            className="font-mono text-xs min-h-[200px]"
                            value={pastedText}
                            onChange={(e) => setPastedText(e.target.value)}
                          />
                          <Button 
                            size="sm" 
                            className="w-full text-xs" 
                            onClick={() => parseTextImport(pastedText)} 
                            disabled={!pastedText.trim()}
                          >
                            <Eye className="h-3.5 w-3.5 mr-1" />
                            Parse & Preview
                          </Button>
                        </div>

                        {/* Parsed Preview */}
                        {showTextPreview && parsedFromText.length > 0 && (
                          <div className="space-y-4 animate-in slide-in-from-bottom-2 duration-300">
                            <div className="border border-border rounded-xl bg-card overflow-hidden">
                              <div className="p-3 bg-emerald-50 border-b border-emerald-100 flex items-center justify-between">
                                <div className="flex items-center gap-2">
                                  <CheckCircle className="h-4 w-4 text-emerald-600" />
                                  <span className="text-xs font-bold text-emerald-800">
                                    Parsed {parsedFromText.length} sections
                                  </span>
                                </div>
                                <span className="text-[10px] text-emerald-600">Preview below</span>
                              </div>
                              <div className="p-3 space-y-3 max-h-[300px] overflow-y-auto">
                                {parsedFromText.slice(0, 10).map((item, idx) => (
                                  <div key={idx} className="p-3 rounded-lg bg-slate-50 border border-slate-100 space-y-1.5 text-xs">
                                    <div className="flex items-center justify-between text-[10px] font-bold text-slate-400 border-b pb-1.5">
                                      <span>
                                        {item.chapter_number ? `Ch. ${item.chapter_number}` : "No Chapter"} 
                                        {item.chapter_title ? ` — ${item.chapter_title}` : ""}
                                      </span>
                                      <span className="text-primary font-black">Sec {item.section_number}</span>
                                    </div>
                                    <h4 className="font-bold text-slate-900">{item.section_title}</h4>
                                    <p className="text-slate-600 line-clamp-2 leading-relaxed">{item.section_text}</p>
                                  </div>
                                ))}
                                {parsedFromText.length > 10 && (
                                  <div className="text-center text-[10px] text-muted-foreground py-2">
                                    ...and {parsedFromText.length - 10} more sections
                                  </div>
                                )}
                              </div>
                            </div>

                            {/* Save Actions */}
                            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 p-4 rounded-xl border border-border bg-slate-50">
                              <label className="flex items-center gap-2 cursor-pointer">
                                <input 
                                  type="checkbox" 
                                  checked={purgeBeforeImport} 
                                  onChange={(e) => setPurgeBeforeImport(e.target.checked)}
                                  className="rounded border-slate-300 text-primary focus:ring-primary"
                                />
                                <div className="space-y-0.5">
                                  <span className="text-xs font-bold text-slate-800 block">Replace existing sections</span>
                                  <span className="text-[10px] text-muted-foreground block">Clears all existing sections for this act before adding</span>
                                </div>
                              </label>
                              <Button 
                                size="sm" 
                                className="text-xs bg-emerald-600 hover:bg-emerald-700 text-white"
                                disabled={parsedFromText.length === 0 || bulkSaving}
                                onClick={() => executeBulkSave(parsedFromText)}
                              >
                                {bulkSaving ? (
                                  <><Loader2 className="h-3.5 w-3.5 mr-1 animate-spin" /> Saving...</>
                                ) : (
                                  <><Upload className="h-3.5 w-3.5 mr-1" /> Import {parsedFromText.length} Sections</>
                                )}
                              </Button>
                            </div>
                          </div>
                        )}
                      </div>
                    )}

                    {/* ───── BULK SAVE PROGRESS ───── */}
                    {bulkSaving && bulkProgress && (
                      <div className="space-y-3 py-4 text-center max-w-sm mx-auto animate-in fade-in duration-200">
                        <RefreshCw className="h-8 w-8 text-primary animate-spin mx-auto" />
                        <div className="space-y-1">
                          <h4 className="font-bold text-sm text-foreground">
                            Saving sections...
                          </h4>
                          <p className="text-xs text-muted-foreground">
                            Processing batch {bulkProgress.current} of {bulkProgress.total}
                          </p>
                        </div>
                        <div className="w-full bg-slate-100 rounded-full h-2">
                          <div 
                            className="bg-primary h-2 rounded-full transition-all duration-300"
                            style={{ width: `${(bulkProgress.current / bulkProgress.total) * 100}%` }}
                          />
                        </div>
                      </div>
                    )}
                  </CardContent>
                </Card>
              </TabsContent>

              {/* TAB 3: Statute Settings */}
              <TabsContent value="settings" className="mt-4 space-y-4">
                <Card>
                  <CardHeader>
                    <CardTitle className="text-base font-bold">Statute Metadata settings</CardTitle>
                    <CardDescription className="text-xs">Edit references or upload official documentations.</CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <div className="space-y-3 p-4 rounded-xl border border-border bg-muted/20">
                      <h4 className="font-bold text-xs text-slate-800 uppercase tracking-wider">Configure Official PDF</h4>
                      <p className="text-[11px] text-muted-foreground leading-normal">
                        Provide a raw gazette copy PDF of the statute for advocates to reference.
                      </p>
                      
                      <div className="flex items-center gap-3">
                        <Input 
                          type="file" 
                          accept=".pdf" 
                          className="h-9 text-xs flex-1 bg-card"
                          onChange={(e) => {
                            const file = e.target.files?.[0];
                            if (file) {
                              toast.promise(
                                (async () => {
                                  const fileName = `${selectedAct.short_title.toLowerCase()}_${Date.now()}.pdf`;
                                  const { error: uploadError } = await supabase.storage.from("bare_acts").upload(fileName, file);
                                  if (uploadError) throw new Error(uploadError.message);
                                  const { data: urlData } = supabase.storage.from("bare_acts").getPublicUrl(fileName);
                                  const pdf_url = urlData.publicUrl;
                                  const { error: updateError } = await supabase.from("bare_acts").update({ pdf_url }).eq("id", selectedAct.id);
                                  if (updateError) throw new Error(updateError.message);
                                  setSelectedAct({...selectedAct, pdf_url});
                                  fetchActs();
                                })(),
                                {
                                  loading: "Uploading PDF file...",
                                  success: "Statute PDF updated!",
                                  error: "Failed to upload: " + file.name
                                }
                              );
                            }
                          }}
                        />
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </TabsContent>
            </Tabs>
          </div>
        )}
      </div>

      {/* CRUD DIALOG FOR SINGLE SECTIONS */}
      <Dialog open={isSectionDialogOpen} onOpenChange={setIsSectionDialogOpen}>
        <DialogContent className="sm:max-w-[500px]">
          <DialogHeader>
            <DialogTitle>{editingSection ? "Modify Section Record" : "Add Statute Section"}</DialogTitle>
            <DialogDescription>Input chapter details and the statutory clause wording below.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-3">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1">
                <label className="text-[11px] font-bold text-slate-700">Chapter Number</label>
                <Input 
                  placeholder="e.g. I" 
                  value={sectionForm.chapter_number} 
                  onChange={(e) => setSectionForm({...sectionForm, chapter_number: e.target.value})}
                  className="text-xs h-9"
                />
              </div>
              <div className="space-y-1">
                <label className="text-[11px] font-bold text-slate-700">Chapter Title</label>
                <Input 
                  placeholder="e.g. Preliminary" 
                  value={sectionForm.chapter_title} 
                  onChange={(e) => setSectionForm({...sectionForm, chapter_title: e.target.value})}
                  className="text-xs h-9"
                />
              </div>
            </div>

            <div className="grid grid-cols-3 gap-4">
              <div className="col-span-1 space-y-1">
                <label className="text-[11px] font-bold text-slate-700">Section Code/No *</label>
                <Input 
                  placeholder="e.g. 1" 
                  value={sectionForm.section_number} 
                  onChange={(e) => setSectionForm({...sectionForm, section_number: e.target.value})}
                  className="text-xs h-9 font-bold text-primary"
                />
              </div>
              <div className="col-span-2 space-y-1">
                <label className="text-[11px] font-bold text-slate-700">Section Title *</label>
                <Input 
                  placeholder="e.g. Short title and commencement" 
                  value={sectionForm.section_title} 
                  onChange={(e) => setSectionForm({...sectionForm, section_title: e.target.value})}
                  className="text-xs h-9"
                />
              </div>
            </div>

            <div className="space-y-1">
              <label className="text-[11px] font-bold text-slate-700">Section Body/Content *</label>
              <Textarea 
                placeholder="Paste the statutory section text content clause..." 
                className="text-xs min-h-[120px] font-sans"
                value={sectionForm.section_text} 
                onChange={(e) => setSectionForm({...sectionForm, section_text: e.target.value})}
              />
            </div>
          </div>
          <DialogFooter>
            <Button size="sm" variant="ghost" onClick={() => setIsSectionDialogOpen(false)} className="text-xs">
              Cancel
            </Button>
            <Button size="sm" onClick={saveSection} className="text-xs">
              Save Section
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
