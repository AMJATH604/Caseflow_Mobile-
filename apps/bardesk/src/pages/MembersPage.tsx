import { useState } from "react";
import { toast } from "sonner";
import { FileSpreadsheet, Search, Plus, UserCheck, UserX, Users } from "lucide-react";

import {
  useMembers,
  useAddMember,
  useUpdateMember,
  useCurrentAdmin,
} from "@/hooks/useBarDesk";
import { getInitials, getMembershipBadge, cn } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { RollImportDialog } from "@/pages/RollImportDialog";
import { DataTable, type Column } from "@/components/DataTable";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
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

type StatusFilter = "all" | "active" | "suspended";

const EMPTY_MEMBER = {
  name: "",
  mobile: "",
  email: "",
  enrollment_number: "",
  membership_type: "regular" as const,
};

export default function MembersPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id || "";
  const { data: members, isLoading, error, refetch } = useMembers(associationId);
  const addMember = useAddMember(associationId);
  const updateMember = useUpdateMember();

  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [showAdd, setShowAdd] = useState(false);
  const [showImport, setShowImport] = useState(false);
  const [draft, setDraft] = useState(EMPTY_MEMBER);

  const all = members || [];
  const term = search.trim().toLowerCase();

  const filtered = all.filter((m) => {
    const matchesSearch =
      !term ||
      m.name.toLowerCase().includes(term) ||
      (m.enrollment_number || "").toLowerCase().includes(term) ||
      (m.mobile || "").includes(term);
    const matchesStatus = statusFilter === "all" || m.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const counts: Record<StatusFilter, number> = {
    all: all.length,
    active: all.filter((m) => m.status === "active").length,
    suspended: all.filter((m) => m.status === "suspended").length,
  };

  // Every mutation here previously ran unguarded, so a failed insert threw
  // into nothing and left the dialog open with no explanation.
  const handleAdd = async () => {
    try {
      await addMember.mutateAsync({
        ...draft,
        status: "active",
        is_caseflow_user: false,
      });
      toast.success(`${draft.name} added to the roll`);
      setShowAdd(false);
      setDraft(EMPTY_MEMBER);
    } catch (err) {
      toast.error("Could not add member", {
        description: err instanceof Error ? err.message : "Please try again.",
      });
    }
  };

  const toggleStatus = async (id: string, current: string, name: string) => {
    const next = current === "active" ? "suspended" : "active";
    try {
      await updateMember.mutateAsync({ id, status: next } as any);
      toast.success(`${name} ${next === "active" ? "reactivated" : "suspended"}`);
    } catch (err) {
      toast.error("Could not update member", {
        description: err instanceof Error ? err.message : "Please try again.",
      });
    }
  };

  // An entry with no user_id is a name the association put on its register
  // that nobody has claimed from CaseFlow yet. Chasing those is the whole of
  // onboarding, so the count sits at the top of the page.
  const claimed = all.filter((m) => m.user_id).length;
  const unclaimed = all.length - claimed;
  const adoption = all.length > 0 ? Math.round((claimed / all.length) * 100) : 0;

  const columns: Column<(typeof all)[number]>[] = [
    {
      key: "name",
      header: "Member",
      primary: true,
      sortValue: (m) => m.name,
      render: (m) => (
        <div className="flex items-center gap-3">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-muted text-2xs font-semibold text-muted-foreground">
            {getInitials(m.name)}
          </span>
          <span className="font-medium text-foreground">{m.name}</span>
        </div>
      ),
    },
    {
      key: "enrollment_number",
      header: "Enrollment",
      sortValue: (m) => m.enrollment_number,
      render: (m) => m.enrollment_number || "—",
    },
    {
      key: "mobile",
      header: "Mobile",
      render: (m) => m.mobile || "—",
    },
    {
      key: "membership_type",
      header: "Type",
      sortValue: (m) => m.membership_type,
      render: (m) => (
        <Badge variant="secondary" className="font-normal">
          {getMembershipBadge(m.membership_type ?? "ordinary")}
        </Badge>
      ),
    },
    {
      key: "status",
      header: "Status",
      sortValue: (m) => m.status,
      render: (m) => (
        <span
          className={cn(
            "inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-2xs font-semibold",
            m.status === "active"
              ? "bg-success/10 text-success"
              : "bg-destructive/10 text-destructive",
          )}
        >
          {m.status === "active" ? (
            <UserCheck className="h-3 w-3" />
          ) : (
            <UserX className="h-3 w-3" />
          )}
          {m.status}
        </span>
      ),
    },
    {
      key: "is_caseflow_user",
      header: "CaseFlow",
      hideOnCard: true,
      render: (m) =>
        m.is_caseflow_user ? (
          <Badge className="bg-accent/15 font-normal text-accent hover:bg-accent/15">
            Linked
          </Badge>
        ) : (
          <span className="text-muted-foreground">—</span>
        ),
    },
    {
      key: "actions",
      header: "",
      align: "right",
      render: (m) => (
        <Button
          variant={m.status === "active" ? "ghost" : "outline"}
          size="sm"
          className={cn(
            "h-7 text-xs",
            m.status === "active" && "text-destructive hover:text-destructive",
          )}
          onClick={(e) => {
            e.stopPropagation();
            void toggleStatus(m.id, m.status ?? "active", m.name);
          }}
          disabled={updateMember.isPending}
        >
          {m.status === "active" ? "Suspend" : "Activate"}
        </Button>
      ),
    },
  ];

  const canSubmit = draft.name.trim() && draft.mobile.trim() && !addMember.isPending;

  return (
    <div>
      <PageHeader
        title="Members"
        description={`${counts.all} on the roll · ${counts.active} active`}
        actions={
          <div className="flex gap-2">
            <Button variant="outline" className="gap-2" onClick={() => setShowImport(true)}>
              <FileSpreadsheet className="h-4 w-4" />
              Import roll
            </Button>
            <Button className="gap-2" onClick={() => setShowAdd(true)}>
              <Plus className="h-4 w-4" />
              Add member
            </Button>
          </div>
        }
      >
        {all.length > 0 && (
          <div className="mb-4 rounded-xl border border-border bg-card p-4">
            <div className="flex flex-wrap items-baseline justify-between gap-2">
              <p className="text-sm font-medium text-foreground">
                <span className="font-mono text-lg font-semibold tabular-nums">{claimed}</span>
                <span className="text-muted-foreground"> of {all.length} have joined CaseFlow</span>
              </p>
              <p className="font-mono text-sm tabular-nums text-muted-foreground">{adoption}%</p>
            </div>
            <div className="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-muted">
              <div
                className="h-full rounded-full bg-primary transition-all"
                style={{ width: `${adoption}%` }}
              />
            </div>
            {unclaimed > 0 && (
              <p className="mt-2 text-xs text-muted-foreground">
                {unclaimed} {unclaimed === 1 ? "entry is" : "entries are"} still unclaimed. They
                join by entering the association code and their enrolment number in CaseFlow.
              </p>
            )}
          </div>
        )}

        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
          <div className="relative w-full sm:max-w-xs">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search name, enrollment or mobile"
              className="pl-9"
            />
          </div>

          <div className="flex gap-1.5">
            {(["all", "active", "suspended"] as const).map((s) => (
              <Button
                key={s}
                variant={statusFilter === s ? "default" : "outline"}
                size="sm"
                className="h-9 text-xs capitalize"
                onClick={() => setStatusFilter(s)}
              >
                {s}
                <span
                  data-numeric
                  className={cn(
                    "ml-1.5",
                    statusFilter === s ? "opacity-80" : "text-muted-foreground",
                  )}
                >
                  {counts[s]}
                </span>
              </Button>
            ))}
          </div>
        </div>
      </PageHeader>

      <DataTable
        data={filtered}
        columns={columns}
        rowKey={(m) => m.id}
        isLoading={isLoading}
        error={error}
        onRetry={() => void refetch()}
        empty={{
          title: term || statusFilter !== "all" ? "No matching members" : "No members yet",
          description:
            term || statusFilter !== "all"
              ? "Try a different search or filter."
              : "Add advocates to the roll to start tracking fees, notices and elections.",
          action:
            term || statusFilter !== "all" ? undefined : (
              <Button className="gap-2" onClick={() => setShowAdd(true)}>
                <Plus className="h-4 w-4" />
                Add the first member
              </Button>
            ),
        }}
      />

      {/* ── Add member ───────────────────────────────────────── */}
      <RollImportDialog
        open={showImport}
        onOpenChange={setShowImport}
        associationId={associationId}
        onImported={() => refetch()}
      />

      <Dialog open={showAdd} onOpenChange={setShowAdd}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="font-display">Add member</DialogTitle>
          </DialogHeader>

          <div className="space-y-4 py-2">
            <div className="space-y-1.5">
              <Label htmlFor="member-name">
                Full name <span className="text-destructive">*</span>
              </Label>
              <Input
                id="member-name"
                value={draft.name}
                onChange={(e) => setDraft({ ...draft, name: e.target.value })}
                placeholder="Adv. Ramesh Kumar"
              />
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="member-enrollment">Enrollment number</Label>
              <Input
                id="member-enrollment"
                value={draft.enrollment_number}
                onChange={(e) => setDraft({ ...draft, enrollment_number: e.target.value })}
                placeholder="TN/1234/2020"
              />
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="space-y-1.5">
                <Label htmlFor="member-mobile">
                  Mobile <span className="text-destructive">*</span>
                </Label>
                <Input
                  id="member-mobile"
                  type="tel"
                  inputMode="numeric"
                  value={draft.mobile}
                  onChange={(e) => setDraft({ ...draft, mobile: e.target.value })}
                  placeholder="9876543210"
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="member-email">Email</Label>
                <Input
                  id="member-email"
                  type="email"
                  value={draft.email}
                  onChange={(e) => setDraft({ ...draft, email: e.target.value })}
                  placeholder="name@example.com"
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="member-type">Membership type</Label>
              <Select
                value={draft.membership_type}
                onValueChange={(v) => setDraft({ ...draft, membership_type: v as any })}
              >
                <SelectTrigger id="member-type">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="regular">Regular</SelectItem>
                  <SelectItem value="life">Life member</SelectItem>
                  <SelectItem value="honorary">Honorary</SelectItem>
                  <SelectItem value="student">Student</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setShowAdd(false)}>
              Cancel
            </Button>
            <Button onClick={() => void handleAdd()} disabled={!canSubmit}>
              {addMember.isPending ? "Adding…" : "Add member"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
