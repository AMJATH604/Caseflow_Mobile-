import { useState } from 'react';
import { useElections, useCreateElection, useUpdateElection, useCurrentAdmin } from '@/hooks/useBarDesk';
import { formatDate } from '@/lib/utils';
import { Plus, Play, Square, Trophy, X, Clock } from 'lucide-react';

export default function ElectionsPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id || '';
  const { data: elections, isLoading } = useElections(associationId);
  const createElection = useCreateElection(associationId);
  const updateElection = useUpdateElection();

  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({
    title: '', description: '',
    nomination_start: '', nomination_end: '',
    voting_start: '', voting_end: '',
  });

  const handleCreate = async () => {
    await createElection.mutateAsync({ ...form, status: 'draft' } as any);
    setShowModal(false);
    setForm({ title: '', description: '', nomination_start: '', nomination_end: '', voting_start: '', voting_end: '' });
  };

  const handleStatusChange = async (id: string, newStatus: string) => {
    const confirmed = window.confirm(`Change election status to "${newStatus}"?`);
    if (!confirmed) return;
    await updateElection.mutateAsync({ id, status: newStatus } as any);
  };

  const getStatusBadge = (status: string) => {
    const config: Record<string, { bg: string; text: string; icon: any }> = {
      draft: { bg: 'bg-slate-100', text: 'text-slate-600', icon: Clock },
      nominations: { bg: 'bg-blue-50', text: 'text-blue-700', icon: Play },
      voting: { bg: 'bg-violet-50', text: 'text-violet-700', icon: Play },
      completed: { bg: 'bg-emerald-50', text: 'text-emerald-700', icon: Trophy },
      cancelled: { bg: 'bg-red-50', text: 'text-red-600', icon: Square },
    };
    const c = config[status] || config.draft;
    return (
      <span className={`inline-flex items-center gap-1 text-xs font-semibold px-2.5 py-1 rounded-lg ${c.bg} ${c.text}`}>
        <c.icon className="w-3 h-3" />
        {status}
      </span>
    );
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="w-8 h-8 border-2 border-cyan-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="p-8 max-w-5xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-extrabold text-slate-900">Elections</h1>
          <p className="text-sm text-slate-500 mt-1">Manage association elections and voting</p>
        </div>
        <button
          onClick={() => setShowModal(true)}
          className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-violet-600 text-white text-sm font-semibold hover:bg-violet-700 transition shadow-sm shadow-violet-500/20"
        >
          <Plus className="w-4 h-4" /> New Election
        </button>
      </div>

      {/* Election Cards */}
      <div className="space-y-4">
        {(elections || []).map((election) => (
          <div key={election.id} className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
            <div className="flex items-start justify-between mb-4">
              <div>
                <div className="flex items-center gap-3 mb-2">
                  <span className="text-xl">🗳️</span>
                  <h3 className="text-lg font-bold text-slate-900">{election.title}</h3>
                </div>
                {election.description && (
                  <p className="text-sm text-slate-500 ml-9">{election.description}</p>
                )}
              </div>
              {getStatusBadge(election.status)}
            </div>

            {/* Timeline */}
            <div className="grid grid-cols-4 gap-4 ml-9 mb-5">
              <TimelineStep label="Nom. Start" date={election.nomination_start} />
              <TimelineStep label="Nom. End" date={election.nomination_end} />
              <TimelineStep label="Vote Start" date={election.voting_start} />
              <TimelineStep label="Vote End" date={election.voting_end} />
            </div>

            {/* Actions */}
            <div className="flex gap-2 ml-9">
              {election.status === 'draft' && (
                <button
                  onClick={() => handleStatusChange(election.id, 'nominations')}
                  className="px-3 py-1.5 rounded-lg bg-blue-50 text-blue-700 text-xs font-semibold hover:bg-blue-100 transition"
                >
                  ▶ Open Nominations
                </button>
              )}
              {election.status === 'nominations' && (
                <button
                  onClick={() => handleStatusChange(election.id, 'voting')}
                  className="px-3 py-1.5 rounded-lg bg-violet-50 text-violet-700 text-xs font-semibold hover:bg-violet-100 transition"
                >
                  🗳️ Start Voting
                </button>
              )}
              {election.status === 'voting' && (
                <>
                  <button
                    onClick={() => handleStatusChange(election.id, 'completed')}
                    className="px-3 py-1.5 rounded-lg bg-emerald-50 text-emerald-700 text-xs font-semibold hover:bg-emerald-100 transition"
                  >
                    🏆 Close & Publish Results
                  </button>
                </>
              )}
              {['draft', 'nominations'].includes(election.status) && (
                <button
                  onClick={() => handleStatusChange(election.id, 'cancelled')}
                  className="px-3 py-1.5 rounded-lg bg-red-50 text-red-600 text-xs font-semibold hover:bg-red-100 transition"
                >
                  Cancel
                </button>
              )}
            </div>
          </div>
        ))}

        {(elections || []).length === 0 && (
          <div className="text-center py-16 text-slate-400">
            <p className="text-3xl">🗳️</p>
            <p className="mt-3 font-medium">No elections created</p>
            <p className="text-sm mt-1">Click "New Election" to set up the first election</p>
          </div>
        )}
      </div>

      {/* Create Election Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-lg p-6 shadow-xl">
            <div className="flex items-center justify-between mb-5">
              <h3 className="text-lg font-bold text-slate-900">Create Election</h3>
              <button onClick={() => setShowModal(false)} className="text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Election Title *</label>
                <input
                  type="text"
                  value={form.title}
                  onChange={(e) => setForm({ ...form, title: e.target.value })}
                  className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none"
                  placeholder="Annual Election 2026"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Description</label>
                <textarea
                  value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                  rows={2}
                  className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none resize-none"
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-1">Nomination Start</label>
                  <input type="date" value={form.nomination_start} onChange={(e) => setForm({ ...form, nomination_start: e.target.value })}
                    className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-1">Nomination End</label>
                  <input type="date" value={form.nomination_end} onChange={(e) => setForm({ ...form, nomination_end: e.target.value })}
                    className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-1">Voting Start</label>
                  <input type="date" value={form.voting_start} onChange={(e) => setForm({ ...form, voting_start: e.target.value })}
                    className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-1">Voting End</label>
                  <input type="date" value={form.voting_end} onChange={(e) => setForm({ ...form, voting_end: e.target.value })}
                    className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none" />
                </div>
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button onClick={() => setShowModal(false)} className="flex-1 py-2.5 rounded-xl border border-slate-200 text-sm font-semibold text-slate-600 hover:bg-slate-50 transition">Cancel</button>
              <button
                onClick={handleCreate}
                disabled={!form.title || createElection.isPending}
                className="flex-1 py-2.5 rounded-xl bg-violet-600 text-white text-sm font-semibold hover:bg-violet-700 disabled:opacity-50 transition"
              >
                {createElection.isPending ? 'Creating...' : 'Create Election'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function TimelineStep({ label, date }: { label: string; date: string }) {
  return (
    <div className="text-center">
      <p className="text-xs text-slate-400 mb-1">{label}</p>
      <p className="text-sm font-semibold text-slate-700">{date ? formatDate(date) : '—'}</p>
    </div>
  );
}
