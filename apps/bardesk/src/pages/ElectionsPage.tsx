import { useState } from 'react';
import {
  useElections, useCreateElection, useUpdateElection, useDeleteElection,
  useElectionPosts, useCreateElectionPost, useDeleteElectionPost,
  useNominations, useCreateNomination, useDeleteNomination,
  useVoteCounts, useMembers, useCurrentAdmin,
} from '@/hooks/useBarDesk';
import { formatDate } from '@/lib/utils';
import {
  Plus, Play, Square, Trophy, X, Clock, Trash2,
  ChevronRight, ChevronLeft, Users, Award, Eye, Vote,
} from 'lucide-react';

export default function ElectionsPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id || '';
  const { data: elections, isLoading } = useElections(associationId);
  const createElection = useCreateElection(associationId);
  const updateElection = useUpdateElection();
  const deleteElection = useDeleteElection();

  const [showWizard, setShowWizard] = useState(false);
  const [wizardStep, setWizardStep] = useState(1);
  const [createdElectionId, setCreatedElectionId] = useState('');
  const [viewingElection, setViewingElection] = useState<string | null>(null);
  const [form, setForm] = useState({
    title: '', description: '',
    voting_start: '', voting_end: '',
  });

  const handleCreateElection = async () => {
    const result = await createElection.mutateAsync({
      ...form,
      nomination_start: form.voting_start,
      nomination_end: form.voting_start,
      status: 'draft',
    } as any);
    setCreatedElectionId(result.id);
    setWizardStep(2);
  };

  const handleStatusChange = async (id: string, newStatus: string) => {
    const confirmed = window.confirm(`Change election status to "${newStatus}"?`);
    if (!confirmed) return;
    await updateElection.mutateAsync({ id, status: newStatus } as any);
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Delete this election? This action cannot be undone.')) return;
    await deleteElection.mutateAsync(id);
  };

  const resetWizard = () => {
    setShowWizard(false);
    setWizardStep(1);
    setCreatedElectionId('');
    setForm({ title: '', description: '', voting_start: '', voting_end: '' });
  };

  const getStatusBadge = (status: string) => {
    const config: Record<string, { bg: string; text: string; icon: any }> = {
      draft: { bg: 'bg-slate-100', text: 'text-slate-600', icon: Clock },
      nominations: { bg: 'bg-blue-50', text: 'text-blue-700', icon: Play },
      voting: { bg: 'bg-violet-50', text: 'text-violet-700', icon: Vote },
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
          onClick={() => setShowWizard(true)}
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
            <div className="grid grid-cols-2 gap-4 ml-9 mb-5">
              <TimelineStep label="Voting Start" date={election.voting_start} />
              <TimelineStep label="Voting End" date={election.voting_end} />
            </div>

            {/* Actions */}
            <div className="flex gap-2 ml-9 flex-wrap">
              {election.status === 'draft' && (
                <>
                  <button
                    onClick={() => setViewingElection(election.id)}
                    className="px-3 py-1.5 rounded-lg bg-slate-50 text-slate-700 text-xs font-semibold hover:bg-slate-100 transition flex items-center gap-1"
                  >
                    <Eye className="w-3 h-3" /> Manage Posts & Candidates
                  </button>
                  <button
                    onClick={() => handleStatusChange(election.id, 'voting')}
                    className="px-3 py-1.5 rounded-lg bg-violet-50 text-violet-700 text-xs font-semibold hover:bg-violet-100 transition"
                  >
                    🗳️ Open Voting
                  </button>
                </>
              )}
              {election.status === 'voting' && (
                <>
                  <button
                    onClick={() => setViewingElection(election.id)}
                    className="px-3 py-1.5 rounded-lg bg-slate-50 text-slate-700 text-xs font-semibold hover:bg-slate-100 transition flex items-center gap-1"
                  >
                    <Eye className="w-3 h-3" /> View Live Results
                  </button>
                  <button
                    onClick={() => handleStatusChange(election.id, 'completed')}
                    className="px-3 py-1.5 rounded-lg bg-emerald-50 text-emerald-700 text-xs font-semibold hover:bg-emerald-100 transition"
                  >
                    🏆 Close & Publish Results
                  </button>
                </>
              )}
              {election.status === 'completed' && (
                <button
                  onClick={() => setViewingElection(election.id)}
                  className="px-3 py-1.5 rounded-lg bg-emerald-50 text-emerald-700 text-xs font-semibold hover:bg-emerald-100 transition flex items-center gap-1"
                >
                  <Trophy className="w-3 h-3" /> View Results
                </button>
              )}
              {['draft', 'cancelled'].includes(election.status) && (
                <button
                  onClick={() => handleDelete(election.id)}
                  className="px-3 py-1.5 rounded-lg bg-red-50 text-red-600 text-xs font-semibold hover:bg-red-100 transition flex items-center gap-1"
                >
                  <Trash2 className="w-3 h-3" /> Delete
                </button>
              )}
              {['draft', 'voting'].includes(election.status) && (
                <button
                  onClick={() => handleStatusChange(election.id, 'cancelled')}
                  className="px-3 py-1.5 rounded-lg bg-red-50 text-red-600 text-xs font-semibold hover:bg-red-100 transition"
                >
                  Cancel Election
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

      {/* ── Election Creation Wizard ── */}
      {showWizard && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-xl p-6 shadow-xl max-h-[90vh] overflow-y-auto">
            {/* Wizard Header */}
            <div className="flex items-center justify-between mb-6">
              <div>
                <h3 className="text-lg font-bold text-slate-900">
                  {wizardStep === 1 && 'Step 1 — Create Election'}
                  {wizardStep === 2 && 'Step 2 — Add Posts'}
                  {wizardStep === 3 && 'Step 3 — Add Candidates'}
                </h3>
                <div className="flex gap-2 mt-2">
                  {[1, 2, 3].map((s) => (
                    <div
                      key={s}
                      className={`h-1.5 rounded-full flex-1 transition-all ${
                        s <= wizardStep ? 'bg-violet-500' : 'bg-slate-200'
                      }`}
                    />
                  ))}
                </div>
              </div>
              <button onClick={resetWizard} className="text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Step 1: Election Details */}
            {wizardStep === 1 && (
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
                    <label className="block text-sm font-medium text-slate-700 mb-1">Voting Start *</label>
                    <input type="date" value={form.voting_start} onChange={(e) => setForm({ ...form, voting_start: e.target.value })}
                      className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none" />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-slate-700 mb-1">Voting End *</label>
                    <input type="date" value={form.voting_end} onChange={(e) => setForm({ ...form, voting_end: e.target.value })}
                      className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none" />
                  </div>
                </div>
                <div className="flex gap-3 mt-6">
                  <button onClick={resetWizard} className="flex-1 py-2.5 rounded-xl border border-slate-200 text-sm font-semibold text-slate-600 hover:bg-slate-50 transition">Cancel</button>
                  <button
                    onClick={handleCreateElection}
                    disabled={!form.title || !form.voting_start || !form.voting_end || createElection.isPending}
                    className="flex-1 py-2.5 rounded-xl bg-violet-600 text-white text-sm font-semibold hover:bg-violet-700 disabled:opacity-50 transition flex items-center justify-center gap-2"
                  >
                    {createElection.isPending ? 'Creating...' : 'Next — Add Posts'}
                    <ChevronRight className="w-4 h-4" />
                  </button>
                </div>
              </div>
            )}

            {/* Step 2: Add Posts */}
            {wizardStep === 2 && <PostsStep electionId={createdElectionId} onNext={() => setWizardStep(3)} onBack={() => setWizardStep(1)} />}

            {/* Step 3: Add Candidates */}
            {wizardStep === 3 && <CandidatesStep electionId={createdElectionId} associationId={associationId} onDone={resetWizard} onBack={() => setWizardStep(2)} />}
          </div>
        </div>
      )}

      {/* ── Election Detail / Results View ── */}
      {viewingElection && (
        <ElectionDetailView
          electionId={viewingElection}
          associationId={associationId}
          onClose={() => setViewingElection(null)}
        />
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// Step 2: Posts Step
// ═══════════════════════════════════════════════════════════
function PostsStep({ electionId, onNext, onBack }: { electionId: string; onNext: () => void; onBack: () => void }) {
  const { data: posts } = useElectionPosts(electionId);
  const createPost = useCreateElectionPost(electionId);
  const deletePost = useDeleteElectionPost(electionId);
  const [postName, setPostName] = useState('');

  const presets = ['President', 'Vice President', 'Secretary', 'Joint Secretary', 'Treasurer'];
  const existingNames = (posts || []).map(p => p.post_name.toLowerCase());

  const handleAdd = async (name: string) => {
    if (!name.trim() || existingNames.includes(name.toLowerCase())) return;
    await createPost.mutateAsync({ post_name: name.trim() });
    setPostName('');
  };

  return (
    <div className="space-y-4">
      <p className="text-sm text-slate-500">Add the positions members will vote for (e.g. President, Secretary).</p>

      {/* Quick Add Presets */}
      <div className="flex flex-wrap gap-2">
        {presets.filter(p => !existingNames.includes(p.toLowerCase())).map((p) => (
          <button
            key={p}
            onClick={() => handleAdd(p)}
            className="px-3 py-1.5 rounded-lg border border-dashed border-slate-300 text-xs font-medium text-slate-600 hover:bg-violet-50 hover:border-violet-300 hover:text-violet-700 transition"
          >
            + {p}
          </button>
        ))}
      </div>

      {/* Custom Post Input */}
      <div className="flex gap-2">
        <input
          type="text"
          value={postName}
          onChange={(e) => setPostName(e.target.value)}
          placeholder="Custom post name..."
          className="flex-1 px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none"
          onKeyDown={(e) => e.key === 'Enter' && handleAdd(postName)}
        />
        <button
          onClick={() => handleAdd(postName)}
          disabled={!postName.trim() || createPost.isPending}
          className="px-4 py-2.5 rounded-xl bg-violet-600 text-white text-sm font-semibold hover:bg-violet-700 disabled:opacity-50 transition"
        >
          Add
        </button>
      </div>

      {/* Added Posts */}
      <div className="space-y-2">
        {(posts || []).map((post) => (
          <div key={post.id} className="flex items-center justify-between bg-slate-50 rounded-xl px-4 py-3">
            <div className="flex items-center gap-2">
              <Award className="w-4 h-4 text-violet-500" />
              <span className="text-sm font-semibold text-slate-800">{post.post_name}</span>
            </div>
            <button
              onClick={() => deletePost.mutateAsync(post.id)}
              className="text-slate-400 hover:text-red-500 transition"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          </div>
        ))}
      </div>

      {(posts || []).length === 0 && (
        <p className="text-center text-sm text-slate-400 py-4">No posts added yet. Add at least one post to continue.</p>
      )}

      <div className="flex gap-3 mt-6">
        <button onClick={onBack} className="flex-1 py-2.5 rounded-xl border border-slate-200 text-sm font-semibold text-slate-600 hover:bg-slate-50 transition flex items-center justify-center gap-1">
          <ChevronLeft className="w-4 h-4" /> Back
        </button>
        <button
          onClick={onNext}
          disabled={(posts || []).length === 0}
          className="flex-1 py-2.5 rounded-xl bg-violet-600 text-white text-sm font-semibold hover:bg-violet-700 disabled:opacity-50 transition flex items-center justify-center gap-2"
        >
          Next — Add Candidates <ChevronRight className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// Step 3: Candidates Step
// ═══════════════════════════════════════════════════════════
function CandidatesStep({ electionId, associationId, onDone, onBack }: {
  electionId: string; associationId: string; onDone: () => void; onBack: () => void;
}) {
  const { data: posts } = useElectionPosts(electionId);
  const { data: members } = useMembers(associationId);
  const activeMembers = (members || []).filter(m => m.status === 'active');

  return (
    <div className="space-y-6">
      <p className="text-sm text-slate-500">Select candidates from the member list for each post.</p>

      {(posts || []).map((post) => (
        <PostCandidates key={post.id} post={post} members={activeMembers} />
      ))}

      <div className="flex gap-3 mt-6">
        <button onClick={onBack} className="flex-1 py-2.5 rounded-xl border border-slate-200 text-sm font-semibold text-slate-600 hover:bg-slate-50 transition flex items-center justify-center gap-1">
          <ChevronLeft className="w-4 h-4" /> Back
        </button>
        <button
          onClick={onDone}
          className="flex-1 py-2.5 rounded-xl bg-emerald-600 text-white text-sm font-semibold hover:bg-emerald-700 transition flex items-center justify-center gap-2"
        >
          ✅ Done — Election Ready
        </button>
      </div>
    </div>
  );
}

function PostCandidates({ post, members }: { post: any; members: any[] }) {
  const { data: nominations } = useNominations(post.id);
  const createNom = useCreateNomination(post.id);
  const deleteNom = useDeleteNomination(post.id);
  const [selectedMember, setSelectedMember] = useState('');

  const nomineeIds = (nominations || []).map((n: any) => n.nominee_member_id);
  const available = members.filter(m => !nomineeIds.includes(m.id));

  const handleAdd = async () => {
    if (!selectedMember) return;
    await createNom.mutateAsync({ nominee_member_id: selectedMember });
    setSelectedMember('');
  };

  return (
    <div className="bg-slate-50 rounded-2xl p-4">
      <div className="flex items-center gap-2 mb-3">
        <Award className="w-4 h-4 text-violet-500" />
        <h4 className="text-sm font-bold text-slate-800">{post.post_name}</h4>
        <span className="text-xs text-slate-400">({(nominations || []).length} candidates)</span>
      </div>

      {/* Add Candidate */}
      <div className="flex gap-2 mb-3">
        <select
          value={selectedMember}
          onChange={(e) => setSelectedMember(e.target.value)}
          className="flex-1 px-3 py-2 rounded-xl border border-slate-200 text-sm focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none bg-white"
        >
          <option value="">Select a member...</option>
          {available.map((m) => (
            <option key={m.id} value={m.id}>{m.name} {m.enrollment_number ? `(${m.enrollment_number})` : ''}</option>
          ))}
        </select>
        <button
          onClick={handleAdd}
          disabled={!selectedMember || createNom.isPending}
          className="px-4 py-2 rounded-xl bg-violet-600 text-white text-xs font-semibold hover:bg-violet-700 disabled:opacity-50 transition"
        >
          Add
        </button>
      </div>

      {/* Candidate List */}
      <div className="space-y-1">
        {(nominations || []).map((nom: any) => (
          <div key={nom.id} className="flex items-center justify-between bg-white rounded-xl px-3 py-2">
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 rounded-full bg-violet-100 flex items-center justify-center text-xs font-bold text-violet-700">
                {(nom.nominee?.name || nom.nominee_member_id || 'U')[0].toUpperCase()}
              </div>
              <span className="text-sm font-medium text-slate-700">{nom.nominee?.name || 'Member'}</span>
            </div>
            <button
              onClick={() => deleteNom.mutateAsync(nom.id)}
              className="text-slate-400 hover:text-red-500 transition"
            >
              <Trash2 className="w-3.5 h-3.5" />
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// Election Detail / Results View
// ═══════════════════════════════════════════════════════════
function ElectionDetailView({ electionId, associationId, onClose }: {
  electionId: string; associationId: string; onClose: () => void;
}) {
  const { data: posts } = useElectionPosts(electionId);

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl w-full max-w-2xl p-6 shadow-xl max-h-[85vh] overflow-y-auto">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-lg font-bold text-slate-900">Election Posts & Results</h3>
          <button onClick={onClose} className="text-slate-400 hover:text-slate-600">
            <X className="w-5 h-5" />
          </button>
        </div>

        {(posts || []).length === 0 && (
          <p className="text-center text-sm text-slate-400 py-8">No posts have been added to this election yet.</p>
        )}

        {(posts || []).map((post) => (
          <PostResultCard key={post.id} post={post} />
        ))}
      </div>
    </div>
  );
}

function PostResultCard({ post }: { post: any }) {
  const { data: nominations } = useNominations(post.id);
  const { data: voteCounts } = useVoteCounts(post.id);

  const totalVotes = (voteCounts || []).reduce((s: number, v: any) => s + (v.vote_count || 0), 0);

  // Sort by vote count descending
  const sorted = [...(nominations || [])].sort((a: any, b: any) => {
    const aVotes = (voteCounts || []).find((v: any) => v.nomination_id === a.id)?.vote_count || 0;
    const bVotes = (voteCounts || []).find((v: any) => v.nomination_id === b.id)?.vote_count || 0;
    return bVotes - aVotes;
  });

  return (
    <div className="mb-4 bg-slate-50 rounded-2xl overflow-hidden">
      <div className="px-5 py-3 bg-violet-50 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Award className="w-4 h-4 text-violet-600" />
          <span className="text-sm font-bold text-violet-700">{post.post_name}</span>
        </div>
        <span className="text-xs text-slate-400">{totalVotes} votes</span>
      </div>
      <div className="p-4 space-y-3">
        {sorted.map((nom: any, index: number) => {
          const votes = (voteCounts || []).find((v: any) => v.nomination_id === nom.id)?.vote_count || 0;
          const pct = totalVotes > 0 ? (votes / totalVotes) * 100 : 0;
          const isWinner = index === 0 && totalVotes > 0;

          return (
            <div key={nom.id} className="flex items-center gap-3">
              {isWinner ? <span className="text-lg">🏆</span> : <span className="w-[1.125rem]" />}
              <div className="w-8 h-8 rounded-full bg-violet-100 flex items-center justify-center text-xs font-bold text-violet-700">
                {(nom.nominee?.name || 'U')[0]}
              </div>
              <div className="flex-1">
                <div className="flex items-center justify-between mb-1">
                  <span className={`text-sm ${isWinner ? 'font-bold' : 'font-medium'} text-slate-800`}>
                    {nom.nominee?.name || 'Member'}
                  </span>
                  <span className={`text-sm ${isWinner ? 'font-bold text-emerald-600' : 'text-slate-500'}`}>
                    {votes} ({pct.toFixed(0)}%)
                  </span>
                </div>
                <div className="h-2 bg-slate-200 rounded-full overflow-hidden">
                  <div
                    className={`h-full rounded-full transition-all duration-500 ${isWinner ? 'bg-emerald-500' : 'bg-slate-400'}`}
                    style={{ width: `${pct}%` }}
                  />
                </div>
              </div>
            </div>
          );
        })}
        {(sorted || []).length === 0 && (
          <p className="text-xs text-slate-400 text-center py-2">No candidates added</p>
        )}
      </div>
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
