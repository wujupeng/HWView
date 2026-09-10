import type { CalendarMode, CalendarDegradationStatus } from '../../types';

interface CalendarStatusBadgeProps {
  status: 'CONNECTED' | 'DISCONNECTED' | 'PAUSED';
  loadedDays: number;
  lastUpdatedAt: string | null;
  mode?: CalendarMode;
  upstreamReachable?: boolean;
  degradationStatus?: CalendarDegradationStatus;
}

const STATUS_TEXT: Record<CalendarStatusBadgeProps['status'], string> = {
  CONNECTED: '实时已连接',
  DISCONNECTED: '实时已断开',
  PAUSED: '已暂停',
};

const STATUS_COLOR: Record<CalendarStatusBadgeProps['status'], string> = {
  CONNECTED: 'bg-green-100 text-green-700',
  DISCONNECTED: 'bg-red-100 text-red-700',
  PAUSED: 'bg-gray-100 text-gray-700',
};

export default function CalendarStatusBadge({
  status,
  loadedDays,
  lastUpdatedAt,
  mode,
  upstreamReachable,
  degradationStatus,
}: CalendarStatusBadgeProps) {
  const formatTime = (t: string | null) => {
    if (!t) return '无';
    return new Date(t).toLocaleString('zh-CN');
  };

  return (
    <div className="flex items-center gap-4 text-sm flex-wrap">
      <span className={`px-3 py-1 rounded font-medium ${STATUS_COLOR[status]}`}>
        {STATUS_TEXT[status]}
      </span>
      <span className="text-gray-500">已载入 {loadedDays} 天</span>
      <span className="text-gray-500">最后更新 {formatTime(lastUpdatedAt)}</span>
      {mode === 'DB_AGGREGATE' && (
        <span className="px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-700">
          取数模式：数据库聚合
        </span>
      )}
      {mode === 'SOURCE_DIRECT' && (
        <>
          <span className="px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-700">
            取数模式：直连源系统
          </span>
          <span
            className={`px-2 py-0.5 rounded text-xs font-medium ${
              upstreamReachable
                ? 'bg-green-100 text-green-700'
                : 'bg-red-100 text-red-700'
            }`}
          >
            {upstreamReachable ? '上游可达' : '上游不可达'}
          </span>
          {degradationStatus?.degraded && (
            <span className="px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-700">
              已降级（{degradationStatus.type === 'overall' ? '整体' : `${degradationStatus.degraded_days}天`}）
            </span>
          )}
        </>
      )}
    </div>
  );
}
