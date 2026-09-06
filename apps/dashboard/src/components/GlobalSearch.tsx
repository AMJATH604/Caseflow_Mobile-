import { useState, useEffect } from "react";
import { CommandDialog, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from "@/components/ui/command";
import { Search, Briefcase, Users, FileText } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { searchAll } from "@/lib/supabase-helpers";
import { Button } from "@/components/ui/button";

export function GlobalSearch() {
    const [open, setOpen] = useState(false);
    const [query, setQuery] = useState("");
    const [results, setResults] = useState<{ cases: any[], clients: any[], documents: any[] }>({ cases: [], clients: [], documents: [] });
    const navigate = useNavigate();

    useEffect(() => {
        const down = (e: KeyboardEvent) => {
            if (e.key === "k" && (e.metaKey || e.ctrlKey)) {
                e.preventDefault();
                setOpen((open) => !open);
            }
        };
        document.addEventListener("keydown", down);
        return () => document.removeEventListener("keydown", down);
    }, []);

    useEffect(() => {
        if (query.length > 2) {
            searchAll(query).then(setResults);
        } else {
            setResults({ cases: [], clients: [], documents: [] });
        }
    }, [query]);

    const runCommand = (command: () => void) => {
        setOpen(false);
        command();
    };

    return (
        <>
            <Button
                variant="ghost"
                className="w-9 h-9 md:w-[200px] lg:w-[300px] justify-center md:justify-start text-[#4252B2] md:text-muted-foreground p-0 md:px-4 md:py-2 hover:bg-white/20 transition-colors"
                onClick={() => setOpen(true)}
            >
                <Search className="h-4 w-4" />
                <span className="hidden md:inline-flex ml-2">Search...</span>
                <kbd className="pointer-events-none hidden md:inline-flex h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium text-muted-foreground ml-auto opacity-100">
                    <span className="text-xs">Ctrl</span>K
                </kbd>
            </Button>
            <CommandDialog open={open} onOpenChange={setOpen}>
                <CommandInput placeholder="Type to search cases, clients, documents..." value={query} onValueChange={setQuery} />
                <CommandList>
                    <CommandEmpty>No results found.</CommandEmpty>
                    {query.length > 2 && (
                        <>
                            {results.cases.length > 0 && (
                                <CommandGroup heading="Cases">
                                    {results.cases.map((c) => (
                                        <CommandItem key={c.id} onSelect={() => runCommand(() => navigate(`/cases/${c.id}`))}>
                                            <Briefcase className="mr-2 h-4 w-4" />
                                            {c.case_title} ({c.case_number})
                                        </CommandItem>
                                    ))}
                                </CommandGroup>
                            )}
                            {results.clients.length > 0 && (
                                <CommandGroup heading="Clients">
                                    {results.clients.map((c) => (
                                        <CommandItem key={c.id} onSelect={() => runCommand(() => navigate(`/clients`))}>
                                            <Users className="mr-2 h-4 w-4" />
                                            {c.name}
                                        </CommandItem>
                                    ))}
                                </CommandGroup>
                            )}
                            {results.documents.length > 0 && (
                                <CommandGroup heading="Documents">
                                    {results.documents.map((d) => (
                                        <CommandItem key={d.id} onSelect={() => runCommand(() => navigate(`/cases/${d.case_id}`))}>
                                            <FileText className="mr-2 h-4 w-4" />
                                            {d.document_type} - {(d.cases as any)?.case_title}
                                        </CommandItem>
                                    ))}
                                </CommandGroup>
                            )}
                        </>
                    )}
                </CommandList>
            </CommandDialog>
        </>
    );
}
