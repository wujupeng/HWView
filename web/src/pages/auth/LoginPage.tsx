import { FormEvent, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import client, { storeKey } from '../../api/client';

export default function LoginPage() {
  const [key, setKey] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!key.trim()) {
      setError('请输入管理员密钥');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const res = await client.post('/auth/login', { key: key.trim() });
      storeKey(res.data.token || key.trim());
      navigate('/', { replace: true });
    } catch (err: unknown) {
      if (err && typeof err === 'object' && 'response' in err) {
        const resp = err as { response?: { status?: number } };
        if (resp.response?.status === 401) {
          setError('密钥无效，请重新输入');
        } else {
          setError('登录服务不可用，请稍后重试');
        }
      } else {
        setError('网络错误，请稍后重试');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100">
      <form onSubmit={handleSubmit} className="bg-white shadow-md rounded-lg px-8 py-10 w-96">
        <h1 className="text-xl font-bold text-center mb-2">HWView 登录</h1>
        <p className="text-sm text-gray-500 text-center mb-6">多产线数据采集与可视化平台</p>
        <label className="block text-sm font-medium mb-1" htmlFor="admin-key">
          管理员密钥
        </label>
        <input
          id="admin-key"
          type="password"
          value={key}
          onChange={(e) => setKey(e.target.value)}
          className="w-full border border-gray-300 rounded px-3 py-2 mb-4 focus:outline-none focus:border-blue-500"
          placeholder="请输入管理员密钥"
          autoFocus
        />
        {error && <p className="text-red-500 text-sm mb-4">{error}</p>}
        <button
          type="submit"
          disabled={loading}
          className="w-full bg-blue-600 text-white rounded py-2 hover:bg-blue-700 disabled:opacity-50"
        >
          {loading ? '登录中...' : '登录'}
        </button>
      </form>
    </div>
  );
}