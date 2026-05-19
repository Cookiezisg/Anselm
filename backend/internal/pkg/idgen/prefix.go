package idgen

// KindByPrefix maps the "<prefix>_<16hex>" ID prefix to the relation entity kind
// (see relationdomain.EntityKind* constants). Only entities with system-issued
// prefix IDs appear here — skill / mcp / user use name-based primary keys and are
// not wikilink-resolvable.
//
// KindByPrefix 把 "<prefix>_<16hex>" 形式 ID 的前缀映射到 relation 实体类型
// (见 relationdomain.EntityKind* 常量)。只收录系统生成 prefix-ID 的实体类型——
// skill / mcp / user 以 name 当主键，wikilink 不可解析。
var KindByPrefix = map[string]string{
	"fn":  "function",
	"hd":  "handler",
	"wf":  "workflow",
	"doc": "document",
	"cv":  "conversation",
}

// KindForID returns the entity kind for an ID like "fn_a1b2c3..."; ok=false on unknown prefix.
//
// KindForID 取 "fn_a1b2c3..." 形式 ID 的实体类型；前缀未知时 ok=false。
func KindForID(id string) (string, bool) {
	for i := 0; i < len(id); i++ {
		if id[i] == '_' {
			kind, ok := KindByPrefix[id[:i]]
			return kind, ok
		}
	}
	return "", false
}
