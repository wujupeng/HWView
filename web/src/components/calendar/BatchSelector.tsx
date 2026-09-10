import { useState, useMemo, useRef, useEffect } from 'react';
import type { CalendarBatchItem } from '../../types';

const VIRTUAL_SCROLL_THRESHOLD = 200;
const ITEM_HEIGHT = 44;
const VISIBLE_COUNT = 10;

interface BatchSelectorProps {
  batches: CalendarBatchItem[];
  value: string;
  onChange: (batchNo: string) => void;
  loading?: boolean;
}

export default function BatchSelector({ batches, value, onChange, loading }: BatchSelectorProps) {
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState('');
  const [scrollTop, setScrollTop] = useState(0);
  const containerRef = useRef<HTMLDivElement>(null);

  const filtered = useMemo(() => {
    if (!search) return batches;
    return batches.filter((b) => b.batch_no.includes(search));
  }, [batches, search]);

  const useVirtual = filtered.length > VIRTUAL_SCROLL_THRESHOLD;
  const startIndex = useVirtual ? Math.floor(scrollTop / ITEM_HEIGHT) : 0;
  const endIndex = useVirtual
    ? Math.min(startIndex + VISIBLE_COUNT + 2, filtered.length)
    : filtered.length;
  const visibleItems = filtered.slice(startIndex, endIndex);

  useEffect(() => {
    if (!open) return;
    const handler = (e: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [open]);

  const formatTime = (t: string | null) => {
    if (!t) return '';
    return new Date(t).toLocaleString('zh-CN');
  };

  return (
    <div className="relative inline-block" ref={containerRef}>
      <button
        className="px-4 py-2 border border-gray-300 rounded bg-white text-sm hover:border-blue-500 min-w-[200px] text-left"
        onClick={() => setOpen(!open)}
      >
        {value || '请选择批次'}
        {loading && <span className="text-gray-400 ml-2">加载中...</span>}
      </button>

      {open && (
        <div className="absolute z-50 mt-1 w-96 bg-white border border-gray-300 rounded shadow-lg">
          <input
            type="text"
            placeholder="搜索批次号..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full px-3 py-2 border-b border-gray-200 text-sm focus:outline-none"
          />
          <div
            className="overflow-y-auto"
            style={{ maxHeight: ITEM_HEIGHT * VISIBLE_COUNT }}
            onScroll={(e) => setScrollTop(e.currentTarget.scrollTop)}
          >
            {visibleItems.length === 0 ? (
              <div className="px-3 py-2 text-gray-400 text-sm">无匹配批次</div>
            ) : (
              <>
                {useVirtual && startIndex > 0 && (
                  <div style={{ height: startIndex * ITEM_HEIGHT }} />
                )}
                {visibleItems.map((batch) => (
                  <div
                    key={batch.batch_no}
                    className={`px-3 py-2 cursor-pointer hover:bg-blue-50 text-sm border-b border-gray-100 ${
                      batch.batch_no === value ? 'bg-blue-100' : ''
                    }`}
                    style={{ height: ITEM_HEIGHT }}
                    onClick={() => {
                      onChange(batch.batch_no);
                      setOpen(false);
                      setSearch('');
                    }}
                  >
                    <div className="font-medium">{batch.batch_no}</div>
                    <div className="text-xs text-gray-500">
                      {formatTime(batch.last_collected_at)} | 记录数: {batch.total_records}
                    </div>
                  </div>
                ))}
                {useVirtual && endIndex < filtered.length && (
                  <div style={{ height: (filtered.length - endIndex) * ITEM_HEIGHT }} />
                )}
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}