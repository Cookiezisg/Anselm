// Forge hooks — trinity (function / handler / workflow) read + mutate.
//
// trinity 锻造相关 hooks。

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

// useIterateForge — implementation lives in @features/forge-iterate (FSD 阶段3迁移).
export { useIterateForge } from "@features/forge-iterate";
