import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import client from '../api/client';
import type { ReportResponse, DailyProductionPlan, HolidayCalendar, CartonSpecification } from '../types';

export function useReport(startDate: string, endDate: string) {
  return useQuery<ReportResponse>({
    queryKey: ['report', startDate, endDate],
    queryFn: async () => {
      const { data } = await client.get('/reports/daily-output-plan', {
        params: { start_date: startDate, end_date: endDate },
      });
      return data;
    },
    enabled: !!startDate && !!endDate,
  });
}

export function usePlans(startDate: string, endDate: string) {
  return useQuery<{ plans: DailyProductionPlan[] }>({
    queryKey: ['plans', startDate, endDate],
    queryFn: async () => {
      const { data } = await client.get('/reports/daily-plan', {
        params: { start_date: startDate, end_date: endDate },
      });
      return data;
    },
    enabled: !!startDate && !!endDate,
  });
}

export function useCreatePlan() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (plan: Partial<DailyProductionPlan> & { plan_date: string; row_no: number; input_by: string }) => {
      const { data } = await client.post('/reports/daily-plan', plan);
      return data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['plans'] }),
  });
}

export function useHolidays(startDate: string, endDate: string) {
  return useQuery<{ holidays: HolidayCalendar[] }>({
    queryKey: ['holidays', startDate, endDate],
    queryFn: async () => {
      const { data } = await client.get('/reports/holidays', {
        params: { start_date: startDate, end_date: endDate },
      });
      return data;
    },
    enabled: !!startDate && !!endDate,
  });
}

export function useCreateHoliday() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (holiday: Partial<HolidayCalendar> & { holiday_date: string; holiday_name: string; config_by: string }) => {
      const { data } = await client.post('/reports/holidays', holiday);
      return data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['holidays'] }),
  });
}

export function useCartonSpecs() {
  return useQuery<{ specs: CartonSpecification[] }>({
    queryKey: ['carton-specs'],
    queryFn: async () => {
      const { data } = await client.get('/config/carton-spec');
      return data;
    },
  });
}

export function useCreateCartonSpec() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (spec: Partial<CartonSpecification> & { line_code: string; product_code: string; units_per_carton: number; effective_from: string; config_by: string }) => {
      const { data } = await client.post('/config/carton-spec', spec);
      return data;
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['carton-specs'] }),
  });
}

export function useExportReport() {
  return useMutation({
    mutationFn: async ({ startDate, endDate }: { startDate: string; endDate: string }) => {
      const response = await client.get('/reports/daily-output-plan/export', {
        params: { start_date: startDate, end_date: endDate },
        responseType: 'blob',
      });
      const url = URL.createObjectURL(response.data);
      const a = document.createElement('a');
      a.href = url;
      a.download = `102_daily_output_plan_${startDate}_to_${endDate}.xlsx`;
      a.click();
      URL.revokeObjectURL(url);
    },
  });
}