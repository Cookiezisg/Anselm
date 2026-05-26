// User entity types — mirrors backend domain/user/user.go fields,
// camelCase per API response contract (json tags on the Go struct).
//
// 对齐后端 domain/user User struct 的 json tag 字段名(camelCase)。

export interface User {
  id: string;
  username: string;
  displayName: string;
  avatarColor: string;
  language: string;
  lastUsedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface CreateUserBody {
  username: string;
  displayName?: string;
  avatarColor?: string;
  language?: string;
}

export interface UpdateUserPatch {
  displayName?: string;
  avatarColor?: string;
  language?: string;
}
