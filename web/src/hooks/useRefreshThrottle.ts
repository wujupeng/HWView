import { useState, useCallback } from 'react';

export const MIN_REFRESH_INTERVAL_MS = 3000;

export function useRefreshThrottle(minIntervalMs: number = MIN_REFRESH_INTERVAL_MS) {
  const [lastRefreshAt, setLastRefreshAt] = useState<number | null>(null);
  const [isThrottled, setIsThrottled] = useState(false);

  const onRefresh = useCallback(() => {
    const now = Date.now();
    if (lastRefreshAt !== null && now - lastRefreshAt < minIntervalMs) {
      setIsThrottled(true);
      return false;
    }
    setLastRefreshAt(now);
    setIsThrottled(false);
    return true;
  }, [lastRefreshAt, minIntervalMs]);

  return { onRefresh, lastRefreshAt, isThrottled };
}