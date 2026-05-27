// useEventLog — single global subscription to /api/v1/eventlog. Dispatches
// the 5 message/block events to the chat store. Sidebar footer status dot
// reflects the connection state.
//
// useEventLog —— /api/v1/eventlog 单例订阅；5 个事件分发到 chat store；
// sidebar 状态点反映连接状态。activeUserId 变化时 tear-down 旧 EventSource
// 重连——否则 Onboarding 切到新账号后还在收旧 user 的事件，新发消息不渲染。

import { useEffect, useState } from "react";
import { createSSE } from "@shared/api/sse";
import { useChatStore } from "@entities/conversation";
import { useSessionStore } from "@entities/session";

export function useEventLog() {
  const [status, setStatus] = useState("connecting");
  const activeUserId = useSessionStore((s) => s.currentUserId);

  useEffect(() => {
    const ch = useChatStore.getState();

    type EventPayload = Record<string, unknown> & { conversationId?: string };
    const handlers = {
      message_start: (e: unknown) => {
        const ev = e as EventPayload;
        if (!ev?.conversationId) return;
        ch.ensureConv(ev.conversationId);
        ch.onMessageStart(ev.conversationId, ev as Parameters<typeof ch.onMessageStart>[1]);
      },
      message_stop: (e: unknown) => {
        const ev = e as EventPayload;
        if (ev?.conversationId) ch.onMessageStop(ev.conversationId, ev as Parameters<typeof ch.onMessageStop>[1]);
      },
      block_start: (e: unknown) => {
        const ev = e as EventPayload;
        if (!ev?.conversationId) return;
        ch.ensureConv(ev.conversationId);
        ch.onBlockStart(ev.conversationId, ev as Parameters<typeof ch.onBlockStart>[1]);
      },
      block_delta: (e: unknown) => {
        const ev = e as EventPayload;
        if (ev?.conversationId) ch.onBlockDelta(ev.conversationId, ev as Parameters<typeof ch.onBlockDelta>[1]);
      },
      block_stop: (e: unknown) => {
        const ev = e as EventPayload;
        if (ev?.conversationId) ch.onBlockStop(ev.conversationId, ev as Parameters<typeof ch.onBlockStop>[1]);
      },
    };

    const ctrl = createSSE({
      path: "/eventlog",
      eventHandlers: handlers,
      onStatus: setStatus,
    });
    return () => ctrl.close();
  }, [activeUserId]);

  return status;
}
