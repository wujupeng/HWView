import type { CalendarMode } from '../../types';

interface ModeSelectorProps {
  mode: CalendarMode;
  onChange: (mode: CalendarMode) => void;
  upstreamEnabled: boolean;
}

const MODE_OPTIONS: { value: CalendarMode; label: string }[] = [
  { value: 'SOURCE_DIRECT', label: '直连源系统' },
  { value: 'DB_AGGREGATE', label: '数据库聚合' },
];

export default function ModeSelector({ mode, onChange, upstreamEnabled }: ModeSelectorProps) {
  return (
    <div className="flex items-center gap-2">
      <span className="text-sm text-gray-500 mr-1">取数模式</span>
      {MODE_OPTIONS.map((opt) => {
        const isActive = mode === opt.value;
        const isDisabled = opt.value === 'SOURCE_DIRECT' && !upstreamEnabled;
        return (
          <button
            key={opt.value}
            type="button"
            disabled={isDisabled}
            onClick={() => onChange(opt.value)}
            className={`px-3 py-1.5 rounded text-sm font-medium transition-colors ${
              isActive
                ? 'bg-blue-600 text-white'
                : 'bg-white text-gray-700 border border-gray-300 hover:bg-gray-50'
            } ${isDisabled ? 'opacity-50 cursor-not-allowed' : ''}`}
          >
            {opt.label}
          </button>
        );
      })}
      {!upstreamEnabled && (
        <span className="text-xs text-gray-400 ml-1">未配置上游源系统</span>
      )}
    </div>
  );
}