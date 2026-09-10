import { useState } from 'react';

interface RefreshToolbarProps {
  onRefresh: () => boolean;
  isThrottled: boolean;
  lastRefreshAt: number | null;
  autoRefresh: boolean;
  onAutoRefreshChange: (enabled: boolean) => void;
}

export default function RefreshToolbar({
  onRefresh,
  isThrottled,
  lastRefreshAt,
  autoRefresh,
  onAutoRefreshChange,
}: RefreshToolbarProps) {
  const [throttleMsg, setThrottleMsg] = useState(false);

  const handleRefresh = () => {
    const ok = onRefresh();
    if (!ok) {
      setThrottleMsg(true);
      setTimeout(() => setThrottleMsg(false), 2000);
    }
  };

  const formatLastRefresh = () => {
    if (!lastRefreshAt) return '未刷新';
    const date = new Date(lastRefreshAt);
    return date.toLocaleTimeString('zh-CN');
  };

  return (
    <div className="flex items-center gap-4 mb-4">
      <button
        className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 text-sm font-medium"
        onClick={handleRefresh}
      >
        手动刷新
      </button>

      {throttleMsg && isThrottled && (
        <span className="text-yellow-600 text-sm">刷新过于频繁，请稍后重试</span>
      )}

      <label className="flex items-center gap-2 text-sm text-gray-600">
        <input
          type="checkbox"
          checked={autoRefresh}
          onChange={(e) => onAutoRefreshChange(e.target.checked)}
          className="rounded"
        />
        自动刷新（10秒）
      </label>

      <span className="text-sm text-gray-400">
        最近刷新: {formatLastRefresh()}
      </span>
    </div>
  );
}