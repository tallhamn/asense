interface SensorReadings {
  location?: { lat: number; lon: number; altitude: number; accuracy: number };
  velocity?: { speed: number; course: number };
  steps?: { count: number; distance: number; floors_up: number; floors_down: number };
  motion?: { state: string; confidence: string };
  bluetooth?: { devices: { name: string; rssi: number; uuid: string }[] };
}

interface TelemetryPayload {
  timestamp: string;
  sensors: SensorReadings;
}

const COURSE_LABELS: Record<string, [number, number]> = {
  N: [337.5, 22.5],
  NE: [22.5, 67.5],
  E: [67.5, 112.5],
  SE: [112.5, 157.5],
  S: [157.5, 202.5],
  SW: [202.5, 247.5],
  W: [247.5, 292.5],
  NW: [292.5, 337.5],
};

function courseToDirection(course: number): string {
  for (const [label, [start, end]] of Object.entries(COURSE_LABELS)) {
    if (label === "N") {
      if (course >= start || course < end) return label;
    } else {
      if (course >= start && course < end) return label;
    }
  }
  return "";
}

function metersPerSecToMph(mps: number): number {
  return mps * 2.23694;
}

function formatNumber(n: number): string {
  return n.toLocaleString("en-US");
}

export function summarize(payload: TelemetryPayload): string {
  const { sensors } = payload;
  const time = new Date(payload.timestamp).toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
  });
  const lines: string[] = [`Physical context (as of ${time}):`];

  // Activity + velocity
  if (sensors.motion) {
    let activity = sensors.motion.state.charAt(0).toUpperCase() + sensors.motion.state.slice(1);
    if (sensors.velocity && sensors.velocity.speed > 0.5) {
      const mph = metersPerSecToMph(sensors.velocity.speed);
      const dir = courseToDirection(sensors.velocity.course);
      activity += ` ${dir} at ~${Math.round(mph)} mph`;
    }
    lines.push(`- Activity: ${activity}`);
  } else if (sensors.velocity && sensors.velocity.speed > 0.5) {
    const mph = metersPerSecToMph(sensors.velocity.speed);
    const dir = courseToDirection(sensors.velocity.course);
    lines.push(`- Speed: ~${Math.round(mph)} mph heading ${dir}`);
  }

  // Location
  if (sensors.location) {
    const { lat, lon, altitude } = sensors.location;
    lines.push(`- Location: ${lat.toFixed(4)}, ${lon.toFixed(4)} (alt ${Math.round(altitude)}m)`);
  }

  // Steps
  if (sensors.steps) {
    let step = `- Steps today: ${formatNumber(sensors.steps.count)}`;
    if (sensors.steps.distance > 0) {
      step += ` (${(sensors.steps.distance / 1000).toFixed(1)} km)`;
    }
    if (sensors.steps.floors_up > 0 || sensors.steps.floors_down > 0) {
      step += ` | Floors: ${sensors.steps.floors_up} up, ${sensors.steps.floors_down} down`;
    }
    lines.push(step);
  }

  // Bluetooth
  if (sensors.bluetooth && sensors.bluetooth.devices.length > 0) {
    const names = sensors.bluetooth.devices
      .slice(0, 5)
      .map((d) => `${d.name} (${d.rssi} dBm)`)
      .join(", ");
    lines.push(`- Nearby devices: ${names}`);
  }

  return lines.join("\n");
}

export function detectTransitions(
  payloads: TelemetryPayload[]
): string[] {
  if (payloads.length < 2) return [];

  const transitions: string[] = [];
  for (let i = 1; i < payloads.length; i++) {
    const prev = payloads[i - 1].sensors.motion?.state;
    const curr = payloads[i].sensors.motion?.state;
    if (prev && curr && prev !== curr) {
      const time = new Date(payloads[i].timestamp).toLocaleTimeString("en-US", {
        hour: "numeric",
        minute: "2-digit",
      });
      transitions.push(`${time}: ${prev} -> ${curr}`);
    }
  }

  return transitions;
}

export type { TelemetryPayload, SensorReadings };
