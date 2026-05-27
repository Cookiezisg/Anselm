import { useMemo } from "react";
import { useTranslation } from "react-i18next";
import { useFunctions, type FunctionEntity } from "@entities/function";
import { useHandlers, type Handler } from "@entities/handler";
import { useWorkflows, type Workflow } from "@entities/workflow";
import { useDocuments, type Document } from "@entities/document";
import { useSkills, type Skill } from "@entities/skill";
import { useMcpServers, type McpServer } from "@entities/mcp";
import { useConversations, type Conversation } from "@entities/conversation";
import { useAllRelations, type Relation } from "@entities/relation";

export interface EntityNode {
  id: string;
  kind: string;
  label: string;
  sub: string;
}

export interface EntityEdge {
  from: string;
  to: string;
  kind: string;
}

export interface EntityDirectory {
  nodes: EntityNode[];
  edges: EntityEdge[];
}

// Raw backend relation → normalised edge (fromId/from, toId/to, kind/type).
// Filters out malformed entries without from/to.
export function normEdges(relations: Relation[]): EntityEdge[] {
  return relations.map((r) => ({
    from: r.fromId,
    to: r.toId,
    kind: r.kind,
  })).filter((e) => e.from && e.to);
}

// Aggregates all 7 entity list queries into a flat node list plus normalised
// edges from useAllRelations — mirrors RelGraph's local useEntityDirectory +
// normEdges for consumption by the force-directed graph.
export function useEntityDirectory(): EntityDirectory {
  const fnQ = useFunctions();
  const hdQ = useHandlers();
  const wfQ = useWorkflows();
  const dcQ = useDocuments();
  const skQ = useSkills();
  const mcQ = useMcpServers();
  const cvQ = useConversations();
  const { data: rawRel = [] } = useAllRelations();

  const { t } = useTranslation("misc");

  const nodes = useMemo<EntityNode[]>(() => {
    const out: EntityNode[] = [];
    for (const x of (fnQ.data as FunctionEntity[] || [])) out.push({ id: x.id, kind: "function", label: x.name || x.id, sub: x.description || "" });
    for (const x of (hdQ.data as Handler[] || [])) out.push({ id: x.id, kind: "handler", label: x.name || x.id, sub: x.description || "" });
    for (const x of (wfQ.data as Workflow[] || [])) out.push({ id: x.id, kind: "workflow", label: x.name || x.id, sub: x.description || "" });
    for (const x of (dcQ.data as Document[] || [])) out.push({ id: x.id, kind: "document", label: x.name || x.id, sub: t("relGraph.subDocument") });
    // skill/mcp use name as primary key (S15 — no id_ prefix, name IS the stable id).
    for (const x of (skQ.data as Skill[] || [])) out.push({ id: x.name, kind: "skill", label: x.name, sub: x.description || "" });
    for (const x of (mcQ.data as McpServer[] || [])) out.push({ id: x.name, kind: "mcp", label: x.name, sub: t("relGraph.subTools", { count: x.tools?.length || 0 }) });
    for (const x of (cvQ.data as Conversation[] || [])) out.push({ id: x.id, kind: "conversation", label: x.title || x.id, sub: "" });
    return out;
  }, [fnQ.data, hdQ.data, wfQ.data, dcQ.data, skQ.data, mcQ.data, cvQ.data, t]);

  const edges = useMemo<EntityEdge[]>(() => normEdges(rawRel as Relation[]), [rawRel]);

  return { nodes, edges };
}
