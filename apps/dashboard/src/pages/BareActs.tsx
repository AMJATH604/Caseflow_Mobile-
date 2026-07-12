import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Textarea } from "@/components/ui/textarea";
import { supabase } from "@/integrations/supabase/client";
import { 
  Book, Plus, Upload, Trash2, Edit, ChevronRight, Search, File, 
  FileJson, CheckCircle, AlertCircle, Loader2, BookOpen, Settings, 
  Database, Info, HelpCircle, Layers, Check, RefreshCw 
} from "lucide-react";
import { toast } from "sonner";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

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

  // Import Wizard State
  const [importStep, setImportStep] = useState(1); // 1: Upload, 2: Map, 3: Preview, 4: Uploader
  const [jsonFile, setJsonFile] = useState<File | null>(null);
  const [pastedJson, setPastedJson] = useState("");
  const [parsedJsonData, setParsedJsonData] = useState<any[]>([]);
  const [availableKeys, setAvailableKeys] = useState<string[]>([]);
  const [fieldMapping, setFieldMapping] = useState({
    chapter_number: "",
    chapter_title: "",
    section_number: "",
    section_title: "",
    section_text: "",
  });
  const [purgeBeforeImport, setPurgeBeforeImport] = useState(true);
  const [importProgress, setImportProgress] = useState<{ current: number; total: number; inserted: number; failed: number } | null>(null);
  const [importing, setImporting] = useState(false);

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

  // Import File Parser
  const parseJsonFile = async (file: File) => {
    try {
      const text = await file.text();
      handleJsonParse(text);
    } catch (err: any) {
      toast.error("Could not read JSON file: " + err.message);
    }
  };

  const handleJsonParse = (text: string) => {
    try {
      const parsed = JSON.parse(text);
      let dataArray: any[] = [];

      if (Array.isArray(parsed)) {
        dataArray = parsed;
      } else if (parsed && typeof parsed === "object") {
        // Look for common array wrapper keys (e.g. data, sections, records)
        const possibleArrayKey = Object.keys(parsed).find(k => Array.isArray(parsed[k]));
        if (possibleArrayKey) {
          dataArray = parsed[possibleArrayKey];
        } else {
          dataArray = [parsed];
        }
      }

      if (dataArray.length === 0) {
        toast.error("JSON structure must contain an array of sections");
        return;
      }

      setParsedJsonData(dataArray);

      // Find all unique keys from sample objects to support mapping
      const keys = new Set<string>();
      dataArray.slice(0, 10).forEach(item => {
        if (item && typeof item === "object" && !Array.isArray(item)) {
          Object.keys(item).forEach(k => keys.add(k));
        }
      });

      const extractedKeys = Array.from(keys);
      setAvailableKeys(extractedKeys);

      // Pre-map standard names
      const preMap = {
        chapter_number: extractedKeys.find(k => /chap.*num|chapter_no|chap_no|chapter$/i.test(k)) || "",
        chapter_title: extractedKeys.find(k => /chap.*title|chapter_name|chap_name/i.test(k)) || "",
        section_number: extractedKeys.find(k => /sec.*num|section_no|sec_no|number|id/i.test(k)) || "",
        section_title: extractedKeys.find(k => /sec.*title|title|heading/i.test(k)) || "",
        section_text: extractedKeys.find(k => /text|content|body|desc/i.test(k)) || "",
      };

      setFieldMapping(preMap);
      setImportStep(2);
      toast.success(`Successfully loaded ${dataArray.length} items. Map your keys to continue.`);
    } catch (err: any) {
      toast.error("Invalid JSON syntax: " + err.message);
    }
  };

  // Run dynamic mapper transformations
  const getMappedData = () => {
    return parsedJsonData.map((item, index) => {
      return {
        act_id: selectedAct.id,
        chapter_number: item[fieldMapping.chapter_number] || "",
        chapter_title: item[fieldMapping.chapter_title] || "",
        section_number: item[fieldMapping.section_number] || "",
        section_title: item[fieldMapping.section_title] || "",
        section_text: item[fieldMapping.section_text] || "",
        title: item[fieldMapping.section_title] || "",
        content: item[fieldMapping.section_text] || "",
        sequence_order: index + 1,
      };
    });
  };

  // Batch Sync execution
  const executeImport = async () => {
    const formattedData = getMappedData();
    setImporting(true);
    setImportProgress(null);

    // 1. Purge older sections
    if (purgeBeforeImport) {
      const { error: purgeError } = await supabase
        .from("bare_act_sections")
        .delete()
        .eq("act_id", selectedAct.id);

      if (purgeError) {
        toast.error("Failed to empty database: " + purgeError.message);
        setImporting(false);
        return;
      }
    }

    // 2. Insert in batches
    const BATCH_SIZE = 50;
    const totalBatches = Math.ceil(formattedData.length / BATCH_SIZE);
    let inserted = 0;
    let failed = 0;

    for (let i = 0; i < formattedData.length; i += BATCH_SIZE) {
      const batch = formattedData.slice(i, i + BATCH_SIZE);
      const batchIndex = Math.floor(i / BATCH_SIZE) + 1;

      setImportProgress({ current: batchIndex, total: totalBatches, inserted, failed });

      const { error } = await supabase.from("bare_act_sections").insert(batch);

      if (error) {
        console.error(`Batch ${batchIndex} import failed:`, error.message);
        failed += batch.length;
      } else {
        inserted += batch.length;
      }
    }

    setImportProgress({ current: totalBatches, total: totalBatches, inserted, failed });
    setImporting(false);

    if (failed > 0) {
      toast.warning(`Import complete. ${inserted} imported, ${failed} failed.`);
    } else {
      toast.success(`Successfully imported all ${inserted} sections!`);
    }

    // Reset wizard
    setJsonFile(null);
    setPastedJson("");
    setParsedJsonData([]);
    setImportStep(1);
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

      {/* RIGHT COLUMN: Chapters/Sections Directory, Uploader, Settings (cols-8) */}
      <div className="lg:col-span-8">
        {!selectedAct ? (
          <div className="h-full flex flex-col items-center justify-center text-center py-24 px-6 border border-dashed rounded-2xl bg-card">
            <BookOpen className="h-16 w-16 text-muted-foreground/30 stroke-[1.5]" />
            <h3 className="mt-4 text-lg font-bold text-foreground">No Statute Selected</h3>
            <p className="mt-1.5 text-xs text-muted-foreground max-w-sm">
              Please choose a statute from the directory sidebar to explore chapters/sections, update contents, or run JSON import tasks.
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
                <TabsTrigger value="import" className="text-xs flex items-center gap-2">
                  <Upload className="h-3.5 w-3.5" />
                  JSON Import Wizard
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
                    {searchSectionQuery ? "No sections match your search query." : "This statute has no sections yet. Go to JSON Import Wizard to upload them."}
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

              {/* TAB 2: JSON Import Wizard */}
              <TabsContent value="import" className="mt-4 space-y-4">
                <Card>
                  <CardHeader>
                    <div className="flex items-center justify-between">
                      <div>
                        <CardTitle className="text-base font-bold">Dynamic JSON Bulk Upload Wizard</CardTitle>
                        <CardDescription className="text-xs">
                          Map custom JSON properties directly to statute columns. Upload in seconds.
                        </CardDescription>
                      </div>
                      <Dialog>
                        <DialogTrigger asChild>
                          <Button variant="outline" size="sm" className="text-xs h-8">
                            <HelpCircle className="h-3.5 w-3.5 mr-1" />
                            View Templates
                          </Button>
                        </DialogTrigger>
                        <DialogContent className="max-w-xl">
                          <DialogHeader>
                            <DialogTitle>Accepted JSON Structures</DialogTitle>
                            <DialogDescription>Your file can contain an array of objects. Use any keys; you will map them in Step 2.</DialogDescription>
                          </DialogHeader>
                          <div className="space-y-4 py-2 text-xs">
                            <p className="font-semibold text-slate-700">Sample Structure (Recommended):</p>
                            <pre className="p-3 rounded-lg bg-slate-950 text-emerald-400 overflow-x-auto font-mono text-[10px]">
{`[
  {
    "chapter": "1",
    "chapter_name": "Preliminary",
    "section": "1",
    "title": "Short title and commencement",
    "content": "This Act may be called the Code..."
  },
  {
    "chapter": "1",
    "chapter_name": "Preliminary",
    "section": "2",
    "title": "Definitions",
    "content": "In this Code, unless the context..."
  }
]`}
                            </pre>
                          </div>
                        </DialogContent>
                      </Dialog>
                    </div>
                  </CardHeader>
                  <CardContent className="space-y-6">
                    {/* WIZARD PROCESS STEPPER */}
                    <div className="flex items-center justify-between max-w-md mx-auto py-2">
                      {[1, 2, 3, 4].map((step) => (
                        <div key={step} className="flex items-center">
                          <div className={`w-7 h-7 rounded-full flex items-center justify-center font-bold text-xs ${
                            importStep === step
                              ? 'bg-primary text-white scale-110 shadow-sm'
                              : importStep > step
                                ? 'bg-emerald-500 text-white'
                                : 'bg-muted text-muted-foreground'
                          }`}>
                            {importStep > step ? <Check className="h-4 w-4" /> : step}
                          </div>
                          {step < 4 && (
                            <div className={`h-[2px] w-12 sm:w-16 mx-2 ${
                              importStep > step ? 'bg-emerald-500' : 'bg-muted'
                            }`} />
                          )}
                        </div>
                      ))}
                    </div>

                    {/* STEP 1: Upload File or Paste Text */}
                    {importStep === 1 && (
                      <div className="space-y-4">
                        <div className="space-y-2">
                          <label className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Option 1: Upload JSON File</label>
                          <div className="flex items-center gap-3">
                            <label className="flex-1 cursor-pointer">
                              <input
                                type="file"
                                accept=".json"
                                className="hidden"
                                onChange={(e) => {
                                  const file = e.target.files?.[0] || null;
                                  setJsonFile(file);
                                  if (file) parseJsonFile(file);
                                }}
                              />
                              <div className={`flex flex-col items-center justify-center p-8 border-2 border-dashed rounded-2xl transition-all duration-200 ${
                                jsonFile ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/50 hover:bg-muted/10'
                              }`}>
                                <FileJson className="h-10 w-10 text-muted-foreground mb-3" />
                                <span className="text-sm font-semibold text-foreground">
                                  {jsonFile ? jsonFile.name : "Click to select statute JSON file"}
                                </span>
                                <span className="text-xs text-muted-foreground mt-1">Supports any file size — processed in batches of 50</span>
                              </div>
                            </label>
                          </div>
                        </div>

                        <div className="flex items-center gap-4 py-2">
                          <div className="flex-1 h-px bg-border" />
                          <span className="text-[10px] text-muted-foreground font-black tracking-widest uppercase">OR</span>
                          <div className="flex-1 h-px bg-border" />
                        </div>

                        <div className="space-y-2">
                          <label className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Option 2: Paste Raw JSON String</label>
                          <Textarea
                            placeholder='[{"chapter_number":"1", "section_number":"1", "section_title":"...", "section_text":"..."}]'
                            className="font-mono text-xs min-h-[160px]"
                            value={pastedJson}
                            onChange={(e) => setPastedJson(e.target.value)}
                          />
                          <Button size="sm" className="w-full text-xs" onClick={() => handleJsonParse(pastedJson)} disabled={!pastedJson.trim()}>
                            Validate & Map Paste Data
                          </Button>
                        </div>
                      </div>
                    )}

                    {/* STEP 2: MAPPING DROPDOWNS */}
                    {importStep === 2 && (
                      <div className="space-y-5 animate-in fade-in duration-300">
                        <div className="p-4 rounded-xl bg-amber-50 border border-amber-100 flex items-start gap-3">
                          <Info className="h-4 w-4 text-amber-600 shrink-0 mt-0.5" />
                          <div className="space-y-0.5">
                            <p className="text-xs font-bold text-amber-800">Assign JSON Keys</p>
                            <p className="text-[11px] text-amber-700 leading-snug">
                              We found keys in your JSON structure. Please map which property represents the statutory fields.
                            </p>
                          </div>
                        </div>

                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                          <div className="space-y-1.5">
                            <label className="text-xs font-bold text-slate-700">Chapter Number</label>
                            <Select 
                              value={fieldMapping.chapter_number} 
                              onValueChange={(val) => setFieldMapping({...fieldMapping, chapter_number: val})}
                            >
                              <SelectTrigger className="text-xs h-9">
                                <SelectValue placeholder="Skip / None" />
                              </SelectTrigger>
                              <SelectContent>
                                <SelectItem value="none">-- Skip Chapter Number --</SelectItem>
                                {availableKeys.map(k => <SelectItem key={k} value={k}>{k}</SelectItem>)}
                              </SelectContent>
                            </Select>
                          </div>

                          <div className="space-y-1.5">
                            <label className="text-xs font-bold text-slate-700">Chapter Title</label>
                            <Select 
                              value={fieldMapping.chapter_title} 
                              onValueChange={(val) => setFieldMapping({...fieldMapping, chapter_title: val})}
                            >
                              <SelectTrigger className="text-xs h-9">
                                <SelectValue placeholder="Skip / None" />
                              </SelectTrigger>
                              <SelectContent>
                                <SelectItem value="none">-- Skip Chapter Title --</SelectItem>
                                {availableKeys.map(k => <SelectItem key={k} value={k}>{k}</SelectItem>)}
                              </SelectContent>
                            </Select>
                          </div>

                          <div className="space-y-1.5">
                            <label className="text-xs font-bold text-slate-700">Section Number * (Required)</label>
                            <Select 
                              value={fieldMapping.section_number} 
                              onValueChange={(val) => setFieldMapping({...fieldMapping, section_number: val})}
                            >
                              <SelectTrigger className="text-xs h-9">
                                <SelectValue placeholder="Select column..." />
                              </SelectTrigger>
                              <SelectContent>
                                {availableKeys.map(k => <SelectItem key={k} value={k}>{k}</SelectItem>)}
                              </SelectContent>
                            </Select>
                          </div>

                          <div className="space-y-1.5">
                            <label className="text-xs font-bold text-slate-700">Section Title * (Required)</label>
                            <Select 
                              value={fieldMapping.section_title} 
                              onValueChange={(val) => setFieldMapping({...fieldMapping, section_title: val})}
                            >
                              <SelectTrigger className="text-xs h-9">
                                <SelectValue placeholder="Select column..." />
                              </SelectTrigger>
                              <SelectContent>
                                {availableKeys.map(k => <SelectItem key={k} value={k}>{k}</SelectItem>)}
                              </SelectContent>
                            </Select>
                          </div>

                          <div className="space-y-1.5 md:col-span-2">
                            <label className="text-xs font-bold text-slate-700">Section Text / Content * (Required)</label>
                            <Select 
                              value={fieldMapping.section_text} 
                              onValueChange={(val) => setFieldMapping({...fieldMapping, section_text: val})}
                            >
                              <SelectTrigger className="text-xs h-9">
                                <SelectValue placeholder="Select column..." />
                              </SelectTrigger>
                              <SelectContent>
                                {availableKeys.map(k => <SelectItem key={k} value={k}>{k}</SelectItem>)}
                              </SelectContent>
                            </Select>
                          </div>
                        </div>

                        <div className="flex justify-between pt-4 border-t border-border/60">
                          <Button size="sm" variant="ghost" onClick={() => setImportStep(1)} className="text-xs">
                            Back
                          </Button>
                          <Button 
                            size="sm" 
                            disabled={!fieldMapping.section_number || !fieldMapping.section_title || !fieldMapping.section_text} 
                            onClick={() => setImportStep(3)}
                            className="text-xs"
                          >
                            Preview Mapping
                          </Button>
                        </div>
                      </div>
                    )}

                    {/* STEP 3: MAPPED PREVIEW */}
                    {importStep === 3 && (
                      <div className="space-y-5 animate-in fade-in duration-300">
                        <div className="border border-border rounded-xl bg-card overflow-hidden">
                          <div className="p-3 bg-muted/30 border-b border-border text-xs font-bold">
                            Live Mapped Data Preview (First 3 entries)
                          </div>
                          <div className="p-3 space-y-4">
                            {getMappedData().slice(0, 3).map((item, idx) => (
                              <div key={idx} className="p-3 rounded-lg bg-slate-50 border border-slate-100 space-y-2 text-xs">
                                <div className="flex items-center justify-between text-[11px] font-bold text-slate-500 border-b pb-1">
                                  <span>Chapter: {item.chapter_number || "None"} - {item.chapter_title || "None"}</span>
                                  <span>Sec: {item.section_number}</span>
                                </div>
                                <h4 className="font-bold text-slate-900">{item.section_title}</h4>
                                <p className="text-slate-600 line-clamp-3 leading-relaxed">{item.section_text}</p>
                              </div>
                            ))}
                          </div>
                        </div>

                        <div className="bg-slate-50 p-4 rounded-xl border border-slate-100 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
                          <label className="flex items-center gap-2 cursor-pointer">
                            <input 
                              type="checkbox" 
                              checked={purgeBeforeImport} 
                              onChange={(e) => setPurgeBeforeImport(e.target.checked)}
                              className="rounded border-slate-300 text-primary focus:ring-primary"
                            />
                            <div className="space-y-0.5">
                              <span className="text-xs font-bold text-slate-800 block">Replace existing sections</span>
                              <span className="text-[10px] text-muted-foreground block">Cleans database table for this act before inserting</span>
                            </div>
                          </label>

                          <div className="flex items-center gap-2 self-end sm:self-center">
                            <Button size="sm" variant="ghost" onClick={() => setImportStep(2)} className="text-xs">
                              Back
                            </Button>
                            <Button size="sm" onClick={() => { setImportStep(4); executeImport(); }} className="text-xs bg-emerald-600 hover:bg-emerald-700 text-white">
                              Execute Import & Sync
                            </Button>
                          </div>
                        </div>
                      </div>
                    )}

                    {/* STEP 4: PROGRESS OVERLAY */}
                    {importStep === 4 && importProgress && (
                      <div className="space-y-4 py-8 animate-in fade-in duration-300 text-center max-w-sm mx-auto">
                        {importing ? (
                          <RefreshCw className="h-10 w-10 text-primary animate-spin mx-auto" />
                        ) : importProgress.failed > 0 ? (
                          <AlertCircle className="h-10 w-10 text-amber-500 mx-auto" />
                        ) : (
                          <CheckCircle className="h-10 w-10 text-emerald-500 mx-auto" />
                        )}

                        <div className="space-y-1">
                          <h4 className="font-bold text-sm text-foreground">
                            {importing ? `Processing batches...` : `Import Session Completed`}
                          </h4>
                          <p className="text-xs text-muted-foreground">
                            {importing 
                              ? `Uploading batch ${importProgress.current} of ${importProgress.total}`
                              : `Synced successfully! ${importProgress.inserted} rows inserted.`
                            }
                          </p>
                        </div>

                        <div className="w-full bg-slate-100 rounded-full h-2">
                          <div 
                            className="bg-primary h-2 rounded-full transition-all duration-300"
                            style={{ width: `${(importProgress.current / importProgress.total) * 100}%` }}
                          />
                        </div>

                        {!importing && (
                          <Button size="sm" className="mt-4 text-xs w-full" onClick={() => setImportStep(1)}>
                            Start New Import Session
                          </Button>
                        )}
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
