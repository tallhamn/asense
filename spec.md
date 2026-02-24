# aSense — Private Agent Context System

## Overview

aSense is a lightweight system for securely collecting mobile sensor telemetry from an iPhone and making it available to a local AI agent. It gives your agent physical awareness — location, movement, activity — so it can respond to what you're actually doing in the real world.

Three components:

1. **aSense iOS App** (Swift) — Collects sensor data, encrypts on-device, transmits encrypted blobs
2. **aSense Worker** (TypeScript, Cloudflare Workers + R2) — Dumb pipe that stores/serves encrypted blobs, never sees plaintext
3. **aSense Skill** (OpenClaw) — Fetches, decrypts, and summarizes physical context for the agent

The server never sees your data. All encryption and decryption happens at the endpoints.

## Architecture

```
┌─────────────────┐    encrypted    ┌─────────────────────┐    encrypted    ┌─────────────────────┐
│  aSense iOS App │ ─────────────▶  │   aSense Worker     │ ◀───────────── │  aSense Skill       │
│  (Swift)        │   HTTPS POST    │   (Cloudflare + R2) │   HTTPS GET    │  (OpenClaw agent)   │
│                 │                 │                     │                │                     │
│  Sensors:       │                 │  Stores opaque      │                │  Decrypts blobs     │
│  - Location     │                 │  encrypted blobs    │                │  Summarizes context  │
│  - Velocity     │                 │  indexed by UUID    │                │  Feeds to agent     │
│  - Steps        │                 │                     │                │                     │
│  - Motion       │                 │  Never sees         │                │                     │
│  - Bluetooth    │                 │  plaintext          │                │                     │
└─────────────────┘                 └─────────────────────┘                └─────────────────────┘
```

**Domain:** `sense.momstudios.com` (DNS managed by Cloudflare)

---

## Component 1: aSense iOS App (Swift)

### Sensor Toggles

The app presents a settings screen with toggles for each sensor. Disabled sensors are not polled (saves battery).

| Sensor | API | Data Collected |
|--------|-----|----------------|
| Location | CoreLocation | lat, lon, altitude, accuracy |
| Velocity | CoreLocation | speed (m/s), course (heading) |
| Steps | CoreMotion (CMPedometer) | step count, distance, floors, cadence |
| Motion State | CoreMotion (CMMotionActivityManager) | stationary, walking, running, driving, cycling |
| Bluetooth | CoreBluetooth | nearby device names, RSSI, UUIDs |

### Transmission Frequency

Configurable via slider: 10s / 30s / 60s / 5min / 15min (default 60s). Only transmits when at least one sensor is enabled and has new data.

### Encryption

- On first launch, generate a 256-bit AES key via `SecRandomCopyBytes`
- Display as base64 string (~44 chars) for one-time manual transfer to the agent
- Store in iOS Keychain
- Encrypt all payloads with AES-256-GCM via Apple's CryptoKit framework
- IV/nonce is prepended to the ciphertext

### Telemetry Payload (pre-encryption)

```json
{
  "timestamp": "2025-02-23T14:30:00Z",
  "sensors": {
    "location": {
      "lat": 35.9260,
      "lon": -86.8689,
      "altitude": 198.3,
      "accuracy": 5.0
    },
    "velocity": {
      "speed": 26.8,
      "course": 182.4
    },
    "steps": {
      "count": 3482,
      "distance": 2710.5,
      "floors_up": 2,
      "floors_down": 0
    },
    "motion": {
      "state": "driving",
      "confidence": "high"
    },
    "bluetooth": {
      "devices": [
        { "name": "Car Stereo", "rssi": -45, "uuid": "..." }
      ]
    }
  }
}
```

Only enabled sensors appear in the payload.

### Transmission

- HTTPS POST to `https://sense.momstudios.com/api/telemetry`
- Headers: `X-Device-ID: <UUID>` (generated on first launch, stored in Keychain), `Content-Type: application/octet-stream`
- Body: encrypted blob (IV + ciphertext)
- Buffers unsent payloads locally if offline, sends when connectivity returns

### Background Execution

- `CLLocationManager` with `allowsBackgroundLocationUpdates` for continuous location
- `startMonitoringSignificantLocationChanges()` as low-power fallback
- Background fetch for periodic transmission of buffered data

### Permissions Required

- Location: "Always" (for background collection)
- Motion & Fitness (for steps and motion state)
- Bluetooth (for nearby device scanning)

### Key Export

Settings screen displays the encryption key with a "Copy to Clipboard" button. One-time setup: user copies or types this key into their agent config.

---

## Component 2: aSense Worker (Cloudflare Workers + R2)

### Infrastructure

- Runtime: Cloudflare Workers (TypeScript)
- Storage: Cloudflare R2 (S3-compatible object storage)
- Domain: `sense.momstudios.com`

### Endpoints

#### `POST /api/telemetry`

Receives and stores an encrypted telemetry blob.

- Headers: `X-Device-ID` (UUID)
- Body: raw encrypted bytes
- Storage key: `{device_id}/{timestamp_ms}` in R2
- Response: `201 Created`

#### `GET /api/telemetry`

Retrieves encrypted telemetry blobs.

- Parameters:
  - `device_id` (required) — UUID of the device
  - `since` (optional) — only return blobs after this ISO timestamp
  - `limit` (optional) — max blobs to return (default 100)
- Response: JSON array of `{ "timestamp": "...", "data": "<base64 encoded encrypted blob>" }`

#### `DELETE /api/telemetry`

Cleanup old data.

- Parameters:
  - `device_id` (required) — UUID of the device
  - `before` (optional) — delete blobs before this ISO timestamp
- Response: `200 OK` with count of deleted items

### Security

- The Worker never decrypts anything — stores and retrieves opaque bytes only
- Rate limiting: 60 requests per minute per device ID
- Optional: API token in `Authorization` header for basic access control

### R2 Configuration

- Bucket name: `sense-telemetry`
- Object key format: `{device_id}/{timestamp_ms}`
- Lifecycle rule: auto-delete objects older than 30 days

### wrangler.toml

```toml
name = "asense-worker"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[[r2_buckets]]
binding = "TELEMETRY"
bucket_name = "sense-telemetry"

[triggers]
routes = ["sense.momstudios.com/*"]
```

### Deployment

```bash
npm create cloudflare@latest asense-worker
# implement endpoints in src/index.ts
wrangler deploy
```

---

## Component 3: aSense Skill (OpenClaw)

### Overview

An OpenClaw skill that gives the agent awareness of the user's physical context. The agent invokes aSense when it wants to know what the user is doing in the real world.

### Configuration

```yaml
# ~/.config/asense/config.yaml
server: https://sense.momstudios.com
device_id: <uuid from aSense iOS app>
encryption_key: <base64 AES-256 key from aSense iOS app>
history_window: 30  # minutes of rolling history to maintain

known_locations:
  - name: "Home"
    lat: 35.926
    lon: -86.869
    radius_m: 100
  - name: "Office"
    lat: 36.162
    lon: -86.781
    radius_m: 200
```

### Skill Commands

```
asense status        → current physical context snapshot
asense history       → rolling context over last N minutes
asense transitions   → recent state changes
```

### Decryption

Uses Python `cryptography` library for AES-256-GCM decryption. Reads key from config. Decrypts each blob and parses the inner JSON.

### Context Summarization

The skill converts raw telemetry into human-readable context the agent can reason about. It does not return raw coordinates.

**Raw input:**

```json
{
  "location": { "lat": 35.926, "lon": -86.869 },
  "velocity": { "speed": 26.8, "course": 182.4 },
  "motion": { "state": "driving" }
}
```

**Summarized output:**

```
Physical context (as of 2:30 PM):
- Activity: Driving south at ~60 mph
- Location: Near Home (Franklin, TN)
- Duration: Driving for approximately 12 minutes
- Steps today: 3,482
- Nearby devices: Car Stereo (Bluetooth connected)
```

### Reverse Geocoding

- Lightweight geocoding to convert coordinates to place names
- Cache recent lookups to minimize API calls
- Match against known locations from config before hitting external APIs

### Rolling History

Maintains a short buffer (default 30 min) of decrypted context to report transitions:

- "User was stationary at home for 2 hours, started driving 12 minutes ago"
- "User has been walking since leaving the office 20 minutes ago"
- "User stopped driving, now stationary at an unknown location"

### State Machine

Tracks activity transitions with timestamps:

```
STATIONARY → WALKING → DRIVING → STATIONARY
     ↑                                │
     └────────────────────────────────┘
```

### Example Agent Interactions

**Agent prompts the user during a drive:**

```
Agent invokes: asense status
Response: "User is driving, has been for 8 minutes.
           Location: I-65 southbound near Franklin.
           No meetings for 2 hours."
Agent: "Hey Marcus, looks like you've got some drive time.
        Want to talk through your priorities for today?"
```

**Agent adjusts behavior based on context:**

```
Agent invokes: asense status
Response: "User is stationary at home. Low step count (200). Early morning."
Agent: [adjusts tone, suggests morning routine items]
```

**Agent detects a transition:**

```
Agent invokes: asense transitions
Response: "User arrived at unknown location after 25 min drive. Now stationary."
Agent: [holds off on interrupting until user seems settled]
```

### Implementation Notes

- Python-based skill following OpenClaw conventions
- Fetches from aSense Worker on demand (when agent invokes), not continuously
- Caches last fetch with 30s TTL to avoid redundant API calls
- Falls back gracefully: "Physical context unavailable" if Worker unreachable

---

## Deployment Checklist

### aSense Worker

1. Create R2 bucket `sense-telemetry` in Cloudflare dashboard
2. `npm create cloudflare@latest asense-worker`
3. Implement the three endpoints in `src/index.ts`
4. Configure R2 binding and domain route in `wrangler.toml`
5. `wrangler deploy`

### aSense iOS App

1. Create new Xcode project (Swift, iOS App)
2. Add capabilities: Background Modes (Location updates, Background fetch), CoreBluetooth
3. Implement sensor manager with toggle-based collection
4. Implement encryption layer (AES-256-GCM via CryptoKit)
5. Implement transmission layer with retry/buffer logic
6. Build settings UI: sensor toggles, frequency slider, key display
7. Deploy to phone via Xcode ($99/yr Apple Developer account recommended)

### aSense Skill

1. Create Python skill following OpenClaw conventions
2. Configure with device UUID + encryption key from iOS app
3. Add known locations to config
4. Register skill with agent
5. Test with `asense status`

---

## Future Considerations

- **Additional sensors:** screen time, ambient light, barometer
- **Geofencing:** different collection profiles based on location (home, office, car)
- **Compression:** compress JSON before encryption to reduce bandwidth
- **WebSocket:** replace polling with persistent connection for real-time context
- **Multi-device:** support multiple phones/devices per agent
- **Pattern learning:** "user usually drives this route at this time"
- **Task integration:** auto-suggest tasks based on physical context and time of day
