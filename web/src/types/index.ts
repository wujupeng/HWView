export interface ReportResponse {
  title: string;
  dates: string[];
  row_names: string[];
  row_colors: string[];
  matrix: (number | null)[][];
  cumulative: number[];
  holidays: Record<string, string>;
  reference?: ReferenceData;
}

export interface ReferenceData {
  description: string;
  per_date: Record<string, Record<string, number>>;
}

export interface DailyProductionPlan {
  id: number;
  plan_date: string;
  row_no: number;
  value?: number | null;
  carton_count?: number | null;
  units_per_carton_snapshot?: number | null;
  loose_quantity?: number | null;
  actual_quantity?: number | null;
  line_code: string;
  input_by: string;
  input_at: string;
  updated_at: string;
}

export interface HolidayCalendar {
  id: number;
  holiday_date: string;
  holiday_name: string;
  is_rest: boolean;
  config_by: string;
  config_at: string;
  updated_at: string;
}

export interface CartonSpecification {
  id: number;
  line_code: string;
  product_code: string;
  units_per_carton: number;
  effective_from: string;
  effective_to?: string | null;
  config_by: string;
  config_at: string;
  updated_at: string;
}

export type CalendarMode = 'SOURCE_DIRECT' | 'DB_AGGREGATE';

export type CalendarDataSource = 'source_direct' | 'db_aggregate' | 'db_aggregate_degraded';

export type CalendarDegradationType = 'none' | 'overall' | 'partial';

export interface CalendarDegradationStatus {
  degraded: boolean;
  type: CalendarDegradationType;
  degraded_days: number;
  reason: string;
}

export interface CalendarSourceStatusResponse {
  current_mode: CalendarMode;
  upstream_enabled: boolean;
  upstream_reachable: boolean;
  degradation_status: CalendarDegradationStatus;
  last_fetch_at: string | null;
  last_degraded_at: string | null;
}

export interface CalendarDailyCount {
  date: string;
  count: number;
  quantity_sum: number;
  source: CalendarDataSource;
}

export interface CalendarSummary {
  today_count: number;
  month_total: number;
  active_days: number;
  max_daily_count: number;
  avg_daily_count: number;
}

export interface CalendarDailyPlanQuantity {
  date: string;
  quantity: number | null;
  source: 'manual_input';
}

export interface CalendarColorLevel {
  label: string;
  min: number;
  max: number;
  color: string;
}

export interface CalendarColorScale {
  field: 'count';
  levels: CalendarColorLevel[];
  source: CalendarDataSource;
}

export interface CalendarOverviewResponse {
  batch_no: string;
  month: string;
  line_code: string;
  daily_counts: CalendarDailyCount[];
  summary: CalendarSummary;
  daily_plan_quantities: CalendarDailyPlanQuantity[];
  color_scale: CalendarColorScale;
  title: string;
  subtitle: string;
  mode: CalendarMode;
  degradation_status: CalendarDegradationStatus;
}

export interface CalendarBatchItem {
  batch_no: string;
  last_collected_at: string | null;
  total_records: number;
}

export interface CalendarBatchesResponse {
  line_code: string;
  total: number;
  batches: CalendarBatchItem[];
}

export interface CalendarDefaultBatchResponse {
  batch_no: string;
  last_collected_at: string | null;
}
