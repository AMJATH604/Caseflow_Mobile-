import { useState } from "react";
import { toast } from "sonner";
import {
  Plus, Play, Square, Trophy, Clock, Trash2, ChevronRight, ChevronLeft,
  Award, Eye, Vote, Check,
} from "lucide-react";

import {
  useElections, useCreateElection, useUpdateElection, useDeleteElection,
  useElectionPosts, useCreateElectionPost, useDeleteElectionPost,
  useNominations, useCreateNomination, useDeleteNomination,
  useVoteCounts, useMembers, useCurrentAdmin,
} from "@/hooks/useBarDesk";
import { formatDate, getInitials, cn } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { EmptyState, ErrorState } from "@/components/states";
import { ConfirmDialog } from "@/components/ConfirmDialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import { Card, CardContent } from "@/components/ui/card";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle,
} from "@/components/ui/dialog";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";

const STATUS = {
  draft: { label: "Draft", chip: "bg-muted text-muted-foreground", icon: Clock },
  nominations: { label: "Nominations", chip: "bg-info/10 text-info", icon: Play },
  voting: { label: "Voting", chip: "bg-accent/15 text-accent", icon: Vote },
  completed: { label: "Completed", chip: "bg-success/10 text-success", icon: Trophy },
  cancelled: { label: "Cancelled", chip: "bg-destructive/10 text-destructive", icon: Square },
} as const;

const statusOf = (s: string) => STATUS[s as keyof typeof STATUS] ?? STATUS.draft;

/** A status change that needs confirming before it is applied. */
type PendingChange =
  | { kind: "status"; id: string; status: string; title: string }
  | { kind: "delete"; id: string; title: string };

export default function ElectionsPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id || "";
  const { data: elections, isLoading, error, refetch } = useElections(associationId);
  const createElection = useCreateElection(associationId);
  const updateElection = useUpdateElection();
  const deleteElection = useDeleteElection();

  const [showWizard, setShowWizard] = useState(false);
  const [wizardStep, setWizardStep] = useState(1);
  const [createdElectionId, setCreatedElectionId] = useState("");
  const [viewing, setViewing] = useState<string | null>(null);
  const [pending, setPending] = useState<PendingChange | null>(null);
  const [form, setForm] = useState({
    title: "", description: "", voting_start: "", voting_end: "",
  });

  const resetWizard = () => {
    setShowWizard(false);
    setWizardStep(1);
    setCreatedElectionId("");
    setForm({ title: "", description: "", voting_start: "", voting_end: "" });
  };

  const handleCreateElection = async () => {
    try {
      const result = await createElection.mutateAsync({
        ...form,
        nomination_start: form.voting_start,
        nomination_end: form.voting_start,
        status: "draft",
      } as any);
      setCreatedElectionId(result.id);
      setWizardStep(2);
    } catch (err) {
      toast.error("Could not create election", {
        description: err instanceof Error ? err.message : "Please try again.",
      });
    }
  };

  const applyPending = async () => {
    if (!pending) return;
    try {
      if (pending.kind === "delete") {
        await deleteElection.mutateAsync(pending.id);
        toast.success("Election deleted");
      } else {
        await updateElection.mutateAsync({ id: pending.id, status: pending.status } as any);
        toast.success(
          pending.status === "voting"
            ? "Voting is open"
            : pending.status === "completed"
              ? "Results published"
              : "Election cancelled",
        );
      }
      setPending(null);
    } catch (err) {
      toast.error("Could not update election", {
        description: err instanceof Error ? err.message : "Please try again.",
      });
      throw err;
    }
  };

  const list = elections || [];
  const canCreate =
    form.title.trim() && form.voting_start && form.voting_end && !createElection.isPending;

  const confirmCopy = (): { title: string; description: string; label: string } => {
    if (!pending) return { title: "", description: "", label: "" };
    if (pending.kind === "delete") {
      return {
        title: "Delete this election?",
        description: `${pending.title} and all its posts and candidates will be removed. This cannot be undone.`,
        label: "Delete",
      };
    }
    switch (pending.status) {
      case "voting":
        return {
          title: "Open voting?",
          description: `Members will be able to cast votes in ${pending.title}. Posts and candidates cannot be changed once voting is open.`,
          label: "Open voting",
        };
      case "completed":
        return {
          title: "Close voting and publish results?",
          description: `Voting in ${pending.title} will end and results become visible to members. This cannot be reopened.`,
          label: "Publish results",
        };
      default:
        return {
          title: "Cancel this election?",
          description: `${pending.title} will be marked cancelled. Any votes already cast are kept but no longer count.`,
          label: "Cancel election",
        };
    }
  };

  const copy = confirmCopy();

  return (
    <div className="max-w-5xl">
      <PageHeader
        title="Elections"
        description="Set up posts, nominate candidates and publish results"
        actions={
          <Button className="gap-2" onClick={() => setShowWizard(true)}>
            <Plus className="h-4 w-4" />
            New election
          </Button>
        }
      />

      {error ? (
        <ErrorState error={error} onRetry={() => void refetch()} />
      ) : isLoading ? (
        <div className="space-y-4">
          {[0, 1].map((i) => (
            <Skeleton key={i} className="h-44 rounded-xl" />
          ))}
        </div>
      ) : list.length === 0 ? (
        <EmptyState
          icon={Vote}
          title="No elections yet"
          description="Create an election to add posts, nominate candidates and collect votes from members."
          action={
            <Button className="gap-2" onClick={() => setShowWizard(true)}>
              <Plus className="h-4 w-4" />
              Create the first election
            </Button>
          }
        />
      ) : (
        <div className="space-y-4">
          {list.map((election) => {
            const status = statusOf(election.status);
            const StatusIcon = status.icon;

            return (
              <Card key={election.id}>
                <CardContent className="p-5">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="min-w-0">
                      <h3 className="font-display text-lg font-semibold text-foreground">
                        {election.title}
                      </h3>
                      {election.description && (
                        <p className="mt-1 text-sm text-muted-foreground">
                          {election.description}
                        </p>
                      )}
                    </div>
                    <span
                      className={cn(
                        "inline-flex shrink-0 items-center gap-1.5 rounded-full px-2.5 py-1 text-2xs font-semibold",
                        status.chip,
                      )}
                    >
                      <StatusIcon className="h-3 w-3" />
                      {status.label}
                    </span>
                  </div>

                  <div className="mt-4 grid grid-cols-2 gap-4 rounded-lg border border-border bg-muted/30 p-3">
                    <Timeline label="Voting opens" date={election.voting_start} />
                    <Timeline label="Voting closes" date={election.voting_end} />
                  </div>

                  <div className="mt-4 flex flex-wrap gap-2">
                    {election.status === "draft" && (
                      <>
                        <Button variant="outline" size="sm" className="gap-1.5"
                          onClick={() => setViewing(election.id)}>
                          <Eye className="h-3.5 w-3.5" />
                          Posts &amp; candidates
                        </Button>
                        <Button size="sm" className="gap-1.5"
                          onClick={() => setPending({ kind: "status", id: election.id, status: "voting", title: election.title })}>
                          <Vote className="h-3.5 w-3.5" />
                          Open voting
                        </Button>
                      </>
                    )}

                    {election.status === "voting" && (
                      <>
                        <Button variant="outline" size="sm" className="gap-1.5"
                          onClick={() => setViewing(election.id)}>
                          <Eye className="h-3.5 w-3.5" />
                          Live results
                        </Button>
                        <Button size="sm" className="gap-1.5"
                          onClick={() => setPending({ kind: "status", id: election.id, status: "completed", title: election.title })}>
                          <Trophy className="h-3.5 w-3.5" />
                          Close &amp; publish
                        </Button>
                      </>
                    )}

                    {election.status === "completed" && (
                      <Button variant="outline" size="sm" className="gap-1.5"
                        onClick={() => setViewing(election.id)}>
                        <Trophy className="h-3.5 w-3.5" />
                        View results
                      </Button>
                    )}

                    {["draft", "voting"].includes(election.status) && (
                      <Button variant="ghost" size="sm"
                        className="text-muted-foreground hover:text-destructive"
                        onClick={() => setPending({ kind: "status", id: election.id, status: "cancelled", title: election.title })}>
                        Cancel
                      </Button>
                    )}

                    {["draft", "cancelled"].includes(election.status) && (
                      <Button variant="ghost" size="sm"
                        className="gap-1.5 text-destructive hover:text-destructive"
                        onClick={() => setPending({ kind: "delete", id: election.id, title: election.title })}>
                        <Trash2 className="h-3.5 w-3.5" />
                        Delete
                      </Button>
                    )}
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}

      {/* ── Wizard ───────────────────────────────────────────── */}
      <Dialog open={showWizard} onOpenChange={(o) => !o && resetWizard()}>
        <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-xl">
          <DialogHeader>
            <DialogTitle className="font-display">
              {wizardStep === 1 && "Create election"}
              {wizardStep === 2 && "Add posts"}
              {wizardStep === 3 && "Add candidates"}
            </DialogTitle>
            <div className="flex gap-1.5 pt-2" role="progressbar"
              aria-valuenow={wizardStep} aria-valuemin={1} aria-valuemax={3}
              aria-label={`Step ${wizardStep} of 3`}>
              {[1, 2, 3].map((s) => (
                <div key={s}
                  className={cn(
                    "h-1.5 flex-1 rounded-full transition-colors",
                    s <= wizardStep ? "bg-accent" : "bg-muted",
                  )}
                />
              ))}
            </div>
          </DialogHeader>

          {wizardStep === 1 && (
            <div className="space-y-4 py-2">
              <div className="space-y-1.5">
                <Label htmlFor="election-title">
                  Title <span className="text-destructive">*</span>
                </Label>
                <Input id="election-title" value={form.title}
                  onChange={(e) => setForm({ ...form, title: e.target.value })}
                  placeholder="Annual election 2026" />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="election-description">Description</Label>
                <Textarea id="election-description" rows={2} value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                  className="resize-none" />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1.5">
                  <Label htmlFor="voting-start">
                    Voting opens <span className="text-destructive">*</span>
                  </Label>
                  <Input id="voting-start" type="date" value={form.voting_start}
                    onChange={(e) => setForm({ ...form, voting_start: e.target.value })} />
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="voting-end">
                    Voting closes <span className="text-destructive">*</span>
                  </Label>
                  <Input id="voting-end" type="date" value={form.voting_end}
                    onChange={(e) => setForm({ ...form, voting_end: e.target.value })} />
                </div>
              </div>

              <div className="flex gap-3 pt-2">
                <Button variant="outline" className="flex-1" onClick={resetWizard}>
                  Cancel
                </Button>
                <Button className="flex-1 gap-1.5" onClick={() => void handleCreateElection()}
                  disabled={!canCreate}>
                  {createElection.isPending ? "Creating…" : "Next"}
                  <ChevronRight className="h-4 w-4" />
                </Button>
              </div>
            </div>
          )}

          {wizardStep === 2 && (
            <PostsStep electionId={createdElectionId}
              onNext={() => setWizardStep(3)} onBack={() => setWizardStep(1)} />
          )}

          {wizardStep === 3 && (
            <CandidatesStep electionId={createdElectionId} associationId={associationId}
              onDone={resetWizard} onBack={() => setWizardStep(2)} />
          )}
        </DialogContent>
      </Dialog>

      {/* ── Detail / results ─────────────────────────────────── */}
      <Dialog open={viewing !== null} onOpenChange={(o) => !o && setViewing(null)}>
        <DialogContent className="max-h-[85vh] overflow-y-auto sm:max-w-2xl">
          <DialogHeader>
            <DialogTitle className="font-display">Posts &amp; results</DialogTitle>
          </DialogHeader>
          {viewing && <ElectionDetail electionId={viewing} />}
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={pending !== null}
        onOpenChange={(o) => !o && setPending(null)}
        title={copy.title}
        description={copy.description}
        confirmLabel={copy.label}
        destructive={pending?.kind === "delete" || pending?.status === "cancelled"}
        onConfirm={applyPending}
      />
    </div>
  );
}

// ─── Step 2 ─────────────────────────────────────────────────

function PostsStep({
  electionId, onNext, onBack,
}: { electionId: string; onNext: () => void; onBack: () => void }) {
  const { data: posts } = useElectionPosts(electionId);
  const createPost = useCreateElectionPost(electionId);
  const deletePost = useDeleteElectionPost(electionId);
  const [postName, setPostName] = useState("");

  const presets = ["President", "Vice President", "Secretary", "Joint Secretary", "Treasurer"];
  const existing = (posts || []).map((p) => p.post_name.toLowerCase());

  const handleAdd = async (name: string) => {
    const trimmed = name.trim();
    if (!trimmed) return;
    if (existing.includes(trimmed.toLowerCase())) {
      toast.error(`"${trimmed}" has already been added`);
      return;
    }
    try {
      await createPost.mutateAsync({ post_name: trimmed });
      setPostName("");
    } catch (err) {
      toast.error("Could not add post", {
        description: err instanceof Error ? err.message : "Please try again.",
      });
    }
  };

  const handleDelete = async (id: string) => {
    try {
      await deletePost.mutateAsync(id);
    } catch (err) {
      toast.error("Could not remove post", {
        description: err instanceof Error ? err.message : "Please try again.",
      });
    }
  };

  return (
    <div className="space-y-4 py-2">
      <p className="text-sm text-muted-foreground">
        Add the positions members will vote for.
      </p>

      <div className="flex flex-wrap gap-2">
        {presets
          .filter((p) => !existing.includes(p.toLowerCase()))
          .map((p) => (
            <button key={p} type="button" onClick={() => void handleAdd(p)}
              className="rounded-lg border border-dashed border-border px-3 py-1.5 text-xs font-medium text-muted-foreground transition-colors hover:border-accent/50 hover:bg-accent/5 hover:text-accent">
              + {p}
            </button>
          ))}
      </div>

      <div className="flex gap-2">
        <Input value={postName} onChange={(e) => setPostName(e.target.value)}
          placeholder="Custom post name"
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              void handleAdd(postName);
            }
          }} />
        <Button onClick={() => void handleAdd(postName)}
          disabled={!postName.trim() || createPost.isPending}>
          Add
        </Button>
      </div>

      {(posts || []).length === 0 ? (
        <p className="rounded-lg border border-dashed border-border py-6 text-center text-sm text-muted-foreground">
          Add at least one post to continue.
        </p>
      ) : (
        <div className="space-y-2">
          {(posts || []).map((post) => (
            <div key={post.id}
              className="flex items-center justify-between rounded-lg bg-muted/50 px-4 py-2.5">
              <span className="flex items-center gap-2 text-sm font-medium text-foreground">
                <Award className="h-4 w-4 text-accent" />
                {post.post_name}
              </span>
              <Button variant="ghost" size="icon"
                className="h-7 w-7 text-muted-foreground hover:text-destructive"
                onClick={() => void handleDelete(post.id)}
                aria-label={`Remove ${post.post_name}`}>
                <Trash2 className="h-3.5 w-3.5" />
              </Button>
            </div>
          ))}
        </div>
      )}

      <div className="flex gap-3 pt-2">
        <Button variant="outline" className="flex-1 gap-1.5" onClick={onBack}>
          <ChevronLeft className="h-4 w-4" />
          Back
        </Button>
        <Button className="flex-1 gap-1.5" onClick={onNext}
          disabled={(posts || []).length === 0}>
          Next
          <ChevronRight className="h-4 w-4" />
        </Button>
      </div>
    </div>
  );
}

// ─── Step 3 ─────────────────────────────────────────────────

function CandidatesStep({
  electionId, associationId, onDone, onBack,
}: { electionId: string; associationId: string; onDone: () => void; onBack: () => void }) {
  const { data: posts } = useElectionPosts(electionId);
  const { data: members } = useMembers(associationId);
  const activeMembers = (members || []).filter((m) => m.status === "active");

  return (
    <div className="space-y-4 py-2">
      <p className="text-sm text-muted-foreground">
        Nominate candidates for each post. Only active members can stand.
      </p>

      {(posts || []).map((post) => (
        <PostCandidates key={post.id} post={post} members={activeMembers} />
      ))}

      <div className="flex gap-3 pt-2">
        <Button variant="outline" className="flex-1 gap-1.5" onClick={onBack}>
          <ChevronLeft className="h-4 w-4" />
          Back
        </Button>
        <Button className="flex-1 gap-1.5" onClick={onDone}>
          <Check className="h-4 w-4" />
          Done
        </Button>
      </div>
    </div>
  );
}

function PostCandidates({ post, members }: { post: any; members: any[] }) {
  const { data: nominations } = useNominations(post.id);
  const createNom = useCreateNomination(post.id);
  const deleteNom = useDeleteNomination(post.id);
  const [selected, setSelected] = useState("");

  const nomineeIds = (nominations || []).map((n: any) => n.nominee_member_id);
  const available = members.filter((m) => !nomineeIds.includes(m.id));

  const handleAdd = async () => {
    if (!selected) return;
    try {
      await createNom.mutateAsync({ nominee_member_id: selected });
      setSelected("");
    } catch (err) {
      toast.error("Could not add candidate", {
        description: err instanceof Error ? err.message : "Please try again.",
      });
    }
  };

  const handleRemove = async (id: string) => {
    try {
      await deleteNom.mutateAsync(id);
    } catch (err) {
      toast.error("Could not remove candidate", {
        description: err instanceof Error ? err.message : "Please try again.",
      });
    }
  };

  return (
    <div className="rounded-xl border border-border bg-muted/30 p-4">
      <div className="mb-3 flex items-center gap-2">
        <Award className="h-4 w-4 text-accent" />
        <h4 className="text-sm font-semibold text-foreground">{post.post_name}</h4>
        <span data-numeric className="text-2xs text-muted-foreground">
          {(nominations || []).length} standing
        </span>
      </div>

      <div className="mb-3 flex gap-2">
        <Select value={selected} onValueChange={setSelected}>
          <SelectTrigger className="flex-1 bg-card">
            <SelectValue placeholder={
              available.length === 0 ? "No members available" : "Select a member"
            } />
          </SelectTrigger>
          <SelectContent>
            {available.map((m) => (
              <SelectItem key={m.id} value={m.id}>
                {m.name}
                {m.enrollment_number ? ` (${m.enrollment_number})` : ""}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Button size="sm" onClick={() => void handleAdd()}
          disabled={!selected || createNom.isPending}>
          Add
        </Button>
      </div>

      <div className="space-y-1.5">
        {(nominations || []).map((nom: any) => (
          <div key={nom.id}
            className="flex items-center justify-between rounded-lg bg-card px-3 py-2">
            <span className="flex items-center gap-2.5">
              <span className="flex h-7 w-7 items-center justify-center rounded-full bg-accent/10 text-2xs font-semibold text-accent">
                {getInitials(nom.nominee?.name || "?")}
              </span>
              <span className="text-sm text-foreground">
                {nom.nominee?.name || "Member"}
              </span>
            </span>
            <Button variant="ghost" size="icon"
              className="h-7 w-7 text-muted-foreground hover:text-destructive"
              onClick={() => void handleRemove(nom.id)}
              aria-label="Remove candidate">
              <Trash2 className="h-3.5 w-3.5" />
            </Button>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Results ────────────────────────────────────────────────

function ElectionDetail({ electionId }: { electionId: string }) {
  const { data: posts } = useElectionPosts(electionId);

  if ((posts || []).length === 0) {
    return (
      <EmptyState
        icon={Award}
        title="No posts yet"
        description="Add posts to this election before candidates can stand."
        className="border-0"
      />
    );
  }

  return (
    <div className="space-y-4">
      {(posts || []).map((post) => (
        <PostResult key={post.id} post={post} />
      ))}
    </div>
  );
}

function PostResult({ post }: { post: any }) {
  const { data: nominations } = useNominations(post.id);
  const { data: voteCounts } = useVoteCounts(post.id);

  const votesFor = (id: string) =>
    (voteCounts || []).find((v: any) => v.nomination_id === id)?.vote_count || 0;

  const total = (voteCounts || []).reduce(
    (sum: number, v: any) => sum + (v.vote_count || 0), 0,
  );

  const sorted = [...(nominations || [])].sort(
    (a: any, b: any) => votesFor(b.id) - votesFor(a.id),
  );

  return (
    <div className="overflow-hidden rounded-xl border border-border">
      <div className="flex items-center justify-between bg-muted/50 px-4 py-2.5">
        <span className="flex items-center gap-2 text-sm font-semibold text-foreground">
          <Award className="h-4 w-4 text-accent" />
          {post.post_name}
        </span>
        <span data-numeric className="text-sm text-muted-foreground">
          {total} {total === 1 ? "vote" : "votes"}
        </span>
      </div>

      <div className="space-y-3 p-4">
        {sorted.length === 0 ? (
          <p className="py-2 text-center text-sm text-muted-foreground">
            No candidates standing
          </p>
        ) : (
          sorted.map((nom: any, index: number) => {
            const votes = votesFor(nom.id);
            const pct = total > 0 ? (votes / total) * 100 : 0;
            // Only a lead with actual votes counts as leading — with no votes
            // cast, first place is just list order.
            const leading = index === 0 && total > 0;

            return (
              <div key={nom.id} className="flex items-center gap-3">
                <span className="w-4 shrink-0">
                  {leading && <Trophy className="h-4 w-4 text-accent" aria-label="Leading" />}
                </span>
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-muted text-2xs font-semibold text-muted-foreground">
                  {getInitials(nom.nominee?.name || "?")}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="mb-1 flex items-center justify-between gap-2">
                    <span className={cn(
                      "truncate text-sm text-foreground",
                      leading && "font-semibold",
                    )}>
                      {nom.nominee?.name || "Member"}
                    </span>
                    <span data-numeric className={cn(
                      "shrink-0 text-sm",
                      leading ? "font-semibold text-success" : "text-muted-foreground",
                    )}>
                      {votes} ({pct.toFixed(0)}%)
                    </span>
                  </div>
                  <div className="h-2 overflow-hidden rounded-full bg-muted">
                    <div
                      className={cn(
                        "h-full rounded-full transition-all duration-500",
                        leading ? "bg-success" : "bg-muted-foreground/40",
                      )}
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}

function Timeline({ label, date }: { label: string; date: string }) {
  return (
    <div>
      <p className="text-2xs uppercase tracking-wider text-muted-foreground">{label}</p>
      <p className="mt-0.5 text-sm font-medium text-foreground">
        {date ? formatDate(date) : "—"}
      </p>
    </div>
  );
}
