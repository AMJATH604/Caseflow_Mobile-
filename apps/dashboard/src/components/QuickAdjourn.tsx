import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { CalendarDays, Forward } from "lucide-react";
import { adjournHearing } from "@/lib/supabase-helpers";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";

interface QuickAdjournProps {
    hearing: any;
    onSuccess?: () => void;
}

export function QuickAdjourn({ hearing, onSuccess }: QuickAdjournProps) {
    const [open, setOpen] = useState(false);
    const [notes, setNotes] = useState(hearing.notes || "");
    const [nextDate, setNextDate] = useState("");
    const [nextStage, setNextStage] = useState(hearing.stage || "");
    const { toast } = useToast();
    const qc = useQueryClient();

    const mutation = useMutation({
        mutationFn: (data: any) => adjournHearing(hearing.id, data),
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: ["hearings-all"] });
            qc.invalidateQueries({ queryKey: ["cases-list"] });
            setOpen(false);
            toast({ title: "Case Adjourned", description: "Updated diary successfully." });
            if (onSuccess) onSuccess();
        },
        onError: (err: any) => {
            toast({ title: "Error", description: err.message, variant: "destructive" });
        }
    });

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        if (!nextDate) {
            toast({ title: "Error", description: "Please select a next hearing date.", variant: "destructive" });
            return;
        }
        mutation.mutate({
            current_notes: notes,
            next_date: nextDate,
            next_stage: nextStage,
            case_id: hearing.case_id
        });
    };

    return (
        <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
                <Button variant="outline" size="sm" className="flex items-center gap-2 text-primary border-primary/20 hover:bg-primary/5">
                    <Forward className="h-4 w-4" /> Adjourn
                </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[425px]">
                <DialogHeader>
                    <DialogTitle>Quick Adjourn</DialogTitle>
                    <DialogDescription>
                        Record what happened today and set the next date.
                    </DialogDescription>
                </DialogHeader>
                <form onSubmit={handleSubmit} className="space-y-4 pt-4">
                    <div className="space-y-2">
                        <Label>Notes for Today (Optional)</Label>
                        <Textarea
                            placeholder="e.g., Petitioner absent, cost ₹500 imposed..."
                            value={notes}
                            onChange={(e) => setNotes(e.target.value)}
                            className="min-h-[80px]"
                        />
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                        <div className="space-y-2">
                            <Label>Next Hearing Date</Label>
                            <div className="relative">
                                <CalendarDays className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
                                <Input
                                    type="date"
                                    className="pl-8"
                                    value={nextDate}
                                    onChange={(e) => setNextDate(e.target.value)}
                                    required
                                />
                            </div>
                        </div>
                        <div className="space-y-2">
                            <Label>Next Stage</Label>
                            <Input
                                placeholder="e.g., Evidence"
                                value={nextStage}
                                onChange={(e) => setNextStage(e.target.value)}
                            />
                        </div>
                    </div>

                    <DialogFooter className="pt-4">
                        <Button type="submit" className="w-full" disabled={mutation.isPending}>
                            {mutation.isPending ? "Updating..." : "Update Diary"}
                        </Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    );
}
