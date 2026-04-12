import { useState, useRef } from "react";
import mammoth from "mammoth";
import { jsPDF } from "jspdf";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { FileUp, FileDown, Loader2, FileType } from "lucide-react";
import { useToast } from "@/hooks/use-toast";

export function WordToPdf() {
    const [loading, setLoading] = useState(false);
    const [convertedText, setConvertedText] = useState("");
    const fileInputRef = useRef<HTMLInputElement>(null);
    const { toast } = useToast();

    const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;

        if (!file.name.endsWith(".docx")) {
            toast({ title: "Invalid file", description: "Please upload a .docx file", variant: "destructive" });
            return;
        }

        setLoading(true);
        try {
            const arrayBuffer = await file.arrayBuffer();
            const result = await mammoth.extractRawText({ arrayBuffer });
            setConvertedText(result.value);
            toast({ title: "Conversion successful", description: "Review the text and download as PDF." });
        } catch (error) {
            console.error(error);
            toast({ title: "Error", description: "Failed to read Word document.", variant: "destructive" });
        } finally {
            setLoading(false);
        }
    };

    const downloadPdf = () => {
        if (!convertedText) return;
        const doc = new jsPDF();
        const splitText = doc.splitTextToSize(convertedText, 180);
        doc.text(splitText, 15, 15);
        doc.save("converted_document.pdf");
        toast({ title: "Downloaded", description: "PDF has been saved to your device." });
    };

    return (
        <Card>
            <CardHeader>
                <CardTitle className="flex items-center gap-2">
                    <FileType className="h-5 w-5 text-blue-600" /> Word to PDF Converter
                </CardTitle>
                <CardDescription>Convert .docx files to PDF instantly in your browser.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
                <div className="flex items-center gap-4">
                    <input
                        type="file"
                        accept=".docx"
                        ref={fileInputRef}
                        className="hidden"
                        onChange={handleFileChange}
                    />
                    <Button onClick={() => fileInputRef.current?.click()} disabled={loading}>
                        {loading ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : <FileUp className="h-4 w-4 mr-2" />}
                        Select Word File
                    </Button>
                    {convertedText && (
                        <Button variant="outline" onClick={downloadPdf}>
                            <FileDown className="h-4 w-4 mr-2" /> Download PDF
                        </Button>
                    )}
                </div>

                {convertedText && (
                    <div className="mt-4 p-4 bg-muted rounded-md max-h-64 overflow-y-auto whitespace-pre-wrap text-sm font-mono">
                        {convertedText}
                    </div>
                )}
            </CardContent>
        </Card>
    );
}
