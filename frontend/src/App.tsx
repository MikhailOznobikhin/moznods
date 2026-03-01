import { useEffect } from 'react';
import { BrowserRouter, Route, Routes, Navigate } from 'react-router-dom';
import { useAuthStore } from './store/useAuthStore';
import { useNotificationStore } from './store/useNotificationStore';
import { LoginPage } from './pages/LoginPage';
import { RegisterPage } from './pages/RegisterPage';
import { PrivateRoute } from './components/PrivateRoute';
import { DashboardLayout } from './components/layout/DashboardLayout';
import { RoomPage } from './pages/RoomPage';
import { SettingsPage } from './pages/SettingsPage';

function App() {
  const { checkAuth, token, isAuthenticated } = useAuthStore();
  const { connect: connectNotifications, disconnect: disconnectNotifications } = useNotificationStore();

  useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  useEffect(() => {
    if (isAuthenticated && token) {
      connectNotifications(token);
    } else {
      disconnectNotifications();
    }

    return () => {
      disconnectNotifications();
    };
  }, [isAuthenticated, token, connectNotifications, disconnectNotifications]);

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />
        
        <Route element={<PrivateRoute />}>
          <Route element={<DashboardLayout />}>
            <Route path="/" element={
              <div className="flex-1 flex items-center justify-center text-gray-400">
                Select a room to start chatting
              </div>
            } />
            <Route path="/rooms/:id" element={<RoomPage />} />
            <Route path="/settings" element={<SettingsPage />} />
          </Route>
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
