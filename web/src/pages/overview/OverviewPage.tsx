import { useOverviewStatistics } from '../../hooks/useStatistics';

function OverviewPage() {
  const today = new Date().toISOString().slice(0, 10);
  const { data, isLoading, error } = useOverviewStatistics(today);

  if (isLoading) return <div>加载中...</div>;
  if (error) return <div>加载失败: {String(error)}</div>;
  if (!data) return <div>无数据</div>;

  return (
    <div className="overview-page">
      <h1>HWView 产线生产监控</h1>
      <div className="summary-cards">
        <div className="card">
          <span className="label">今日总产量</span>
          <span className="value">{data.total_piece_count.toLocaleString()}只</span>
        </div>
        <div className="card">
          <span className="label">今日箱数</span>
          <span className="value">{data.total_box_count.toLocaleString()}箱</span>
        </div>
        <div className="card">
          <span className="label">在线产线</span>
          <span className="value">{data.online_line_count}/{data.total_line_count}</span>
        </div>
      </div>
      <table className="line-table">
        <thead>
          <tr>
            <th>产线</th>
            <th>今日产量</th>
            <th>今日箱数</th>
            <th>批次</th>
            <th>状态</th>
          </tr>
        </thead>
        <tbody>
          {data.lines.map((line) => (
            <tr key={line.line_code}>
              <td>{line.line_name}</td>
              <td>{line.piece_count.toLocaleString()}</td>
              <td>{line.box_count.toLocaleString()}</td>
              <td>{line.batch_count}</td>
              <td>🟢</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default OverviewPage;