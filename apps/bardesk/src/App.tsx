import { Routes, Route, Navigate } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import Layout from '@/components/Layout';
import LoginPage from '@/pages/LoginPage';
import DashboardPage from '@/pages/DashboardPage';
import MembersPage from '@/pages/MembersPage';
import NoticesPage from '@/pages/NoticesPage';
import FeesPage from '@/pages/FeesPage';
import RenewalsPage from '@/pages/RenewalsPage';
import ClerksPage from '@/pages/ClerksPage';
import IdCardsPage from '@/pages/IdCardsPage';
import WelfarePage from '@/pages/WelfarePage';
import StipendPage from '@/pages/StipendPage';
import CondolencesPage from '@/pages/CondolencesPage';
import EventsPage from '@/pages/EventsPage';
import SettingsPage from '@/pages/SettingsPage';

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const [loading, setLoading] = useState(true);
  const [authenticated, setAuthenticated] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setAuthenticated(!!session);
      setLoading(false);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setAuthenticated(!!session);
    });

    return () => subscription.unsubscribe();
  }, []);

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center bg-background">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-accent border-t-transparent" />
      </div>
    );
  }

  return authenticated ? <>{children}</> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        element={
          <ProtectedRoute>
            <Layout />
          </ProtectedRoute>
        }
      >
        <Route index element={<DashboardPage />} />
        <Route path="members" element={<MembersPage />} />
        <Route path="renewals" element={<RenewalsPage />} />
        <Route path="clerks" element={<ClerksPage />} />
        <Route path="id-cards" element={<IdCardsPage />} />
        <Route path="welfare" element={<WelfarePage />} />
        <Route path="stipend" element={<StipendPage />} />
        <Route path="condolences" element={<CondolencesPage />} />
        <Route path="notices" element={<NoticesPage />} />
        <Route path="fees" element={<FeesPage />} />
        <Route path="events" element={<EventsPage />} />
        <Route path="settings" element={<SettingsPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
