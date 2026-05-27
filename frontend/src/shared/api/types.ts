// SSE notification payload shapes shared across layers.
// PendingAsk is the ask-user question payload pushed via notifications SSE.
//
// SSE 通知载荷类型：PendingAsk 是 ask-user 工具调用的 SSE 载荷，被 features/widgets 消费。

export interface PendingAsk {
  id: string;
  conversationId: string;
  toolCallId: string;
  question?: string;
  context?: string;
  options?: Array<{ id?: string; value?: string; text?: string; label?: string; sub?: string }>;
}
