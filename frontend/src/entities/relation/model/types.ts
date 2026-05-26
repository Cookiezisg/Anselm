// Relation entity types — mirrors backend domain/relation json tags, camelCase per API contract.
// json:"-" fields (Attrs raw string) omitted; AttrsParsed exposed as attrs.
//
// 对齐后端 domain/relation json tag 字段名(camelCase)；json:"-" 字段省略。

export type EntityKind =
  | "conversation"
  | "function"
  | "handler"
  | "workflow"
  | "document"
  | "skill"
  | "mcp";

export type RelationKind =
  | "conversation_forged_entity"
  | "conversation_edited_entity"
  | "workflow_uses_function"
  | "workflow_uses_handler"
  | "workflow_uses_mcp"
  | "workflow_uses_skill"
  | "workflow_uses_document"
  | "document_links_entity";

export interface Relation {
  id: string;
  userId: string;
  fromKind: string;
  fromId: string;
  toKind: string;
  toId: string;
  kind: RelationKind;
  attrs?: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface GraphNode {
  kind: string;
  id: string;
  label: string;
  sub?: string;
}

export interface Neighborhood {
  nodes: GraphNode[];
  edges: Relation[];
}

export interface RelationFilter {
  fromKind?: string;
  toKind?: string;
  kind?: string;
}

export interface NeighborhoodVars {
  kind: string;
  id: string;
  depth?: number;
}
