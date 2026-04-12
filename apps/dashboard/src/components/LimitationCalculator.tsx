import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Calculator } from "lucide-react";
import { addDays, addMonths, addYears, format } from "date-fns";
import { Label } from "@/components/ui/label";

export function LimitationCalculator() {
    const [date, setDate] = useState("");
    const [period, setPeriod] = useState("");
    const [unit, setUnit] = useState("days");
    const [result, setResult] = useState<string | null>(null);

    const calculate = () => {
        if (!date || !period) return;
        const startDate = new Date(date);
        const amount = parseInt(period);
        let endDate;
        if (unit === "days") endDate = addDays(startDate, amount);
        else if (unit === "months") endDate = addMonths(startDate, amount);
        else endDate = addYears(startDate, amount);
        setResult(format(endDate, "dd MMM yyyy"));
    };

    return (
        <Card className="h-full">
            <CardHeader className="pb-3">
                <CardTitle className="text-lg flex items-center gap-2">
                    <Calculator className="h-5 w-5" /> Limitation Calculator
                </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
                <div className="space-y-2">
                    <Label>Event Date (Judgment/Order)</Label>
                    <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
                </div>
                <div className="flex gap-2">
                    <div className="space-y-2 flex-1">
                        <Label>Period</Label>
                        <Input type="number" value={period} onChange={(e) => setPeriod(e.target.value)} placeholder="90" />
                    </div>
                    <div className="space-y-2 w-32">
                        <Label>Unit</Label>
                        <Select value={unit} onValueChange={setUnit}>
                            <SelectTrigger><SelectValue /></SelectTrigger>
                            <SelectContent>
                                <SelectItem value="days">Days</SelectItem>
                                <SelectItem value="months">Months</SelectItem>
                                <SelectItem value="years">Years</SelectItem>
                            </SelectContent>
                        </Select>
                    </div>
                </div>
                <Button onClick={calculate} className="w-full">Calculate Deadline</Button>
                {result && (
                    <div className="mt-4 p-3 bg-muted rounded-md text-center animate-fade-in">
                        <p className="text-xs text-muted-foreground">Deadline Date</p>
                        <p className="text-xl font-bold text-foreground">{result}</p>
                    </div>
                )}
            </CardContent>
        </Card>
    );
}
