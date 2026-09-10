import type {
  CalendarDailyCount,
  CalendarDailyPlanQuantity,
  CalendarColorScale,
  CalendarDataSource,
} from '../../types';

interface CalendarGridProps {
  dailyCounts: CalendarDailyCount[];
  planQuantities: CalendarDailyPlanQuantity[];
  colorScale: CalendarColorScale;
  month: string;
  onDateClick: (date: string) => void;
}

const WEEKDAYS = ['日', '一', '二', '三', '四', '五', '六'];

const SOURCE_BADGE: Record<CalendarDataSource, { text: string; className: string }> = {
  source_direct: { text: '直连', className: 'bg-blue-100 text-blue-600' },
  db_aggregate: { text: '聚合', className: 'bg-gray-100 text-gray-600' },
  db_aggregate_degraded: { text: '降级', className: 'bg-red-100 text-red-600' },
};

function getColor(count: number, colorScale: CalendarColorScale): string {
  for (const level of colorScale.levels) {
    if (count >= level.min && count <= level.max) {
      return level.color;
    }
  }
  return '#F3F4F6';
}

export default function CalendarGrid({
  dailyCounts,
  planQuantities,
  colorScale,
  month,
  onDateClick,
}: CalendarGridProps) {
  const [year, mon] = month.split('-').map(Number);
  const firstDay = new Date(year, mon - 1, 1);
  const lastDay = new Date(year, mon, 0);
  const startWeekday = firstDay.getDay();
  const daysInMonth = lastDay.getDate();

  const countMap = new Map<string, CalendarDailyCount>();
  for (const dc of dailyCounts) {
    countMap.set(dc.date, dc);
  }

  const planMap = new Map<string, CalendarDailyPlanQuantity>();
  for (const pq of planQuantities) {
    planMap.set(pq.date, pq);
  }

  const cells: (string | null)[] = [];
  for (let i = 0; i < startWeekday; i++) {
    cells.push(null);
  }
  for (let d = 1; d <= daysInMonth; d++) {
    cells.push(`${month}-${String(d).padStart(2, '0')}`);
  }

  return (
    <div className="bg-white border border-gray-200 rounded-lg p-4 shadow-sm">
      <div className="grid grid-cols-7 gap-1 mb-2">
        {WEEKDAYS.map((w) => (
          <div key={w} className="text-center text-sm font-medium text-gray-500 py-1">
            {w}
          </div>
        ))}
      </div>
      <div className="grid grid-cols-7 gap-1">
        {cells.map((date, i) => {
          if (date === null) {
            return <div key={i} />;
          }
          const dc = countMap.get(date);
          const pq = planMap.get(date);
          const dayNum = parseInt(date.split('-')[2]);
          const hasData = dc !== undefined;
          const color = hasData ? getColor(dc.count, colorScale) : '#FFFFFF';

          return (
            <div
              key={i}
              className={`border border-gray-100 rounded p-2 min-h-[80px] ${
                hasData ? 'cursor-pointer hover:ring-2 hover:ring-blue-300' : ''
              }`}
              style={{ backgroundColor: color }}
              onClick={() => hasData && onDateClick(date)}
            >
              <div className="text-xs text-gray-600 mb-1">{dayNum}</div>
              {hasData && (
                <>
                  <div className="text-lg font-bold text-gray-800">{dc.count}</div>
                  <span className={`text-xs px-1 rounded ${SOURCE_BADGE[dc.source].className}`}>
                    {SOURCE_BADGE[dc.source].text}
                  </span>
                </>
              )}
              {pq && (
                <div className="text-xs text-gray-500 mt-1">
                  {pq.quantity !== null
                    ? `产量:${pq.quantity}（人工录入）`
                    : '待录入'}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}