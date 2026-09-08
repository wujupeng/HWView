import { useState } from 'react';
import { useCartonSpecs, useCreateCartonSpec } from '../../hooks/useReport';

export default function CartonSpecPage() {
  const { data, isLoading } = useCartonSpecs();
  const [lineCode, setLineCode] = useState('HW102');
  const [productCode, setProductCode] = useState('HW102');
  const [unitsPerCarton, setUnitsPerCarton] = useState(30);
  const [effectiveFrom, setEffectiveFrom] = useState('2026-09-01');
  const [effectiveTo, setEffectiveTo] = useState('');
  const [configBy, setConfigBy] = useState('admin');
  const createMutation = useCreateCartonSpec();

  return (
    <div className="p-6 max-w-4xl">
      <h1 className="text-2xl font-bold mb-4">装箱规格配置</h1>
      <div className="bg-yellow-50 border border-yellow-300 p-3 rounded mb-4 text-sm">
        <strong>⚠️ R4-BLOCKER-01:</strong> 装箱规格支持三维适用范围（产品 + 产线 + 生效时间）。
        30 和 60 可并存（不同产品/产线/时间）。禁止硬编码。
      </div>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          createMutation.mutate({
            line_code: lineCode,
            product_code: productCode,
            units_per_carton: unitsPerCarton,
            effective_from: effectiveFrom,
            effective_to: effectiveTo || null,
            config_by: configBy,
          });
        }}
        className="space-y-3 mb-6 border p-4 rounded"
      >
        <h2 className="font-bold">新增装箱规格</h2>
        <div className="grid grid-cols-3 gap-4">
          <div>
            <label className="block mb-1 text-sm">产线编码</label>
            <input type="text" value={lineCode} onChange={(e) => setLineCode(e.target.value)} required className="border rounded px-2 py-1 w-full" />
          </div>
          <div>
            <label className="block mb-1 text-sm">产品编码</label>
            <input type="text" value={productCode} onChange={(e) => setProductCode(e.target.value)} required className="border rounded px-2 py-1 w-full" />
          </div>
          <div>
            <label className="block mb-1 text-sm">每箱数量</label>
            <input type="number" value={unitsPerCarton} onChange={(e) => setUnitsPerCarton(parseInt(e.target.value) || 0)} min="1" required className="border rounded px-2 py-1 w-full" />
          </div>
          <div>
            <label className="block mb-1 text-sm">生效起始</label>
            <input type="date" value={effectiveFrom} onChange={(e) => setEffectiveFrom(e.target.value)} required className="border rounded px-2 py-1 w-full" />
          </div>
          <div>
            <label className="block mb-1 text-sm">失效日期（空=长期）</label>
            <input type="date" value={effectiveTo} onChange={(e) => setEffectiveTo(e.target.value)} className="border rounded px-2 py-1 w-full" />
          </div>
          <div>
            <label className="block mb-1 text-sm">配置人</label>
            <input type="text" value={configBy} onChange={(e) => setConfigBy(e.target.value)} required className="border rounded px-2 py-1 w-full" />
          </div>
        </div>
        <button type="submit" disabled={createMutation.isPending} className="bg-blue-600 text-white px-4 py-2 rounded">
          {createMutation.isPending ? '保存中...' : '保存'}
        </button>
      </form>
      {isLoading && <div>加载中...</div>}
      {data && (
        <table className="border-collapse border border-gray-300 w-full text-sm">
          <thead>
            <tr className="bg-gray-200">
              <th className="border border-gray-300 px-2 py-1">产线</th>
              <th className="border border-gray-300 px-2 py-1">产品</th>
              <th className="border border-gray-300 px-2 py-1">件/箱</th>
              <th className="border border-gray-300 px-2 py-1">生效起</th>
              <th className="border border-gray-300 px-2 py-1">生效止</th>
              <th className="border border-gray-300 px-2 py-1">配置人</th>
            </tr>
          </thead>
          <tbody>
            {data.specs.map((s) => (
              <tr key={s.id}>
                <td className="border border-gray-300 px-2 py-1">{s.line_code}</td>
                <td className="border border-gray-300 px-2 py-1">{s.product_code}</td>
                <td className="border border-gray-300 px-2 py-1 text-center font-bold">{s.units_per_carton}</td>
                <td className="border border-gray-300 px-2 py-1">{s.effective_from}</td>
                <td className="border border-gray-300 px-2 py-1">{s.effective_to ?? '长期'}</td>
                <td className="border border-gray-300 px-2 py-1">{s.config_by}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}