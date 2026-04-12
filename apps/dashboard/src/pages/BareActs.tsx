import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Textarea } from "@/components/ui/textarea";
import { supabase } from "@/integrations/supabase/client";
import { Book, Plus, Upload, Trash2, Edit, ChevronRight, Search, File } from "lucide-react";
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

    const handleBulkUpload = async () => {
        if (!selectedAct || !bulkJson) return;

        try {
            const sections = JSON.parse(bulkJson);
            if (!Array.isArray(sections)) throw new Error("JSON must be an array of sections");

            const formattedSections = sections.map((s, index) => ({
                act_id: selectedAct.id,
                chapter_number: s.chapter_number || "",
                chapter_title: s.chapter_title || "",
                section_number: s.section_number || "",
                section_title: s.section_title || "",
                section_text: s.section_text || "",
                sequence_order: index,
            }));

            const { error } = await supabase.from("bare_act_sections").insert(formattedSections);
            if (error) throw error;

            toast.success(`Successfully uploaded ${sections.length} sections`);
            setBulkJson("");
        } catch (err: any) {
            toast.error("Invalid JSON format: " + err.message);
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
                                    <CardDescription className="text-emerald-600/80">Paste a JSON array of sections to populate the statute.</CardDescription>
                                </div>
                                <Button variant="ghost" size="sm" onClick={() => setSelectedAct(null)}>Close</Button>
                            </div>
                        </CardHeader>
                        <CardContent className="space-y-4 pt-6">
                            <div className="space-y-2">
                                <label className="text-xs font-bold uppercase tracking-wider text-muted-foreground">JSON Input</label>
                                <Textarea
                                    className="font-mono text-xs min-h-[300px]"
                                    placeholder='[{"section_number": "1", "section_title": "...", "section_text": "..."}]'
                                    value={bulkJson}
                                    onChange={(e) => setBulkJson(e.target.value)}
                                />
                            </div>
                            <div className="flex justify-between items-center bg-muted/50 p-4 rounded-lg">
                                <p className="text-xs text-muted-foreground max-w-md">
                                    Note: This will append new sections to the existing act. Ensure your JSON matches the format: [chapter_number, chapter_title, section_number, section_title, section_text]
                                </p>
                                <Button onClick={handleBulkUpload} className="bg-emerald-600 hover:bg-emerald-700 text-white shadow-lg">
                                    <Upload className="h-4 w-4 mr-2" />
                                    Process & Sync to App
                                </Button>
                            </div>
                        </CardContent>
                    </Card>
                )}
            </div>
        </div>
    );
}
