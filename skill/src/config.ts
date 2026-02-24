export interface Config {
  server: string;
  deviceId: string;
  apiToken: string;
  encryptionKey: Buffer;
}

export function loadConfig(): Config {
  const server = env("ASENSE_SERVER", "https://sense.momstudios.com");
  const deviceId = env("ASENSE_DEVICE_ID");
  const apiToken = env("ASENSE_API_TOKEN");
  const keyBase64 = env("ASENSE_ENCRYPTION_KEY");

  return {
    server: server.replace(/\/$/, ""),
    deviceId,
    apiToken,
    encryptionKey: Buffer.from(keyBase64, "base64"),
  };
}

function env(name: string, fallback?: string): string {
  const val = process.env[name] ?? fallback;
  if (!val) {
    console.error(JSON.stringify({ ok: false, error: `Missing ${name}` }));
    process.exit(1);
  }
  return val;
}
