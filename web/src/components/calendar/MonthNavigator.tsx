interface MonthNavigatorProps {
  month: string;
  onPrev: () => void;
  onNext: () => void;
  onToday: () => void;
}

export default function MonthNavigator({ month, onPrev, onNext, onToday }: MonthNavigatorProps) {
  const [y, m] = month.split('-');
  return (
    <div className="flex items-center gap-3">
      <button
        className="px-3 py-1 border border-gray-300 rounded text-sm hover:bg-gray-100"
        onClick={onPrev}
      >
        上一月
      </button>
      <span className="text-lg font-semibold text-gray-800 min-w-[100px] text-center">
        {y}年{parseInt(m)}月
      </span>
      <button
        className="px-3 py-1 border border-gray-300 rounded text-sm hover:bg-gray-100"
        onClick={onNext}
      >
        下一月
      </button>
      <button
        className="px-3 py-1 border border-gray-300 rounded text-sm hover:bg-gray-100 ml-2"
        onClick={onToday}
      >
        回到今天
      </button>
    </div>
  );
}