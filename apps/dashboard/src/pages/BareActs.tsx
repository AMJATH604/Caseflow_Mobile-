import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Textarea } from "@/components/ui/textarea";
import { supabase } from "@/integrations/supabase/client";
import { Book, Plus, Upload, Trash2, Edit, ChevronRight, Search, File, FileJson, CheckCircle, AlertCircle, Loader2 } from "lucide-react";
import { toast } from "sonner";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";

export default function BareActs() {
    const [acts, setActs] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const [searchQuery, setSearchQuery] = useState("");
    const [newAct, setNewAct] = useState({ title: "", short_title: "", description: "" });
    const [selectedAct, setSelectedAct] = useState<any>(null);
    const [bulkJson, setBulkJson] = useState("");
    const [pdfFile, setPdfFile] = useState<File | null>(null);
    const [uploading, setUploading] = useState(false);
    const [uploadProgress, setUploadProgress] = useState<{ current: number; total: number; inserted: number; failed: number } | null>(null);
    const [purgeBeforeImport, setPurgeBeforeImport] = useState(true);
    const [jsonFile, setJsonFile] = useState<File | null>(null);

    useEffect(() => {
        fetchActs();
    }, []);

    const fetchActs = async () => {
        setLoading(true);
        const { data, error } = await supabase.from("bare_acts").select("*").order("title");
        if (error) {
            toast.error("Failed to fetch bare acts");
        } else {
            setActs(data || []);
        }
        setLoading(false);
    };

    const createAct = async () => {
        if (!newAct.title || !newAct.short_title) {
            toast.error("Please fill in title and short title");
            return;
        }

        let pdf_url = null;
        if (pdfFile) {
            setUploading(true);
            const fileName = `${newAct.short_title}_${Date.now()}.pdf`;
            const { data: uploadData, error: uploadError } = await supabase.storage
                .from("bare_acts")
                .upload(fileName, pdfFile);

            if (uploadError) {
                toast.error("PDF Upload Failed: " + uploadError.message);
                setUploading(false);
                return;
            }

            const { data: urlData } = supabase.storage.from("bare_acts").getPublicUrl(fileName);
            pdf_url = urlData.publicUrl;
        }

        const { data, error } = await supabase.from("bare_acts").insert([{ ...newAct, pdf_url }]).select();
        setUploading(false);
        if (error) {
            toast.error("Failed to create act: " + error.message);
        } else {
            toast.success("Bare Act created successfully");
            fetchActs();
            setNewAct({ title: "", short_title: "", description: "" });
            setPdfFile(null);
        }
    };

    const updatePdf = async (act: any, file: File) => {
        setUploading(true);
        const fileName = `${act.short_title}_${Date.now()}.pdf`;
        const { error: uploadError } = await supabase.storage.from("bare_acts").upload(fileName, file);
        if (uploadError) {
            toast.error("PDF Upload Failed: " + uploadError.message);
            setUploading(false);
            return;
        }
        const { data: urlData } = supabase.storage.from("bare_acts").getPublicUrl(fileName);
        const pdf_url = urlData.publicUrl;

        const { error } = await supabase.from("bare_acts").update({ pdf_url }).eq("id", act.id);
        if (error) {
            toast.error("Failed to update act: " + error.message);
        } else {
            toast.success("PDF attached successfully");
            fetchActs();
        }
        setUploading(false);
    };

    const deleteAct = async (id: string) => {
        if (!confirm("Are you sure? This will delete all sections under this act.")) return;
        const { error } = await supabase.from("bare_acts").delete().eq("id", id);
        if (error) {
            toast.error("Failed to delete act");
        } else {
            toast.success("Act deleted");
            fetchActs();
        }
    };

    /**
     * Transform a single JSON entry (object or array format) into a bare_act_sections record.
     */
    const transformSection = (item: any, index: number, actId: string) => {
        if (Array.isArray(item)) {
            // Array format: ["act_name", "chapter_num", "chapter_title", "section_num", "section_title", "section_text"]
            if (item.length >= 6) {
                return {
                    act_id: actId,
                    chapter_number: item[1] || "",
                    chapter_title: item[2] || "",
                    section_number: item[3] || "",
                    section_title: item[4] || "",
                    section_text: item[5] || "",
                    title: item[4] || "",
                    content: item[5] || "",
                    sequence_order: index + 1,
                };
            } else if (item.length >= 5) {
                return {
                    act_id: actId,
                    chapter_number: item[0] || "",
                    chapter_title: item[1] || "",
                    section_number: item[2] || "",
                    section_title: item[3] || "",
                    section_text: item[4] || "",
                    title: item[3] || "",
                    content: item[4] || "",
                    sequence_order: index + 1,
                };
            }
            return null;
        } else {
            // Object format: {chapter_number, chapter_title, section_number, section_title, section_text}
            return {
                act_id: actId,
                chapter_number: item.chapter_number || item.chapter || "",
                chapter_title: item.chapter_title || item.chapter_name || "",
                section_number: item.section_number || item.number || item.article_number || "",
                section_title: item.section_title || item.title || item.heading || "",
                section_text: item.section_text || item.text || item.content || item.body || "",
                title: item.section_title || item.title || item.heading || "",
                content: item.section_text || item.text || item.content || item.body || "",
                sequence_order: index + 1,
            };
        }
    };

    const handleBulkUpload = async () => {
        if (!selectedAct) return;

        let jsonText = bulkJson;

        // If a JSON file was selected, read it
        if (jsonFile) {
            try {
                jsonText = await jsonFile.text();
            } catch (err: any) {
                toast.error("Failed to read JSON file: " + err.message);
                return;
            }
        }

        if (!jsonText.trim()) {
            toast.error("Please select a JSON file or paste JSON data");
            return;
        }

        setUploading(true);
        setUploadProgress(null);

        try {
            const sections = JSON.parse(jsonText);
            if (!Array.isArray(sections)) throw new Error("JSON must be an array of sections");

            // Transform all sections (auto-detects format)
            const formattedSections = sections
                .map((s, index) => transformSection(s, index, selectedAct.id))
                .filter(Boolean);

            if (formattedSections.length === 0) {
                toast.error("No valid sections found in JSON");
                setUploading(false);
                return;
            }

            // Purge existing sections if option is enabled
            if (purgeBeforeImport) {
                const { error: purgeError } = await supabase
                    .from("bare_act_sections")
                    .delete()
                    .eq("act_id", selectedAct.id);
                if (purgeError) {
                    toast.error("Failed to clear existing sections: " + purgeError.message);
                    setUploading(false);
                    return;
                }
            }

            // Upload in batches of 50
            const BATCH_SIZE = 50;
            const totalBatches = Math.ceil(formattedSections.length / BATCH_SIZE);
            let inserted = 0;
            let failed = 0;

            for (let i = 0; i < formattedSections.length; i += BATCH_SIZE) {
                const batch = formattedSections.slice(i, i + BATCH_SIZE);
                const batchNum = Math.floor(i / BATCH_SIZE) + 1;

                setUploadProgress({ current: batchNum, total: totalBatches, inserted, failed });

                const { error } = await supabase.from("bare_act_sections").insert(batch);

                if (error) {
                    console.error(`Batch ${batchNum} failed:`, error.message);
                    failed += batch.length;
                } else {
                    inserted += batch.length;
                }
            }

            setUploadProgress({ current: totalBatches, total: totalBatches, inserted, failed });

            if (failed > 0) {
                toast.warning(`Uploaded ${inserted} sections, but ${failed} failed`);
            } else {
                toast.success(`Successfully uploaded all ${inserted} sections!`);
            }

            setBulkJson("");
            setJsonFile(null);

            // Clear progress after a short delay
            setTimeout(() => setUploadProgress(null), 3000);
        } catch (err: any) {
            toast.error("Invalid JSON: " + err.message);
        } finally {
            setUploading(false);
        }
    };

    const filteredActs = acts.filter(a =>
        a.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        a.short_title.toLowerCase().includes(searchQuery.toLowerCase())
    );

    return (
        <div className="space-y-6 max-w-6xl mx-auto pb-12">
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div>
                    <h1 className="text-2xl font-bold flex items-center gap-2">
                        <Book className="h-6 w-6 text-primary" />
                        Bare Acts Management
                    </h1>
                    <p className="text-muted-foreground text-sm">Upload and manage statutes for the mobile library</p>
                </div>

                <Dialog>
                    <DialogTrigger asChild>
                        <Button className="bg-primary hover:bg-primary/90">
                            <Plus className="h-4 w-4 mr-2" />
                            New Bare Act
                        </Button>
                    </DialogTrigger>
                    <DialogContent>
                        <DialogHeader>
                            <DialogTitle>Add New Bare Act</DialogTitle>
                            <DialogDescription>Create the shell for a new statute. You can upload sections later.</DialogDescription>
                        </DialogHeader>
                        <div className="space-y-4 py-4">
                            <div className="space-y-2">
                                <label className="text-sm font-medium">Full Title</label>
                                <Input
                                    placeholder="e.g. Bharatiya Nyaya Sanhita, 2023"
                                    value={newAct.title}
                                    onChange={(e) => setNewAct({ ...newAct, title: e.target.value })}
                                />
                            </div>
                            <div className="space-y-2">
                                <label className="text-sm font-medium">Short Title (Abbreviation)</label>
                                <Input
                                    placeholder="e.g. BNS"
                                    value={newAct.short_title}
                                    onChange={(e) => setNewAct({ ...newAct, short_title: e.target.value })}
                                />
                            </div>
                            <div className="space-y-2">
                                <label className="text-sm font-medium">Description</label>
                                <Textarea
                                    placeholder="Optional details about the act..."
                                    value={newAct.description}
                                    onChange={(e) => setNewAct({ ...newAct, description: e.target.value })}
                                />
                            </div>
                            <div className="space-y-2">
                                <label className="text-sm font-medium">Official PDF (Optional)</label>
                                <Input
                                    type="file"
                                    accept=".pdf"
                                    onChange={(e) => setPdfFile(e.target.files?.[0] || null)}
                                />
                            </div>
                        </div>
                        <DialogFooter>
                            <Button onClick={createAct}>Create Statute</Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>
            </div>

            <div className="flex items-center gap-2 bg-card p-3 rounded-xl border border-border shadow-sm">
                <Search className="h-4 w-4 text-muted-foreground ml-2" />
                <Input
                    className="border-none bg-transparent focus-visible:ring-0"
                    placeholder="Search by title or code..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                />
            </div>

            <div className="grid grid-cols-1 gap-6">
                <Card>
                    <CardHeader>
                        <CardTitle>Available Statutes</CardTitle>
                        <CardDescription aria-hidden="true" className="sr-only">List of all laws uploaded to the system</CardDescription>
                    </CardHeader>
                    <CardContent>
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead>Short Code</TableHead>
                                    <TableHead>Statute Title</TableHead>
                                    <TableHead>Created</TableHead>
                                    <TableHead className="text-right">Actions</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {loading ? (
                                    <TableRow><TableCell colSpan={4} className="text-center py-8">Loading statutes...</TableCell></TableRow>
                                ) : filteredActs.length === 0 ? (
                                    <TableRow><TableCell colSpan={4} className="text-center py-8">No statutes found.</TableCell></TableRow>
                                ) : (
                                    filteredActs.map((act) => (
                                        <TableRow key={act.id}>
                                            <TableCell><span className="font-bold text-primary">{act.short_title}</span></TableCell>
                                            <TableCell>{act.title}</TableCell>
                                            <TableCell className="text-muted-foreground text-xs">{new Date(act.created_at).toLocaleDateString()}</TableCell>
                                            <TableCell className="text-right space-x-2">
                                                {act.pdf_url && (
                                                    <Button
                                                        variant="ghost"
                                                        size="sm"
                                                        className="text-blue-600 hover:bg-blue-50"
                                                        onClick={() => window.open(act.pdf_url, '_blank')}
                                                    >
                                                        <File className="h-3.5 w-3.5" />
                                                    </Button>
                                                )}
                                                {!act.pdf_url && (
                                                    <label className="cursor-pointer inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 border border-blue-100 bg-transparent hover:bg-blue-50 text-blue-600 h-9 px-3">
                                                        <input type="file" accept=".pdf" className="hidden" onChange={(e) => {
                                                            if (e.target.files?.[0]) updatePdf(act, e.target.files[0]);
                                                        }} />
                                                        <Upload className="h-3.5 w-3.5 mr-1" />
                                                        Attach PDF
                                                    </label>
                                                )}
                                                <Button
                                                    variant="outline"
                                                    size="sm"
                                                    onClick={() => setSelectedAct(act)}
                                                    className="text-emerald-600 border-emerald-100 hover:bg-emerald-50"
                                                >
                                                    <Upload className="h-3.5 w-3.5 mr-1" />
                                                    Bulk Upload
                                                </Button>
                                                <Button
                                                    variant="ghost"
                                                    size="sm"
                                                    className="text-destructive hover:bg-destructive/10"
                                                    onClick={() => deleteAct(act.id)}
                                                >
                                                    <Trash2 className="h-3.5 w-3.5" />
                                                </Button>
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </CardContent>
                </Card>

                {selectedAct && (
                    <Card className="border-2 border-emerald-500 shadow-md animate-in slide-in-from-bottom-4">
                        <CardHeader className="bg-emerald-50/50 rounded-t-xl">
                            <div className="flex items-center justify-between">
                                <div>
                                    <CardTitle className="text-emerald-800">Bulk Upload: {selectedAct.title}</CardTitle>
                                    <CardDescription className="text-emerald-600/80">
                                        Upload a JSON file or paste JSON data. Supports both object and array formats. Uploads in batches — no size limit!
                                    </CardDescription>
                                </div>
                                <Button variant="ghost" size="sm" onClick={() => { setSelectedAct(null); setUploadProgress(null); setJsonFile(null); setBulkJson(""); }}>Close</Button>
                            </div>
                        </CardHeader>
                        <CardContent className="space-y-4 pt-6">
                            {/* JSON File Picker */}
                            <div className="space-y-2">
                                <label className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Option 1: Pick JSON File (Recommended)</label>
                                <div className="flex items-center gap-3">
                                    <label className="flex-1 cursor-pointer">
                                        <input
                                            type="file"
                                            accept=".json"
                                            className="hidden"
                                            onChange={(e) => {
                                                const file = e.target.files?.[0] || null;
                                                setJsonFile(file);
                                                if (file) setBulkJson("");
                                            }}
                                        />
                                        <div className={`flex items-center gap-3 p-4 border-2 border-dashed rounded-xl transition-colors ${
                                            jsonFile ? 'border-emerald-400 bg-emerald-50' : 'border-gray-200 hover:border-emerald-300 hover:bg-emerald-50/30'
                                        }`}>
                                            <FileJson className={`h-8 w-8 ${jsonFile ? 'text-emerald-600' : 'text-gray-400'}`} />
                                            <div>
                                                {jsonFile ? (
                                                    <>
                                                        <p className="text-sm font-semibold text-emerald-700">{jsonFile.name}</p>
                                                        <p className="text-xs text-emerald-600">{(jsonFile.size / 1024).toFixed(1)} KB</p>
                                                    </>
                                                ) : (
                                                    <>
                                                        <p className="text-sm font-medium text-gray-600">Click to select a JSON file</p>
                                                        <p className="text-xs text-gray-400">Supports any size — uploaded in batches of 50</p>
                                                    </>
                                                )}
                                            </div>
                                        </div>
                                    </label>
                                    {jsonFile && (
                                        <Button variant="ghost" size="sm" onClick={() => setJsonFile(null)} className="text-gray-400 hover:text-red-500">
                                            <Trash2 className="h-4 w-4" />
                                        </Button>
                                    )}
                                </div>
                            </div>

                            {/* Divider */}
                            {!jsonFile && (
                                <>
                                    <div className="flex items-center gap-3">
                                        <div className="flex-1 h-px bg-gray-200" />
                                        <span className="text-xs text-gray-400 font-medium">OR</span>
                                        <div className="flex-1 h-px bg-gray-200" />
                                    </div>

                                    {/* Textarea Fallback */}
                                    <div className="space-y-2">
                                        <label className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Option 2: Paste JSON</label>
                                        <Textarea
                                            className="font-mono text-xs min-h-[200px]"
                                            placeholder='[{"section_number": "1", "section_title": "...", "section_text": "..."}]'
                                            value={bulkJson}
                                            onChange={(e) => setBulkJson(e.target.value)}
                                        />
                                    </div>
                                </>
                            )}

                            {/* Upload Progress */}
                            {uploadProgress && (
                                <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-4 space-y-3">
                                    <div className="flex items-center justify-between">
                                        <div className="flex items-center gap-2">
                                            {uploading ? (
                                                <Loader2 className="h-4 w-4 text-emerald-600 animate-spin" />
                                            ) : uploadProgress.failed > 0 ? (
                                                <AlertCircle className="h-4 w-4 text-amber-500" />
                                            ) : (
                                                <CheckCircle className="h-4 w-4 text-emerald-600" />
                                            )}
                                            <span className="text-sm font-semibold text-emerald-800">
                                                {uploading
                                                    ? `Uploading batch ${uploadProgress.current} of ${uploadProgress.total}...`
                                                    : uploadProgress.failed > 0
                                                        ? `Done — ${uploadProgress.inserted} inserted, ${uploadProgress.failed} failed`
                                                        : `Done — All ${uploadProgress.inserted} sections uploaded!`
                                                }
                                            </span>
                                        </div>
                                    </div>
                                    {/* Progress bar */}
                                    <div className="w-full bg-emerald-100 rounded-full h-2">
                                        <div
                                            className="bg-emerald-500 h-2 rounded-full transition-all duration-300"
                                            style={{ width: `${(uploadProgress.current / uploadProgress.total) * 100}%` }}
                                        />
                                    </div>
                                </div>
                            )}

                            {/* Actions Row */}
                            <div className="flex justify-between items-center bg-muted/50 p-4 rounded-lg">
                                <div className="space-y-2">
                                    <label className="flex items-center gap-2 cursor-pointer">
                                        <input
                                            type="checkbox"
                                            checked={purgeBeforeImport}
                                            onChange={(e) => setPurgeBeforeImport(e.target.checked)}
                                            className="rounded border-gray-300"
                                        />
                                        <span className="text-xs font-medium text-muted-foreground">Replace existing sections (recommended)</span>
                                    </label>
                                    <p className="text-xs text-muted-foreground max-w-md">
                                        Supports both formats: objects <code className="bg-gray-100 px-1 rounded">{'{...}'}</code> and arrays <code className="bg-gray-100 px-1 rounded">{'[...]'}</code>
                                    </p>
                                </div>
                                <Button
                                    onClick={handleBulkUpload}
                                    disabled={uploading || (!jsonFile && !bulkJson.trim())}
                                    className="bg-emerald-600 hover:bg-emerald-700 text-white shadow-lg disabled:opacity-50"
                                >
                                    {uploading ? (
                                        <><Loader2 className="h-4 w-4 mr-2 animate-spin" /> Uploading...</>
                                    ) : (
                                        <><Upload className="h-4 w-4 mr-2" /> Process & Sync to App</>
                                    )}
                                </Button>
                            </div>
                        </CardContent>
                    </Card>
                )}
            </div>
        </div>
    );
}
