import { useQuery } from '@tanstack/react-query';
import client from '../api/client';
import type { OverviewStatistics, DailyStatistics, HealthStatus } from '../types';

export function useOverviewStatistics(date?: string) {
  return useQuery<OverviewStatistics>({
    queryKey: ['overview', date],
    queryFn: async () => {
      const res = await client.get('/statistics/overview', { params: { date } });
      return res.data;
    },
  });
}

export function useLineStatistics(lineCode: string, date?: string) {
  return useQuery<DailyStatistics>({
    queryKey: ['line-statistics', lineCode, date],
    queryFn: async () => {
      const res = await client.get(`/statistics/lines/${lineCode}`, { params: { date } });
      return res.data;
    },
    enabled: !!lineCode,
  });
}

export function useLineHealth(lineCode: string) {
  return useQuery<HealthStatus>({
    queryKey: ['line-health', lineCode],
    queryFn: async () => {
      const res = await client.get(`/health/lines/${lineCode}`);
      return res.data;
    },
    enabled: !!lineCode,
  });
}