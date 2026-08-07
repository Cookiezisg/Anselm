package trigger

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	searchapp "github.com/sunweilin/anselm/backend/internal/app/search"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	triggerapp "github.com/sunweilin/anselm/backend/internal/app/trigger"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
)

// --- search_triggers -------------------------------------------------------

type SearchTriggers struct {
	svc     *triggerapp.Service
	content *searchapp.Service // nil → legacy substring only. nil → 仅原子串路径。
}

func (t *SearchTriggers) Name() string { return "search_triggers" }

func (t *SearchTriggers) Description() string {
	return "Find triggers by keyword + semantic relevance over name / description / kind. Direct name/description/kind matches take precedence over weak semantic-only matches. Returns id + name + kind + description + whether its listener is currently live (refCount of active workflows). Empty query lists all. Use get_trigger for full config. The canonical search field is query; pattern is accepted as a compatibility alias for hosted models."
}

func (t *SearchTriggers) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"query": {"type": "string", "description": "Canonical search text; omit to list all."},
			"pattern": {"type": "string", "description": "Compatibility alias for query; use query when possible."}
		}
	}`)
}

func (t *SearchTriggers) ValidateInput(json.RawMessage) error { return nil }

func (t *SearchTriggers) Execute(ctx context.Context, argsJSON string) (string, error) {
	query, err := decodeSearchTriggersQuery(argsJSON)
	if err != nil {
		return "", fmt.Errorf("search_triggers: bad args: %w", err)
	}
	// A direct field match is a stronger user signal than a weak semantic neighbor.
	// Keep semantic recall for queries that have no direct match, but never dilute an exact
	// keyword search with unrelated trigger rows.
	if strings.TrimSpace(query) != "" {
		ts, err := t.svc.Search(ctx, query)
		if err != nil {
			return "", fmt.Errorf("search_triggers: %w", err)
		}
		if len(ts) > 0 {
			return triggerSearchJSON(ts), nil
		}
	}
	if body, ok := toolapp.ContentSearch(ctx, t.content, searchdomain.TypeTrigger, query, "triggers"); ok {
		return body, nil
	}
	ts, err := t.svc.Search(ctx, query)
	if err != nil {
		return "", fmt.Errorf("search_triggers: %w", err)
	}
	return triggerSearchJSON(ts), nil
}

func triggerSearchJSON(ts []*triggerdomain.Trigger) string {
	type slim struct {
		searchdomain.EntitySlim
		Kind      string `json:"kind"`
		RefCount  int    `json:"refCount"`
		Listening bool   `json:"listening"`
	}
	out := make([]slim, 0, len(ts))
	for _, tr := range ts {
		out = append(out, slim{
			EntitySlim: searchdomain.EntitySlim{ID: tr.ID, Name: tr.Name, Description: tr.Description},
			Kind:       tr.Kind, RefCount: tr.RefCount, Listening: tr.Listening,
		})
	}
	return toolapp.ToJSON(map[string]any{"count": len(out), "triggers": out})
}

// decodeSearchTriggersQuery keeps query canonical but accepts pattern from hosted models that
// carry over the vocabulary of filesystem search tools. Unknown-key omission must never turn a
// targeted search into an accidental "list all" request.
func decodeSearchTriggersQuery(argsJSON string) (string, error) {
	var args struct {
		Query   string `json:"query"`
		Pattern string `json:"pattern"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", err
	}
	if strings.TrimSpace(args.Query) != "" {
		return args.Query, nil
	}
	return args.Pattern, nil
}

// --- get_trigger -----------------------------------------------------------

type GetTrigger struct{ svc *triggerapp.Service }

func (t *GetTrigger) Name() string { return "get_trigger" }

func (t *GetTrigger) Description() string {
	return "Get one trigger by its exact opaque triggerId (the trg_... id copied from a prior trigger result, mention, or search_triggers result): kind, source config, and runtime state (how many active workflows listen to it / whether its listener is live). This is not a name or pattern lookup. Use the triggerId key. A hosted-model compatibility alias accepts file_path only when its value is an unmistakable trg_... ID; never send a filesystem path, query, name, or placeholder. If you only know a name, call search_triggers first and copy its returned id."
}

func (t *GetTrigger) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"additionalProperties": false,
		"required": ["triggerId"],
		"properties": {"triggerId": {"type": "string", "description": "Required opaque trigger ID. Copy the trg_... value exactly. A file_path key is accepted only as a narrow hosted-model compatibility alias when it contains the same exact trg_... ID; never use a filesystem path."}}
	}`)
}

// NormalizeArguments repairs one observed hosted-model drift: some providers have emitted the
// filesystem-shaped `file_path` key for an opaque trigger ID even though the schema requires
// `triggerId`. Only a syntactically unmistakable trigger ID is eligible. An explicit triggerId
// always wins; a conflicting alias remains untouched and is rejected by ValidateInput.
//
// NormalizeArguments 修复一次已观测到的 hosted model 漂移：尽管 schema 要求 `triggerId`，某些 provider
// 曾把不透明 trigger ID 放进 filesystem 形状的 `file_path`。只有形状明确的 trigger ID 才可修复；显式
// triggerId 永远优先；冲突别名保持原样并由 ValidateInput 拒绝。
func (t *GetTrigger) NormalizeArguments(args json.RawMessage) (json.RawMessage, bool) {
	var fields map[string]any
	if json.Unmarshal(args, &fields) != nil || fields == nil {
		return args, false
	}
	if value, ok := fields["triggerId"].(string); ok && value != "" {
		if alias, ok := fields["file_path"].(string); ok && alias == value {
			delete(fields, "file_path")
			normalized, err := json.Marshal(fields)
			if err == nil {
				return normalized, true
			}
		}
		return args, false
	}
	value, ok := fields["file_path"].(string)
	if !ok || !isOpaqueTriggerID(value) {
		return args, false
	}
	delete(fields, "file_path")
	fields["triggerId"] = value
	normalized, err := json.Marshal(fields)
	if err != nil {
		return args, false
	}
	return normalized, true
}

func isOpaqueTriggerID(value string) bool {
	const prefix = "trg_"
	if !strings.HasPrefix(value, prefix) || len(value) == len(prefix) {
		return false
	}
	for _, r := range value[len(prefix):] {
		if (r < 'a' || r > 'z') && (r < 'A' || r > 'Z') && (r < '0' || r > '9') {
			return false
		}
	}
	return true
}

func (t *GetTrigger) ValidateInput(args json.RawMessage) error {
	var fields map[string]any
	if err := json.Unmarshal(args, &fields); err != nil {
		return fmt.Errorf("get_trigger: bad args: %w", err)
	}
	if _, ok := fields["file_path"]; ok {
		return fmt.Errorf("get_trigger: file_path is not accepted; provide the trigger ID in triggerId")
	}
	triggerID, _ := fields["triggerId"].(string)
	if triggerID == "" {
		return ErrTriggerIDRequired
	}
	return nil
}

func (t *GetTrigger) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		TriggerID string `json:"triggerId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_trigger: bad args: %w", err)
	}
	tr, err := t.svc.Get(ctx, args.TriggerID)
	if err != nil {
		return "", fmt.Errorf("get_trigger: %w", err)
	}
	return toolapp.ToJSON(tr), nil
}
