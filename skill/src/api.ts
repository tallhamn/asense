import type { Config } from "./config.js";

interface RawEntry {
  timestamp: string;
  data: string;
}

export interface TelemetryEntry {
  timestamp: string;
  payload: Buffer;
}

export async function fetchTelemetry(
  config: Config,
  opts: { since?: string; limit?: number } = {}
): Promise<TelemetryEntry[]> {
  const url = new URL(`${config.server}/api/telemetry`);
  url.searchParams.set("device_id", config.deviceId);
  if (opts.since) url.searchParams.set("since", opts.since);
  if (opts.limit) url.searchParams.set("limit", String(opts.limit));

  const res = await fetch(url.toString(), {
    headers: { Authorization: `Bearer ${config.apiToken}` },
  });

  if (!res.ok) {
    throw new Error(`API error: ${res.status} ${res.statusText}`);
  }

  const entries: RawEntry[] = await res.json();
  return entries.map((e) => ({
    timestamp: e.timestamp,
    payload: Buffer.from(e.data, "base64"),
  }));
}
