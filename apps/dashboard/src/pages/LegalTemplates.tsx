import { useState, useEffect } from "react";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
} from "@/components/ui/dialog";
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from "@/components/ui/table";
import { toast } from "sonner";
import { Plus, Trash2, FileText, Download, Loader2 } from "lucide-react";

interface LegalTemplate {
    id: string;
    title: string;
    description: string;
    category: string;
    pdf_url: string;
    docx_url: string;
    created_at: string;
}

export default function LegalTemplates() {
    const [templates, setTemplates] = useState<LegalTemplate[]>([]);
    const [loading, setLoading] = useState(true);
    const [isDialogOpen, setIsDialogOpen] = useState(false);
    const [uploading, setUploading] = useState(false);

    // Form states
    const [title, setTitle] = useState("");
    const [description, setDescription] = useState("");
    const [category, setCategory] = useState("");
    const [pdfFile, setPdfFile] = useState<File | null>(null);
    const [docxFile, setDocxFile] = useState<File | null>(null);

    useEffect(() => {
        fetchTemplates();
    }, []);

    async function fetchTemplates() {
        try {
            setLoading(true);
            const { data, error } = await supabase
                .from("legal_templates")
                .select("*")
                .order("created_at", { ascending: false });

            if (error) throw error;
            setTemplates(data || []);
        } catch (error: any) {
            toast.error("Error fetching templates: " + error.message);
        } finally {
            setLoading(false);
        }
    }

    async function handleCreateTemplate(e: React.FormEvent) {
        e.preventDefault();
        if (!pdfFile && !docxFile) {
            toast.error("Please select at least one template file (PDF or Word)");
            return;
        }

        try {
            setUploading(true);
            let pdfUrl = "";
            let docxUrl = "";

            // 1. Upload PDF if selected
            if (pdfFile) {
                const fileExt = pdfFile.name.split(".").pop();
                const fileName = `pdf_${Math.random()}.${fileExt}`;
                const filePath = `templates/${fileName}`;
                const { error: uploadError } = await supabase.storage
                    .from("legal_templates")
                    .upload(filePath, pdfFile);
                if (uploadError) throw uploadError;
                const { data: urlData } = supabase.storage.from("legal_templates").getPublicUrl(filePath);
                pdfUrl = urlData.publicUrl;
            }

            // 2. Upload Word if selected
            if (docxFile) {
                const fileExt = docxFile.name.split(".").pop();
                const fileName = `docx_${Math.random()}.${fileExt}`;
                const filePath = `templates/${fileName}`;
                const { error: uploadError } = await supabase.storage
                    .from("legal_templates")
                    .upload(filePath, docxFile);
                if (uploadError) throw uploadError;
                const { data: urlData } = supabase.storage.from("legal_templates").getPublicUrl(filePath);
                docxUrl = urlData.publicUrl;
            }

            // 3. Insert record into database
            const { error: insertError } = await supabase.from("legal_templates").insert([
                {
                    title,
                    description,
                    category,
                    pdf_url: pdfUrl,
                    docx_url: docxUrl,
                },
            ]);

            if (insertError) throw insertError;

            toast.success("Template created successfully");
            setIsDialogOpen(false);
            setTitle("");
            setDescription("");
            setCategory("");
            setPdfFile(null);
            setDocxFile(null);
            fetchTemplates();
        } catch (error: any) {
            toast.error("Error creating template: " + error.message);
        } finally {
            setUploading(false);
        }
    }

    async function handleDelete(id: string, pdfUrl?: string, docxUrl?: string) {
        if (!confirm("Are you sure you want to delete this template?")) return;

        try {
            // Delete PDF from storage
            if (pdfUrl) {
                const path = pdfUrl.split("/").pop();
                if (path) await supabase.storage.from("legal_templates").remove([`templates/${path}`]);
            }
            // Delete DOCX from storage
            if (docxUrl) {
                const path = docxUrl.split("/").pop();
                if (path) await supabase.storage.from("legal_templates").remove([`templates/${path}`]);
            }

            const { error } = await supabase.from("legal_templates").delete().eq("id", id);
            if (error) throw error;

            toast.success("Template deleted");
            fetchTemplates();
        } catch (error: any) {
            toast.error("Error deleting template: " + error.message);
        }
    }

    return (
        <div className="p-6 space-y-6">
            <div className="flex justify-between items-center">
                <div>
                    <h1 className="text-3xl font-bold tracking-tight">Legal Templates</h1>
                    <p className="text-muted-foreground">Manage readymade legal documents and forms.</p>
                </div>

                <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
                    <DialogTrigger asChild>
                        <Button className="gap-2">
                            <Plus className="h-4 w-4" /> Add Template
                        </Button>
                    </DialogTrigger>
                    <DialogContent>
                        <DialogHeader>
                            <DialogTitle>Add New Legal Template</DialogTitle>
                        </DialogHeader>
                        <form onSubmit={handleCreateTemplate} className="space-y-4 pt-4">
                            <div className="space-y-2">
                                <label className="text-sm font-medium">Template Title</label>
                                <Input
                                    placeholder="e.g. Plaint, Bail Application"
                                    value={title}
                                    onChange={(e) => setTitle(e.target.value)}
                                    required
                                />
                            </div>
                            <div className="space-y-2">
                                <label className="text-sm font-medium">Description</label>
                                <Input
                                    placeholder="Short description of the template"
                                    value={description}
                                    onChange={(e) => setDescription(e.target.value)}
                                />
                            </div>
                            <div className="space-y-2">
                                <label className="text-sm font-medium">Category</label>
                                <Input
                                    placeholder="e.g. Civil, Criminal, General"
                                    value={category}
                                    onChange={(e) => setCategory(e.target.value)}
                                />
                            </div>
                            <div className="space-y-2">
                                <label className="text-sm font-medium">PDF Template (Optional)</label>
                                <Input
                                    type="file"
                                    accept=".pdf"
                                    onChange={(e) => setPdfFile(e.target.files?.[0] || null)}
                                />
                            </div>
                            <div className="space-y-2">
                                <label className="text-sm font-medium">Word Template (Optional)</label>
                                <Input
                                    type="file"
                                    accept=".doc,.docx"
                                    onChange={(e) => setDocxFile(e.target.files?.[0] || null)}
                                />
                            </div>
                            <Button type="submit" className="w-full" disabled={uploading}>
                                {uploading ? (
                                    <>
                                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                        Uploading...
                                    </>
                                ) : (
                                    "Upload Template"
                                )}
                            </Button>
                        </form>
                    </DialogContent>
                </Dialog>
            </div>

            {loading ? (
                <div className="flex justify-center py-12">
                    <Loader2 className="h-8 w-8 animate-spin text-primary" />
                </div>
            ) : (
                <div className="border rounded-lg bg-card">
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead>Template Title</TableHead>
                                <TableHead>Category</TableHead>
                                <TableHead>Description</TableHead>
                                <TableHead>Date Added</TableHead>
                                <TableHead className="text-right">Actions</TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {templates.length === 0 ? (
                                <TableRow>
                                    <TableCell colSpan={5} className="h-24 text-center text-muted-foreground">
                                        No templates found. Upload your first legal template!
                                    </TableCell>
                                </TableRow>
                            ) : (
                                templates.map((t) => (
                                    <TableRow key={t.id}>
                                        <TableCell className="font-medium">
                                            <div className="flex items-center gap-2">
                                                <FileText className="h-4 w-4 text-primary" />
                                                {t.title}
                                            </div>
                                        </TableCell>
                                        <TableCell>
                                            <span className="px-2 py-1 rounded-full bg-secondary text-secondary-foreground text-xs font-semibold">
                                                {t.category || "General"}
                                            </span>
                                        </TableCell>
                                        <TableCell className="max-w-xs truncate">{t.description}</TableCell>
                                        <TableCell>{new Date(t.created_at).toLocaleDateString()}</TableCell>
                                        <TableCell className="text-right">
                                            <div className="flex justify-end gap-2">
                                                {t.pdf_url && (
                                                    <Button variant="outline" size="sm" className="gap-2" asChild>
                                                        <a href={t.pdf_url} target="_blank" rel="noopener noreferrer">
                                                            <Download className="h-4 w-4" /> PDF
                                                        </a>
                                                    </Button>
                                                )}
                                                {t.docx_url && (
                                                    <Button variant="outline" size="sm" className="gap-2" asChild>
                                                        <a href={t.docx_url} target="_blank" rel="noopener noreferrer">
                                                            <Download className="h-4 w-4" /> WORD
                                                        </a>
                                                    </Button>
                                                )}
                                                <Button
                                                    variant="ghost"
                                                    size="icon"
                                                    onClick={() => handleDelete(t.id, t.pdf_url, t.docx_url)}
                                                    className="text-destructive hover:text-destructive hover:bg-destructive/10"
                                                >
                                                    <Trash2 className="h-4 w-4" />
                                                </Button>
                                            </div>
                                        </TableCell>
                                    </TableRow>
                                ))
                            )}
                        </TableBody>
                    </Table>
                </div>
            )}
        </div>
    );
}
