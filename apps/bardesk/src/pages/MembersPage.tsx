import { useState } from 'react';
import { useMembers, useAddMember, useUpdateMember, useCurrentAdmin } from '@/hooks/useBarDesk';
import { getInitials, getMembershipBadge } from '@/lib/utils';
import { Search, Plus, UserCheck, UserX, X } from 'lucide-react';

export default function MembersPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id || '';
  const { data: members, isLoading } = useMembers(associationId);
  const addMember = useAddMember(associationId);
  const updateMember = useUpdateMember();

  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [showAddModal, setShowAddModal] = useState(false);
  const [newMember, setNewMember] = useState({ name: '', mobile: '', email: '', enrollment_number: '', membership_type: 'regular' as const });

  const filtered = (members || []).filter((m) => {
    const matchesSearch = m.name.toLowerCase().includes(search.toLowerCase()) ||
      (m.enrollment_number || '').toLowerCase().includes(search.toLowerCase()) ||
      m.mobile.includes(search);
    const matchesStatus = statusFilter === 'all' || m.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  const statusCounts = {
    all: (members || []).length,
    active: (members || []).filter(m => m.status === 'active').length,
    suspended: (members || []).filter(m => m.status === 'suspended').length,
  };

  const handleAdd = async () => {
    await addMember.mutateAsync({ ...newMember, status: 'active', is_caseflow_user: false });
    setShowAddModal(false);
    setNewMember({ name: '', mobile: '', email: '', enrollment_number: '', membership_type: 'regular' });
  };

  const toggleStatus = async (id: string, current: string) => {
    await updateMember.mutateAsync({
      id,
      status: current === 'active' ? 'suspended' : 'active',
    } as any);
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="w-8 h-8 border-2 border-cyan-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="p-8 max-w-7xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-extrabold text-slate-900">Members</h1>
          <p className="text-sm text-slate-500 mt-1">{statusCounts.all} total • {statusCounts.active} active</p>
        </div>
        <button
          onClick={() => setShowAddModal(true)}
          className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-cyan-600 text-white text-sm font-semibold hover:bg-cyan-700 transition shadow-sm shadow-cyan-500/20"
        >
          <Plus className="w-4 h-4" /> Add Member
        </button>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3 mb-6">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="text"
            placeholder="Search by name, enrollment, or mobile..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none transition"
          />
        </div>
        {(['all', 'active', 'suspended'] as const).map((s) => (
          <button
            key={s}
            onClick={() => setStatusFilter(s)}
            className={`px-3 py-2 rounded-xl text-xs font-semibold transition ${
              statusFilter === s
                ? 'bg-cyan-600 text-white'
                : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-50'
            }`}
          >
            {s.charAt(0).toUpperCase() + s.slice(1)} ({statusCounts[s as keyof typeof statusCounts] || 0})
          </button>
        ))}
      </div>

      {/* Members Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="border-b border-slate-100">
              <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Member</th>
              <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Enrollment</th>
              <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Mobile</th>
              <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Type</th>
              <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Status</th>
              <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">CaseFlow</th>
              <th className="text-right py-3 px-4 text-xs font-semibold text-slate-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((member) => (
              <tr key={member.id} className="border-b border-slate-50 hover:bg-slate-50/50 transition">
                <td className="py-3 px-4">
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center text-xs font-bold text-slate-600">
                      {getInitials(member.name)}
                    </div>
                    <span className="text-sm font-semibold text-slate-800">{member.name}</span>
                  </div>
                </td>
                <td className="py-3 px-4 text-sm text-slate-600">{member.enrollment_number || '—'}</td>
                <td className="py-3 px-4 text-sm text-slate-600">{member.mobile || '—'}</td>
                <td className="py-3 px-4">
                  <span className="text-xs font-semibold px-2 py-1 rounded-lg bg-slate-100 text-slate-600">
                    {getMembershipBadge(member.membership_type)}
                  </span>
                </td>
                <td className="py-3 px-4">
                  <span className={`inline-flex items-center gap-1 text-xs font-semibold px-2 py-1 rounded-lg ${
                    member.status === 'active'
                      ? 'bg-emerald-50 text-emerald-700'
                      : 'bg-red-50 text-red-600'
                  }`}>
                    {member.status === 'active' ? <UserCheck className="w-3 h-3" /> : <UserX className="w-3 h-3" />}
                    {member.status}
                  </span>
                </td>
                <td className="py-3 px-4">
                  {member.is_caseflow_user ? (
                    <span className="text-xs bg-cyan-50 text-cyan-700 font-semibold px-2 py-1 rounded-lg">✓ Linked</span>
                  ) : (
                    <span className="text-xs text-slate-400">—</span>
                  )}
                </td>
                <td className="py-3 px-4 text-right">
                  <button
                    onClick={() => toggleStatus(member.id, member.status)}
                    className={`text-xs font-semibold px-3 py-1.5 rounded-lg transition ${
                      member.status === 'active'
                        ? 'bg-red-50 text-red-600 hover:bg-red-100'
                        : 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100'
                    }`}
                  >
                    {member.status === 'active' ? 'Suspend' : 'Activate'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {filtered.length === 0 && (
          <div className="text-center py-12 text-sm text-slate-400">No members found</div>
        )}
      </div>

      {/* Add Member Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-md p-6 shadow-xl">
            <div className="flex items-center justify-between mb-5">
              <h3 className="text-lg font-bold text-slate-900">Add New Member</h3>
              <button onClick={() => setShowAddModal(false)} className="text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Full Name *</label>
                <input
                  type="text"
                  value={newMember.name}
                  onChange={(e) => setNewMember({ ...newMember, name: e.target.value })}
                  className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none"
                  placeholder="Adv. Ramesh Kumar"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Enrollment Number</label>
                <input
                  type="text"
                  value={newMember.enrollment_number}
                  onChange={(e) => setNewMember({ ...newMember, enrollment_number: e.target.value })}
                  className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none"
                  placeholder="TN/1234/2020"
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-1">Mobile *</label>
                  <input
                    type="tel"
                    value={newMember.mobile}
                    onChange={(e) => setNewMember({ ...newMember, mobile: e.target.value })}
                    className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none"
                    placeholder="9876543210"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-1">Email</label>
                  <input
                    type="email"
                    value={newMember.email}
                    onChange={(e) => setNewMember({ ...newMember, email: e.target.value })}
                    className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none"
                    placeholder="email@example.com"
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Membership Type</label>
                <select
                  value={newMember.membership_type}
                  onChange={(e) => setNewMember({ ...newMember, membership_type: e.target.value as any })}
                  className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none"
                >
                  <option value="regular">Regular</option>
                  <option value="life">Life Member</option>
                  <option value="honorary">Honorary</option>
                  <option value="student">Student</option>
                </select>
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button
                onClick={() => setShowAddModal(false)}
                className="flex-1 py-2.5 rounded-xl border border-slate-200 text-sm font-semibold text-slate-600 hover:bg-slate-50 transition"
              >
                Cancel
              </button>
              <button
                onClick={handleAdd}
                disabled={!newMember.name || !newMember.mobile || addMember.isPending}
                className="flex-1 py-2.5 rounded-xl bg-cyan-600 text-white text-sm font-semibold hover:bg-cyan-700 disabled:opacity-50 transition"
              >
                {addMember.isPending ? 'Adding...' : 'Add Member'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
