interface Env {
	TELEMETRY: R2Bucket;
	API_TOKEN: string;
}

interface TelemetryEntry {
	timestamp: string;
	data: string;
}

// In-memory rate limiting
const rateLimits = new Map<string, { count: number; resetTime: number }>();

const RATE_LIMIT = 60;
const RATE_WINDOW_MS = 60_000;

function checkRateLimit(deviceId: string): boolean {
	const now = Date.now();
	const entry = rateLimits.get(deviceId);

	if (!entry || now > entry.resetTime) {
		rateLimits.set(deviceId, { count: 1, resetTime: now + RATE_WINDOW_MS });
		return true;
	}

	if (entry.count >= RATE_LIMIT) {
		return false;
	}

	entry.count++;
	return true;
}

function jsonResponse(body: unknown, status = 200): Response {
	return new Response(JSON.stringify(body), {
		status,
		headers: { "Content-Type": "application/json" },
	});
}

async function handlePost(request: Request, env: Env): Promise<Response> {
	const deviceId = request.headers.get("X-Device-ID");
	if (!deviceId) {
		return jsonResponse({ error: "Missing X-Device-ID header" }, 400);
	}

	if (!checkRateLimit(deviceId)) {
		return jsonResponse({ error: "Rate limit exceeded" }, 429);
	}

	const body = await request.arrayBuffer();
	if (body.byteLength === 0) {
		return jsonResponse({ error: "Empty body" }, 400);
	}

	const key = `${deviceId}/${Date.now()}`;
	await env.TELEMETRY.put(key, body);

	return jsonResponse({ status: "created" }, 201);
}

const FETCH_CONCURRENCY = 50;

async function inBatches<T, R>(items: T[], batchSize: number, fn: (item: T) => Promise<R>): Promise<R[]> {
	const results: R[] = [];
	for (let i = 0; i < items.length; i += batchSize) {
		const batch = await Promise.all(items.slice(i, i + batchSize).map(fn));
		results.push(...batch);
	}
	return results;
}

async function listAllObjects(bucket: R2Bucket, prefix: string): Promise<R2Object[]> {
	const objects: R2Object[] = [];
	let cursor: string | undefined;

	do {
		const batch = await bucket.list({ prefix, cursor });
		objects.push(...batch.objects);
		cursor = batch.truncated ? batch.cursor : undefined;
	} while (cursor);

	return objects;
}

async function handleGet(request: Request, env: Env): Promise<Response> {
	const url = new URL(request.url);
	const deviceId = url.searchParams.get("device_id");
	if (!deviceId) {
		return jsonResponse({ error: "Missing device_id parameter" }, 400);
	}

	if (!checkRateLimit(deviceId)) {
		return jsonResponse({ error: "Rate limit exceeded" }, 429);
	}

	const since = url.searchParams.get("since");
	const sinceMs = since ? new Date(since).getTime() : 0;
	const limit = Math.min(parseInt(url.searchParams.get("limit") || "100", 10) || 100, 1000);

	const allObjects = await listAllObjects(env.TELEMETRY, `${deviceId}/`);

	const keys = allObjects
		.map((obj) => {
			const ts = parseInt(obj.key.split("/")[1], 10);
			return { key: obj.key, ts };
		})
		.filter((entry) => entry.ts >= sinceMs)
		.sort((a, b) => b.ts - a.ts) // newest first
		.slice(0, limit);

	// Fetch blobs in parallel, bounded concurrency
	const entries: TelemetryEntry[] = (
		await inBatches(keys, FETCH_CONCURRENCY, async ({ key, ts }) => {
			const obj = await env.TELEMETRY.get(key);
			if (!obj) return null;

			const buf = await obj.arrayBuffer();
			const base64 = btoa(String.fromCharCode(...new Uint8Array(buf)));
			return { timestamp: new Date(ts).toISOString(), data: base64 };
		})
	).filter((e): e is TelemetryEntry => e !== null);

	return jsonResponse(entries);
}

async function handleDelete(request: Request, env: Env): Promise<Response> {
	const url = new URL(request.url);
	const deviceId = url.searchParams.get("device_id");
	if (!deviceId) {
		return jsonResponse({ error: "Missing device_id parameter" }, 400);
	}

	if (!checkRateLimit(deviceId)) {
		return jsonResponse({ error: "Rate limit exceeded" }, 429);
	}

	const before = url.searchParams.get("before");
	const beforeMs = before ? new Date(before).getTime() : Infinity;

	const allObjects = await listAllObjects(env.TELEMETRY, `${deviceId}/`);

	const toDelete = allObjects
		.filter((obj) => {
			const ts = parseInt(obj.key.split("/")[1], 10);
			return ts < beforeMs;
		})
		.map((obj) => obj.key);

	if (toDelete.length > 0) {
		await env.TELEMETRY.delete(toDelete);
	}

	return jsonResponse({ deleted: toDelete.length });
}

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		const url = new URL(request.url);

		if (url.pathname !== "/api/telemetry") {
			return jsonResponse({ error: "Not found" }, 404);
		}

		const auth = request.headers.get("Authorization");
		if (!auth || auth !== `Bearer ${env.API_TOKEN}`) {
			return jsonResponse({ error: "Unauthorized" }, 401);
		}

		switch (request.method) {
			case "POST":
				return handlePost(request, env);
			case "GET":
				return handleGet(request, env);
			case "DELETE":
				return handleDelete(request, env);
			default:
				return jsonResponse({ error: "Method not allowed" }, 405);
		}
	},
} satisfies ExportedHandler<Env>;
