// Orchestrates send / cancel / self-heal for a single conversation.
// Extracted verbatim from ChatPane.onSend / onCancel so the component
// only handles rendering.
//
// 封装发送/取消/自愈编排;ChatPane 只负责渲染,不再含业务决策。

import { useTranslation } from "react-i18next";
import { useQueryClient } from "@tanstack/react-query";
import { useSendMessage, useCancelStream } from "@entities/conversation";
import { qk } from "@shared/api";
import { useToastStore } from "@shared/ui/toastStore";

import type { SendMessageBody } from "@entities/conversation";

// Superset of SendMessageBody — attachments/mentions are assembled here before
// casting to SendMessageBody so the wire shape stays identical to the original
// ChatPane.onSend logic.
//
// 发送时按原 ChatPane.onSend 逻辑组装 body，字段名与后端 API 完全一致。
interface SendPayload {
  content: string;
  attachments?: Array<{ name: string; size: number }>;
  mentions?: Array<{ type: string; id: string }>;
}

interface SendMessageFlowOptions {
  // Called when backend says this conversation no longer exists. The
  // component (ChatPane) owns pane state and performs self-heal navigation.
  //
  // 后端返回 CONVERSATION_NOT_FOUND 时通知组件，组件持有 pane store 做自愈导航。
  onConvGone?: () => void;
}

export function useSendMessageFlow(convId: string | null, { onConvGone }: SendMessageFlowOptions = {}) {
  const { t } = useTranslation("conv");
  const qc = useQueryClient();
  const pushToast = useToastStore((s) => s.pushToast);

  const send = useSendMessage(convId as string);
  const cancel = useCancelStream(convId as string);

  const submit = ({ content, attachments, mentions }: SendPayload) => {
    const body = { content } as unknown as SendMessageBody & Record<string, unknown>;
    if (attachments?.length) body.attachments = attachments.map((a) => ({ fileName: a.name, sizeBytes: a.size }));
    if (mentions?.length) body.mentions = mentions.map((m) => ({ type: m.type, id: m.id }));
    send.mutate(body as SendMessageBody, {
      onError: (err: Error & { code?: string }) => {
        // Stale conv: backend says this conversation doesn't exist (deleted,
        // or belongs to a different user after account switch). Feature fires
        // the onConvGone intent; ChatPane owns pane store and performs self-heal.
        // Toast is emitted by the global onError via CONVERSATION_NOT_FOUND in errorMap.
        //
        // activeConv 已失效。feature 发出 onConvGone 意图；ChatPane 持有 pane store 做自愈。
        // Toast 由全局 onError 通过 errorMap CONVERSATION_NOT_FOUND 发出。
        if (err?.code === "CONVERSATION_NOT_FOUND") {
          qc.invalidateQueries({ queryKey: qk.conversations() });
          onConvGone?.();
        }
        // Generic send errors: handled by global MutationCache onError.
        // No toast here to avoid double-toast.
        //
        // 通用发送错误由全局 onError 处理，此处不重复 toast。
      },
    });
  };

  // Cancel errors surface as warn kind — useCancelStream has meta.suppressGlobal=true
  // so global onError skips it; this feature callback handles it exclusively.
  //
  // 取消失败以 warn 种类显示；cancel mutation 标记了 suppressGlobal，此处独占处理。
  const cancelStream = () => {
    cancel.mutate(undefined, {
      onError: (err: Error) => pushToast({ kind: "warn", title: t("toast.cancelFailTitle"), desc: err.message }),
    });
  };

  return {
    submit,
    cancelStream,
    isPending: send.isPending,
  };
}
