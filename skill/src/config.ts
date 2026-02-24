import { readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

export interface Config {
  server: string;
  deviceId: string;
  apiToken: string;
  encryptionKey: Buffer;
}

interface FileConfig {
  server?: string;
  deviceId?: string;
  apiToken?: string;
  encryptionKey?: string;
}

function loadFileConfig(): FileConfig {
  try {
    const path = join(homedir(), ".config", "asense", "config.json");
    return JSON.parse(readFileSync(path, "utf-8"));
  } catch {
    return {};
  }
}

export function loadConfig(): Config {
  const file = loadFileConfig();

  const server = process.env.ASENSE_SERVER ?? file.server ?? "https://asense-worker.momstudios.workers.dev";
  const deviceId = process.env.ASENSE_DEVICE_ID ?? file.deviceId;
  const apiToken = process.env.ASENSE_API_TOKEN ?? file.apiToken;
  const keyBase64 = process.env.ASENSE_ENCRYPTION_KEY ?? file.encryptionKey;

  if (!deviceId) fail("Missing deviceId (set ASENSE_DEVICE_ID or add to ~/.config/asense/config.json)");
  if (!apiToken) fail("Missing apiToken (set ASENSE_API_TOKEN or add to ~/.config/asense/config.json)");
  if (!keyBase64) fail("Missing encryptionKey (set ASENSE_ENCRYPTION_KEY or add to ~/.config/asense/config.json)");

  return {
    server: server.replace(/\/$/, ""),
    deviceId,
    apiToken,
    encryptionKey: Buffer.from(keyBase64, "base64"),
  };
}

function fail(msg: string): never {
  console.log(JSON.stringify({ ok: false, error: msg }));
  process.exit(1);
}
