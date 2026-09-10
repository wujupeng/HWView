import type { CalendarSummary } from '../../types';

const LABELS = ['今日采集数', '本月采集合计', '有采集天数', '单日最高采集数', '日均采集数'];

interface SummaryCardsProps {
  summary: CalendarSummary;
}

export default function SummaryCards({ summary }: SummaryCardsProps) {
  const values = [
    summary.today_count,
    summary.month_total,
    summary.active_days,
    summary.max_daily_count,
    summary.avg_daily_count,
  ];

  return (
    <div className="grid grid-cols-5 gap-4 mb-6">
      {LABELS.map((label, i) => (
        <div key={label} className="bg-white border border-gray-200 rounded-lg p-4 shadow-sm">
          <div className="text-sm text-gray-500 mb-1">{label}</div>
          <div className="text-2xl font-bold text-gray-800">{values[i]}</div>
        </div>
      ))}
    </div>
  );
}