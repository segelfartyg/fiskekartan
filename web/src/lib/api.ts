import { getToken } from './auth.svelte';

export class ApiError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export interface CatchSummary {
  id: string;
  species: string;
  latitude: number;
  longitude: number;
  caught_at: string;
  thumbnail?: string;
}

export interface CatchDetail extends CatchSummary {
  weight_grams?: number;
  length_cm?: number;
  bait_lure?: string;
  technique?: string;
  water_type?: string;
  notes?: string;
  weather_temp_c?: number;
  weather_wind_speed_ms?: number;
  weather_wind_direction?: string;
  weather_pressure_hpa?: number;
  weather_cloud_cover?: string;
  water_temp_c?: number;
  images?: string[];
  owned_by_me: boolean;
  has_owner: boolean;
  logged_by?: string;
}

export interface Lure {
  id: string;
  title: string;
  description?: string;
  image?: string;
  created_at: string;
}

export async function listCatches(opts?: { mine?: boolean }): Promise<CatchSummary[]> {
  const token = await getToken();
  const url = opts?.mine ? '/api/catches?mine=true' : '/api/catches';
  const res = await fetch(url, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!res.ok) throw new Error('Failed to load catches');
  return res.json();
}

export async function getCatch(id: string): Promise<CatchDetail> {
  const token = await getToken();
  const res = await fetch(`/api/catches/${id}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!res.ok) throw new Error('Failed to load catch');
  return res.json();
}

export async function createCatch(form: FormData): Promise<{ id: string }> {
  const token = await getToken();
  const res = await fetch('/api/catches', {
    method: 'POST',
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    body: form,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new ApiError(res.status, text || 'Failed to save catch');
  }
  return res.json();
}

export async function deleteCatch(id: string): Promise<void> {
  const token = await getToken();
  const res = await fetch(`/api/catches/${id}`, {
    method: 'DELETE',
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!res.ok) {
    const text = await res.text();
    throw new ApiError(res.status, text || 'Failed to delete catch');
  }
}

export async function listMyLures(): Promise<Lure[]> {
  const token = await getToken();
  const res = await fetch('/api/lures', {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!res.ok) throw new Error('Failed to load lures');
  return res.json();
}

export async function createLure(form: FormData): Promise<{ id: string }> {
  const token = await getToken();
  const res = await fetch('/api/lures', {
    method: 'POST',
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    body: form,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new ApiError(res.status, text || 'Failed to save lure');
  }
  return res.json();
}

export async function deleteLure(id: string): Promise<void> {
  const token = await getToken();
  const res = await fetch(`/api/lures/${id}`, {
    method: 'DELETE',
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!res.ok) {
    const text = await res.text();
    throw new ApiError(res.status, text || 'Failed to delete lure');
  }
}
