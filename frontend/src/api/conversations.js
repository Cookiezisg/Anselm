// Conversation hooks 已迁移至 entities/conversation (FSD 阶段2);此处转 re-export 保持调用点零改。
export {
  useConversations,
  useConversation,
  useConversationMessages,
  useCreateConversation,
  useUpdateConversation,
  useDeleteConversation,
  useSendMessage,
  useCancelStream,
} from "@entities/conversation";
