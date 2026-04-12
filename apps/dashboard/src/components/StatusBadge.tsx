const statusStyles: Record<string, string> = {
  active: "bg-success/10 text-success",
  closed: "bg-muted text-muted-foreground",
  appeal: "bg-warning/10 text-warning",
  filing: "bg-info/10 text-info",
  evidence: "bg-accent/10 text-accent",
  argument: "bg-warning/10 text-warning",
  judgment: "bg-primary/10 text-primary",
  drafting: "bg-muted text-muted-foreground",
  review: "bg-info/10 text-info",
  signature_pending: "bg-warning/10 text-warning",
  filed: "bg-success/10 text-success",
  defect: "bg-destructive/10 text-destructive",
  accepted: "bg-success/10 text-success",
};

export function StatusBadge({ status }: { status: string }) {
  if (!status) return null;
  return (
    <span className={`status-badge ${statusStyles[status] || "bg-muted text-muted-foreground"}`}>
      {status.replace(/_/g, " ")}
    </span>
  );
}
