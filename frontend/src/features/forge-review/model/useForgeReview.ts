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
// TODO(阶段4): ui store 拆进 app/model 后,将此 import 替换为正式 FSD 路径。
// eslint-disable-next-line boundaries/dependencies
import { useUIStore } from "../../../store/ui.js";

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
  const pushToast = useUIStore((s) => s.pushToast);

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
          onError: (e: Error) =>
            pushToast({ kind: "error", title: t("detail.acceptFail"), desc: e.message }),
        }),
      reject: () =>
        rejectFn.mutate(id, {
          onSuccess: () => pushToast({ kind: "warn", title: "Reverted pending", desc: name }),
          onError: (e: Error) =>
            pushToast({ kind: "error", title: t("detail.revertFail"), desc: e.message }),
        }),
      revert: () =>
        revertFn.mutate(id, {
          onSuccess: () => pushToast({ kind: "warn", title: "Reverted pending", desc: name }),
          onError: (e: Error) =>
            pushToast({ kind: "error", title: t("detail.revertFail"), desc: e.message }),
        }),
    };
  }

  if (kind === "handler") {
    return {
      accept: () =>
        acceptHd.mutate(id, {
          onSuccess: () => pushToast({ kind: "success", title: "Accepted" }),
          onError: (e: Error) =>
            pushToast({ kind: "error", title: t("detail.acceptFail"), desc: e.message }),
        }),
      reject: () =>
        rejectHd.mutate(id, {
          onSuccess: () => pushToast({ kind: "warn", title: "Reverted pending" }),
          onError: (e: Error) =>
            pushToast({ kind: "error", title: t("detail.revertFail"), desc: e.message }),
        }),
    };
  }

  return {
    accept: () =>
      acceptWf.mutate(id, {
        onSuccess: () => pushToast({ kind: "success", title: "Accepted" }),
        onError: (e: Error) =>
          pushToast({ kind: "error", title: t("detail.acceptFail"), desc: e.message }),
      }),
    reject: () =>
      rejectWf.mutate(id, {
        onSuccess: () => pushToast({ kind: "warn", title: "Reverted pending" }),
        onError: (e: Error) =>
          pushToast({ kind: "error", title: t("detail.revertFail"), desc: e.message }),
      }),
  };
}
