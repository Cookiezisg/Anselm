// Orchestrates the :iterate call for trinity (function/handler/workflow)
// detail headers — same logic extracted verbatim from AskAiTrigger.submit.
//
// 封装 AskAiTrigger 的提交编排;conversationId 取值/跳转/toast 逐字保留。

import { useTranslation } from "react-i18next";
import { useMutation } from "@tanstack/react-query";
import { apiFetch } from "@shared/api";
import { useToastStore } from "@shared/ui/toastStore";

interface IterateParams {
  kind: string;
  id: string;
  prompt: string;
}

// Mutation that calls POST /{kind}s/{id}:iterate — same implementation
// that lived in api/forge.js before the FSD migration.
//
// 原 api/forge.js 的 useIterateForge 实现,按 FSD 归宿搬入 features 层。
export function useIterateForge() {
  return useMutation({
    mutationFn: ({ kind, id, prompt }: IterateParams) =>
      apiFetch(`/${kind}s/${id}:iterate`, { method: "POST", body: { prompt } }),
  });
}

export function useForgeIterate() {
  const { t } = useTranslation("misc");
  const iterate = useIterateForge();
  const pushToast = useToastStore((s) => s.pushToast);

  // Returns the conversationId on success so the component can navigate.
  // Navigation (setActiveConv + openPane) is the component's responsibility.
  //
  // 成功时返回 conversationId；导航(setActiveConv+openPane)由组件负责。
  const submit = async (kind: string, id: string, prompt: string): Promise<string | null> => {
    try {
      const res = await iterate.mutateAsync({ kind, id, prompt });
      const cid = (res as any)?.conversationId || (res as any)?.id;
      if (!cid) {
        // Not an API error — server returned success but no conversationId.
        // This is a business-logic warn that global onError cannot detect.
        //
        // 非 ApiError 的业务 warn：服务返回成功但无 conversationId，全局不感知此情况。
        pushToast({ kind: "warn", title: t("askAi.iterateEmptyTitle"), desc: t("askAi.iterateEmptyDesc") });
        return null;
      }
      return cid;
    } catch {
      // Iterate API errors: handled by global MutationCache onError via errorMap.
      // No toast here to avoid double-toast.
      //
      // iterate 请求错误由全局 onError 处理，此处不重复 toast。
      return null;
    }
  };

  return {
    submit,
    isPending: iterate.isPending,
  };
}
