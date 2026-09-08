export interface ProductionLine {
  id: number;
  line_code: string;
  line_name: string;
  customer: string;
  product: string;
  adapter_type: string;
  enabled: boolean;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface DataSource {
  id: number;
  line_id: number;
  agent_id: string;
  hostname: string;
  current_ip: string;
  port: number;
  base_path: string;
  enabled: boolean;
  status: string;
  last_success_at: string | null;
  last_error_at: string | null;
  last_heartbeat_at: string | null;
}

export interface DailyStatistics {
  line_id: number;
  line_code: string;
  line_name: string;
  production_date: string;
  box_count: number;
  piece_count: number;
  batch_count: number;
  first_production_at: string;
  last_production_at: string;
}

export interface HealthStatus {
  source_id: number;
  status: 'ONLINE' | 'DEGRADED' | 'OFFLINE' | 'SWITCHING';
  last_success_at: string | null;
  last_failure_at: string | null;
  consecutive_failures: number;
  last_error: string | null;
}

export interface OverviewStatistics {
  total_piece_count: number;
  total_box_count: number;
  online_line_count: number;
  total_line_count: number;
  lines: DailyStatistics[];
}