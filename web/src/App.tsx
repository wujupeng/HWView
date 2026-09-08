import { Routes, Route } from 'react-router-dom';
import OverviewPage from './pages/overview/OverviewPage';
import LineDetailPage from './pages/line_detail/LineDetailPage';

function App() {
  return (
    <Routes>
      <Route path="/" element={<OverviewPage />} />
      <Route path="/lines/:lineCode" element={<LineDetailPage />} />
    </Routes>
  );
}

export default App;