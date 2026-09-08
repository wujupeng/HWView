import { useState } from 'react';
import { useCreatePlan } from '../../hooks/useReport';

const ROW_OPTIONS = [
  { value: 1, label: '行1: 目标数量老线', mode: 'value' },
  { value: 2, label: '行2: 实际完成（老线白班）', mode: 'carton' },
  { value: 3, label: '行3: 实际完成（老线夜班）', mode: 'carton' },
  { value: 4, label: '行4: 目标数量新线', mode: 'value' },
  { value: 5, label: '行5: 实际完成（新线）', mode: 'carton' },
  { value: 7, label: '行7: 成C品入库数量', mode: 'value' },
  { value: 8, label: '行8: 出货数量', mode: 'value' },
  { value: 10, label: '行10: 产线成品剩余量', mode: 'value' },
];

export default function InputPage() {
  const [planDate, setPlanDate] = useState('');
  const [rowNo, setRowNo] = useState(1);
  const [value, setValue] = useState('');
  const [cartonCount, setCartonCount] = useState('');
  const [looseQuantity, setLooseQuantity] = useState('');
  const [productCode, setProductCode] = useState('HW102');
  const [inputBy, setInputBy] = useState('admin');
  const createMutation = useCreatePlan();

  const selectedRow = ROW_OPTIONS.find((r) => r.value === rowNo);
  const isCartonMode = selectedRow?.mode === 'carton';

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const payload: Record<string, unknown> = {
      plan_date: planDate,
      row_no: rowNo,
      input_by: inputBy,
      product_code: productCode,
    };
    if (isCartonMode) {
      payload.carton_count = parseInt(cartonCount) || 0;
      payload.loose_quantity = parseInt(looseQuantity) || 0;
    } else {
      payload.value = parseInt(value) || 0;
    }
    createMutation.mutate(payload as never);
  };

  return (
    <div className="p-6 max-w-2xl">
      <h1 className="text-2xl font-bold mb-4">数据录入</h1>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block mb-1">日期</label>
          <input
            type="date"
            value={planDate}
            onChange={(e) => setPlanDate(e.target.value)}
            required
            className="border rounded px-3 py-2 w-full"
          />
        </div>
        <div>
          <label className="block mb-1">行号</label>
          <select
            value={rowNo}
            onChange={(e) => setRowNo(parseInt(e.target.value))}
            className="border rounded px-3 py-2 w-full"
          >
            {ROW_OPTIONS.map((r) => (
              <option key={r.value} value={r.value}>{r.label}</option>
            ))}
          </select>
        </div>
        {isCartonMode ? (
          <>
            <div>
              <label className="block mb-1">整箱数 (carton_count)</label>
              <input
                type="number"
                value={cartonCount}
                onChange={(e) => setCartonCount(e.target.value)}
                min="0"
                className="border rounded px-3 py-2 w-full"
              />
            </div>
            <div>
              <label className="block mb-1">散件数 (loose_quantity)</label>
              <input
                type="number"
                value={looseQuantity}
                onChange={(e) => setLooseQuantity(e.target.value)}
                min="0"
                className="border rounded px-3 py-2 w-full"
              />
            </div>
            <div>
              <label className="block mb-1">产品编码 (product_code)</label>
              <input
                type="text"
                value={productCode}
                onChange={(e) => setProductCode(e.target.value)}
                className="border rounded px-3 py-2 w-full"
              />
            </div>
          </>
        ) : (
          <div>
            <label className="block mb-1">数值 (value)</label>
            <input
              type="number"
              value={value}
              onChange={(e) => setValue(e.target.value)}
              min="0"
              className="border rounded px-3 py-2 w-full"
            />
          </div>
        )}
        <div>
          <label className="block mb-1">录入人</label>
          <input
            type="text"
            value={inputBy}
            onChange={(e) => setInputBy(e.target.value)}
            required
            className="border rounded px-3 py-2 w-full"
          />
        </div>
        <button
          type="submit"
          disabled={createMutation.isPending}
          className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700 disabled:opacity-50"
        >
          {createMutation.isPending ? '提交中...' : '提交'}
        </button>
        {createMutation.isError && (
          <div className="text-red-600">错误: {(createMutation.error as Error).message}</div>
        )}
        {createMutation.isSuccess && (
          <div className="text-green-600">录入成功！actual_quantity 已自动计算</div>
        )}
      </form>
    </div>
  );
}