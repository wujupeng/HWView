import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQueryClient } from '@tanstack/react-query';
import {
  useCalendarOverview,
  useCalendarBatches,
  useCalendarDefaultBatch,
  useCalendarMonth,
  useCalendarMode,
  useCalendarSourceStatus,
  CALENDAR_REFRESH_INTERVAL_MS,
} from '../../hooks/useCalendar';
import { useRefreshThrottle } from '../../hooks/useRefreshThrottle';
import BatchSelector from '../../components/calendar/BatchSelector';
import MonthNavigator from '../../components/calendar/MonthNavigator';
import SummaryCards from '../../components/calendar/SummaryCards';
import CalendarGrid from '../../components/calendar/CalendarGrid';
import CalendarStatusBadge from '../../components/calendar/CalendarStatusBadge';
import ModeSelector from '../../components/calendar/ModeSelector';
import DegradationNotice from '../../components/calendar/DegradationNotice';
import RefreshToolbar from '../../components/common/RefreshToolbar';

export default function CalendarPage() {
  const [selectedBatch, setSelectedBatch] = useState<string>('');
  const [autoRefresh, setAutoRefresh] = useState(true);
  const [lineCode] = useState<string | undefined>(undefined);

  const navigate = useNavigate();
  const qc = useQueryClient();
  const { month, goPrev, goNext, goToday } = useCalendarMonth();
  const { onRefresh, lastRefreshAt, isThrottled } = useRefreshThrottle();
  const { mode, setMode } = useCalendarMode();
  const sourceStatus = useCalendarSourceStatus();

  const defaultBatch = useCalendarDefaultBatch();
  const batches = useCalendarBatches(lineCode);

  useEffect(() => {
    if (!selectedBatch && defaultBatch.data?.batch_no) {
      setSelectedBatch(defaultBatch.data.batch_no);
    }
  }, [selectedBatch, defaultBatch.data?.batch_no]);

  const overview = useCalendarOverview(selectedBatch, month, lineCode, mode, {
    enabled: !!selectedBatch,
    refetchInterval: autoRefresh ? CALENDAR_REFRESH_INTERVAL_MS : false,
  });

  const handleRefresh = () => {
    const ok = onRefresh();
    if (ok) {
      qc.invalidateQueries({ queryKey: ['calendar-overview'] });
    }
    return ok;
  };

  const handleDateClick = (date: string) => {
    navigate(`/realtime?batchNo=${selectedBatch}&date=${date}`);
  };

  const status: 'CONNECTED' | 'DISCONNECTED' | 'PAUSED' = !autoRefresh
    ? 'PAUSED'
    : overview.isError
    ? 'DISCONNECTED'
    : 'CONNECTED';

  const loadedDays = overview.data?.summary.active_days ?? 0;
  const lastUpdatedAt = lastRefreshAt
    ? new Date(lastRefreshAt).toISOString()
    : overview.dataUpdatedAt
    ? new Date(overview.dataUpdatedAt).toISOString()
    : null;

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold text-gray-800 mb-2">源系统采集数量日历</h1>
      {selectedBatch && (
        <p className="text-gray-500 mb-4">批次：{selectedBatch}</p>
      )}

      <div className="flex items-center gap-4 mb-4">
        <BatchSelector
          batches={batches.data?.batches ?? []}
          value={selectedBatch}
          onChange={setSelectedBatch}
          loading={batches.isLoading}
        />
        <MonthNavigator month={month} onPrev={goPrev} onNext={goNext} onToday={goToday} />
      </div>

      <div className="mb-4">
        <ModeSelector
          mode={mode}
          onChange={setMode}
          upstreamEnabled={sourceStatus.data?.upstream_enabled ?? false}
        />
      </div>

      <div className="flex items-center justify-between mb-4">
        <RefreshToolbar
          onRefresh={handleRefresh}
          isThrottled={isThrottled}
          lastRefreshAt={lastRefreshAt}
          autoRefresh={autoRefresh}
          onAutoRefreshChange={setAutoRefresh}
        />
        <CalendarStatusBadge
          status={status}
          loadedDays={loadedDays}
          lastUpdatedAt={lastUpdatedAt}
          mode={mode}
          upstreamReachable={sourceStatus.data?.upstream_reachable}
          degradationStatus={overview.data?.degradation_status}
        />
      </div>

      {!selectedBatch && (
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-8 text-center text-gray-500">
          请先选择批次
        </div>
      )}

      {selectedBatch && batches.data && batches.data.total === 0 && (
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-8 text-center text-gray-500">
          暂无批次数据，请等待采集
        </div>
      )}

      {selectedBatch && overview.error && (
        <div className="text-red-600 mb-4">
          加载失败: {String(overview.error)}（显示上次数据）
        </div>
      )}

      {selectedBatch && overview.data && (
        <>
          {overview.data.degradation_status && (
            <DegradationNotice degradationStatus={overview.data.degradation_status} />
          )}
          <SummaryCards summary={overview.data.summary} />
          <CalendarGrid
            dailyCounts={overview.data.daily_counts}
            planQuantities={overview.data.daily_plan_quantities}
            colorScale={overview.data.color_scale}
            month={month}
            onDateClick={handleDateClick}
          />
        </>
      )}

      {selectedBatch && overview.isLoading && !overview.data && (
        <div className="text-gray-500">加载中...</div>
      )}
    </div>
  );
}