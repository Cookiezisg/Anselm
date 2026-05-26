// useEntityName — resolve an entity ID to its display name by reading the
// already-cached TanStack Query lists (no extra network calls). Prefix
// dispatches to the matching query so we don't pull lists we don't need
// per lookup.
//
// useEntityName —— 把实体 ID 翻成显示名；按 prefix 路由到对应 list query
// 拿名字，没拿到就 fallback 回 ID（少了不会断）。

import { useFunctions } from "@entities/function";
import { useHandlers } from "@entities/handler";
import { useWorkflows } from "@entities/workflow";
import { useDocuments } from "@entities/document";
import { useSkills } from "@entities/skill";
import { useMcpServers } from "@entities/mcp";
import { useConversations } from "@entities/conversation";
import { useFlowRuns } from "@entities/flowrun";

function pickName<T>(
  list: T[] | undefined,
  id: string,
  getName: (item: T) => string | undefined
): string | null {
  const hit = (list || []).find((x: any) => x.id === id);
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
    case "f": case "fn":   return pickName(fnQ.data, id, (x: any) => x.name);
    case "h": case "hd":   return pickName(hdQ.data, id, (x: any) => x.name);
    case "w": case "wf":   return pickName(wfQ.data, id, (x: any) => x.name);
    case "d": case "doc":  return pickName(dcQ.data, id, (x: any) => x.name || x.title);
    case "s": case "sk":   return pickName(skQ.data, id, (x: any) => x.name);
    case "mcp": case "m":  return pickName(mcQ.data, id, (x: any) => x.name);
    case "cv":             return pickName(cvQ.data, id, (x: any) => x.title);
    case "fr":             return pickName(frQ.data, id, (x: any) => x.workflow || x.workflowId);
    default:               return null;
  }
}
