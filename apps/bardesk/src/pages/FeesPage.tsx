import { toast } from "sonner";
import { TrendingUp, AlertCircle, CheckCircle, Download, Receipt } from "lucide-react";

import { useFeePayments, useFeeStats, useCurrentAdmin } from "@/hooks/useBarDesk";
import { formatCurrency, formatDate, getInitials, cn } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { KpiCard } from "@/components/KpiCard";
import { DataTable, type Column } from "@/components/DataTable";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";

const statusTone: Record<string, string> = {
  paid: "bg-success/10 text-success",
  pending: "bg-warning/10 text-warning",
};

/** Wraps a CSV field, escaping quotes and anything that would break a column. */
function csvField(value: unknown): string {
  const text = value == null ? "" : String(value);
  return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

export default function FeesPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id || "";
  const { data: payments, isLoading, error, refetch } = useFeePayments(associationId);
  const { data: stats } = useFeeStats(associationId);
  const currentYear = new Date().getFullYear();

  const rows = payments || [];
  const collectionRate = stats?.collectionRate || 0;

  /**
   * The export button existed but had no click handler at all, so it looked
   * available and did nothing.
   */
  const handleExport = () => {
    if (rows.length === 0) {
      toast.error("Nothing to export", {
        description: "There are no payment records yet.",
      });
      return;
    }

    const header = ["Member", "Enrollment", "Receipt", "Year", "Amount", "Status", "Paid on"];
    const body = rows.map((p) =>
      [
        (p.member as any)?.name ?? "",
        (p.member as any)?.enrollment_number ?? "",
        p.receipt_number ?? "",
        `${p.fee_year}-${p.fee_year + 1}`,
        p.amount,
        p.status,
        p.paid_at ? formatDate(p.paid_at) : "",
      ]
        .map(csvField)
        .join(","),
    );

    const csv = [header.join(","), ...body].join("\n");
    // BOM so Excel opens the rupee sign and Indian names correctly.
    const blob = new Blob(["﻿" + csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);

    const link = document.createElement("a");
    link.href = url;
    link.download = `bardesk-fees-${currentYear}-${currentYear + 1}.csv`;
    link.click();
    URL.revokeObjectURL(url);

    toast.success(`Exported ${rows.length} record${rows.length === 1 ? "" : "s"}`);
  };

  const columns: Column<(typeof rows)[number]>[] = [
    {
      key: "member",
      header: "Member",
      primary: true,
      sortValue: (p) => (p.member as any)?.name,
      render: (p) => (
        <div className="flex items-center gap-3">
          <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-muted text-2xs font-semibold text-muted-foreground">
            {getInitials((p.member as any)?.name || "??")}
          </span>
          <div className="min-w-0">
            <p className="truncate font-medium text-foreground">
              {(p.member as any)?.name || "—"}
            </p>
            {(p.member as any)?.enrollment_number && (
              <p className="truncate text-2xs text-muted-foreground">
                {(p.member as any).enrollment_number}
              </p>
            )}
          </div>
        </div>
      ),
    },
    {
      key: "receipt_number",
      header: "Receipt",
      sortValue: (p) => p.receipt_number,
      render: (p) => (
        <span className="font-mono text-xs">{p.receipt_number || "—"}</span>
      ),
    },
    {
      key: "fee_year",
      header: "Year",
      sortValue: (p) => p.fee_year,
      render: (p) => `${p.fee_year}–${p.fee_year + 1}`,
    },
    {
      key: "amount",
      header: "Amount",
      align: "right",
      sortValue: (p) => p.amount,
      render: (p) => (
        <span className="font-semibold text-foreground">{formatCurrency(p.amount)}</span>
      ),
    },
    {
      key: "status",
      header: "Status",
      sortValue: (p) => p.status,
      render: (p) => (
        <span
          className={cn(
            "inline-flex rounded-full px-2 py-0.5 text-2xs font-semibold capitalize",
            statusTone[p.status] ?? "bg-destructive/10 text-destructive",
          )}
        >
          {p.status}
        </span>
      ),
    },
    {
      key: "paid_at",
      header: "Paid on",
      align: "right",
      sortValue: (p) => p.paid_at,
      render: (p) => (
        <span className="text-muted-foreground">
          {p.paid_at ? formatDate(p.paid_at) : "—"}
        </span>
      ),
    },
  ];

  return (
    <div>
      <PageHeader
        title="Fees"
        description={`Financial year ${currentYear}–${currentYear + 1}`}
        actions={
          <Button variant="outline" className="gap-2" onClick={handleExport}>
            <Download className="h-4 w-4" />
            Export CSV
          </Button>
        }
      />

      <div className="space-y-6">
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <KpiCard
            title="Collected"
            value={formatCurrency(stats?.totalCollected || 0)}
            icon={TrendingUp}
            color="success"
            hint={`of ${formatCurrency(stats?.totalExpected || 0)} expected`}
          />
          <KpiCard
            title="Paid"
            value={stats?.paidCount ?? 0}
            icon={CheckCircle}
            color="info"
            hint={`of ${stats?.totalMembers ?? 0} members`}
          />
          <KpiCard
            title="Pending"
            value={stats?.pendingCount ?? 0}
            icon={AlertCircle}
            color="warning"
            hint="members yet to pay"
          />
          <KpiCard
            title="Collection rate"
            value={`${collectionRate.toFixed(1)}%`}
            icon={Receipt}
            color="accent"
            hint={collectionRate >= 100 ? "Fully collected" : "of expected fees"}
          />
        </div>

        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="font-display text-md font-semibold">
              Collection progress
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div
              className="h-2.5 w-full overflow-hidden rounded-full bg-muted"
              role="progressbar"
              aria-valuenow={Math.round(collectionRate)}
              aria-valuemin={0}
              aria-valuemax={100}
              aria-label="Share of expected fees collected"
            >
              <div
                className="h-full rounded-full bg-success transition-all duration-500"
                style={{ width: `${Math.min(collectionRate, 100)}%` }}
              />
            </div>
            <div className="mt-2 flex justify-between text-sm text-muted-foreground">
              <span data-numeric>{formatCurrency(stats?.totalCollected || 0)}</span>
              <span data-numeric>{formatCurrency(stats?.totalExpected || 0)}</span>
            </div>
          </CardContent>
        </Card>

        <div>
          <h2 className="mb-3 font-display text-md font-semibold text-foreground">
            Payment records
          </h2>
          <DataTable
            data={rows}
            columns={columns}
            rowKey={(p) => p.id}
            isLoading={isLoading}
            error={error}
            onRetry={() => void refetch()}
            empty={{
              title: "No payment records",
              description:
                "Fee payments appear here once members have paid for the year.",
            }}
          />
        </div>
      </div>
    </div>
  );
}
