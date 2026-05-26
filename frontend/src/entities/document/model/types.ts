// Document entity types — mirrors backend domain/document/*.go json tags,
// camelCase per API contract.
//
// 对齐后端 domain/document json tag 字段名(camelCase)。

export interface Document {
  id: string;
  userId: string;
  parentId: string | null;
  name: string;
  description: string;
  content: string;
  tags: string[];
  position: number;
  path: string;
  sizeBytes: number;
  createdAt: string;
  updatedAt: string;
}

// DocTreeNode is returned by GET /documents/tree — flat list with path for sidebar rendering.
//
// /documents/tree 返回的扁平节点，含 path 供侧边栏渲染树形结构。
export interface DocTreeNode {
  id: string;
  userId: string;
  parentId: string | null;
  name: string;
  description: string;
  tags: string[];
  position: number;
  path: string;
  sizeBytes: number;
  createdAt: string;
  updatedAt: string;
}

export interface CreateDocumentBody {
  name: string;
  parentId?: string | null;
  content?: string;
  description?: string;
  tags?: string[];
}

export interface UpdateDocumentPatch {
  name?: string;
  content?: string;
  description?: string;
  tags?: string[];
}

export interface MoveDocumentVars {
  id: string;
  parentId: string | null;
  position?: number;
}
