import { useState } from 'react';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import Login from './components/Login';
import Register from './components/Register';
import CandidateDashboard from './components/CandidateDashboard';
import AdminDashboard from './components/AdminDashboard';
import ApplicationForm from './components/ApplicationForm';

function AppContent() {
  const { user, profile, loading } = useAuth();
  const [authMode, setAuthMode] = useState<'login' | 'register'>('login');
  const [hasSubmittedApplication, setHasSubmittedApplication] = useState(false);

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 flex items-center justify-center">
        <div className="text-center">
          <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
          <p className="mt-4 text-slate-600">Loading...</p>
        </div>
      </div>
    );
  }

  if (!user || !profile) {
    return authMode === 'login' ? (
      <Login onToggleMode={() => setAuthMode('register')} />
    ) : (
      <Register onToggleMode={() => setAuthMode('login')} />
    );
  }

  if (profile.role === 'admin') {
    return <AdminDashboard />;
  }

  if (!hasSubmittedApplication) {
    return (
      <ApplicationForm
        onSuccess={() => setHasSubmittedApplication(true)}
      />
    );
  }

  return (
    <CandidateDashboard
      onNewApplication={() => setHasSubmittedApplication(false)}
    />
  );
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;
