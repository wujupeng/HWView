import type { DailyStatistics } from '../types';

interface LineCardProps {
  line: DailyStatistics;
  onClick?: (lineCode: string) => void;
}

function LineCard({ line, onClick }: LineCardProps) {
  const statusColor = line.box_count > 0 ? '#22c55e' : '#94a3b8';

  return (
    <div
      className="line-card"
      onClick={() => onClick?.(line.line_code)}
      style={{
        background: 'white',
        padding: '16px',
        borderRadius: '8px',
        boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
        cursor: onClick ? 'pointer' : 'default',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
      }}
    >
      <div>
        <div style={{ fontWeight: 600, fontSize: 16 }}>{line.line_name}</div>
        <div style={{ color: '#666', fontSize: 13, marginTop: 4 }}>
          {line.piece_count.toLocaleString()} pcs / {line.box_count} boxes / {line.batch_count} batches
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <span style={{ width: 10, height: 10, borderRadius: '50%', background: statusColor, display: 'inline-block' }} />
        <span style={{ color: '#666', fontSize: 13 }}>{line.box_count > 0 ? 'ONLINE' : 'OFFLINE'}</span>
      </div>
    </div>
  );
}

export default LineCard;