import { useQuery } from '@tanstack/react-query';
import client from '../api/client';
import type { ProductionLine, DataSource } from '../types';

export function useLines() {
  return useQuery<ProductionLine[]>({
    queryKey: ['lines'],
    queryFn: async () => {
      const res = await client.get('/lines');
      return res.data.lines;
    },
  });
}

export function useSources(lineID?: number) {
  return useQuery<DataSource[]>({
    queryKey: ['sources', lineID],
    queryFn: async () => {
      const res = await client.get(`/sources/line/${lineID}`);
      return res.data.sources;
    },
    enabled: !!lineID,
  });
}