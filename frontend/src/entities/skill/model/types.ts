// Skill entity types — mirrors backend domain/skill/*.go json tags, camelCase per API contract.
// Skill uses name as primary key (no id prefix). json:"-" fields omitted.
//
// 对齐后端 domain/skill json tag 字段名(camelCase)；skill 以 name 为主键。

export interface SkillFrontmatter {
  name: string;
  description: string;
  whenToUse?: string;
  allowedTools?: string[];
  disableModelInvocation?: boolean;
  userInvocable?: boolean;
  paths?: string[];
  context?: string;
  agent?: string;
  arguments?: string[];
  argumentHint?: string;
  model?: string;
  effort?: string;
}

export interface Skill {
  name: string;
  source: string;
  dirPath: string;
  bodyPath: string;
  description: string;
  frontmatter: SkillFrontmatter;
  loadedAt: string;
}
