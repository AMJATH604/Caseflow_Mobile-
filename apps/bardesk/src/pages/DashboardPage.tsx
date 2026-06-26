import { useDashboardStats, useCurrentAdmin, useNotices, useFeePayments } from '@/hooks/useBarDesk';
import { formatCurrency, formatDate } from '@/lib/utils';
import { Users, Receipt, Megaphone, Vote, TrendingUp, ArrowUpRight } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

export default function DashboardPage() {
  const navigate = useNavigate();
  const { data: admin, isLoading: adminLoading } = useCurrentAdmin();
  const associationId = admin?.association_id || '';
  const associationName = (admin as any)?.bar_associations?.name || 'Bar Association';

  const { data: stats, isLoading } = useDashboardStats(associationId);
  const { data: notices } = useNotices(associationId);
  const { data: payments } = useFeePayments(associationId);

  if (adminLoading || isLoading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="w-8 h-8 border-2 border-cyan-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const recentNotices = (notices || []).slice(0, 5);
  const recentPayments = (payments || []).filter(p => p.status === 'paid').slice(0, 5);
  const currentYear = new Date().getFullYear();

  return (
    <div className="p-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-extrabold text-slate-900">Dashboard</h1>
        <p className="text-sm text-slate-500 mt-1">{associationName} • {currentYear}–{currentYear + 1}</p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 mb-8">
        <StatCard
          icon={Users}
          label="Total Members"
          value={stats?.totalMembers || 0}
          sublabel={`${stats?.activeMembers || 0} active`}
          color="cyan"
          onClick={() => navigate('/members')}
        />
        <StatCard
          icon={Receipt}
          label="Fees Collected"
          value={formatCurrency(stats?.feeCollectedThisYear || 0)}
          sublabel={`${stats?.pendingPayments || 0} pending`}
          color="emerald"
          onClick={() => navigate('/fees')}
        />
        <StatCard
          icon={Megaphone}
          label="Total Notices"
          value={stats?.totalNotices || 0}
          sublabel="Published"
          color="violet"
          onClick={() => navigate('/notices')}
        />
        <StatCard
          icon={Vote}
          label="Election"
          value={stats?.activeElection ? 'Active' : 'None'}
          sublabel={stats?.activeElection ? 'In progress' : 'No active election'}
          color="rose"
          onClick={() => navigate('/elections')}
        />
      </div>

      {/* Two-Column Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Notices */}
        <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
          <div className="flex items-center justify-between mb-5">
            <h3 className="text-base font-bold text-slate-900">Recent Notices</h3>
            <button
              onClick={() => navigate('/notices')}
              className="text-xs font-semibold text-cyan-600 hover:text-cyan-700 flex items-center gap-1"
            >
              View All <ArrowUpRight className="w-3 h-3" />
            </button>
          </div>
          {recentNotices.length === 0 ? (
            <p className="text-sm text-slate-400 text-center py-8">No notices published yet</p>
          ) : (
            <div className="space-y-3">
              {recentNotices.map((notice) => (
                <div key={notice.id} className="flex items-start gap-3 p-3 rounded-xl hover:bg-slate-50 transition">
                  <div className={`w-2 h-2 rounded-full mt-2 flex-shrink-0 ${
                    notice.category === 'urgent' ? 'bg-red-500' :
                    notice.category === 'election' ? 'bg-violet-500' :
                    'bg-cyan-500'
                  }`} />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-slate-800 truncate">{notice.title}</p>
                    <div className="flex items-center gap-2 mt-1">
                      <span className="text-xs text-slate-400">{formatDate(notice.published_at)}</span>
                      <span className="text-xs text-slate-400">•</span>
                      <span className="text-xs text-slate-400">{notice.read_count} read</span>
                    </div>
                  </div>
                  {notice.is_pinned && (
                    <span className="text-xs bg-amber-50 text-amber-600 font-semibold px-2 py-0.5 rounded-md">📌</span>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Recent Payments */}
        <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
          <div className="flex items-center justify-between mb-5">
            <h3 className="text-base font-bold text-slate-900">Recent Fee Payments</h3>
            <button
              onClick={() => navigate('/fees')}
              className="text-xs font-semibold text-cyan-600 hover:text-cyan-700 flex items-center gap-1"
            >
              View All <ArrowUpRight className="w-3 h-3" />
            </button>
          </div>
          {recentPayments.length === 0 ? (
            <p className="text-sm text-slate-400 text-center py-8">No payments received yet</p>
          ) : (
            <div className="space-y-3">
              {recentPayments.map((payment) => (
                <div key={payment.id} className="flex items-center gap-3 p-3 rounded-xl hover:bg-slate-50 transition">
                  <div className="w-9 h-9 rounded-xl bg-emerald-50 flex items-center justify-center flex-shrink-0">
                    <TrendingUp className="w-4 h-4 text-emerald-600" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-slate-800 truncate">
                      {(payment.member as any)?.name || 'Member'}
                    </p>
                    <p className="text-xs text-slate-400">
                      {payment.receipt_number} • {payment.paid_at ? formatDate(payment.paid_at) : ''}
                    </p>
                  </div>
                  <span className="text-sm font-bold text-emerald-600">{formatCurrency(payment.amount)}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Quick Actions */}
      <div className="mt-6 bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
        <h3 className="text-base font-bold text-slate-900 mb-4">Quick Actions</h3>
        <div className="flex flex-wrap gap-3">
          <QuickAction label="Send Notice" icon="📢" onClick={() => navigate('/notices')} />
          <QuickAction label="Add Member" icon="👤" onClick={() => navigate('/members')} />
          <QuickAction label="View Pending Fees" icon="💰" onClick={() => navigate('/fees')} />
          <QuickAction label="Create Election" icon="🗳️" onClick={() => navigate('/elections')} />
          <QuickAction label="Add Event" icon="📅" onClick={() => navigate('/events')} />
        </div>
      </div>
    </div>
  );
}

function StatCard({ icon: Icon, label, value, sublabel, color, onClick }: {
  icon: any; label: string; value: string | number; sublabel: string; color: string; onClick: () => void;
}) {
  const colorClasses: Record<string, { bg: string; icon: string; text: string }> = {
    cyan: { bg: 'bg-cyan-50', icon: 'text-cyan-600', text: 'text-cyan-600' },
    emerald: { bg: 'bg-emerald-50', icon: 'text-emerald-600', text: 'text-emerald-600' },
    violet: { bg: 'bg-violet-50', icon: 'text-violet-600', text: 'text-violet-600' },
    rose: { bg: 'bg-rose-50', icon: 'text-rose-600', text: 'text-rose-600' },
  };
  const c = colorClasses[color] || colorClasses.cyan;

  return (
    <button
      onClick={onClick}
      className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm hover:shadow-md transition-all duration-200 text-left w-full group"
    >
      <div className="flex items-center justify-between mb-3">
        <div className={`w-10 h-10 rounded-xl ${c.bg} flex items-center justify-center`}>
          <Icon className={`w-5 h-5 ${c.icon}`} />
        </div>
        <ArrowUpRight className="w-4 h-4 text-slate-300 group-hover:text-slate-500 transition" />
      </div>
      <p className="text-2xl font-extrabold text-slate-900">{value}</p>
      <p className="text-xs text-slate-400 mt-0.5">{label} • {sublabel}</p>
    </button>
  );
}

function QuickAction({ label, icon, onClick }: { label: string; icon: string; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-slate-50 border border-slate-200 hover:bg-cyan-50 hover:border-cyan-200 transition-all text-sm font-medium text-slate-700"
    >
      <span>{icon}</span>
      {label}
    </button>
  );
}
