import { createDecipheriv } from "node:crypto";

/**
 * Decrypt AES-256-GCM data produced by the iOS app.
 * Format: nonce (12 bytes) || ciphertext || tag (16 bytes)
 */
export function decrypt(combined: Buffer, key: Buffer): Buffer {
  const nonce = combined.subarray(0, 12);
  const tag = combined.subarray(combined.length - 16);
  const ciphertext = combined.subarray(12, combined.length - 16);

  const decipher = createDecipheriv("aes-256-gcm", key, nonce);
  decipher.setAuthTag(tag);

  return Buffer.concat([decipher.update(ciphertext), decipher.final()]);
}
