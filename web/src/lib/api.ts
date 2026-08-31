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
}

export async function listCatches(): Promise<CatchSummary[]> {
  const res = await fetch('/api/catches');
  if (!res.ok) throw new Error('Failed to load catches');
  return res.json();
}

export async function getCatch(id: string): Promise<CatchDetail> {
  const res = await fetch(`/api/catches/${id}`);
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
