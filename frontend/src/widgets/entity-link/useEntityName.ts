// useEntityName — resolve an entity ID to its display name by reading the
// already-cached TanStack Query lists (no extra network calls). Prefix
// dispatches to the matching query so we don't pull lists we don't need
// per lookup.
//
// useEntityName —— 把实体 ID 翻成显示名；按 prefix 路由到对应 list query
// 拿名字，没拿到就 fallback 回 ID（少了不会断）。

import { useFunctions, type FunctionEntity } from "@entities/function";
import { useHandlers, type Handler } from "@entities/handler";
import { useWorkflows, type Workflow } from "@entities/workflow";
import { useDocuments, type Document } from "@entities/document";
import { useSkills, type Skill } from "@entities/skill";
import { useMcpServers, type McpServer } from "@entities/mcp";
import { useConversations, type Conversation } from "@entities/conversation";
import { useFlowRuns, type FlowRun } from "@entities/flowrun";

function pickName<T>(
  list: T[] | undefined,
  id: string,
  getName: (item: T) => string | undefined
): string | null {
  const hit = (list || []).find((x) => (x as { id?: string; name?: string }).id === id);
  return hit ? (getName(hit) ?? null) : null;
}

export function useEntityName(id: string | null | undefined): string | null {
  const prefix = (id || "").split("_")[0];

  const fnQ = useFunctions();
  const hdQ = useHandlers();
  const wfQ = useWorkflows();
  const dcQ = useDocuments();
  const skQ = useSkills();
  const mcQ = useMcpServers();
  const cvQ = useConversations();
  const frQ = useFlowRuns();

  if (!id) return null;

  switch (prefix) {
    case "f": case "fn":   return pickName<FunctionEntity>(fnQ.data, id, (x) => x.name);
    case "h": case "hd":   return pickName<Handler>(hdQ.data, id, (x) => x.name);
    case "w": case "wf":   return pickName<Workflow>(wfQ.data, id, (x) => x.name);
    case "d": case "doc":  return pickName<Document>(dcQ.data, id, (x) => x.name || (x as Document & { title?: string }).title);
    case "s": case "sk":   return pickName<Skill>(skQ.data, id, (x) => x.name);
    case "mcp": case "m":  return pickName<McpServer>(mcQ.data, id, (x) => x.name);
    case "cv":             return pickName<Conversation>(cvQ.data, id, (x) => x.title);
    case "fr":             return pickName<FlowRun>(frQ.data, id, (x) => (x as FlowRun & { workflow?: string }).workflow || x.workflowId);
    default:               return null;
  }
}
