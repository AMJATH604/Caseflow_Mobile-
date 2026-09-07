import { useState } from "react";
import { toast } from "sonner";
import { Copy, Check, Building2, ShieldCheck } from "lucide-react";

import { useCurrentAdmin, useAssociation } from "@/hooks/useBarDesk";
import { formatCurrency, formatDate } from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";

export default function SettingsPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id || "";
  const { data: assoc, isLoading } = useAssociation(associationId);
  const [copied, setCopied] = useState(false);

  const copyInviteCode = async () => {
    if (!assoc?.invite_code) return;
    try {
      await navigator.clipboard.writeText(assoc.invite_code);
      setCopied(true);
      toast.success("Invite code copied");
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Clipboard access is denied in some browsers and over plain http.
      toast.error("Could not copy", {
        description: "Select the code and copy it manually.",
      });
    }
  };

  if (isLoading) {
    return (
      <div className="max-w-3xl space-y-6">
        <Skeleton className="h-9 w-40" />
        <Skeleton className="h-64 rounded-xl" />
        <Skeleton className="h-44 rounded-xl" />
      </div>
    );
  }

  return (
    <div className="max-w-3xl">
      <PageHeader
        title="Settings"
        description="Association profile and your access"
      />

      <div className="space-y-6">
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 font-display text-md font-semibold">
              <Building2 className="h-4 w-4 text-muted-foreground" />
              Association
            </CardTitle>
            <CardDescription className="text-sm">
              These details are managed by CaseFlow support — contact them to change anything here.
            </CardDescription>
          </CardHeader>
          <CardContent className="divide-y divide-border">
            <InfoRow label="Name" value={assoc?.name} />
            <InfoRow label="District" value={assoc?.district} />
            <InfoRow label="Court" value={assoc?.court} />
            <InfoRow label="Address" value={assoc?.address} />
            <InfoRow
              label="Annual fee"
              value={assoc?.annual_fee != null ? formatCurrency(assoc.annual_fee) : undefined}
              numeric
            />
            <InfoRow
              label="Plan"
              value={assoc?.subscription_plan || "free"}
              badge
            />
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="font-display text-md font-semibold">Invite code</CardTitle>
            <CardDescription className="text-sm">
              Advocates enter this in CaseFlow to join your association.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex items-center gap-3">
              <div className="flex-1 rounded-xl border border-border bg-muted/40 px-5 py-4 text-center">
                <span
                  data-numeric
                  className="font-mono text-2xl font-bold tracking-[0.4em] text-foreground"
                >
                  {assoc?.invite_code || "——————"}
                </span>
              </div>
              <Button
                variant="outline"
                size="icon"
                className="h-12 w-12 shrink-0"
                onClick={() => void copyInviteCode()}
                disabled={!assoc?.invite_code}
                aria-label="Copy invite code"
              >
                {copied ? (
                  <Check className="h-5 w-5 text-success" />
                ) : (
                  <Copy className="h-5 w-5" />
                )}
              </Button>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 font-display text-md font-semibold">
              <ShieldCheck className="h-4 w-4 text-muted-foreground" />
              Your access
            </CardTitle>
          </CardHeader>
          <CardContent className="divide-y divide-border">
            <InfoRow
              label="Role"
              value={(admin?.role || "admin").replace(/_/g, " ")}
              badge
            />
            <InfoRow
              label="Admin since"
              value={admin?.created_at ? formatDate(admin.created_at) : undefined}
            />
          </CardContent>
        </Card>

        <p className="text-center text-2xs text-muted-foreground">
          BarDesk · Powered by CaseFlow
        </p>
      </div>
    </div>
  );
}

function InfoRow({
  label,
  value,
  badge,
  numeric,
}: {
  label: string;
  value?: string | null;
  badge?: boolean;
  numeric?: boolean;
}) {
  return (
    <div className="flex items-center justify-between gap-4 py-3 first:pt-0 last:pb-0">
      <span className="shrink-0 text-sm text-muted-foreground">{label}</span>
      {value ? (
        badge ? (
          <Badge variant="secondary" className="font-normal capitalize">
            {value}
          </Badge>
        ) : (
          <span
            {...(numeric ? { "data-numeric": true } : {})}
            className="truncate text-sm font-medium text-foreground"
          >
            {value}
          </span>
        )
      ) : (
        <span className="text-sm text-muted-foreground">—</span>
      )}
    </div>
  );
}
