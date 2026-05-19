// Shared SSE connection factory. EventSource ships its own auto-reconnect
// and automatically replays the last `id:` value via the Last-Event-ID
// header — which is exactly what the backend's /eventlog, /notifications,
// and /forge handlers honour. We don't manually close on transient
// errors; we only close if the caller does (component unmount).
//
// 共享 SSE 连接工厂。依赖 EventSource 内建自动重连 + 自动 Last-Event-ID
// 行为（后端三个 SSE 端点都读这个 header）。组件 unmount 才 close。

import { apiUrl } from "../bridge/wails.js";

export function createSSE({ path, eventHandlers, onStatus }) {
  const url = apiUrl("/api/v1" + path);
  const es = new EventSource(url);

  if (onStatus) {
    onStatus("connecting");
    es.addEventListener("open", () => onStatus("connected"));
    es.addEventListener("error", () => {
      // readyState 0 = CONNECTING (about to retry), 2 = CLOSED (terminal).
      onStatus(es.readyState === EventSource.CLOSED ? "disconnected" : "connecting");
    });
  }

  for (const [evt, handler] of Object.entries(eventHandlers)) {
    es.addEventListener(evt, (e) => {
      let payload = null;
      try { payload = JSON.parse(e.data); } catch { /* fall through */ }
      try { handler(payload, { seq: parseInt(e.lastEventId || "0", 10), raw: e.data }); }
      catch (err) { console.error(`[SSE ${path}] handler ${evt} threw`, err); }
    });
  }

  return { close: () => es.close() };
}
