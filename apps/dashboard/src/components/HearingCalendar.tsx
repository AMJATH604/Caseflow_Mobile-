import { useState } from "react";
import { Calendar } from "@/components/ui/calendar";
import { format, isSameDay, parseISO } from "date-fns";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { useNavigate } from "react-router-dom";

export function HearingCalendar({ hearings }: { hearings: any[] }) {
    const [selectedDate, setSelectedDate] = useState<Date | undefined>(new Date());
    const navigate = useNavigate();

    // Days that have hearings
    const hearingDays = hearings.map(h => parseISO(h.hearing_date));

    const selectedHearings = hearings.filter(h =>
        selectedDate && isSameDay(parseISO(h.hearing_date), selectedDate)
    );

    return (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
            <Card className="md:col-span-1 h-fit shadow-md border-primary/10">
                <CardContent className="pt-6 flex justify-center">
                    <Calendar
                        mode="single"
                        selected={selectedDate}
                        onSelect={setSelectedDate}
                        modifiers={{
                            hasHearing: hearingDays,
                        }}
                        modifiersClassNames={{
                            hasHearing: "relative after:absolute after:bottom-1 after:left-1/2 after:-translate-x-1/2 after:w-1 after:h-1 after:bg-primary after:rounded-full font-bold text-primary",
                        }}
                        className="rounded-md border-none"
                    />
                </CardContent>
            </Card>

            <Card className="md:col-span-2 shadow-md border-primary/10">
                <CardHeader className="border-b border-primary/5 pb-4">
                    <CardTitle className="text-lg font-serif">
                        Hearings on {selectedDate ? format(selectedDate, "dd MMMM yyyy") : "Selected Date"}
                    </CardTitle>
                </CardHeader>
                <CardContent className="pt-6">
                    {selectedHearings.length === 0 ? (
                        <div className="flex flex-col items-center justify-center py-12 text-center space-y-3">
                            <div className="w-12 h-12 rounded-full bg-muted flex items-center justify-center">
                                <GavelIcon className="h-6 w-6 text-muted-foreground opacity-20" />
                            </div>
                            <p className="text-sm text-muted-foreground">No hearings scheduled for this day.</p>
                        </div>
                    ) : (
                        <div className="overflow-x-auto">
                            <Table>
                                <TableHeader>
                                    <TableRow className="hover:bg-transparent">
                                        <TableHead>Case Detail</TableHead>
                                        <TableHead>Stage</TableHead>
                                        <TableHead>Action Required</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {selectedHearings.map((h: any) => (
                                        <TableRow
                                            key={h.id}
                                            className="cursor-pointer hover:bg-muted/50 group transition-colors"
                                            onClick={() => navigate(`/cases/${h.case_id}`)}
                                        >
                                            <TableCell className="font-medium">
                                                <div className="flex flex-col">
                                                    <span className="group-hover:text-primary transition-colors truncate max-w-[200px]">{h.cases?.case_title}</span>
                                                    <span className="text-xs text-muted-foreground underline">{h.cases?.case_number}</span>
                                                </div>
                                            </TableCell>
                                            <TableCell>
                                                <Badge variant="secondary" className="font-normal capitalize">{h.stage || "N/A"}</Badge>
                                            </TableCell>
                                            <TableCell className="text-sm text-muted-foreground group-hover:text-foreground italic">
                                                {h.next_action || "No specific action recorded"}
                                            </TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                        </div>
                    )}
                </CardContent>
            </Card>
        </div>
    );
}

function GavelIcon({ className }: { className?: string }) {
    return (
        <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            className={className}
        >
            <path d="m14 13-5-5" />
            <path d="m3 21 3-3" />
            <path d="m9 15 10-10c.5-.5 3 .5 3 3.5s-4 2.5-4.5 3L11 18c-.5.5-2.5 5-5.5 5S3 20.5 3.5 20s4.5-5 5-5Z" />
        </svg>
    );
}
