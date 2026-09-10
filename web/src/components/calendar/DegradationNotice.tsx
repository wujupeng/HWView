import type { CalendarDegradationStatus } from '../../types';

interface DegradationNoticeProps {
  degradationStatus: CalendarDegradationStatus;
}

export default function DegradationNotice({ degradationStatus }: DegradationNoticeProps) {
  if (degradationStatus.type === 'none') {
    return null;
  }

  if (degradationStatus.type === 'overall') {
    const needsCookieHint = degradationStatus.reason.includes('登录凭据');
    return (
      <div className="bg-red-50 border border-red-200 text-red-700 rounded-lg p-3 mb-4 text-sm">
        上游源系统不可达，已回退至数据库聚合数据（原因：{degradationStatus.reason}）
        {needsCookieHint && (
          <span className="ml-2 text-red-600">请联系管理员配置 UP_COOKIE</span>
        )}
      </div>
    );
  }

  return (
    <div className="bg-yellow-50 border border-yellow-200 text-yellow-700 rounded-lg p-3 mb-4 text-sm">
      {degradationStatus.degraded_days} 天上游取数失败已回退至数据库聚合
    </div>
  );
}