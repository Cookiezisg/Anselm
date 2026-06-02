// Conversation, Message, Block entity types — mirrors backend json tags (camelCase).
// Block types / statuses are the canonical 7+4 enums from backend/domain/eventlog/eventlog.go.
//
// 对齐后端 domain/chat + domain/eventlog 的 json tag 字段名(camelCase)。

// ── Conversation ─────────────────────────────────────────────────────

export interface AttachedDocument {
  documentId: string;
  includeSubtree: boolean;
}

// ModelRef — stable (apiKeyId, modelId) pair reusable across domains.
// provider is implicit via the api_key referenced by apiKeyId.
//
// 跨 domain (apiKeyId, modelId) 对(conv 和 node override 复用);provider 由 api_key 隐含。
export interface ModelRef {
  apiKeyId: string;
  modelId: string;
  options?: Record<string, string>;
}

export interface Conversation {
  id: string;
  title: string;
  autoTitled: boolean;
  systemPrompt?: string;
  summary?: string;
  summaryCoversUpToSeq?: number;
  attachedDocuments?: AttachedDocument[];
  archived: boolean;
  pinned: boolean;
  modelOverride?: ModelRef | null;
  createdAt: string;
  updatedAt: string;
}

export interface CreateConversationBody {
  title?: string;
}

export interface UpdateConversationPatch {
  title?: string;
  systemPrompt?: string;
  attachedDocuments?: AttachedDocument[];
  archived?: boolean;
  pinned?: boolean;
  modelOverride?: ModelRef | null;
}

// ── Block ────────────────────────────────────────────────────────────

// 7 sealed block types — from backend/internal/domain/eventlog/eventlog.go consts.
export type BlockType =
  | "text"
  | "reasoning"
  | "tool_call"
  | "tool_result"
  | "progress"
  | "message"
  | "compaction";

// 4 block/message statuses — streaming → terminal (completed | error | cancelled).
export type BlockStatus = "streaming" | "completed" | "error" | "cancelled";

// Frontend runtime shape; durationMs is computed client-side from SSE timings.
export interface Block {
  id: string;
  messageId: string;
  parentId: string;
  type: BlockType;
  attrs: Record<string, unknown> | null;
  content: string;
  status: BlockStatus;
  durationMs: number | null;
  error: string | null;
  children: string[];
  version: number;
}

// ── Message ──────────────────────────────────────────────────────────

export type MessageRole = "user" | "assistant";

// Message status superset (pending only appears in DB; streaming/completed/error/cancelled on wire).
export type MessageStatus = "pending" | "streaming" | "completed" | "error" | "cancelled";

export interface AttachmentRef {
  attachmentId: string;
  fileName: string;
  mimeType: string;
}

export interface Message {
  id: string;
  conversationId: string;
  role: MessageRole;
  status: MessageStatus;
  parentBlockId: string | null;
  stopReason?: string;
  errorCode?: string;
  errorMessage?: string;
  inputTokens?: number;
  outputTokens?: number;
  modelId?: string;
  provider?: string;
  attrs?: Record<string, unknown> | null;
  blocks: Block[];
  attachments: AttachmentRef[];
  createdAt: string;
  updatedAt?: string;
}

// ── Send / Cancel ────────────────────────────────────────────────────

export interface SendMessageBody {
  content: string;
  attachmentIds?: string[];
}
