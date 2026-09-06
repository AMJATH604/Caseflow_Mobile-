import { useState, useRef } from "react";
import Tesseract from "tesseract.js";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { ScanText, Loader2, Copy, Check } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { Progress } from "@/components/ui/progress";

export function OcrTool() {
    const [loading, setLoading] = useState(false);
    const [progress, setProgress] = useState(0);
    const [text, setText] = useState("");
    const [copied, setCopied] = useState(false);
    const fileInputRef = useRef<HTMLInputElement>(null);
    const { toast } = useToast();

    const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;

        if (!file.type.startsWith("image/")) {
            toast({ title: "Invalid file", description: "Please upload an image file (JPG, PNG).", variant: "destructive" });
            return;
        }

        setLoading(true);
        setProgress(0);
        setText("");

        try {
            const result = await Tesseract.recognize(
                file,
                "eng",
                {
                    logger: (m) => {
                        if (m.status === "recognizing text") {
                            setProgress(parseInt((m.progress * 100).toFixed(0)));
                        }
                    },
                }
            );
            setText(result.data.text);
            toast({ title: "Scan Complete", description: "Text extracted successfully." });
        } catch (error) {
            console.error(error);
            toast({ title: "Scan Failed", description: "Could not extract text from this image.", variant: "destructive" });
        } finally {
            setLoading(false);
        }
    };

    const copyToClipboard = () => {
        navigator.clipboard.writeText(text);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
        toast({ title: "Copied", description: "Text copied to clipboard." });
    };

    return (
        <Card>
            <CardHeader>
                <CardTitle className="flex items-center gap-2">
                    <ScanText className="h-5 w-5 text-purple-600" /> OCR Scanner
                </CardTitle>
                <CardDescription>Upload scanned documents or images to extract text.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
                <div className="flex items-center gap-4">
                    <input
                        type="file"
                        accept="image/*"
                        ref={fileInputRef}
                        className="hidden"
                        onChange={handleFileChange}
                    />
                    <Button onClick={() => fileInputRef.current?.click()} disabled={loading}>
                        {loading ? <Loader2 className="h-4 w-4 mr-2 animate-spin" /> : <ScanText className="h-4 w-4 mr-2" />}
                        Upload Image
                    </Button>
                    {text && (
                        <Button variant="outline" onClick={copyToClipboard}>
                            {copied ? <Check className="h-4 w-4 mr-2 text-green-500" /> : <Copy className="h-4 w-4 mr-2" />}
                            Copy Text
                        </Button>
                    )}
                </div>

                {loading && (
                    <div className="space-y-1">
                        <Progress value={progress} className="h-2" />
                        <p className="text-xs text-muted-foreground text-center">Scanning... {progress}%</p>
                    </div>
                )}

                {text && (
                    <div className="mt-4 p-4 bg-muted rounded-md max-h-64 overflow-y-auto whitespace-pre-wrap text-sm font-mono border border-border">
                        {text}
                    </div>
                )}
            </CardContent>
        </Card>
    );
}
