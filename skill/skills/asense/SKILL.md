---
name: asense
description: Physical context from the user's iPhone sensors — location, movement, activity, and nearby Bluetooth devices.
metadata: {"openclaw": {"requires": {"bins": ["asense"], "env": ["ASENSE_SERVER", "ASENSE_DEVICE_ID", "ASENSE_API_TOKEN", "ASENSE_ENCRYPTION_KEY"]}, "primaryEnv": "ASENSE_DEVICE_ID", "install": [{"id": "npm", "kind": "node", "package": "asense", "bins": ["asense"], "label": "Install via npm"}]}}
---

# aSense CLI

Query the user's real-world physical context from their iPhone's sensors. All data is end-to-end encrypted — the server never sees plaintext.

```bash
asense <command>
```

## Commands

### `asense status`

Current physical context snapshot. Returns the most recent sensor reading (last 5 minutes).

```bash
asense status
```

Example output:
```
Physical context (as of 2:30 PM):
- Activity: Driving S at ~60 mph
- Location: 35.9260, -86.8689 (alt 198m)
- Steps today: 3,482 (2.7 km)
- Nearby devices: Car Stereo (-45 dBm)
```

### `asense history`

Rolling context over the last 30 minutes. Returns multiple timestamped snapshots in chronological order.

```bash
asense history
```

Use this to understand what the user has been doing recently — were they just walking, driving, sitting?

### `asense transitions`

Detect activity state changes in the last hour (e.g. stationary → walking → driving).

```bash
asense transitions
```

Example output:
```
Activity transitions (last hour):
- 1:45 PM: stationary -> walking
- 1:58 PM: walking -> driving
- 2:25 PM: driving -> stationary
```

## When to Use

- **Before interrupting**: Check if the user is driving, in a meeting, or exercising. Adjust tone and urgency accordingly.
- **Proactive suggestions**: If the user just arrived somewhere or started a new activity, context-aware suggestions are welcome.
- **Ambient awareness**: Use `status` periodically during long conversations to stay aware of the user's physical state.

## Notes

- All commands return JSON: `{"ok": true, "data": "..."}` on success, `{"ok": false, "error": "..."}` on failure.
- Data is decrypted locally — the aSense worker only stores opaque encrypted blobs.
- If no recent data is available, the command returns a message saying so rather than failing.
- The iOS app must be running with at least one sensor enabled for data to flow.
