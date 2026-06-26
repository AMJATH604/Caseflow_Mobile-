import { useState } from 'react';
import { useNotices, useCreateNotice, useDeleteNotice, useCurrentAdmin } from '@/hooks/useBarDesk';
import { formatDateTime, getCategoryColor } from '@/lib/utils';
import { Plus, Pin, Trash2, X, Send } from 'lucide-react';

export default function NoticesPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id || '';
  const { data: notices, isLoading } = useNotices(associationId);
  const createNotice = useCreateNotice(associationId);
  const deleteNotice = useDeleteNotice();

  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({ title: '', body: '', category: 'general', is_pinned: false });

  const handlePublish = async () => {
    await createNotice.mutateAsync({
      ...form,
      published_at: new Date().toISOString(),
    } as any);
    setShowModal(false);
    setForm({ title: '', body: '', category: 'general', is_pinned: false });
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Delete this notice?')) return;
    await deleteNotice.mutateAsync(id);
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
          <h1 className="text-2xl font-extrabold text-slate-900">Notices</h1>
          <p className="text-sm text-slate-500 mt-1">{(notices || []).length} notices published</p>
        </div>
        <button
          onClick={() => setShowModal(true)}
          className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-cyan-600 text-white text-sm font-semibold hover:bg-cyan-700 transition shadow-sm shadow-cyan-500/20"
        >
          <Plus className="w-4 h-4" /> New Notice
        </button>
      </div>

      {/* Notices List */}
      <div className="space-y-4">
        {(notices || []).map((notice) => (
          <div key={notice.id} className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm hover:shadow-md transition group">
            <div className="flex items-start gap-4">
              <div
                className="w-1 h-full min-h-[60px] rounded-full flex-shrink-0"
                style={{ backgroundColor: getCategoryColor(notice.category) }}
              />
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-2">
                  {notice.is_pinned && (
                    <span className="flex items-center gap-1 text-xs bg-amber-50 text-amber-600 font-semibold px-2 py-0.5 rounded-md">
                      <Pin className="w-3 h-3" /> Pinned
                    </span>
                  )}
                  <span
                    className="text-xs font-semibold px-2 py-0.5 rounded-md"
                    style={{
                      backgroundColor: getCategoryColor(notice.category) + '15',
                      color: getCategoryColor(notice.category),
                    }}
                  >
                    {notice.category}
                  </span>
                </div>
                <h3 className="text-base font-bold text-slate-800">{notice.title}</h3>
                <p className="text-sm text-slate-500 mt-1 line-clamp-2">{notice.body}</p>
                <div className="flex items-center gap-3 mt-3">
                  <span className="text-xs text-slate-400">{formatDateTime(notice.published_at)}</span>
                  <span className="text-xs text-slate-400">•</span>
                  <span className="text-xs text-slate-400">{notice.read_count} read</span>
                  {notice.fcm_sent && (
                    <>
                      <span className="text-xs text-slate-400">•</span>
                      <span className="text-xs text-emerald-600 font-medium">✓ Push sent</span>
                    </>
                  )}
                </div>
              </div>
              <button
                onClick={() => handleDelete(notice.id)}
                className="opacity-0 group-hover:opacity-100 text-slate-400 hover:text-red-500 transition p-1"
              >
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          </div>
        ))}
        {(notices || []).length === 0 && (
          <div className="text-center py-16 text-slate-400">
            <p className="text-lg">📢</p>
            <p className="mt-2 font-medium">No notices yet</p>
            <p className="text-sm mt-1">Click "New Notice" to publish your first announcement</p>
          </div>
        )}
      </div>

      {/* Publish Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-lg p-6 shadow-xl">
            <div className="flex items-center justify-between mb-5">
              <h3 className="text-lg font-bold text-slate-900">Publish Notice</h3>
              <button onClick={() => setShowModal(false)} className="text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Title *</label>
                <input
                  type="text"
                  value={form.title}
                  onChange={(e) => setForm({ ...form, title: e.target.value })}
                  className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none"
                  placeholder="Notice title"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Content *</label>
                <textarea
                  value={form.body}
                  onChange={(e) => setForm({ ...form, body: e.target.value })}
                  rows={5}
                  className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none resize-none"
                  placeholder="Write the notice content..."
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-1">Category</label>
                  <select
                    value={form.category}
                    onChange={(e) => setForm({ ...form, category: e.target.value })}
                    className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none"
                  >
                    <option value="general">General</option>
                    <option value="urgent">🔴 Urgent</option>
                    <option value="election">🗳️ Election</option>
                    <option value="event">📅 Event</option>
                    <option value="holiday">🏖️ Holiday</option>
                  </select>
                </div>
                <div className="flex items-end pb-1">
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={form.is_pinned}
                      onChange={(e) => setForm({ ...form, is_pinned: e.target.checked })}
                      className="w-4 h-4 rounded border-slate-300 text-cyan-600 focus:ring-cyan-500"
                    />
                    <span className="text-sm font-medium text-slate-700">📌 Pin to top</span>
                  </label>
                </div>
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button
                onClick={() => setShowModal(false)}
                className="flex-1 py-2.5 rounded-xl border border-slate-200 text-sm font-semibold text-slate-600 hover:bg-slate-50 transition"
              >
                Cancel
              </button>
              <button
                onClick={handlePublish}
                disabled={!form.title || !form.body || createNotice.isPending}
                className="flex-1 py-2.5 rounded-xl bg-cyan-600 text-white text-sm font-semibold hover:bg-cyan-700 disabled:opacity-50 transition flex items-center justify-center gap-2"
              >
                <Send className="w-4 h-4" />
                {createNotice.isPending ? 'Publishing...' : 'Publish'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
