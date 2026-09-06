import { useState } from "react";
import { useRealtimeQuery } from "@/hooks/useRealtimeQuery";
import { fetchTasks, createTask, updateTask, deleteTask } from "@/lib/supabase-helpers";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Checkbox } from "@/components/ui/checkbox";
import { ClipboardList, Plus, Trash2 } from "lucide-react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";

export function TaskWidget() {
    const { data: tasks = [], isLoading } = useRealtimeQuery({ queryKey: ["tasks"], queryFn: () => fetchTasks(), table: "tasks" });
    const [newTask, setNewTask] = useState("");
    const qc = useQueryClient();
    const { toast } = useToast();

    const createMutation = useMutation({
        mutationFn: (title: string) => createTask(title),
        onSuccess: () => {
            qc.invalidateQueries({ queryKey: ["tasks"] });
            setNewTask("");
        },
        onError: (err: any) => toast({ title: "Error", description: err.message, variant: "destructive" })
    });

    const updateMutation = useMutation({
        mutationFn: ({ id, is_completed }: { id: string; is_completed: boolean }) => updateTask(id, { is_completed }),
        onSuccess: () => qc.invalidateQueries({ queryKey: ["tasks"] }),
    });

    const deleteMutation = useMutation({
        mutationFn: (id: string) => deleteTask(id),
        onSuccess: () => qc.invalidateQueries({ queryKey: ["tasks"] }),
    });

    const handleAdd = (e: React.FormEvent) => {
        e.preventDefault();
        if (!newTask.trim()) return;
        createMutation.mutate(newTask);
    };

    return (
        <Card className="h-full flex flex-col">
            <CardHeader className="pb-3">
                <CardTitle className="text-lg flex items-center gap-2">
                    <ClipboardList className="h-5 w-5" /> Daily Tasks
                </CardTitle>
            </CardHeader>
            <CardContent className="flex-1 overflow-hidden flex flex-col gap-4">
                <form onSubmit={handleAdd} className="flex gap-2">
                    <Input
                        placeholder="Add a new task..."
                        value={newTask}
                        onChange={(e) => setNewTask(e.target.value)}
                        disabled={createMutation.isPending}
                    />
                    <Button type="submit" size="icon" disabled={createMutation.isPending}>
                        <Plus className="h-4 w-4" />
                    </Button>
                </form>
                <div className="flex-1 overflow-y-auto space-y-2 pr-1">
                    {isLoading ? (
                        <p className="text-sm text-muted-foreground text-center py-4">Loading tasks...</p>
                    ) : tasks.length === 0 ? (
                        <p className="text-sm text-muted-foreground text-center py-4">No tasks yet. Add one above!</p>
                    ) : (
                        tasks.map((task: any) => (
                            <div key={task.id} className="flex items-center gap-3 group p-2 rounded-md hover:bg-muted/50 transition-colors">
                                <Checkbox
                                    checked={task.is_completed}
                                    onCheckedChange={(checked) => updateMutation.mutate({ id: task.id, is_completed: checked as boolean })}
                                />
                                <span className={`flex-1 text-sm ${task.is_completed ? "line-through text-muted-foreground" : "text-foreground"}`}>
                                    {task.title}
                                </span>
                                <Button
                                    variant="ghost"
                                    size="icon"
                                    className="h-6 w-6 opacity-0 group-hover:opacity-100 transition-opacity text-muted-foreground hover:text-destructive"
                                    onClick={() => deleteMutation.mutate(task.id)}
                                >
                                    <Trash2 className="h-3 w-3" />
                                </Button>
                            </div>
                        ))
                    )}
                </div>
            </CardContent>
        </Card>
    );
}
