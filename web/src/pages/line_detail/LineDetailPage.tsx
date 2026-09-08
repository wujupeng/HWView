import { useParams } from 'react-router-dom';
import { useLineStatistics, useLineHealth } from '../../hooks/useStatistics';

function LineDetailPage() {
  const { lineCode } = useParams<{ lineCode: string }>();
  const today = new Date().toISOString().slice(0, 10);
  const { data: stats, isLoading } = useLineStatistics(lineCode ?? '', today);
  const { data: health } = useLineHealth(lineCode ?? '');

  if (isLoading) return <div>加载中...</div>;
  if (!stats) return <div>无数据</div>;

  return (
    <div className="line-detail-page">
      <h1>{stats.line_name}</h1>
      <div className="detail-section">
        <h2>今日生产</h2>
        <p>箱数: {stats.box_count}</p>
        <p>只数: {stats.piece_count.toLocaleString()}</p>
        <p>批次: {stats.batch_count}</p>
      </div>
      {health && (
        <div className="detail-section">
          <h2>数据源健康</h2>
          <p>状态: {health.status}</p>
          <p>连续失败: {health.consecutive_failures}</p>
        </div>
      )}
    </div>
  );
}

export default LineDetailPage;