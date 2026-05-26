// Orchestrates the :iterate call for trinity (function/handler/workflow)
// detail headers — same logic extracted verbatim from AskAiTrigger.submit.
//
// 封装 AskAiTrigger 的提交编排;conversationId 取值/跳转/toast 逐字保留。

import { useTranslation } from "react-i18next";
import { useMutation } from "@tanstack/react-query";
import { apiFetch } from "@shared/api";
// TODO(4b): pages props 化后移除 feature-tmp→app 过渡反向引用
// eslint-disable-next-line boundaries/dependencies
import { usePaneStore } from "@app/model";
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
  const setActiveConv = usePaneStore((s) => s.setActiveConv);
  const openPane = usePaneStore((s) => s.openPane);

  const submit = async (kind: string, id: string, prompt: string) => {
    try {
      const res = await iterate.mutateAsync({ kind, id, prompt });
      const cid = (res as any)?.conversationId || (res as any)?.id;
      if (cid) {
        setActiveConv(cid);
        openPane("chat");
      } else {
        pushToast({ kind: "warn", title: t("askAi.iterateEmptyTitle"), desc: t("askAi.iterateEmptyDesc") });
      }
    } catch (err) {
      pushToast({ kind: "error", title: t("askAi.iterateFailedTitle"), desc: (err as Error).message });
    }
  };

  return {
    submit,
    isPending: iterate.isPending,
  };
}
