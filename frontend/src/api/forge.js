// Forge hooks — trinity (function / handler / workflow) read + mutate.
//
// trinity 锻造相关 hooks。

// TODO(阶段3): useIterateForge(跨实体用例)→ features/forge-iterate/model

import { useMutation } from "@tanstack/react-query";
import { apiFetch } from "./client.js";

// Function hooks — implementation lives in @entities/function (FSD 阶段2迁移).
export {
  useFunctions,
  useFunction,
  useFunctionVersions,
  useAcceptFunction,
  useRejectFunction,
  useRevertFunction,
  useRunFunction,
  useDeleteFunction,
} from "@entities/function";

// Handler hooks — implementation lives in @entities/handler (FSD 阶段2迁移).
export {
  useHandlers,
  useHandler,
  useHandlerVersions,
  useHandlerConfig,
  useAcceptHandler,
  useRejectHandler,
  useCallHandler,
  useDeleteHandler,
} from "@entities/handler";

// Workflow hooks — implementation lives in @entities/workflow (FSD 阶段2迁移).
export {
  useWorkflows,
  useWorkflow,
  useWorkflowVersions,
  useAcceptWorkflow,
  useRejectWorkflow,
  useDeleteWorkflow,
  useUpdateWorkflow,
  useRunWorkflow,
  useEditWorkflow,
  useCapabilityCheck,
} from "@entities/workflow";

// ── AskAI iterate (for FunctionDetail / HandlerDetail / WorkflowDetail) ──
export function useIterateForge() {
  return useMutation({
    mutationFn: ({ kind, id, prompt }) =>
      apiFetch(`/${kind}s/${id}:iterate`, { method: "POST", body: { prompt } }),
  });
}
