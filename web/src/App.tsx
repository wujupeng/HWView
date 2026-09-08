import { Routes, Route, Link, useLocation } from 'react-router-dom';
import OverviewPage from './pages/overview/OverviewPage';
import LineDetailPage from './pages/line_detail/LineDetailPage';
import ReportPage from './pages/reports/ReportPage';
import InputPage from './pages/reports/InputPage';
import HolidayPage from './pages/reports/HolidayPage';
import CartonSpecPage from './pages/config/CartonSpecPage';

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
    <nav className="bg-gray-800 text-white px-6 py-2 flex gap-6">
      {links.map((link) => (
        <Link
          key={link.to}
          to={link.to}
          className={`hover:text-blue-300 ${location.pathname === link.to ? 'text-blue-300 font-bold' : ''}`}
        >
          {link.label}
        </Link>
      ))}
    </nav>
  );
}

function App() {
  return (
    <div>
      <Nav />
      <Routes>
        <Route path="/" element={<OverviewPage />} />
        <Route path="/lines/:lineCode" element={<LineDetailPage />} />
        <Route path="/reports" element={<ReportPage />} />
        <Route path="/reports/input" element={<InputPage />} />
        <Route path="/reports/holidays" element={<HolidayPage />} />
        <Route path="/config/carton-spec" element={<CartonSpecPage />} />
      </Routes>
    </div>
  );
}

export default App;
