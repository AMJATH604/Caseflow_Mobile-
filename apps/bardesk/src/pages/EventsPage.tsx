import { useState } from "react";
import { toast } from "sonner";
import { Plus, MapPin, Clock, CalendarDays, Trash2 } from "lucide-react";

import {
  useEvents,
  useCreateEvent,
  useDeleteEvent,
  useCurrentAdmin,
} from "@/hooks/useBarDesk";
import { cn } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { EmptyState, ErrorState } from "@/components/states";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
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

/** Token-based category styling, so it follows the theme. */
const CATEGORIES = [
  { value: "meeting", label: "Meeting", text: "text-chart-1", chip: "bg-chart-1/10 text-chart-1" },
  { value: "holiday", label: "Holiday", text: "text-warning", chip: "bg-warning/10 text-warning" },
  { value: "lecture", label: "Lecture", text: "text-success", chip: "bg-success/10 text-success" },
  { value: "sports", label: "Sports", text: "text-info", chip: "bg-info/10 text-info" },
  { value: "annual", label: "Annual", text: "text-chart-4", chip: "bg-chart-4/10 text-chart-4" },
] as const;

const categoryStyle = (value: string) =>
  CATEGORIES.find((c) => c.value === value) ?? CATEGORIES[0];

const EMPTY_FORM = {
  title: "",
  description: "",
  event_date: "",
  start_time: "",
  end_time: "",
  location: "",
  agenda: "",
  category: "meeting",
};

export default function EventsPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id || "";
  const { data: events, isLoading, error, refetch } = useEvents(associationId);
  const createEvent = useCreateEvent(associationId);
  const deleteEvent = useDeleteEvent();

  const [showCreate, setShowCreate] = useState(false);
  const [form, setForm] = useState(EMPTY_FORM);
  const [pendingDelete, setPendingDelete] = useState<{ id: string; title: string } | null>(null);

  const handleCreate = async () => {
    try {
      await createEvent.mutateAsync(form as any);
      toast.success("Event scheduled");
      setShowCreate(false);
      setForm(EMPTY_FORM);
    } catch (err) {
      toast.error("Could not create event", {
        description: err instanceof Error ? err.message : "Please try again.",
      });
    }
  };

  const handleDelete = async () => {
    if (!pendingDelete) return;
    try {
      await deleteEvent.mutateAsync(pendingDelete.id);
      toast.success("Event deleted");
      setPendingDelete(null);
    } catch (err) {
      toast.error("Could not delete event", {
        description: err instanceof Error ? err.message : "Please try again.",
      });
      throw err;
    }
  };

  const all = events || [];
  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const upcoming = all.filter((e) => new Date(e.event_date) >= startOfToday);
  const past = all.filter((e) => new Date(e.event_date) < startOfToday);

  const canCreate = form.title.trim() && form.event_date && !createEvent.isPending;

  return (
    <div className="max-w-5xl">
      <PageHeader
        title="Events"
        description={`${upcoming.length} upcoming · ${past.length} past`}
        actions={
          <Button className="gap-2" onClick={() => setShowCreate(true)}>
            <Plus className="h-4 w-4" />
            Add event
          </Button>
        }
      />

      {error ? (
        <ErrorState error={error} onRetry={() => void refetch()} />
      ) : isLoading ? (
        <div className="space-y-3">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-24 rounded-xl" />
          ))}
        </div>
      ) : all.length === 0 ? (
        <EmptyState
          icon={CalendarDays}
          title="No events scheduled"
          description="Meetings, lectures and association events appear here and in members' calendars."
          action={
            <Button className="gap-2" onClick={() => setShowCreate(true)}>
              <Plus className="h-4 w-4" />
              Schedule the first event
            </Button>
          }
        />
      ) : (
        <div className="space-y-8">
          {upcoming.length > 0 && (
            <section>
              <h2 className="mb-3 text-2xs font-semibold uppercase tracking-wider text-muted-foreground">
                Upcoming
              </h2>
              <div className="space-y-3">
                {upcoming.map((event) => (
                  <EventCard
                    key={event.id}
                    event={event}
                    onDelete={() => setPendingDelete({ id: event.id, title: event.title })}
                  />
                ))}
              </div>
            </section>
          )}

          {past.length > 0 && (
            <section>
              <h2 className="mb-3 text-2xs font-semibold uppercase tracking-wider text-muted-foreground">
                Past
              </h2>
              <div className="space-y-3">
                {past.map((event) => (
                  <EventCard
                    key={event.id}
                    event={event}
                    past
                    onDelete={() => setPendingDelete({ id: event.id, title: event.title })}
                  />
                ))}
              </div>
            </section>
          )}
        </div>
      )}

      {/* ── Create ───────────────────────────────────────────── */}
      <Dialog open={showCreate} onOpenChange={setShowCreate}>
        <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-lg">
          <DialogHeader>
            <DialogTitle className="font-display">Add event</DialogTitle>
          </DialogHeader>

          <div className="space-y-4 py-2">
            <div className="space-y-1.5">
              <Label htmlFor="event-title">
                Title <span className="text-destructive">*</span>
              </Label>
              <Input
                id="event-title"
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                placeholder="Monthly general meeting"
              />
            </div>

            <div className="grid grid-cols-3 gap-3">
              <div className="space-y-1.5">
                <Label htmlFor="event-date">
                  Date <span className="text-destructive">*</span>
                </Label>
                <Input
                  id="event-date"
                  type="date"
                  value={form.event_date}
                  onChange={(e) => setForm({ ...form, event_date: e.target.value })}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="event-start">Start</Label>
                <Input
                  id="event-start"
                  type="time"
                  value={form.start_time}
                  onChange={(e) => setForm({ ...form, start_time: e.target.value })}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="event-end">End</Label>
                <Input
                  id="event-end"
                  type="time"
                  value={form.end_time}
                  onChange={(e) => setForm({ ...form, end_time: e.target.value })}
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="event-location">Location</Label>
              <Input
                id="event-location"
                value={form.location}
                onChange={(e) => setForm({ ...form, location: e.target.value })}
                placeholder="Bar hall, court complex"
              />
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="event-category">Category</Label>
              <Select
                value={form.category}
                onValueChange={(v) => setForm({ ...form, category: v })}
              >
                <SelectTrigger id="event-category">
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

            <div className="space-y-1.5">
              <Label htmlFor="event-description">Description</Label>
              <Textarea
                id="event-description"
                rows={2}
                value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                className="resize-none"
              />
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="event-agenda">Agenda</Label>
              <Textarea
                id="event-agenda"
                rows={3}
                value={form.agenda}
                onChange={(e) => setForm({ ...form, agenda: e.target.value })}
                placeholder={"1. Roll call\n2. Reading of minutes\n3. Treasurer's report"}
                className="resize-none"
              />
            </div>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setShowCreate(false)}>
              Cancel
            </Button>
            <Button onClick={() => void handleCreate()} disabled={!canCreate}>
              {createEvent.isPending ? "Creating…" : "Create event"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={pendingDelete !== null}
        onOpenChange={(open) => !open && setPendingDelete(null)}
        title="Delete this event?"
        description={
          <>
            <span className="font-medium text-foreground">{pendingDelete?.title}</span>{" "}
            will be removed from members' calendars. This cannot be undone.
          </>
        }
        onConfirm={handleDelete}
      />
    </div>
  );
}

function EventCard({
  event,
  past,
  onDelete,
}: {
  event: any;
  past?: boolean;
  onDelete: () => void;
}) {
  const style = categoryStyle(event.category);
  const date = new Date(event.event_date);

  return (
    <article
      className={cn(
        "group flex gap-4 rounded-xl border border-border bg-card p-4 shadow-xs transition-shadow hover:shadow-sm",
        past && "opacity-70",
      )}
    >
      <div className="flex w-12 shrink-0 flex-col items-center justify-center">
        <span data-numeric className={cn("font-display text-2xl font-semibold", style.text)}>
          {date.getDate()}
        </span>
        <span className={cn("text-2xs font-semibold uppercase", style.text)}>
          {date.toLocaleString("en", { month: "short" })}
        </span>
      </div>

      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <h3 className="font-medium text-foreground">{event.title}</h3>
          <span
            className={cn(
              "rounded-full px-2 py-0.5 text-2xs font-semibold capitalize",
              style.chip,
            )}
          >
            {event.category}
          </span>
        </div>

        <div className="mt-1.5 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-muted-foreground">
          {event.start_time && (
            <span className="inline-flex items-center gap-1.5">
              <Clock className="h-3.5 w-3.5" />
              {event.start_time}
              {event.end_time ? ` – ${event.end_time}` : ""}
            </span>
          )}
          {event.location && (
            <span className="inline-flex min-w-0 items-center gap-1.5">
              <MapPin className="h-3.5 w-3.5 shrink-0" />
              <span className="truncate">{event.location}</span>
            </span>
          )}
        </div>

        {event.description && (
          <p className="mt-1.5 line-clamp-1 text-sm text-muted-foreground">
            {event.description}
          </p>
        )}
      </div>

      <Button
        variant="ghost"
        size="icon"
        className={cn(
          "h-8 w-8 shrink-0 self-start text-muted-foreground hover:text-destructive",
          "md:opacity-0 md:group-hover:opacity-100 md:focus-visible:opacity-100",
        )}
        onClick={onDelete}
        aria-label={`Delete event: ${event.title}`}
      >
        <Trash2 className="h-4 w-4" />
      </Button>
    </article>
  );
}
