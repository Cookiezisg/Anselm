import { useUsersStore } from "@/stores/users";

export type StreamID = "eventlog" | "notifications" | "forge";

export interface StreamEvent<T = unknown> {
  event: string;
  id: number;
  data: T;
  receivedAt: number;
}

type Listener = (e: StreamEvent) => void;

interface Channel {
  url: string;
  es: EventSource | null;
  lastEventId: number;
  listeners: Set<Listener>;
  connected: boolean;
  connectedAt?: number;
  lastError?: string;
}

const URLS: Record<StreamID, string> = {
  eventlog: "/api/v1/eventlog",
  notifications: "/api/v1/notifications",
  forge: "/api/v1/forge",
};

const EVENT_NAMES: Record<StreamID, string[]> = {
  eventlog: ["message_start", "message_stop", "block_start", "block_delta", "block_stop"],
  notifications: ["notification"],
  forge: ["forge_started", "forge_op_applied", "forge_env_attempt", "forge_completed"],
};

const channels: Record<StreamID, Channel> = {
  eventlog: blank("eventlog"),
  notifications: blank("notifications"),
  forge: blank("forge"),
};

function blank(s: StreamID): Channel {
  return { url: URLS[s], es: null, lastEventId: 0, listeners: new Set(), connected: false };
}

function connect(stream: StreamID) {
  const ch = channels[stream];
  if (ch.es) return;
  const uid = useUsersStore.getState().activeId;
  const url = uid ? `${ch.url}?userID=${encodeURIComponent(uid)}` : ch.url;
  const es = new EventSource(url, { withCredentials: false });
  ch.es = es;
  ch.connected = false;

  es.onopen = () => {
    ch.connected = true;
    ch.connectedAt = Date.now();
    ch.lastError = undefined;
  };

  es.onerror = () => {
    ch.connected = false;
    ch.lastError = "connection error / 410 SEQ_TOO_OLD; reconnecting…";
    if (ch.es) {
      ch.es.close();
      ch.es = null;
    }
    setTimeout(() => {
      if (ch.listeners.size > 0) {
        ch.lastEventId = 0;
        connect(stream);
      }
    }, 1000);
  };

  es.onmessage = (ev) => fanOut(stream, "message", ev);
  for (const name of EVENT_NAMES[stream]) {
    es.addEventListener(name, (ev) => fanOut(stream, name, ev as MessageEvent));
  }
}

function fanOut(stream: StreamID, eventName: string, ev: MessageEvent) {
  const ch = channels[stream];
  let parsed: unknown = ev.data;
  try {
    parsed = JSON.parse(ev.data as string);
  } catch {
    /* keep raw */
  }
  const id = ev.lastEventId ? Number(ev.lastEventId) : 0;
  if (id > ch.lastEventId) ch.lastEventId = id;
  const wrapped: StreamEvent = { event: eventName, id, data: parsed, receivedAt: Date.now() };
  for (const fn of ch.listeners) {
    try { fn(wrapped); } catch (e) { console.error(`[sse:${stream}]`, e); }
  }
}

export function subscribe(stream: StreamID, fn: Listener): () => void {
  const ch = channels[stream];
  ch.listeners.add(fn);
  if (!ch.es) connect(stream);
  return () => {
    ch.listeners.delete(fn);
    if (ch.listeners.size === 0 && ch.es) {
      ch.es.close();
      ch.es = null;
      ch.connected = false;
    }
  };
}

export function status(stream: StreamID) {
  const ch = channels[stream];
  return {
    connected: ch.connected,
    connectedAt: ch.connectedAt,
    listenerCount: ch.listeners.size,
    lastEventId: ch.lastEventId,
    lastError: ch.lastError,
  };
}

export function reconnect(stream: StreamID) {
  const ch = channels[stream];
  if (ch.es) {
    ch.es.close();
    ch.es = null;
  }
  ch.lastEventId = 0;
  if (ch.listeners.size > 0) connect(stream);
}
