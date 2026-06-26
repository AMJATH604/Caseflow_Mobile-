import { useCurrentAdmin, useAssociation } from '@/hooks/useBarDesk';
import { Copy, Check } from 'lucide-react';
import { useState } from 'react';

export default function SettingsPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id || '';
  const { data: assoc, isLoading } = useAssociation(associationId);
  const [copied, setCopied] = useState(false);

  const copyInviteCode = () => {
    if (assoc?.invite_code) {
      navigator.clipboard.writeText(assoc.invite_code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="w-8 h-8 border-2 border-cyan-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="p-8 max-w-3xl mx-auto">
      <h1 className="text-2xl font-extrabold text-slate-900 mb-6">Settings</h1>

      {/* Association Info */}
      <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm mb-6">
        <h3 className="text-base font-bold text-slate-900 mb-4">Association Details</h3>
        <div className="space-y-4">
          <InfoRow label="Name" value={assoc?.name || '—'} />
          <InfoRow label="District" value={assoc?.district || '—'} />
          <InfoRow label="Court" value={assoc?.court || '—'} />
          <InfoRow label="Address" value={assoc?.address || '—'} />
          <InfoRow label="Annual Fee" value={`₹${assoc?.annual_fee || 0}`} />
          <InfoRow label="Subscription" value={assoc?.subscription_plan || 'free'} />
        </div>
      </div>

      {/* Invite Code */}
      <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm mb-6">
        <h3 className="text-base font-bold text-slate-900 mb-2">Invite Code</h3>
        <p className="text-sm text-slate-500 mb-4">Share this code with advocates to join your association in CaseFlow.</p>
        <div className="flex items-center gap-3">
          <div className="flex-1 px-5 py-4 bg-slate-50 rounded-xl border border-slate-200 text-center">
            <span className="text-3xl font-extrabold text-slate-900 tracking-[8px] font-mono">
              {assoc?.invite_code || '------'}
            </span>
          </div>
          <button
            onClick={copyInviteCode}
            className={`p-3 rounded-xl border transition ${
              copied
                ? 'bg-emerald-50 border-emerald-200 text-emerald-600'
                : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
            }`}
          >
            {copied ? <Check className="w-5 h-5" /> : <Copy className="w-5 h-5" />}
          </button>
        </div>
      </div>

      {/* Admin Info */}
      <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
        <h3 className="text-base font-bold text-slate-900 mb-4">Your Admin Role</h3>
        <div className="space-y-4">
          <InfoRow label="Role" value={(admin?.role || 'admin').replace('_', ' ').toUpperCase()} />
          <InfoRow label="Admin Since" value={admin?.created_at ? new Date(admin.created_at).toLocaleDateString() : '—'} />
        </div>
      </div>

      <p className="text-center text-xs text-slate-400 mt-8">
        BarDesk v0.1.0 • Powered by CaseFlow
      </p>
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between py-2 border-b border-slate-50 last:border-0">
      <span className="text-sm text-slate-500">{label}</span>
      <span className="text-sm font-semibold text-slate-800">{value}</span>
    </div>
  );
}
