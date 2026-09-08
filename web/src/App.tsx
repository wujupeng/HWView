import { ReactNode } from 'react';
import { Routes, Route, Link, useLocation, Navigate } from 'react-router-dom';
import OverviewPage from './pages/overview/OverviewPage';
import LineDetailPage from './pages/line_detail/LineDetailPage';
import ReportPage from './pages/reports/ReportPage';
import InputPage from './pages/reports/InputPage';
import HolidayPage from './pages/reports/HolidayPage';
import CartonSpecPage from './pages/config/CartonSpecPage';
import LoginPage from './pages/auth/LoginPage';
import { getStoredKey, clearKey } from './api/client';

function RequireAuth({ children }: { children: ReactNode }) {
  if (!getStoredKey()) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
}

function Nav() {
  const location = useLocation();
  const links = [
    { to: '/', label: '总览' },
    { to: '/reports', label: '产出报表' },
    { to: '/reports/input', label: '数据录入' },
    { to: '/reports/holidays', label: '节假日' },
    { to: '/config/carton-spec', label: '装箱规格' },
  ];
  return (
    <nav className="bg-gray-800 text-white px-6 py-2 flex gap-6 items-center">
      {links.map((link) => (
        <Link
          key={link.to}
          to={link.to}
          className={`hover:text-blue-300 ${location.pathname === link.to ? 'text-blue-300 font-bold' : ''}`}
        >
          {link.label}
        </Link>
      ))}
      <button
        onClick={() => {
          clearKey();
          window.location.href = '/login';
        }}
        className="ml-auto text-sm text-gray-300 hover:text-white"
      >
        退出登录
      </button>
    </nav>
  );
}

function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="*"
        element={
          <div>
            <Nav />
            <Routes>
              <Route path="/" element={<RequireAuth><OverviewPage /></RequireAuth>} />
              <Route path="/lines/:lineCode" element={<RequireAuth><LineDetailPage /></RequireAuth>} />
              <Route path="/reports" element={<RequireAuth><ReportPage /></RequireAuth>} />
              <Route path="/reports/input" element={<RequireAuth><InputPage /></RequireAuth>} />
              <Route path="/reports/holidays" element={<RequireAuth><HolidayPage /></RequireAuth>} />
              <Route path="/config/carton-spec" element={<RequireAuth><CartonSpecPage /></RequireAuth>} />
            </Routes>
          </div>
        }
      />
    </Routes>
  );
}

export default App;
