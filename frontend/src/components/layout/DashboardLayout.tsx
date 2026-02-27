import { Outlet } from 'react-router-dom';
import { Sidebar } from './Sidebar';
import { CallOverlay } from '../call/CallOverlay';

export const DashboardLayout = () => {
  return (
    <div className="flex h-screen bg-gray-900 text-white overflow-hidden">
      <Sidebar />
      <div className="flex-1 flex flex-col min-w-0 relative">
        <main className="flex-1 overflow-y-auto">
          <Outlet />
        </main>
        <CallOverlay />
      </div>
    </div>
  );
};
