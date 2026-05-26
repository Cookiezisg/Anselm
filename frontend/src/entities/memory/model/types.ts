// Memory entity types — mirrors backend domain/memory/*.go json tags, camelCase per API contract.
// Memory uses name as primary key. json:"-" fields omitted.
//
// 对齐后端 domain/memory json tag 字段名(camelCase)；memory 以 name 为主键。

export interface Memory {
  id: string;
  name: string;
  type: "user" | "feedback" | "project" | "reference";
  description: string;
  content: string;
  pinned: boolean;
  source: "user" | "ai";
  metadata?: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
  accessedAt?: string;
  accessCount: number;
}

export interface CreateMemoryBody {
  name: string;
  type: "user" | "feedback" | "project" | "reference";
  description: string;
  content: string;
  pinned?: boolean;
  source?: "user" | "ai";
}

export interface UpdateMemoryBody {
  description?: string;
  content?: string;
  type?: "user" | "feedback" | "project" | "reference";
  pinned?: boolean;
}

export interface PinMemoryVars {
  name: string;
  pinned: boolean;
}
