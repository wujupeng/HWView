import { useState } from 'react';
import { useHolidays, useCreateHoliday } from '../../hooks/useReport';

export default function HolidayPage() {
  const [startDate, setStartDate] = useState('2026-09-01');
  const [endDate, setEndDate] = useState('2026-09-30');
  const { data, isLoading } = useHolidays(startDate, endDate);
  const [holidayDate, setHolidayDate] = useState('');
  const [holidayName, setHolidayName] = useState('');
  const [isRest, setIsRest] = useState(true);
  const [configBy, setConfigBy] = useState('admin');
  const createMutation = useCreateHoliday();

  return (
    <div className="p-6 max-w-4xl">
      <h1 className="text-2xl font-bold mb-4">节假日配置</h1>
      <div className="flex gap-4 mb-4">
        <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} className="border rounded px-2 py-1" />
        <span>~</span>
        <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} className="border rounded px-2 py-1" />
      </div>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          createMutation.mutate({ holiday_date: holidayDate, holiday_name: holidayName, is_rest: isRest, config_by: configBy });
        }}
        className="space-y-3 mb-6 border p-4 rounded"
      >
        <h2 className="font-bold">新增/更新节假日</h2>
        <div className="flex gap-4">
          <input type="date" value={holidayDate} onChange={(e) => setHolidayDate(e.target.value)} required className="border rounded px-2 py-1" />
          <input type="text" value={holidayName} onChange={(e) => setHolidayName(e.target.value)} placeholder="节假日名称" required className="border rounded px-2 py-1 flex-1" />
          <label className="flex items-center gap-1">
            <input type="checkbox" checked={isRest} onChange={(e) => setIsRest(e.target.checked)} />
            休息
          </label>
          <input type="text" value={configBy} onChange={(e) => setConfigBy(e.target.value)} placeholder="配置人" required className="border rounded px-2 py-1 w-32" />
          <button type="submit" disabled={createMutation.isPending} className="bg-blue-600 text-white px-3 py-1 rounded">
            保存
          </button>
        </div>
      </form>
      {isLoading && <div>加载中...</div>}
      {data && (
        <table className="border-collapse border border-gray-300 w-full text-sm">
          <thead>
            <tr className="bg-gray-200">
              <th className="border border-gray-300 px-2 py-1">日期</th>
              <th className="border border-gray-300 px-2 py-1">名称</th>
              <th className="border border-gray-300 px-2 py-1">休息</th>
              <th className="border border-gray-300 px-2 py-1">配置人</th>
            </tr>
          </thead>
          <tbody>
            {data.holidays.map((h) => (
              <tr key={h.id}>
                <td className="border border-gray-300 px-2 py-1">{h.holiday_date}</td>
                <td className="border border-gray-300 px-2 py-1">{h.holiday_name}</td>
                <td className="border border-gray-300 px-2 py-1 text-center">{h.is_rest ? '✓' : ''}</td>
                <td className="border border-gray-300 px-2 py-1">{h.config_by}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}