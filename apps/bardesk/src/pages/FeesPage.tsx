import { useFeePayments, useFeeStats, useCurrentAdmin } from '@/hooks/useBarDesk';
import { formatCurrency, formatDate, getInitials } from '@/lib/utils';
import { TrendingUp, AlertCircle, CheckCircle, Download } from 'lucide-react';

export default function FeesPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id || '';
  const { data: payments, isLoading } = useFeePayments(associationId);
  const { data: stats } = useFeeStats(associationId);
  const currentYear = new Date().getFullYear();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="w-8 h-8 border-2 border-cyan-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const paidPayments = (payments || []).filter(p => p.status === 'paid');
  const pendingPayments = (payments || []).filter(p => p.status === 'pending');

  return (
    <div className="p-8 max-w-7xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-extrabold text-slate-900">Fee Management</h1>
          <p className="text-sm text-slate-500 mt-1">Financial year {currentYear}–{currentYear + 1}</p>
        </div>
        <button className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-white border border-slate-200 text-sm font-semibold text-slate-700 hover:bg-slate-50 transition">
          <Download className="w-4 h-4" /> Export CSV
        </button>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 mb-8">
        <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-xl bg-emerald-50 flex items-center justify-center">
              <TrendingUp className="w-5 h-5 text-emerald-600" />
            </div>
            <span className="text-xs font-semibold text-slate-500 uppercase">Collected</span>
          </div>
          <p className="text-2xl font-extrabold text-slate-900">{formatCurrency(stats?.totalCollected || 0)}</p>
          <p className="text-xs text-slate-400 mt-1">of {formatCurrency(stats?.totalExpected || 0)} expected</p>
        </div>

        <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-xl bg-cyan-50 flex items-center justify-center">
              <CheckCircle className="w-5 h-5 text-cyan-600" />
            </div>
            <span className="text-xs font-semibold text-slate-500 uppercase">Paid</span>
          </div>
          <p className="text-2xl font-extrabold text-slate-900">{stats?.paidCount || 0}</p>
          <p className="text-xs text-slate-400 mt-1">of {stats?.totalMembers || 0} members</p>
        </div>

        <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-xl bg-amber-50 flex items-center justify-center">
              <AlertCircle className="w-5 h-5 text-amber-600" />
            </div>
            <span className="text-xs font-semibold text-slate-500 uppercase">Pending</span>
          </div>
          <p className="text-2xl font-extrabold text-slate-900">{stats?.pendingCount || 0}</p>
          <p className="text-xs text-slate-400 mt-1">members unpaid</p>
        </div>

        <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-xl bg-violet-50 flex items-center justify-center">
              <TrendingUp className="w-5 h-5 text-violet-600" />
            </div>
            <span className="text-xs font-semibold text-slate-500 uppercase">Collection Rate</span>
          </div>
          <p className="text-2xl font-extrabold text-slate-900">{(stats?.collectionRate || 0).toFixed(1)}%</p>
          <div className="mt-2 bg-slate-100 rounded-full h-2 overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-cyan-500 to-emerald-500 rounded-full transition-all duration-500"
              style={{ width: `${Math.min(stats?.collectionRate || 0, 100)}%` }}
            />
          </div>
        </div>
      </div>

      {/* Payments Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="p-5 border-b border-slate-100">
          <h3 className="text-base font-bold text-slate-900">Payment Records</h3>
        </div>
        <table className="w-full">
          <thead>
            <tr className="border-b border-slate-100">
              <th className="text-left py-3 px-5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Member</th>
              <th className="text-left py-3 px-5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Receipt</th>
              <th className="text-left py-3 px-5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Year</th>
              <th className="text-left py-3 px-5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Amount</th>
              <th className="text-left py-3 px-5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Status</th>
              <th className="text-left py-3 px-5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Date</th>
            </tr>
          </thead>
          <tbody>
            {(payments || []).map((p) => (
              <tr key={p.id} className="border-b border-slate-50 hover:bg-slate-50/50 transition">
                <td className="py-3 px-5">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-slate-100 flex items-center justify-center text-xs font-bold text-slate-600">
                      {getInitials((p.member as any)?.name || 'U')}
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-slate-800">{(p.member as any)?.name || '—'}</p>
                      <p className="text-xs text-slate-400">{(p.member as any)?.enrollment_number || ''}</p>
                    </div>
                  </div>
                </td>
                <td className="py-3 px-5 text-sm text-slate-600 font-mono">{p.receipt_number || '—'}</td>
                <td className="py-3 px-5 text-sm text-slate-600">{p.fee_year}–{p.fee_year + 1}</td>
                <td className="py-3 px-5 text-sm font-bold text-slate-800">{formatCurrency(p.amount)}</td>
                <td className="py-3 px-5">
                  <span className={`inline-flex text-xs font-semibold px-2 py-1 rounded-lg ${
                    p.status === 'paid'
                      ? 'bg-emerald-50 text-emerald-700'
                      : p.status === 'pending'
                      ? 'bg-amber-50 text-amber-700'
                      : 'bg-red-50 text-red-600'
                  }`}>
                    {p.status}
                  </span>
                </td>
                <td className="py-3 px-5 text-sm text-slate-500">{p.paid_at ? formatDate(p.paid_at) : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {(payments || []).length === 0 && (
          <div className="text-center py-12 text-sm text-slate-400">No payment records</div>
        )}
      </div>
    </div>
  );
}
