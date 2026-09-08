import axios from 'axios';

const KEY_STORAGE = 'hwview_admin_key';

export function getStoredKey(): string | null {
  return localStorage.getItem(KEY_STORAGE);
}

export function storeKey(key: string): void {
  localStorage.setItem(KEY_STORAGE, key);
}

export function clearKey(): void {
  localStorage.removeItem(KEY_STORAGE);
}

const client = axios.create({
  baseURL: '/api/v1',
  timeout: 10000,
});

client.interceptors.request.use((config) => {
  const key = getStoredKey();
  if (key) {
    config.headers['X-Admin-Key'] = key;
  }
  return config;
});

client.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response && error.response.status === 401) {
      clearKey();
      if (window.location.pathname !== '/login') {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

export default client;
