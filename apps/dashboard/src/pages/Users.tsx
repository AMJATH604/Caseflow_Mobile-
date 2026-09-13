import { useMemo, useState } from "react";
import { formatDistanceToNowStrict, format } from "date-fns";
import { DashboardLayout } from "@/components/DashboardLayout";
import { PageHeader } from "@/components/PageHeader";
import { DataTable, type Column } from "@/components/DataTable";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useAdminUsers, type AdminUser } from "@/hooks/useAdminMetrics";
import { Search, BellOff, ShieldCheck } from "lucide-react";

/**
 * Every registered account, with how much each one actually uses CaseFlow.
 *
 * Counts only. There is deliberately no column that reveals what any record
 * contains — case titles, client names and fee figures are privileged
 * advocate-client material, and the data never leaves the server in that form.
 */

type Filter = "all" | "active" | "dormant" | "no_push";

function activity(u: AdminUser): { label: string; tone: string } {
  if (!u.last_sign_in_at) return { label: "Never signed in", tone: "bg-muted text-muted-foreground" };
  const days = (Date.now() - new Date(u.last_sign_in_at).getTime()) / 86_400_000;
  if (days <= 7) return { label: "Active", tone: "bg-success/10 text-success" };
  if (days <= 30) return { label: "Recent", tone: "bg-info/10 text-info" };
  return { label: "Dormant", tone: "bg-warning/10 text-warning" };
}

export default function Users() {
  const { data, isLoading, error, refetch } = useAdminUsers();
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<Filter>("all");

  const rows = useMemo(() => {
    let list = data ?? [];
    const q = search.trim().toLowerCase();
    if (q) {
      list = list.filter(
        (u) =>
          u.full_name?.toLowerCase().includes(q) ||
          u.email?.toLowerCase().includes(q) ||
          u.practice_district?.toLowerCase().includes(q),
      );
    }
    if (filter === "active") list = list.filter((u) => activity(u).label === "Active");
    if (filter === "dormant")
      list = list.filter((u) => ["Dormant", "Never signed in"].includes(activity(u).label));
    if (filter === "no_push") list = list.filter((u) => !u.has_push);
    return list;
  }, [data, search, filter]);

  const columns: Column<AdminUser>[] = [
    {
      key: "full_name",
      header: "Name",
      primary: true,
      sortValue: (u) => u.full_name ?? u.email ?? "",
      render: (u) => (
        <div className="min-w-0">
          <div className="flex items-center gap-1.5 font-medium text-foreground">
            <span className="truncate">{u.full_name || "—"}</span>
            {u.is_admin && <ShieldCheck className="h-3.5 w-3.5 shrink-0 text-primary" />}
          </div>
          <div className="truncate text-xs text-muted-foreground">{u.email}</div>
        </div>
      ),
    },
    {
      key: "user_role",
      header: "Role",
      sortValue: (u) => u.user_role,
      render: (u) => <span className="capitalize text-sm">{u.user_role}</span>,
    },
    {
      key: "last_sign_in_at",
      header: "Last seen",
      sortValue: (u) => (u.last_sign_in_at ? new Date(u.last_sign_in_at).getTime() : 0),
      render: (u) => {
        const a = activity(u);
        return (
          <div>
            <Badge variant="secondary" className={`${a.tone} border-0 font-normal`}>
              {a.label}
            </Badge>
            {u.last_sign_in_at && (
              <div className="mt-1 text-xs text-muted-foreground">
                {formatDistanceToNowStrict(new Date(u.last_sign_in_at))} ago
              </div>
            )}
          </div>
        );
      },
    },
    {
      key: "cases",
      header: "Cases",
      align: "right",
      sortValue: (u) => u.cases,
      render: (u) => <span className="tabular-nums">{u.cases}</span>,
    },
    {
      key: "clients",
      header: "Clients",
      align: "right",
      sortValue: (u) => u.clients,
      render: (u) => <span className="tabular-nums">{u.clients}</span>,
      hideOnCard: true,
    },
    {
      key: "hearings",
      header: "Hearings",
      align: "right",
      sortValue: (u) => u.hearings,
      render: (u) => <span className="tabular-nums">{u.hearings}</span>,
      hideOnCard: true,
    },
    {
      key: "subscription_tier",
      header: "Plan",
      sortValue: (u) => u.subscription_tier,
      render: (u) => <span className="text-sm capitalize">{u.subscription_tier}</span>,
    },
    {
      key: "has_push",
      header: "Push",
      sortValue: (u) => (u.has_push ? 1 : 0),
      render: (u) =>
        u.has_push ? (
          <span className="text-sm text-success">Registered</span>
        ) : (
          <span className="inline-flex items-center gap-1 text-sm text-muted-foreground">
            <BellOff className="h-3.5 w-3.5" /> None
          </span>
        ),
    },
    {
      key: "created_at",
      header: "Joined",
      sortValue: (u) => new Date(u.created_at).getTime(),
      render: (u) => (
        <span className="text-sm text-muted-foreground">
          {format(new Date(u.created_at), "d MMM yyyy")}
        </span>
      ),
      hideOnCard: true,
    },
  ];

  const filters: Array<{ id: Filter; label: string; n?: number }> = [
    { id: "all", label: "All", n: data?.length },
    { id: "active", label: "Active", n: data?.filter((u) => activity(u).label === "Active").length },
    {
      id: "dormant",
      label: "Dormant",
      n: data?.filter((u) => ["Dormant", "Never signed in"].includes(activity(u).label)).length,
    },
    { id: "no_push", label: "No push", n: data?.filter((u) => !u.has_push).length },
  ];

  return (
    <DashboardLayout>
      <PageHeader
        title="Users"
        description="Every registered account and how much of CaseFlow it actually uses. Counts only — no case or client contents."
      >
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
          <div className="relative max-w-xs flex-1">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              id="user-search"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Name, email or district"
              className="pl-9"
            />
          </div>
          <div className="flex flex-wrap gap-1.5">
            {filters.map((f) => (
              <Button
                key={f.id}
                size="sm"
                variant={filter === f.id ? "default" : "outline"}
                onClick={() => setFilter(f.id)}
              >
                {f.label}
                {f.n !== undefined && (
                  <span className="ml-1.5 tabular-nums opacity-70">{f.n}</span>
                )}
              </Button>
            ))}
          </div>
        </div>
      </PageHeader>

      <DataTable
        data={rows}
        columns={columns}
        rowKey={(u) => u.id}
        isLoading={isLoading}
        error={error}
        onRetry={() => refetch()}
        empty={{
          title: search || filter !== "all" ? "No matching users" : "No users yet",
          description:
            search || filter !== "all"
              ? "Try a different search or filter."
              : "Accounts appear here as advocates register.",
        }}
      />
    </DashboardLayout>
  );
}
