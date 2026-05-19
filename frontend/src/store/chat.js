// Chat store — message/block tree built from eventlog SSE.
//
// State shape (per conversation):
//   messages: Map<msgId, Message{id, role, status, blocks: [blockId..], ...}>
//   blocks:   Map<blockId, Block{id, parentId, messageId, type, content, status, ...}>
//   topMsgIds: msgId[] — top-level messages in arrival order (subagent
//              inner messages live nested under message-type blocks).
//
// Algorithms:
//   onMessageStart: insert into messages; if parentBlockId given, the
//     message is nested under that block's children (the parent block
//     should already exist as type="message"). Otherwise it joins
//     topMsgIds.
//   onBlockStart: insert into blocks; attach to either parent
//     message.blocks[] or parent block.children[].
//   onBlockDelta: append delta to block.content; bump version.
//   onBlockStop: set block.status + durationMs; final cleanup.
//   onMessageStop: set message.status + token counts.
//
// 设计目标：tree 增量更新，TextBlock/ToolCallBlock 等 React 组件按 id
// memo，单 delta 只重渲染对应 block，不会重渲染整个对话。

import { create } from "zustand";

function emptyConv() {
  return { messages: new Map(), blocks: new Map(), topMsgIds: [], lastSeq: 0 };
}

export const useChatStore = create((set, get) => ({
  convs: {},

  ensureConv(convId) {
    const state = get();
    if (state.convs[convId]) return;
    set((s) => ({ convs: { ...s.convs, [convId]: emptyConv() } }));
  },

  resetConv(convId) {
    set((s) => ({ convs: { ...s.convs, [convId]: emptyConv() } }));
  },

  // Hydrate from REST history (array of messages with nested blocks).
  // Replaces tree contents; safe to call on conv switch / 410 recovery.
  hydrateConv(convId, messages) {
    const conv = emptyConv();
    const installBlock = (msgId, parentId, b) => {
      const block = {
        id: b.id,
        messageId: msgId,
        parentId: parentId || msgId,
        type: b.type,
        attrs: b.attrs || null,
        content: b.content || "",
        status: b.status || "completed",
        durationMs: b.durationMs ?? null,
        error: b.error || null,
        children: [],
        version: 0,
      };
      conv.blocks.set(b.id, block);
      // Attach to parent's children list.
      if (parentId && conv.blocks.has(parentId)) {
        conv.blocks.get(parentId).children.push(b.id);
      } else if (conv.messages.has(msgId)) {
        conv.messages.get(msgId).blocks.push(b.id);
      }
      if (Array.isArray(b.children)) {
        for (const child of b.children) installBlock(msgId, b.id, child);
      }
      if (b.type === "message" && b.innerMessage) {
        installMessage(b.innerMessage, b.id);
      }
    };

    const installMessage = (m, parentBlockId) => {
      const message = {
        id: m.id,
        role: m.role,
        status: m.status || "completed",
        createdAt: m.createdAt,
        stopReason: m.stopReason || null,
        inputTokens: m.inputTokens ?? null,
        outputTokens: m.outputTokens ?? null,
        model: m.model || null,
        parentBlockId: parentBlockId || null,
        blocks: [],
        attachments: m.attachments || [],
        attrs: m.attrs || null,
      };
      conv.messages.set(m.id, message);
      if (!parentBlockId) {
        conv.topMsgIds.push(m.id);
      }
      if (Array.isArray(m.blocks)) {
        for (const b of m.blocks) installBlock(m.id, parentBlockId, b);
      }
    };

    for (const m of messages || []) installMessage(m, null);

    set((s) => ({ convs: { ...s.convs, [convId]: conv } }));
  },

  // ── SSE handlers ───────────────────────────────────────────────────
  onMessageStart(convId, e) {
    set((s) => {
      const conv = s.convs[convId] || emptyConv();
      if (conv.messages.has(e.id)) return s; // dedupe
      const messages = new Map(conv.messages);
      const blocks = new Map(conv.blocks);
      const parentBlockId = e.parentBlockId || null;

      messages.set(e.id, {
        id: e.id,
        role: e.role,
        status: "streaming",
        createdAt: new Date().toISOString(),
        stopReason: null,
        inputTokens: null,
        outputTokens: null,
        model: null,
        parentBlockId,
        blocks: [],
        attachments: [],
        attrs: e.attrs || null,
      });

      let topMsgIds = conv.topMsgIds;
      if (parentBlockId && blocks.has(parentBlockId)) {
        // Nest the message-id under the placeholder message block so
        // SubagentBlock can find it.
        const parent = { ...blocks.get(parentBlockId) };
        parent.attrs = { ...(parent.attrs || {}), messageId: e.id };
        blocks.set(parentBlockId, parent);
      } else {
        topMsgIds = [...conv.topMsgIds, e.id];
      }

      return { convs: { ...s.convs, [convId]: { ...conv, messages, blocks, topMsgIds } } };
    });
  },

  onMessageStop(convId, e) {
    set((s) => {
      const conv = s.convs[convId];
      if (!conv) return s;
      const cur = conv.messages.get(e.id);
      if (!cur) return s;
      const messages = new Map(conv.messages);
      messages.set(e.id, {
        ...cur,
        status: e.status || "completed",
        stopReason: e.stopReason || cur.stopReason,
        inputTokens: e.inputTokens ?? cur.inputTokens,
        outputTokens: e.outputTokens ?? cur.outputTokens,
      });
      return { convs: { ...s.convs, [convId]: { ...conv, messages } } };
    });
  },

  onBlockStart(convId, e) {
    set((s) => {
      const conv = s.convs[convId] || emptyConv();
      if (conv.blocks.has(e.id)) return s;

      const blocks = new Map(conv.blocks);
      const messages = new Map(conv.messages);

      const parentId = e.parentId || e.messageId;
      const messageId = e.messageId;

      blocks.set(e.id, {
        id: e.id,
        messageId,
        parentId,
        type: e.blockType,
        attrs: e.attrs || null,
        content: "",
        status: "streaming",
        durationMs: null,
        error: null,
        children: [],
        version: 0,
      });

      // attach to parent's child list
      if (parentId === messageId && messages.has(messageId)) {
        const msg = { ...messages.get(messageId), blocks: [...messages.get(messageId).blocks, e.id] };
        messages.set(messageId, msg);
      } else if (blocks.has(parentId)) {
        const parent = blocks.get(parentId);
        const updated = { ...parent, children: [...parent.children, e.id] };
        blocks.set(parentId, updated);
      }

      return { convs: { ...s.convs, [convId]: { ...conv, blocks, messages } } };
    });
  },

  onBlockDelta(convId, e) {
    set((s) => {
      const conv = s.convs[convId];
      if (!conv) return s;
      const cur = conv.blocks.get(e.id);
      if (!cur) return s;
      const blocks = new Map(conv.blocks);
      blocks.set(e.id, {
        ...cur,
        content: cur.content + (e.delta || ""),
        version: cur.version + 1,
      });
      return { convs: { ...s.convs, [convId]: { ...conv, blocks } } };
    });
  },

  onBlockStop(convId, e) {
    set((s) => {
      const conv = s.convs[convId];
      if (!conv) return s;
      const cur = conv.blocks.get(e.id);
      if (!cur) return s;
      const blocks = new Map(conv.blocks);
      blocks.set(e.id, {
        ...cur,
        status: e.status || "completed",
        error: e.error || cur.error,
        durationMs: e.durationMs ?? cur.durationMs,
      });
      return { convs: { ...s.convs, [convId]: { ...conv, blocks } } };
    });
  },
}));

// Select helper: array of top-level Message objects for a conv in order.
// Component selectors should use this + per-block selectors to memo.
export function selectTopMessages(convId, state) {
  const conv = state.convs[convId];
  if (!conv) return [];
  return conv.topMsgIds.map((id) => conv.messages.get(id)).filter(Boolean);
}
export function selectBlock(convId, blockId, state) {
  return state.convs[convId]?.blocks.get(blockId) || null;
}
export function selectChildren(convId, parentId, state) {
  const conv = state.convs[convId];
  if (!conv) return [];
  const parent = conv.blocks.get(parentId);
  return parent ? parent.children.map((id) => conv.blocks.get(id)).filter(Boolean) : [];
}
