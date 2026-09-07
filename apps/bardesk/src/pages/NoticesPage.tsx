import { useState } from "react";
import { toast } from "sonner";
import { Plus, Pin, Trash2, Send, Megaphone, BellRing } from "lucide-react";

import {
  useNotices,
  useCreateNotice,
  useDeleteNotice,
  useCurrentAdmin,
} from "@/hooks/useBarDesk";
import { formatDateTime, cn } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { EmptyState, ErrorState } from "@/components/states";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Switch } from "@/components/ui/switch";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

/**
 * Category styling from tokens.
 *
 * getCategoryColor() in lib/utils returns raw hex, which cannot respond to
 * the theme — a #6366F1 dot stays the same on a dark ground.
 */
const CATEGORIES = [
  { value: "general", label: "General", bar: "bg-chart-1", chip: "bg-chart-1/10 text-chart-1" },
  { value: "urgent", label: "Urgent", bar: "bg-destructive", chip: "bg-destructive/10 text-destructive" },
  { value: "election", label: "Election", bar: "bg-chart-4", chip: "bg-chart-4/10 text-chart-4" },
  { value: "event", label: "Event", bar: "bg-info", chip: "bg-info/10 text-info" },
  { value: "holiday", label: "Holiday", bar: "bg-warning", chip: "bg-warning/10 text-warning" },
] as const;

const categoryStyle = (value: string) =>
  CATEGORIES.find((c) => c.value === value) ?? CATEGORIES[0];

const EMPTY_FORM = { title: "", body: "", category: "general", is_pinned: false };

export default function NoticesPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id || "";
  const { data: notices, isLoading, error, refetch } = useNotices(associationId);
  const createNotice = useCreateNotice(associationId);
  const deleteNotice = useDeleteNotice();

  const [showCompose, setShowCompose] = useState(false);
  const [form, setForm] = useState(EMPTY_FORM);
  const [pendingDelete, setPendingDelete] = useState<{ id: string; title: string } | null>(null);

  const handlePublish = async () => {
    try {
      await createNotice.mutateAsync({
        ...form,
        published_at: new Date().toISOString(),
      } as any);
      toast.success("Notice published", {
        description: "Members will see it in CaseFlow.",
      });
      setShowCompose(false);
      setForm(EMPTY_FORM);
    } catch (err) {
      toast.error("Could not publish notice", {
        description: err instanceof Error ? err.message : "Please try again.",
      });
    }
  };

  const handleDelete = async () => {
    if (!pendingDelete) return;
    try {
      await deleteNotice.mutateAsync(pendingDelete.id);
      toast.success("Notice deleted");
      setPendingDelete(null);
    } catch (err) {
      toast.error("Could not delete notice", {
        description: err instanceof Error ? err.message : "Please try again.",
      });
      throw err;
    }
  };

  const list = notices || [];
  const canPublish = form.title.trim() && form.body.trim() && !createNotice.isPending;

  return (
    <div className="max-w-5xl">
      <PageHeader
        title="Notices"
        description={
          list.length === 1 ? "1 notice published" : `${list.length} notices published`
        }
        actions={
          <Button className="gap-2" onClick={() => setShowCompose(true)}>
            <Plus className="h-4 w-4" />
            New notice
          </Button>
        }
      />

      {error ? (
        <ErrorState error={error} onRetry={() => void refetch()} />
      ) : isLoading ? (
        <div className="space-y-3">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-32 rounded-xl" />
          ))}
        </div>
      ) : list.length === 0 ? (
        <EmptyState
          icon={Megaphone}
          title="No notices yet"
          description="Publish an announcement and every member of your association sees it in CaseFlow."
          action={
            <Button className="gap-2" onClick={() => setShowCompose(true)}>
              <Plus className="h-4 w-4" />
              Publish the first notice
            </Button>
          }
        />
      ) : (
        <div className="space-y-3">
          {list.map((notice) => {
            const style = categoryStyle(notice.category);
            return (
              <article
                key={notice.id}
                className="group flex gap-4 rounded-xl border border-border bg-card p-5 shadow-xs transition-shadow hover:shadow-sm"
              >
                <span
                  className={cn("w-1 shrink-0 rounded-full", style.bar)}
                  aria-hidden
                />

                <div className="min-w-0 flex-1">
                  <div className="mb-2 flex flex-wrap items-center gap-2">
                    {notice.is_pinned && (
                      <span className="inline-flex items-center gap-1 rounded-full bg-accent/10 px-2 py-0.5 text-2xs font-semibold text-accent">
                        <Pin className="h-3 w-3" />
                        Pinned
                      </span>
                    )}
                    <span
                      className={cn(
                        "rounded-full px-2 py-0.5 text-2xs font-semibold capitalize",
                        style.chip,
                      )}
                    >
                      {notice.category}
                    </span>
                  </div>

                  <h3 className="font-display text-md font-semibold text-foreground">
                    {notice.title}
                  </h3>
                  <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">
                    {notice.body}
                  </p>

                  <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-muted-foreground">
                    <span>{formatDateTime(notice.published_at)}</span>
                    <span aria-hidden>·</span>
                    <span data-numeric>{notice.read_count} read</span>
                    {notice.fcm_sent && (
                      <>
                        <span aria-hidden>·</span>
                        <span className="inline-flex items-center gap-1 text-success">
                          <BellRing className="h-3 w-3" />
                          Push sent
                        </span>
                      </>
                    )}
                  </div>
                </div>

                <Button
                  variant="ghost"
                  size="icon"
                  className={cn(
                    "h-8 w-8 shrink-0 text-muted-foreground hover:text-destructive",
                    // Always reachable on touch, where hover does not exist.
                    "md:opacity-0 md:group-hover:opacity-100 md:focus-visible:opacity-100",
                  )}
                  onClick={() => setPendingDelete({ id: notice.id, title: notice.title })}
                  aria-label={`Delete notice: ${notice.title}`}
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              </article>
            );
          })}
        </div>
      )}

      {/* ── Compose ──────────────────────────────────────────── */}
      <Dialog open={showCompose} onOpenChange={setShowCompose}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle className="font-display">Publish notice</DialogTitle>
          </DialogHeader>

          <div className="space-y-4 py-2">
            <div className="space-y-1.5">
              <Label htmlFor="notice-title">
                Title <span className="text-destructive">*</span>
              </Label>
              <Input
                id="notice-title"
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                placeholder="Court holiday on 2 October"
              />
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="notice-body">
                Content <span className="text-destructive">*</span>
              </Label>
              <Textarea
                id="notice-body"
                rows={5}
                value={form.body}
                onChange={(e) => setForm({ ...form, body: e.target.value })}
                placeholder="Write the announcement…"
                className="resize-none"
              />
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div className="space-y-1.5">
                <Label htmlFor="notice-category">Category</Label>
                <Select
                  value={form.category}
                  onValueChange={(v) => setForm({ ...form, category: v })}
                >
                  <SelectTrigger id="notice-category">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {CATEGORIES.map((c) => (
                      <SelectItem key={c.value} value={c.value}>
                        {c.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="flex items-center justify-between rounded-lg border border-border px-3 sm:mt-6">
                <Label htmlFor="notice-pin" className="cursor-pointer">
                  Pin to top
                </Label>
                <Switch
                  id="notice-pin"
                  checked={form.is_pinned}
                  onCheckedChange={(v) => setForm({ ...form, is_pinned: v })}
                />
              </div>
            </div>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setShowCompose(false)}>
              Cancel
            </Button>
            <Button className="gap-2" onClick={() => void handlePublish()} disabled={!canPublish}>
              <Send className="h-4 w-4" />
              {createNotice.isPending ? "Publishing…" : "Publish"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={pendingDelete !== null}
        onOpenChange={(open) => !open && setPendingDelete(null)}
        title="Delete this notice?"
        description={
          <>
            <span className="font-medium text-foreground">{pendingDelete?.title}</span>{" "}
            will be removed for every member. This cannot be undone.
          </>
        }
        onConfirm={handleDelete}
      />
    </div>
  );
}
