import { useEffect } from 'react';
import { BrowserRouter, Route, Routes, Navigate } from 'react-router-dom';
import { useAuthStore } from './store/useAuthStore';
import { LoginPage } from './pages/LoginPage';
import { RegisterPage } from './pages/RegisterPage';
import { PrivateRoute } from './components/PrivateRoute';

function App() {
  const checkAuth = useAuthStore((state) => state.checkAuth);

  useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />
        
        <Route element={<PrivateRoute />}>
          <Route path="/" element={
            <div className="min-h-screen bg-gray-900 text-white flex items-center justify-center">
              <h1 className="text-4xl font-bold">Dashboard (Coming Soon)</h1>
            </div>
          } />
          {/* Add more private routes here */}
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
