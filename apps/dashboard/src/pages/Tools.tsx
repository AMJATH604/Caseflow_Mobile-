import { useState } from "react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { WordToPdf } from "@/components/tools/WordToPdf";
import { OcrTool } from "@/components/tools/OcrTool";
import { CourtFeeCalculator } from "@/components/tools/CourtFeeCalculator";
import { InterestCalculator } from "@/components/tools/InterestCalculator";
import { DelayCalculator } from "@/components/tools/DelayCalculator";
import { LimitationCalculator } from "@/components/LimitationCalculator";
import { FileType, ScanText, Calculator, Percent, Clock, Timer, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";

const tools = [
    { id: "word-pdf", title: "Word to PDF", desc: "Convert documents", icon: FileType, color: "bg-blue-500", component: WordToPdf },
    { id: "ocr", title: "OCR Scanner", desc: "Extract text from images", icon: ScanText, color: "bg-emerald-500", component: OcrTool },
    { id: "court-fee", title: "Court Fee", desc: "Calculate court fees", icon: Calculator, color: "bg-amber-500", component: CourtFeeCalculator },
    { id: "interest", title: "Interest", desc: "Calculate interest", icon: Percent, color: "bg-purple-500", component: InterestCalculator },
    { id: "delay", title: "Delay (Sec 5)", desc: "Calculate delay period", icon: Clock, color: "bg-rose-500", component: DelayCalculator },
    { id: "limitation", title: "Limitation", desc: "Limitation deadline", icon: Timer, color: "bg-teal-500", component: LimitationCalculator },
];

export default function Tools() {
    const [activeTool, setActiveTool] = useState<string | null>(null);

    const ActiveComponent = tools.find(t => t.id === activeTool)?.component;

    return (
        <div className="space-y-4">
            {/* Desktop view — tabs with Limitation added */}
            <div className="hidden md:block space-y-6">
                <div>
                    <h1 className="text-2xl font-serif font-bold text-foreground">Document Tools</h1>
                    <p className="text-sm text-muted-foreground mt-1">
                        Utilities for document conversion, text extraction, and legal calculators. All processing happens securely on your device.
                    </p>
                </div>

                <Tabs defaultValue="word-pdf" className="w-full">
                    <TabsList className="grid w-full grid-cols-6 lg:w-[1000px]">
                        <TabsTrigger value="word-pdf" className="flex items-center gap-2">
                            <FileType className="h-4 w-4" /> Word to PDF
                        </TabsTrigger>
                        <TabsTrigger value="ocr" className="flex items-center gap-2">
                            <ScanText className="h-4 w-4" /> OCR Scanner
                        </TabsTrigger>
                        <TabsTrigger value="court-fee" className="flex items-center gap-2">
                            <Calculator className="h-4 w-4" /> Court Fee
                        </TabsTrigger>
                        <TabsTrigger value="interest" className="flex items-center gap-2">
                            <Percent className="h-4 w-4" /> Interest
                        </TabsTrigger>
                        <TabsTrigger value="delay" className="flex items-center gap-2">
                            <Clock className="h-4 w-4" /> Delay (Sec 5)
                        </TabsTrigger>
                        <TabsTrigger value="limitation" className="flex items-center gap-2">
                            <Timer className="h-4 w-4" /> Limitation
                        </TabsTrigger>
                    </TabsList>
                    <div className="mt-6">
                        <TabsContent value="word-pdf"><WordToPdf /></TabsContent>
                        <TabsContent value="ocr"><OcrTool /></TabsContent>
                        <TabsContent value="court-fee"><CourtFeeCalculator /></TabsContent>
                        <TabsContent value="interest"><InterestCalculator /></TabsContent>
                        <TabsContent value="delay"><DelayCalculator /></TabsContent>
                        <TabsContent value="limitation"><LimitationCalculator /></TabsContent>
                    </div>
                </Tabs>
            </div>

            {/* ═══ MOBILE VIEW — Tool Cards Grid ═══ */}
            <div className="md:hidden space-y-4">
                {!activeTool ? (
                    /* Tool Selection Grid */
                    <div className="grid grid-cols-2 gap-3">
                        {tools.map((tool) => (
                            <button
                                key={tool.id}
                                onClick={() => setActiveTool(tool.id)}
                                className="mobile-card flex flex-col items-center text-center gap-3 py-6"
                            >
                                <div className={cn("w-14 h-14 rounded-2xl flex items-center justify-center shadow-sm", tool.color)}>
                                    <tool.icon className="h-6 w-6 text-white" />
                                </div>
                                <div>
                                    <h3 className="text-sm font-bold">{tool.title}</h3>
                                    <p className="text-[11px] text-muted-foreground mt-0.5">{tool.desc}</p>
                                </div>
                            </button>
                        ))}
                    </div>
                ) : (
                    /* Active Tool View */
                    <div className="space-y-4">
                        <button
                            onClick={() => setActiveTool(null)}
                            className="flex items-center gap-2 text-sm font-semibold text-primary active:opacity-70 transition-opacity"
                        >
                            <ChevronRight className="h-4 w-4 rotate-180" />
                            Back to Tools
                        </button>
                        {ActiveComponent && <ActiveComponent />}
                    </div>
                )}
            </div>
        </div>
    );
}
