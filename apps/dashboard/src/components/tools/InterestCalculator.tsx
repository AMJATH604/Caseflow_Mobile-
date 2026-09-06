import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Calculator, Calendar, Copy, IndianRupee, Percent } from "lucide-react";
import { differenceInDays, format, parseISO } from "date-fns";
import { toast } from "sonner";

export function InterestCalculator() {
    const [principal, setPrincipal] = useState("");
    const [rate, setRate] = useState("12");
    const [customRate, setCustomRate] = useState("");
    const [fromDate, setFromDate] = useState("");
    const [toDate, setToDate] = useState("");
    const [interestType, setInterestType] = useState("simple");

    const [result, setResult] = useState<{
        days: number;
        interest: number;
        total: number;
        text: string;
    } | null>(null);

    const calculate = () => {
        if (!principal || !fromDate || !toDate) return;

        const p = parseFloat(principal);
        const r = rate === "custom" ? parseFloat(customRate) : parseFloat(rate);

        if (isNaN(p) || isNaN(r)) return;

        const start = parseISO(fromDate);
        const end = parseISO(toDate);

        const days = differenceInDays(end, start);

        if (days < 0) {
            toast.error("To Date must be after From Date");
            return;
        }

        // Simple Interest Formula: (P * R * T) / 100
        // T is in years. Days / 365 (Legally usually 365 or 366, keeping 365 for standard calculation)
        // Some courts use 30 days per month, but days/365 is more accurate for "Date to Date"

        const timeInYears = days / 365.25; // Accounting for leap years roughly over long periods, or use 365? 
        // Legal standard is often exact days / 365. Let's stick to days logic.

        let interest = 0;

        if (interestType === "simple") {
            interest = (p * r * days) / 36500;
        } else {
            // Compound Interest (Annually)
            // A = P(1 + r/100)^t
            const amount = p * Math.pow((1 + r / 100), timeInYears);
            interest = amount - p;
        }

        const total = p + interest;

        const formattedInterest = Math.round(interest).toLocaleString('en-IN');
        const formattedTotal = Math.round(total).toLocaleString('en-IN');
        const formattedPrincipal = Math.floor(p).toLocaleString('en-IN');

        const resultText = `Interest on ₹${formattedPrincipal}/- from ${format(start, 'dd-MM-yyyy')} to ${format(end, 'dd-MM-yyyy')} (${days} days) at ${r}% p.a. is ₹${formattedInterest}/-. Total amount payable: ₹${formattedTotal}/-`;

        setResult({
            days,
            interest,
            total,
            text: resultText
        });
    };

    const copyToClipboard = () => {
        if (result) {
            navigator.clipboard.writeText(result.text);
            toast.success("Copied to clipboard");
        }
    };

    useEffect(() => {
        calculate();
    }, [principal, rate, customRate, fromDate, toDate, interestType]);

    return (
        <Card className="w-full">
            <CardHeader>
                <CardTitle className="flex items-center gap-2">
                    <Percent className="h-5 w-5" />
                    Legal Interest Calculator
                </CardTitle>
                <CardDescription>
                    Calculate Simple or Compound interest for Money Suits, EPs, and Pronotes.
                </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="space-y-2">
                        <Label htmlFor="principal">Principal Amount (₹)</Label>
                        <div className="relative">
                            <IndianRupee className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
                            <Input
                                id="principal"
                                type="number"
                                placeholder="Ex. 100000"
                                className="pl-8"
                                value={principal}
                                onChange={(e) => setPrincipal(e.target.value)}
                            />
                        </div>
                    </div>

                    <div className="space-y-2">
                        <Label htmlFor="rate">Interest Rate (% p.a.)</Label>
                        <div className="flex gap-2">
                            <Select value={rate} onValueChange={setRate}>
                                <SelectTrigger className="w-[120px]">
                                    <SelectValue />
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="6">6% (Civil)</SelectItem>
                                    <SelectItem value="9">9% (NI Act)</SelectItem>
                                    <SelectItem value="12">12% (Comm)</SelectItem>
                                    <SelectItem value="18">18% (Pvt)</SelectItem>
                                    <SelectItem value="24">24%</SelectItem>
                                    <SelectItem value="custom">Custom</SelectItem>
                                </SelectContent>
                            </Select>
                            {rate === "custom" && (
                                <Input
                                    type="number"
                                    placeholder="Rate"
                                    value={customRate}
                                    onChange={(e) => setCustomRate(e.target.value)}
                                    className="w-full"
                                />
                            )}
                        </div>
                    </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="space-y-2">
                        <Label htmlFor="from">From Date</Label>
                        <div className="relative">
                            <Calendar className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
                            <Input
                                type="date"
                                id="from"
                                className="pl-8"
                                value={fromDate}
                                onChange={(e) => setFromDate(e.target.value)}
                            />
                        </div>
                    </div>
                    <div className="space-y-2">
                        <Label htmlFor="to">To Date</Label>
                        <div className="relative">
                            <Calendar className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
                            <Input
                                type="date"
                                id="to"
                                className="pl-8"
                                value={toDate}
                                onChange={(e) => setToDate(e.target.value)}
                            />
                        </div>
                    </div>
                </div>

                <div className="space-y-2">
                    <Label>Interest Type</Label>
                    <div className="flex items-center gap-4 border p-2 rounded-md bg-muted/20">
                        <Label className="flex items-center gap-2 cursor-pointer font-normal">
                            <input
                                type="radio"
                                name="type"
                                value="simple"
                                checked={interestType === "simple"}
                                onChange={() => setInterestType("simple")}
                                className="accent-primary"
                            />
                            Simple Interest
                        </Label>
                        <Label className="flex items-center gap-2 cursor-pointer font-normal">
                            <input
                                type="radio"
                                name="type"
                                value="compound"
                                checked={interestType === "compound"}
                                onChange={() => setInterestType("compound")}
                                className="accent-primary"
                            />
                            Compound Interest (Annual)
                        </Label>
                    </div>
                </div>

                {result && (
                    <div className="bg-muted p-4 rounded-lg space-y-3 animate-in fade-in zoom-in-95 duration-200">
                        <div className="grid grid-cols-3 gap-2 text-center pb-3 border-b border-muted-foreground/20">
                            <div>
                                <span className="text-xs text-muted-foreground">Days</span>
                                <p className="font-semibold">{result.days}</p>
                            </div>
                            <div>
                                <span className="text-xs text-muted-foreground">Interest</span>
                                <p className="font-semibold text-primary">₹{Math.round(result.interest).toLocaleString('en-IN')}</p>
                            </div>
                            <div>
                                <span className="text-xs text-muted-foreground">Total</span>
                                <p className="font-bold">₹{Math.round(result.total).toLocaleString('en-IN')}</p>
                            </div>
                        </div>

                        <div className="relative pt-1">
                            <Label className="text-xs text-muted-foreground">Plaint Text (Copy-paste)</Label>
                            <div className="flex gap-2 mt-1">
                                <p className="text-sm font-mono bg-background p-2 rounded border w-full flex-1">
                                    {result.text}
                                </p>
                                <Button size="icon" variant="outline" onClick={copyToClipboard} title="Copy to Clipboard">
                                    <Copy className="h-4 w-4" />
                                </Button>
                            </div>
                        </div>
                    </div>
                )}
            </CardContent>
        </Card>
    );
}
