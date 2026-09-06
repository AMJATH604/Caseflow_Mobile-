import { useState, useEffect } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Calculator, IndianRupee } from "lucide-react";

export function CourtFeeCalculator() {
    const [category, setCategory] = useState("money_suit");
    const [value, setValue] = useState("");
    const [courtType, setCourtType] = useState("sub_court");
    const [fee2017, setFee2017] = useState<number | null>(null);
    const [fee1955, setFee1955] = useState<number | null>(null);

    const calculateFee = () => {
        const amount = parseFloat(value);
        let calculatedFee2017 = 0;
        let calculatedFee1955 = 0;

        switch (category) {
            case "money_suit":
            case "immovable_property":
            case "appeal":
                // 2017: 3% ad valorem
                if (!isNaN(amount)) {
                    calculatedFee2017 = amount * 0.03;
                    // 1955 (Pre-2017): Approx 1% (based on market notes of 1% to 3% hike)
                    // Note: This is an approximation of the old ad valorem scale for comparison
                    calculatedFee1955 = amount * 0.01;
                }
                break;
            case "partition":
                // 2017 Rates
                if (courtType === "high_court") {
                    calculatedFee2017 = 10000;
                    calculatedFee1955 = 1000; // Old High Court
                } else {
                    calculatedFee2017 = 5000;
                    // Old Sub Court / District Court tiered rates (Sec 37(2))
                    // < 30k: 100, 30k-1L: 500, > 1L: 750 (Taking max 750 for simplicity in this general view or 200 for munsif)
                    // Let's use the Sub-Court max slab for better comparison
                    calculatedFee1955 = 750;
                }
                break;
            case "probate":
                // 2017: 3% max 25k
                if (!isNaN(amount)) {
                    calculatedFee2017 = Math.min(amount * 0.03, 25000);
                    // 1955: 3% (Article 6) - often similar percentage but different caps or slabs. 
                    // Keeping standard 3% without new cap for comparison or similar
                    calculatedFee2017 = Math.min(amount * 0.03, 25000); // 2017
                    // Old rate widely cited as similar percentage but let's assume valid comparison is the cap
                    calculatedFee1955 = amount * 0.03; // Old often had no cap or different slab
                }
                break;
            case "writ":
                calculatedFee2017 = 1000;
                calculatedFee1955 = 200; // Common old rate for writs
                break;
            case "application":
                calculatedFee2017 = 20;
                calculatedFee1955 = 2; // Old rate was Re. 2
                break;

            default:
                calculatedFee2017 = 0;
                calculatedFee1955 = 0;
        }

        // Rounding off to nearest rupee as per Section 21-A (2017)
        setFee2017(Math.round(calculatedFee2017));
        setFee1955(Math.round(calculatedFee1955));
    };

    useEffect(() => {
        calculateFee();
    }, [category, value, courtType]);

    return (
        <Card className="w-full">
            <CardHeader>
                <CardTitle className="flex items-center gap-2">
                    <Calculator className="h-5 w-5" />
                    Court Fee Calculator
                </CardTitle>
                <CardDescription>
                    Compare fees between the 1955 Act (Old) and 2017 Amendment (New).
                </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
                <div className="space-y-2">
                    <Label htmlFor="category">Case Category</Label>
                    <Select value={category} onValueChange={setCategory}>
                        <SelectTrigger>
                            <SelectValue placeholder="Select category" />
                        </SelectTrigger>
                        <SelectContent>
                            <SelectItem value="money_suit">Money Suit (Recovery of Money)</SelectItem>
                            <SelectItem value="immovable_property">Immovable Property Dispute</SelectItem>
                            <SelectItem value="partition">Partition Suit</SelectItem>
                            <SelectItem value="probate">Probate / Letters of Administration</SelectItem>
                            <SelectItem value="appeal">Appeal</SelectItem>
                            <SelectItem value="writ">Writ Petition</SelectItem>
                            <SelectItem value="application">Interim Application</SelectItem>
                        </SelectContent>
                    </Select>
                </div>

                {(category === "money_suit" || category === "immovable_property" || category === "probate" || category === "appeal") && (
                    <div className="space-y-2">
                        <Label htmlFor="value">Subject Matter Value / Claim Amount (₹)</Label>
                        <div className="relative">
                            <IndianRupee className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
                            <Input
                                id="value"
                                type="number"
                                placeholder="Enter amount"
                                className="pl-8"
                                value={value}
                                onChange={(e) => setValue(e.target.value)}
                            />
                        </div>
                    </div>
                )}

                {category === "partition" && (
                    <div className="space-y-2">
                        <Label htmlFor="court-type">Court Type</Label>
                        <Select value={courtType} onValueChange={setCourtType}>
                            <SelectTrigger>
                                <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                                <SelectItem value="high_court">High Court (Original Side)</SelectItem>
                                <SelectItem value="sub_court">District / Subordinate Courts</SelectItem>
                            </SelectContent>
                        </Select>
                    </div>
                )}

                <div className="grid grid-cols-2 gap-4 pt-4">
                    <div className="rounded-lg bg-muted/30 p-4 flex flex-col items-center justify-center text-center border border-dashed">
                        <span className="text-xs text-muted-foreground uppercase tracking-wider">Old Fee (1955 Act)</span>
                        <div className="text-2xl font-bold text-muted-foreground mt-1 flex items-center">
                            <IndianRupee className="h-5 w-5" />
                            {fee1955 !== null ? fee1955.toLocaleString('en-IN') : "0"}
                        </div>
                        <p className="text-[10px] text-muted-foreground mt-1">
                            (Approx. Pre-2017 rates)
                        </p>
                    </div>

                    <div className="rounded-lg bg-primary/10 p-4 flex flex-col items-center justify-center text-center border border-primary/20">
                        <span className="text-xs text-primary uppercase tracking-wider font-semibold">New Fee (2017 Act)</span>
                        <div className="text-2xl font-bold text-primary mt-1 flex items-center">
                            <IndianRupee className="h-5 w-5" />
                            {fee2017 !== null ? fee2017.toLocaleString('en-IN') : "0"}
                        </div>
                        <p className="text-[10px] text-primary/80 mt-1">
                            (As per 2017 Amendment)
                        </p>
                    </div>
                </div>
            </CardContent>
        </Card>
    );
}
