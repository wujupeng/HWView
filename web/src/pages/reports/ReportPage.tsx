import { useState } from 'react';
import { useReport, useExportReport } from '../../hooks/useReport';

export default function ReportPage() {
  const [startDate, setStartDate] = useState('2026-09-05');
  const [endDate, setEndDate] = useState('2026-09-30');
  const { data: report, isLoading } = useReport(startDate, endDate);
  const exportMutation = useExportReport();

  const rowColorClass = (color: string) => {
    switch (color) {
      case 'green': return 'bg-green-100';
      case 'blue': return 'bg-blue-100';
      default: return '';
    }
  };

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-2xl font-bold">102日产出计划报表</h1>
        <div className="flex items-center gap-4">
          <input
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            className="border rounded px-2 py-1"
          />
          <span>~</span>
          <input
            type="date"
            value={endDate}
            onChange={(e) => setEndDate(e.target.value)}
            className="border rounded px-2 py-1"
          />
          <button
            onClick={() => exportMutation.mutate({ startDate, endDate })}
            disabled={exportMutation.isPending}
            className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700 disabled:opacity-50"
          >
            {exportMutation.isPending ? '导出中...' : '导出 Excel'}
          </button>
        </div>
      </div>

      {isLoading && <div>加载中...</div>}
      {report && (
        <div className="overflow-x-auto">
          <table className="border-collapse border border-gray-300 text-sm">
            <thead>
              <tr>
                <th className="border border-gray-300 px-2 py-1 bg-gray-200 sticky left-0">指标</th>
                {report.dates.map((date) => (
                  <th
                    key={date}
                    className={`border border-gray-300 px-2 py-1 ${
                      report.holidays[date] ? 'bg-yellow-200' : 'bg-gray-200'
                    }`}
                  >
                    {date.slice(5)}
                    {report.holidays[date] && (
                      <div className="text-xs text-orange-600">{report.holidays[date]}</div>
                    )}
                  </th>
                ))}
                <th className="border border-gray-300 px-2 py-1 bg-gray-300">累计</th>
              </tr>
            </thead>
            <tbody>
              {report.row_names.map((name, rowIdx) => (
                <tr key={rowIdx}>
                  <td className={`border border-gray-300 px-2 py-1 font-medium ${rowColorClass(report.row_colors[rowIdx])} sticky left-0`}>
                    {name}
                  </td>
                  {report.dates.map((_, colIdx) => (
                    <td
                      key={colIdx}
                      className={`border border-gray-300 px-2 py-1 text-center ${
                        rowColorClass(report.row_colors[rowIdx])
                      } ${
                        report.holidays[report.dates[colIdx]] ? 'bg-yellow-50' : ''
                      }`}
                    >
                      {report.matrix[rowIdx]?.[colIdx] ?? ''}
                    </td>
                  ))}
                  <td className="border border-gray-300 px-2 py-1 text-center font-bold bg-gray-100">
                    {report.cumulative[rowIdx]}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {report.reference && Object.keys(report.reference.per_date).length > 0 && (
            <div className="mt-6">
              <h2 className="text-lg font-bold mb-2 text-gray-600">
                {report.reference.description}
              </h2>
              <table className="border-collapse border border-gray-300 text-sm">
                <thead>
                  <tr>
                    <th className="border border-gray-300 px-2 py-1 bg-gray-200">日期</th>
                    <th className="border border-gray-300 px-2 py-1 bg-gray-200">A (记录数)</th>
                    <th className="border border-gray-300 px-2 py-1 bg-gray-200">B (唯一条码)</th>
                    <th className="border border-gray-300 px-2 py-1 bg-gray-200">D (quantity求和)</th>
                  </tr>
                </thead>
                <tbody>
                  {Object.entries(report.reference.per_date).map(([date, vals]) => (
                    <tr key={date}>
                      <td className="border border-gray-300 px-2 py-1">{date}</td>
                      <td className="border border-gray-300 px-2 py-1 text-center">{vals.A_records}</td>
                      <td className="border border-gray-300 px-2 py-1 text-center">{vals.B_unique_barcodes}</td>
                      <td className="border border-gray-300 px-2 py-1 text-center">{vals.D_sum_quantity}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  );
}