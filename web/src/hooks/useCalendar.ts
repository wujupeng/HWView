import { useQuery } from '@tanstack/react-query';
import { useState, useCallback } from 'react';
import client from '../api/client';
import type {
  CalendarOverviewResponse,
  CalendarBatchesResponse,
  CalendarDefaultBatchResponse,
  CalendarMode,
  CalendarSourceStatusResponse,
} from '../types';

export const CALENDAR_REFRESH_INTERVAL_MS = 60000;

export function useCalendarOverview(
  batchNo: string,
  month: string,
  lineCode?: string,
  mode?: CalendarMode,
  options?: { enabled?: boolean; refetchInterval?: number | false }
) {
  return useQuery<CalendarOverviewResponse>({
    queryKey: ['calendar-overview', batchNo, month, lineCode, mode],
    queryFn: async () => {
      const res = await client.get('/calendar/overview', {
        params: { batchNo, month, lineCode, mode },
      });
      return res.data;
    },
    enabled: !!batchNo && options?.enabled !== false,
    refetchInterval: options?.refetchInterval ?? CALENDAR_REFRESH_INTERVAL_MS,
    refetchIntervalInBackground: false,
  });
}

export function useCalendarMode() {
  const [mode, setModeState] = useState<CalendarMode>(() => {
    try {
      const saved = localStorage.getItem('calendar_fetch_mode');
      if (saved === 'SOURCE_DIRECT' || saved === 'DB_AGGREGATE') return saved;
    } catch {
      // localStorage 不可用时降级为内存状态
    }
    return 'DB_AGGREGATE';
  });

  const setMode = useCallback((m: CalendarMode) => {
    setModeState(m);
    try {
      localStorage.setItem('calendar_fetch_mode', m);
    } catch {
      // localStorage 不可用时静默降级
    }
  }, []);

  return { mode, setMode };
}

export function useCalendarSourceStatus() {
  return useQuery<CalendarSourceStatusResponse>({
    queryKey: ['calendar-source-status'],
    queryFn: async () => {
      const res = await client.get('/calendar/source-status');
      return res.data;
    },
    refetchInterval: CALENDAR_REFRESH_INTERVAL_MS,
    refetchIntervalInBackground: false,
  });
}

export function useCalendarBatches(lineCode?: string) {
  return useQuery<CalendarBatchesResponse>({
    queryKey: ['calendar-batches', lineCode],
    queryFn: async () => {
      const res = await client.get('/calendar/batches', {
        params: { lineCode },
      });
      return res.data;
    },
    refetchInterval: false,
  });
}

export function useCalendarDefaultBatch() {
  return useQuery<CalendarDefaultBatchResponse>({
    queryKey: ['calendar-default-batch'],
    queryFn: async () => {
      const res = await client.get('/calendar/default-batch');
      return res.data;
    },
    refetchInterval: false,
  });
}

export function useCalendarMonth() {
  const [month, setMonth] = useState<string>(() => {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  });

  const goPrev = useCallback(() => {
    setMonth((prev) => {
      const [y, m] = prev.split('-').map(Number);
      const d = new Date(y, m - 1, 1);
      d.setMonth(d.getMonth() - 1);
      return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    });
  }, []);

  const goNext = useCallback(() => {
    setMonth((prev) => {
      const [y, m] = prev.split('-').map(Number);
      const d = new Date(y, m - 1, 1);
      d.setMonth(d.getMonth() + 1);
      return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    });
  }, []);

  const goToday = useCallback(() => {
    const now = new Date();
    setMonth(`${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`);
  }, []);

  return { month, setMonth, goPrev, goNext, goToday };
}