// Orchestrates accept/reject/revert for trinity (function/handler/workflow)
// detail headers. All entity hooks are called unconditionally; kind selects
// which mutation is surfaced. Verbatim toast copy from each original detail.
//
// 统一封装三类 detail 的 accept/reject/revert 编排；hook 无条件全调，按 kind 路由。

import { useTranslation } from "react-i18next";
import {
  useAcceptFunction,
  useRejectFunction,
  useRevertFunction,
} from "@entities/function";
import {
  useAcceptHandler,
  useRejectHandler,
} from "@entities/handler";
import {
  useAcceptWorkflow,
  useRejectWorkflow,
} from "@entities/workflow";
// TODO(4b): pages props 化后移除 feature-tmp→app 过渡反向引用
// eslint-disable-next-line boundaries/dependencies
import { useToastStore } from "@shared/ui/toastStore";

type ForgeKind = "function" | "handler" | "workflow";

interface ReviewActions {
  accept: () => void;
  reject: () => void;
  revert?: () => void;
}

// Returns accept/reject/revert callbacks for the given kind+id+name. Revert
// is only defined for function (dedicated useRevertFunction). name is used
// for FunctionDetail toast desc (verbatim from original).
//
// 返回对应 kind 的 accept/reject/revert 动作；revert 仅 function 有；name 供 toast desc。
export function useForgeReview(
  kind: ForgeKind,
  id: string,
  name?: string,
): ReviewActions {
  const { t } = useTranslation("forge");
  const pushToast = useToastStore((s) => s.pushToast);

  const acceptFn = useAcceptFunction();
  const rejectFn = useRejectFunction();
  const revertFn = useRevertFunction();
  const acceptHd = useAcceptHandler();
  const rejectHd = useRejectHandler();
  const acceptWf = useAcceptWorkflow();
  const rejectWf = useRejectWorkflow();

  if (kind === "function") {
    return {
      accept: () =>
        acceptFn.mutate(id, {
          onSuccess: () => pushToast({ kind: "success", title: "Accepted", desc: name }),
          // Error handled by global MutationCache onError (errorMap).
        }),
      reject: () =>
        rejectFn.mutate(id, {
          onSuccess: () => pushToast({ kind: "warn", title: "Reverted pending", desc: name }),
          // Error handled by global MutationCache onError (errorMap).
        }),
      revert: () =>
        revertFn.mutate(id, {
          onSuccess: () => pushToast({ kind: "warn", title: "Reverted pending", desc: name }),
          // Error handled by global MutationCache onError (errorMap).
        }),
    };
  }

  if (kind === "handler") {
    return {
      accept: () =>
        acceptHd.mutate(id, {
          onSuccess: () => pushToast({ kind: "success", title: "Accepted" }),
          // Error handled by global MutationCache onError (errorMap).
        }),
      reject: () =>
        rejectHd.mutate(id, {
          onSuccess: () => pushToast({ kind: "warn", title: "Reverted pending" }),
          // Error handled by global MutationCache onError (errorMap).
        }),
    };
  }

  return {
    accept: () =>
      acceptWf.mutate(id, {
        onSuccess: () => pushToast({ kind: "success", title: "Accepted" }),
        // Error handled by global MutationCache onError (errorMap).
      }),
    reject: () =>
      rejectWf.mutate(id, {
        onSuccess: () => pushToast({ kind: "warn", title: "Reverted pending" }),
        // Error handled by global MutationCache onError (errorMap).
      }),
  };
}
