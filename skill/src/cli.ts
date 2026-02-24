import { loadConfig } from "./config.js";
import { fetchTelemetry } from "./api.js";
import { decrypt } from "./crypto.js";
import { summarize, detectTransitions, type TelemetryPayload } from "./context.js";

function ok(data: unknown) {
  console.log(JSON.stringify({ ok: true, data }));
}

function fail(error: string) {
  console.log(JSON.stringify({ ok: false, error }));
  process.exit(1);
}

async function fetchAndDecrypt(
  sinceMinutes: number,
  limit = 100
): Promise<TelemetryPayload[]> {
  const config = loadConfig();
  const since = new Date(Date.now() - sinceMinutes * 60_000).toISOString();
  const entries = await fetchTelemetry(config, { since, limit });

  return entries
    .map((entry) => {
      try {
        const plaintext = decrypt(entry.payload, config.encryptionKey);
        return JSON.parse(plaintext.toString()) as TelemetryPayload;
      } catch {
        return null;
      }
    })
    .filter((p): p is TelemetryPayload => p !== null);
}

async function status() {
  const payloads = await fetchAndDecrypt(5, 1);
  if (payloads.length === 0) {
    return ok("No recent telemetry available.");
  }
  ok(summarize(payloads[0]));
}

async function history() {
  const payloads = await fetchAndDecrypt(30, 50);
  if (payloads.length === 0) {
    return ok("No telemetry in the last 30 minutes.");
  }

  // Oldest first for chronological reading
  const summaries = payloads.reverse().map(summarize);
  ok(summaries.join("\n\n---\n\n"));
}

async function transitions() {
  const payloads = await fetchAndDecrypt(60, 100);
  if (payloads.length < 2) {
    return ok("Not enough data to detect transitions.");
  }

  // Oldest first for chronological order
  const sorted = payloads.sort(
    (a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
  );
  const changes = detectTransitions(sorted);

  if (changes.length === 0) {
    const current = sorted[sorted.length - 1].sensors.motion?.state ?? "unknown";
    return ok(`No activity transitions in the last hour. Current state: ${current}.`);
  }

  ok("Activity transitions (last hour):\n" + changes.map((t) => `- ${t}`).join("\n"));
}

async function main() {
  const command = process.argv[2];

  try {
    switch (command) {
      case "status":
        await status();
        break;
      case "history":
        await history();
        break;
      case "transitions":
        await transitions();
        break;
      default:
        fail(`Unknown command: ${command ?? "(none)"}. Use: status, history, transitions`);
    }
  } catch (e) {
    fail(e instanceof Error ? e.message : String(e));
  }
}

main();
