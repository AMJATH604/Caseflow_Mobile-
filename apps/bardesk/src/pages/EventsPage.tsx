import { useState } from 'react';
import { useEvents, useCreateEvent, useCurrentAdmin } from '@/hooks/useBarDesk';
import { formatDate, getCategoryColor } from '@/lib/utils';
import { Plus, MapPin, Clock, X, CalendarDays } from 'lucide-react';

export default function EventsPage() {
  const { data: admin } = useCurrentAdmin();
  const associationId = admin?.association_id || '';
  const { data: events, isLoading } = useEvents(associationId);
  const createEvent = useCreateEvent(associationId);

  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({
    title: '', description: '', event_date: '', start_time: '',
    end_time: '', location: '', agenda: '', category: 'meeting',
  });

  const handleCreate = async () => {
    await createEvent.mutateAsync(form as any);
    setShowModal(false);
    setForm({ title: '', description: '', event_date: '', start_time: '', end_time: '', location: '', agenda: '', category: 'meeting' });
  };

  const now = new Date();
  const upcoming = (events || []).filter(e => new Date(e.event_date) >= new Date(now.getFullYear(), now.getMonth(), now.getDate()));
  const past = (events || []).filter(e => new Date(e.event_date) < new Date(now.getFullYear(), now.getMonth(), now.getDate()));

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
          <h1 className="text-2xl font-extrabold text-slate-900">Events & Calendar</h1>
          <p className="text-sm text-slate-500 mt-1">{upcoming.length} upcoming • {past.length} past</p>
        </div>
        <button
          onClick={() => setShowModal(true)}
          className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-cyan-600 text-white text-sm font-semibold hover:bg-cyan-700 transition shadow-sm shadow-cyan-500/20"
        >
          <Plus className="w-4 h-4" /> Add Event
        </button>
      </div>

      {/* Upcoming */}
      {upcoming.length > 0 && (
        <div className="mb-8">
          <h2 className="text-sm font-bold text-slate-500 uppercase tracking-wider mb-4">Upcoming</h2>
          <div className="space-y-3">
            {upcoming.map((event) => (
              <EventCard key={event.id} event={event} />
            ))}
          </div>
        </div>
      )}

      {/* Past */}
      {past.length > 0 && (
        <div>
          <h2 className="text-sm font-bold text-slate-500 uppercase tracking-wider mb-4">Past Events</h2>
          <div className="space-y-3 opacity-60">
            {past.map((event) => (
              <EventCard key={event.id} event={event} />
            ))}
          </div>
        </div>
      )}

      {(events || []).length === 0 && (
        <div className="text-center py-16 text-slate-400">
          <p className="text-3xl">📅</p>
          <p className="mt-3 font-medium">No events scheduled</p>
          <p className="text-sm mt-1">Click "Add Event" to schedule the first event</p>
        </div>
      )}

      {/* Create Event Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-lg p-6 shadow-xl max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-5">
              <h3 className="text-lg font-bold text-slate-900">Add Event</h3>
              <button onClick={() => setShowModal(false)} className="text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Title *</label>
                <input type="text" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })}
                  className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none"
                  placeholder="Monthly General Meeting" />
              </div>
              <div className="grid grid-cols-3 gap-3">
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-1">Date *</label>
                  <input type="date" value={form.event_date} onChange={(e) => setForm({ ...form, event_date: e.target.value })}
                    className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-1">Start</label>
                  <input type="time" value={form.start_time} onChange={(e) => setForm({ ...form, start_time: e.target.value })}
                    className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-1">End</label>
                  <input type="time" value={form.end_time} onChange={(e) => setForm({ ...form, end_time: e.target.value })}
                    className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none" />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Location</label>
                <input type="text" value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })}
                  className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none"
                  placeholder="Bar Hall, Court Complex" />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Category</label>
                <select value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}
                  className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none">
                  <option value="meeting">📋 Meeting</option>
                  <option value="holiday">🏖️ Holiday</option>
                  <option value="lecture">🎓 Lecture</option>
                  <option value="sports">🏏 Sports</option>
                  <option value="annual">🎉 Annual</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Description</label>
                <textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })}
                  rows={2} className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none resize-none" />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Agenda</label>
                <textarea value={form.agenda} onChange={(e) => setForm({ ...form, agenda: e.target.value })}
                  rows={3} className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 outline-none resize-none"
                  placeholder="1. Roll call&#10;2. Reading of minutes&#10;3. Treasurer's report" />
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button onClick={() => setShowModal(false)} className="flex-1 py-2.5 rounded-xl border border-slate-200 text-sm font-semibold text-slate-600 hover:bg-slate-50 transition">Cancel</button>
              <button
                onClick={handleCreate}
                disabled={!form.title || !form.event_date || createEvent.isPending}
                className="flex-1 py-2.5 rounded-xl bg-cyan-600 text-white text-sm font-semibold hover:bg-cyan-700 disabled:opacity-50 transition"
              >
                {createEvent.isPending ? 'Creating...' : 'Create Event'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function EventCard({ event }: { event: any }) {
  const color = getCategoryColor(event.category);
  const date = new Date(event.event_date);
  const day = date.getDate();
  const month = date.toLocaleString('en', { month: 'short' }).toUpperCase();

  return (
    <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm hover:shadow-md transition flex gap-4">
      <div className="flex flex-col items-center justify-center w-14 flex-shrink-0">
        <span className="text-2xl font-extrabold" style={{ color }}>{day}</span>
        <span className="text-xs font-bold" style={{ color }}>{month}</span>
      </div>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 mb-1">
          <h3 className="text-sm font-bold text-slate-800">{event.title}</h3>
          <span className="text-xs font-semibold px-2 py-0.5 rounded-md" style={{ backgroundColor: color + '15', color }}>
            {event.category}
          </span>
        </div>
        <div className="flex items-center gap-4 text-xs text-slate-400">
          {event.start_time && (
            <span className="flex items-center gap-1">
              <Clock className="w-3 h-3" /> {event.start_time}{event.end_time ? ` — ${event.end_time}` : ''}
            </span>
          )}
          {event.location && (
            <span className="flex items-center gap-1">
              <MapPin className="w-3 h-3" /> {event.location}
            </span>
          )}
        </div>
        {event.description && (
          <p className="text-xs text-slate-500 mt-1 line-clamp-1">{event.description}</p>
        )}
      </div>
    </div>
  );
}
