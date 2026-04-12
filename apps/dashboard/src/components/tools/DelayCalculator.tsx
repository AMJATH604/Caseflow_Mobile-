import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Clock, Copy, CheckCircle2, AlertCircle } from "lucide-react";
import { addDays, differenceInDays, format, parseISO, isAfter } from "date-fns";
import { toast } from "sonner";

export function DelayCalculator() {
    const [orderDate, setOrderDate] = useState("");
    const [limitationDays, setLimitationDays] = useState("30");
    const [customDays, setCustomDays] = useState("");
    const [filingDate, setFilingDate] = useState(format(new Date(), "yyyy-MM-dd"));
    const [result, setResult] = useState<{
        dueDate: Date;
        delayDays: number;
        isDelayed: boolean;
        text: string;
    } | null>(null);

    const calculateDelay = () => {
        if (!orderDate || !filingDate) return;

        const start = parseISO(orderDate);
        const filing = parseISO(filingDate);
        const days = limitationDays === "custom" ? parseInt(customDays) : parseInt(limitationDays);

        if (isNaN(days)) return;

        // Under Section 12 of Limitation Act, the date of order is usually excluded
        // But for simplicity in counting "days", we add the period to the order date
        const dueDate = addDays(start, days);
        const isDelayed = isAfter(filing, dueDate);
        const delayDays = isDelayed ? differenceInDays(filing, dueDate) : 0;

        const formattedOrder = format(start, "dd.MM.yyyy");
        const formattedDue = format(dueDate, "dd.MM.yyyy");
        const formattedFiling = format(filing, "dd.MM.yyyy");

        let text = "";
        if (isDelayed) {
            text = `The order was passed on ${formattedOrder}. The limitation of ${days} days expired on ${formattedDue}. However, the petition is being filed on ${formattedFiling}. Accordingly, there is a delay of ${delayDays} days in filing the above petition.`;
        } else {
            text = `The order was passed on ${formattedOrder}. The limitation of ${days} days expires on ${formattedDue}. The petition is being filed on ${formattedFiling}, which is within the period of limitation.`;
        }

        setResult({ dueDate, delayDays, isDelayed, text });
    };

    useEffect(() => {
        calculateDelay();
    }, [orderDate, limitationDays, customDays, filingDate]);

    const copyToClipboard = () => {
        if (result) {
            navigator.clipboard.writeText(result.text);
            toast.success("Affidavit text copied to clipboard");
        }
    };

    return (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <Card>
                <CardHeader className="pb-3">
                    <CardTitle className="text-lg flex items-center gap-2 text-primary">
                        <Clock className="h-5 w-5" /> Delay Parameters
                    </CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                    <div className="space-y-2">
                        <Label>Date of Order / Judgment</Label>
                        <Input
                            type="date"
                            value={orderDate}
                            onChange={(e) => setOrderDate(e.target.value)}
                        />
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                        <div className="space-y-2">
                            <Label>Limitation Period</Label>
                            <Select value={limitationDays} onValueChange={setLimitationDays}>
                                <SelectTrigger><SelectValue /></SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="30">30 Days (Local)</SelectItem>
                                    <SelectItem value="60">60 Days</SelectItem>
                                    <SelectItem value="90">90 Days (High Court)</SelectItem>
                                    <SelectItem value="custom">Custom Days</SelectItem>
                                </SelectContent>
                            </Select>
                        </div>
                        {limitationDays === "custom" && (
                            <div className="space-y-2 text-primary animate-in fade-in slide-in-from-left-2">
                                <Label>Enter Days</Label>
                                <Input
                                    type="number"
                                    value={customDays}
                                    onChange={(e) => setCustomDays(e.target.value)}
                                    placeholder="e.g. 120"
                                />
                            </div>
                        )}
                    </div>

                    <div className="space-y-2">
                        <Label>Actual / Proposed Filing Date</Label>
                        <Input
                            type="date"
                            value={filingDate}
                            onChange={(e) => setFilingDate(e.target.value)}
                        />
                    </div>
                </CardContent>
            </Card>

            <Card className={`border-2 ${result?.isDelayed ? 'border-destructive/20 bg-destructive/5' : 'border-primary/20 bg-primary/5'}`}>
                <CardHeader className="pb-3">
                    <CardTitle className="text-lg flex items-center gap-2">
                        {result?.isDelayed ? (
                            <><AlertCircle className="h-5 w-5 text-destructive" /> Delay Detected</>
                        ) : (
                            <><CheckCircle2 className="h-5 w-5 text-primary" /> Within Limitation</>
                        )}
                    </CardTitle>
                </CardHeader>
                <CardContent className="space-y-6">
                    {result ? (
                        <>
                            <div className="grid grid-cols-2 gap-4">
                                <div className="p-3 bg-background rounded-lg border shadow-sm">
                                    <p className="text-[10px] uppercase tracking-wider text-muted-foreground">Due Date</p>
                                    <p className="text-lg font-bold">{format(result.dueDate, "dd MMM yyyy")}</p>
                                </div>
                                <div className={`p-3 rounded-lg border shadow-sm ${result.isDelayed ? 'bg-destructive/10 border-destructive/20' : 'bg-green-500/10 border-green-500/20'}`}>
                                    <p className="text-[10px] uppercase tracking-wider text-muted-foreground">Days of Delay</p>
                                    <p className={`text-lg font-bold ${result.isDelayed ? 'text-destructive' : 'text-green-600'}`}>
                                        {result.delayDays} Days
                                    </p>
                                </div>
                            </div>

                            <div className="space-y-2">
                                <Label className="text-xs uppercase text-muted-foreground">Affidavit Text (Ready to Copy)</Label>
                                <div className="relative group">
                                    <div className="p-4 bg-background border rounded-lg text-sm leading-relaxed italic text-foreground/80 min-h-[100px]">
                                        {result.text}
                                    </div>
                                    <Button
                                        size="sm"
                                        variant="outline"
                                        className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity"
                                        onClick={copyToClipboard}
                                    >
                                        <Copy className="h-3 w-3 mr-2" /> Copy
                                    </Button>
                                </div>
                            </div>
                        </>
                    ) : (
                        <div className="py-12 text-center text-muted-foreground">
                            <Clock className="h-12 w-12 mx-auto mb-4 opacity-10" />
                            <p>Enter dates to see results</p>
                        </div>
                    )}
                </CardContent>
            </Card>
        </div>
    );
}
