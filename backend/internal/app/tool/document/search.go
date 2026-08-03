package document

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	documentapp "github.com/sunweilin/anselm/backend/internal/app/document"
	searchapp "github.com/sunweilin/anselm/backend/internal/app/search"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
)

// docHit is the unified slim shape both search paths render. Content hits are hydrated from
// durable documents so a matching snippet never makes the model guess path or metadata.
//
// docHit 是两条检索路径共用的 slim 形状。内容命中会从 durable document 补齐元数据，
// 让模型不必根据 snippet 猜 path 或其它字段。
type docHit struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Path        string   `json:"path,omitempty"`
	Description string   `json:"description,omitempty"`
	Tags        []string `json:"tags,omitempty"`
	Snippet     string   `json:"snippet,omitempty"`
}

const searchDocumentsDescription = `Search the Anselm document library by keyword. This is NOT filesystem search: send query, never Grep's path/pattern fields. The unified index searches document name, description, tags, and Markdown body/headings. Returns id, name, path, description, tags, a matching snippet, total, and nextCursor only when results are truncated. If nextCursor is absent, the result is complete: do not repeat the identical query. As soon as a matching document ID appears, use that exact ID for the next operation instead of searching again. If the user specifies a maximum result count, pass that limit in the FIRST call; never make a default/unbounded call first and then redo it. To continue, repeat the same query with the returned cursor copied byte-for-byte; do not invent or edit a cursor. Use list_documents only to enumerate a known folder; do not call it to answer a keyword search. Hosted-provider compatibility: if a provider mistakenly sends a filesystem-shaped path/pattern object, a non-empty pattern (or path) is treated only as a document-library query; if both are empty, return one bounded library page. This never reads the filesystem.`

const searchDocumentsDefaultLimit = 10

var searchDocumentsSchema = json.RawMessage(`{
	"type": "object",
	"required": ["query"],
	"properties": {
		"query": {
			"type": "string",
			"description": "Keyword or phrase in the document library, including Markdown body text. Do not use path or pattern."
		},
		"limit": {
			"type": "integer",
			"description": "Maximum matching documents to return (default 10, hard maximum 50). If the user gives a maximum, pass it on the first call; do not probe with the default first.",
			"default": 10,
			"maximum": 50
		},
		"cursor": {
			"type": "string",
			"description": "Opaque continuation cursor returned by a prior search_documents call. Copy it byte-for-byte with the same query; omit on the first page."
		}
	}
}`)

// SearchDocuments implements the search_documents system tool.
//
// SearchDocuments 是 search_documents 系统工具的实现。
type SearchDocuments struct {
	svc     *documentapp.Service
	content *searchapp.Service // nil → legacy substring only. nil → 仅原子串路径。
}

func (t *SearchDocuments) Name() string                { return "search_documents" }
func (t *SearchDocuments) Description() string         { return searchDocumentsDescription }
func (t *SearchDocuments) Parameters() json.RawMessage { return searchDocumentsSchema }

func (t *SearchDocuments) ValidateInput(args json.RawMessage) error {
	var a struct {
		Query   string `json:"query"`
		Limit   int    `json:"limit"`
		Path    string `json:"path"`
		Pattern string `json:"pattern"`
		Cursor  string `json:"cursor"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("search_documents: bad args: %w", err)
	}
	if strings.TrimSpace(a.Query) == "" {
		legacyShape := false
		var fields map[string]json.RawMessage
		if err := json.Unmarshal(args, &fields); err == nil {
			if _, ok := fields["path"]; ok {
				legacyShape = true
			}
			if _, ok := fields["pattern"]; ok {
				legacyShape = true
			}
		}
		if !legacyShape && (strings.TrimSpace(a.Path) != "" || strings.TrimSpace(a.Pattern) != "") {
			return fmt.Errorf("search_documents: query is required; this searches the document library, not the filesystem (use query, not path/pattern)")
		}
		if !legacyShape {
			return ErrQueryRequired
		}
	}
	if a.Limit < 0 || a.Limit > 50 {
		return fmt.Errorf("search_documents: limit must be 0..50, got %d", a.Limit)
	}
	return nil
}

func (t *SearchDocuments) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a struct {
		Query   string `json:"query"`
		Limit   int    `json:"limit"`
		Cursor  string `json:"cursor"`
		Path    string `json:"path"`
		Pattern string `json:"pattern"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("search_documents: %w", err)
	}
	if a.Limit == 0 {
		a.Limit = searchDocumentsDefaultLimit
	}
	// A hosted provider can occasionally borrow the resident filesystem search shape. Recover only
	// that explicit shape: a non-empty pattern/path becomes the document query, while two empty
	// fields fall through to the bounded legacy listing below. No filesystem access is introduced.
	// 托管 provider 偶尔会借用驻地 filesystem search 的参数形状。只恢复这个明确形状：非空 pattern/path
	// 变成文档 query；两者都空则落到下面有界的旧检索列表。这里不引入任何文件系统访问。
	if strings.TrimSpace(a.Query) == "" {
		if strings.TrimSpace(a.Pattern) != "" {
			a.Query = a.Pattern
		} else if strings.TrimSpace(a.Path) != "" {
			a.Query = a.Path
		}
	}
	// Content engine first: full-text over names AND markdown bodies, heading
	// snippets included; engine errors fall back to the legacy name search.
	// 先走内容引擎：全文覆盖名字**及 markdown 正文**、附标题 snippet；引擎出错回退原名字检索。
	if t.content != nil {
		if page, err := t.content.Search(ctx, &searchdomain.Query{
			Q: a.Query, Types: []searchdomain.EntityType{searchdomain.TypeDocument}, IncludeArchived: true, LexicalOnly: true, Cursor: a.Cursor, Limit: a.Limit,
		}); err == nil {
			ids := make([]string, 0, len(page.Hits))
			for _, h := range page.Hits {
				ids = append(ids, h.EntityID)
			}
			metadata := make(map[string]*documentdomain.Document, len(ids))
			if len(ids) > 0 {
				rows, getErr := t.svc.GetBatch(ctx, ids)
				if getErr != nil {
					return "", fmt.Errorf("search_documents: hydrate matches: %w", getErr)
				}
				for _, d := range rows {
					metadata[d.ID] = d
				}
			}
			out := make([]docHit, 0, len(page.Hits))
			for _, h := range page.Hits {
				hit := docHit{ID: h.EntityID, Name: h.Name, Snippet: h.Snippet}
				if d := metadata[h.EntityID]; d != nil {
					hit.Path = d.Path
					hit.Description = d.Description
					hit.Tags = d.Tags
				}
				out = append(out, hit)
			}
			// Disclose truncation (total + nextCursor/hasMore) so the LLM doesn't read `count` as the
			// full match count (F175-M4, sibling of the entity-search ContentSearch fix; shared helper).
			// 披露截断（total + nextCursor/hasMore），免 LLM 把 `count` 当全量匹配数（F175-M4，与实体搜 ContentSearch 同修；共用 helper）。
			return toolapp.ToJSON(toolapp.SlimPageResult(len(out), page.Total, page.NextCursor, "documents", out)), nil
		}
	}
	if a.Cursor != "" {
		return "", fmt.Errorf("search_documents: cursor continuation requires the unified document search index")
	}
	rows, err := t.svc.Search(ctx, a.Query, a.Limit)
	if err != nil {
		return "", err
	}
	out := make([]docHit, 0, len(rows))
	for _, d := range rows {
		out = append(out, docHit{ID: d.ID, Name: d.Name, Path: d.Path, Description: d.Description, Tags: d.Tags})
	}
	return toolapp.ToJSON(map[string]any{"count": len(out), "documents": out}), nil
}
