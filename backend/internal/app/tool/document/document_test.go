package document

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	"go.uber.org/zap"

	documentapp "github.com/sunweilin/anselm/backend/internal/app/document"
	dbinfra "github.com/sunweilin/anselm/backend/internal/infra/db"
	documentstore "github.com/sunweilin/anselm/backend/internal/infra/store/document"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// newToolSvc spins a real in-memory document Service (store + SQLite) under a workspace
// ctx — the tools are exercised end-to-end (tool → app → store), fully offline.
//
// newToolSvc 起一个真内存 document Service（store + SQLite）在 workspace ctx 下——工具被
// 端到端跑通（tool → app → store），全离线。
func newToolSvc(t *testing.T) (*documentapp.Service, context.Context) {
	t.Helper()
	db, err := dbinfra.Open(dbinfra.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })
	if err := dbinfra.Migrate(db, documentstore.Schema...); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	svc := documentapp.NewService(documentstore.New(db), nil, zap.NewNop())
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_test")
	return svc, ctx
}

func TestDocumentTools_NamesAndCount(t *testing.T) {
	svc, _ := newToolSvc(t)
	tools := DocumentTools(svc, nil)
	if len(tools) != 7 {
		t.Fatalf("want 7 tools, got %d", len(tools))
	}
	want := []string{"search_documents", "list_documents", "read_document", "create_document", "edit_document", "move_document", "delete_document"}
	names := map[string]bool{}
	for _, tl := range tools {
		names[tl.Name()] = true
	}
	for _, w := range want {
		if !names[w] {
			t.Fatalf("missing tool %s", w)
		}
	}
}

func TestCreateDocument_ToolAndAutoSuffix(t *testing.T) {
	svc, ctx := newToolSvc(t)
	out1, err := (&CreateDocument{svc: svc}).Execute(ctx, `{"name":"Note","content":"# A"}`)
	if err != nil {
		t.Fatalf("create 1: %v", err)
	}
	if !strings.Contains(out1, "Created document \"Note\"") {
		t.Fatalf("create 1 got %q", out1)
	}
	out2, err := (&CreateDocument{svc: svc}).Execute(ctx, `{"name":"Note","content":"# B"}`)
	if err != nil {
		t.Fatalf("create 2: %v", err)
	}
	if !strings.Contains(out2, "auto-renamed") || !strings.Contains(out2, "Note 2") {
		t.Fatalf("expected auto-rename note, got %q", out2)
	}
}

func TestReadDocument_RoundTrip(t *testing.T) {
	svc, ctx := newToolSvc(t)
	d, err := svc.Create(ctx, documentapp.CreateInput{Name: "PRD", Description: "product req", Content: "# Goals\nship it"})
	if err != nil {
		t.Fatalf("seed: %v", err)
	}
	out, err := (&ReadDocument{svc: svc}).Execute(ctx, `{"id":"`+d.ID+`"}`)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if !strings.Contains(out, "# Goals") || !strings.Contains(out, d.Path) || !strings.Contains(out, "product req") {
		t.Fatalf("rendered doc missing fields: %q", out)
	}
}

func TestReadDocument_NotFoundSoftFails(t *testing.T) {
	svc, ctx := newToolSvc(t)
	out, err := (&ReadDocument{svc: svc}).Execute(ctx, `{"id":"doc_ghost"}`)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if !strings.Contains(out, "not found") {
		t.Fatalf("got %q", out)
	}
}

func TestReadDocument_ContractRequiresOpaqueID(t *testing.T) {
	description := (&ReadDocument{}).Description()
	for _, want := range []string{"exact opaque doc_ ID", "search_documents", "list_documents", "never pass a document name or path"} {
		if !strings.Contains(description, want) {
			t.Errorf("description must contain %q; got %q", want, description)
		}
	}
	schema := string((&ReadDocument{}).Parameters())
	for _, want := range []string{"Exact opaque document ID", "never a name or path", "doc_0123456789abcdef"} {
		if !strings.Contains(schema, want) {
			t.Errorf("schema must contain %q; got %q", want, schema)
		}
	}
}

func TestListDocuments_RootAndChild(t *testing.T) {
	svc, ctx := newToolSvc(t)
	root, _ := svc.Create(ctx, documentapp.CreateInput{Name: "Root"})
	if _, err := svc.Create(ctx, documentapp.CreateInput{Name: "Child", ParentID: &root.ID}); err != nil {
		t.Fatalf("seed child: %v", err)
	}
	rootOut, err := (&ListDocuments{svc: svc}).Execute(ctx, `{}`)
	if err != nil {
		t.Fatalf("list root: %v", err)
	}
	if !strings.Contains(rootOut, "Root") || strings.Contains(rootOut, "Child") {
		t.Fatalf("root list should show Root not Child: %q", rootOut)
	}
	childOut, err := (&ListDocuments{svc: svc}).Execute(ctx, `{"parentId":"`+root.ID+`"}`)
	if err != nil {
		t.Fatalf("list child: %v", err)
	}
	if !strings.Contains(childOut, "Child") {
		t.Fatalf("child list should show Child: %q", childOut)
	}
}

func TestListDocuments_PaginatesAndDisclosesCompleteness(t *testing.T) {
	svc, ctx := newToolSvc(t)
	for _, name := range []string{"A", "B", "C", "D", "E"} {
		if _, err := svc.Create(ctx, documentapp.CreateInput{Name: name}); err != nil {
			t.Fatalf("seed %s: %v", name, err)
		}
	}

	var first struct {
		Count     int              `json:"count"`
		Total     int              `json:"total"`
		Complete  bool             `json:"complete"`
		HasMore   bool             `json:"hasMore"`
		Next      string           `json:"nextCursor"`
		Documents []map[string]any `json:"documents"`
	}
	out, err := (&ListDocuments{svc: svc}).Execute(ctx, `{"limit":2}`)
	if err != nil {
		t.Fatalf("page 1: %v", err)
	}
	if err := json.Unmarshal([]byte(out), &first); err != nil {
		t.Fatalf("decode page 1: %v", err)
	}
	if first.Count != 2 || first.Total != 5 || first.Complete || !first.HasMore || first.Next == "" || len(first.Documents) != 2 {
		t.Fatalf("page 1 completeness = %+v", first)
	}

	var last struct {
		Count     int              `json:"count"`
		Total     int              `json:"total"`
		Complete  bool             `json:"complete"`
		HasMore   bool             `json:"hasMore"`
		Next      string           `json:"nextCursor"`
		Documents []map[string]any `json:"documents"`
	}
	out, err = (&ListDocuments{svc: svc}).Execute(ctx, `{"cursor":"`+first.Next+`","limit":10}`)
	if err != nil {
		t.Fatalf("page 2: %v", err)
	}
	if err := json.Unmarshal([]byte(out), &last); err != nil {
		t.Fatalf("decode page 2: %v", err)
	}
	if last.Count != 3 || last.Total != 5 || !last.Complete || last.HasMore || last.Next != "" || len(last.Documents) != 3 {
		t.Fatalf("page 2 completeness = %+v", last)
	}
}

func TestListDocuments_ContractExplainsOpaquePaging(t *testing.T) {
	description := (&ListDocuments{}).Description()
	for _, want := range []string{"cursor-paged", "total", "complete", "hasMore", "byte-for-byte", "Never infer completeness", "identical list_documents call", "Default page size is 50"} {
		if !strings.Contains(description, want) {
			t.Errorf("description must contain %q; got %q", want, description)
		}
	}
	schema := string((&ListDocuments{}).Parameters())
	for _, want := range []string{"cursor", "limit", "Opaque nextCursor", "1-200"} {
		if !strings.Contains(schema, want) {
			t.Errorf("schema must contain %q; got %q", want, schema)
		}
	}
}

func TestSearchDocuments(t *testing.T) {
	svc, ctx := newToolSvc(t)
	if _, err := svc.Create(ctx, documentapp.CreateInput{Name: "Alpha", Description: "about alpha", Tags: []string{"fixture"}}); err != nil {
		t.Fatalf("seed: %v", err)
	}
	hit, err := (&SearchDocuments{svc: svc}).Execute(ctx, `{"query":"alpha"}`)
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if !strings.Contains(hit, `"count":1`) || !strings.Contains(hit, "Alpha") {
		t.Fatalf("expected 1 hit for Alpha, got %q", hit)
	}
	miss, err := (&SearchDocuments{svc: svc}).Execute(ctx, `{"query":"zzzznope"}`)
	if err != nil {
		t.Fatalf("search miss: %v", err)
	}
	if !strings.Contains(miss, `"count":0`) {
		t.Fatalf("expected miss (count 0), got %q", miss)
	}
	compat, err := (&SearchDocuments{svc: svc}).Execute(ctx, `{"path":"","pattern":""}`)
	if err != nil || !strings.Contains(compat, "Alpha") {
		t.Fatalf("empty filesystem-shaped provider args should return bounded document listing: err=%v result=%q", err, compat)
	}
	pattern, err := (&SearchDocuments{svc: svc}).Execute(ctx, `{"path":"","pattern":"alpha"}`)
	if err != nil || !strings.Contains(pattern, "Alpha") {
		t.Fatalf("non-empty provider pattern should become a document query: err=%v result=%q", err, pattern)
	}
}

func TestSearchDocumentsContractSeparatesFilesystemGrep(t *testing.T) {
	description := (&SearchDocuments{}).Description()
	for _, want := range []string{"document library", "NOT filesystem", "path/pattern", "Markdown body", "nextCursor only when results are truncated", "result is complete", "use that exact ID", "byte-for-byte", "FIRST call", "default/unbounded", "Hosted-provider compatibility", "bounded library page"} {
		if !strings.Contains(description, want) {
			t.Errorf("description must contain %q; got %q", want, description)
		}
	}
	schema := string((&SearchDocuments{}).Parameters())
	for _, want := range []string{"Keyword or phrase", "Do not use path or pattern", "Maximum matching documents", "first call", "Opaque continuation cursor"} {
		if !strings.Contains(schema, want) {
			t.Errorf("schema must contain %q; got %q", want, schema)
		}
	}
	if err := (&SearchDocuments{}).ValidateInput([]byte(`{"path":".","pattern":"heliograph"}`)); err != nil {
		t.Fatalf("filesystem-shaped provider args should enter compatibility recovery, got %v", err)
	}
	if err := (&SearchDocuments{}).ValidateInput([]byte(`{"path":"","pattern":""}`)); err != nil {
		t.Fatalf("empty filesystem-shaped provider args should enter bounded compatibility recovery, got %v", err)
	}
	if err := (&SearchDocuments{}).ValidateInput([]byte(`{"query":"heliograph","cursor":"opaque_cursor"}`)); err != nil {
		t.Fatalf("opaque cursor should be accepted for unified search, got %v", err)
	}
}

func TestEditDocument(t *testing.T) {
	svc, ctx := newToolSvc(t)
	d, _ := svc.Create(ctx, documentapp.CreateInput{Name: "Doc", Content: "old"})
	out, err := (&EditDocument{svc: svc}).Execute(ctx, `{"id":"`+d.ID+`","content":"new body"}`)
	if err != nil {
		t.Fatalf("edit: %v", err)
	}
	if !strings.Contains(out, "Updated document") {
		t.Fatalf("got %q", out)
	}
	got, _ := svc.Get(ctx, d.ID)
	if got.Content != "new body" {
		t.Fatalf("content not updated: %q", got.Content)
	}
	// Empty update is a friendly no-op.
	noop, err := (&EditDocument{svc: svc}).Execute(ctx, `{"id":"`+d.ID+`"}`)
	if err != nil {
		t.Fatalf("edit noop: %v", err)
	}
	if !strings.Contains(noop, "nothing to update") {
		t.Fatalf("got %q", noop)
	}
}

func TestEditDocumentAcceptsOnlyJSONEncodedTagsArrayCompatibilityShape(t *testing.T) {
	svc, ctx := newToolSvc(t)
	d, _ := svc.Create(ctx, documentapp.CreateInput{Name: "Doc", Tags: []string{"draft"}})

	if _, err := (&EditDocument{svc: svc}).Execute(ctx, `{"id":"`+d.ID+`","tags":"[\"release\",\"accepted\"]"}`); err != nil {
		t.Fatalf("JSON-encoded tags array should be accepted: %v", err)
	}
	got, _ := svc.Get(ctx, d.ID)
	if strings.Join(got.Tags, ",") != "release,accepted" {
		t.Fatalf("decoded tags = %#v", got.Tags)
	}

	if _, err := (&EditDocument{svc: svc}).Execute(ctx, `{"id":"`+d.ID+`","tags":"release,accepted"}`); err == nil {
		t.Fatal("comma-joined tags string must remain invalid")
	}
	got, _ = svc.Get(ctx, d.ID)
	if strings.Join(got.Tags, ",") != "release,accepted" {
		t.Fatalf("invalid tags input changed durable tags = %#v", got.Tags)
	}
}

func TestMoveDocument(t *testing.T) {
	svc, ctx := newToolSvc(t)
	a, _ := svc.Create(ctx, documentapp.CreateInput{Name: "A"})
	b, _ := svc.Create(ctx, documentapp.CreateInput{Name: "B"})
	tool := &MoveDocument{svc: svc}
	out, err := tool.Execute(ctx, `{"id":"`+b.ID+`","parentId":"`+a.ID+`","position":"0"}`)
	if err != nil {
		t.Fatalf("move: %v", err)
	}
	if !strings.Contains(out, "/A/B") {
		t.Fatalf("expected new path /A/B, got %q", out)
	}
	// Cycle: move A under B (now a descendant of A).
	cyc, err := (&MoveDocument{svc: svc}).Execute(ctx, `{"id":"`+a.ID+`","parentId":"`+b.ID+`"}`)
	if err != nil {
		t.Fatalf("move cycle: %v", err)
	}
	if !strings.Contains(cyc, "cycle") {
		t.Fatalf("expected cycle rejection, got %q", cyc)
	}
	if !(&MoveDocument{svc: svc}).HaltOnRepeat(cyc, "") {
		t.Fatalf("cycle rejection must be terminal for exact repeat: %q", cyc)
	}
	// parentId omitted → friendly required hint.
	miss, err := (&MoveDocument{svc: svc}).Execute(ctx, `{"id":"`+b.ID+`"}`)
	if err != nil {
		t.Fatalf("move no-parent: %v", err)
	}
	if !strings.Contains(miss, "parentId required") {
		t.Fatalf("got %q", miss)
	}
}

func TestMoveDocument_RejectsNonIntegerPositionWithoutMutation(t *testing.T) {
	svc, ctx := newToolSvc(t)
	a, _ := svc.Create(ctx, documentapp.CreateInput{Name: "A"})
	b, _ := svc.Create(ctx, documentapp.CreateInput{Name: "B"})
	tool := &MoveDocument{svc: svc}

	for _, position := range []string{`0.5`, `true`, `[]`, `"0.5"`, `"first"`, `-1`} {
		args := `{"id":"` + b.ID + `","parentId":"` + a.ID + `","position":` + position + `}`
		if err := tool.ValidateInput([]byte(args)); err == nil {
			t.Fatalf("position %s should fail validation", position)
		}
		if _, err := tool.Execute(ctx, args); err == nil {
			t.Fatalf("position %s should fail execution", position)
		}
	}
	got, err := svc.Get(ctx, b.ID)
	if err != nil {
		t.Fatalf("get after rejected moves: %v", err)
	}
	if got.ParentID != nil || got.Path != "/B" {
		t.Fatalf("rejected positions mutated document: parent=%v path=%q", got.ParentID, got.Path)
	}
}

func TestMoveDocument_ContractDescribesHostedPositionCompatibility(t *testing.T) {
	for _, want := range []string{`exact decimal integer string`, "floats", "booleans", "arrays", "malformed strings"} {
		if !strings.Contains((&MoveDocument{}).Description(), want) {
			t.Errorf("description must contain %q; got %q", want, (&MoveDocument{}).Description())
		}
	}
	if !strings.Contains(string((&MoveDocument{}).Parameters()), "exact decimal integer string") {
		t.Error("schema must disclose hosted position compatibility")
	}
}

func TestDeleteDocument_Cascade(t *testing.T) {
	svc, ctx := newToolSvc(t)
	root, _ := svc.Create(ctx, documentapp.CreateInput{Name: "Root"})
	if _, err := svc.Create(ctx, documentapp.CreateInput{Name: "Child", ParentID: &root.ID}); err != nil {
		t.Fatalf("seed child: %v", err)
	}
	out, err := (&DeleteDocument{svc: svc}).Execute(ctx, `{"id":"`+root.ID+`"}`)
	if err != nil {
		t.Fatalf("delete: %v", err)
	}
	if !strings.Contains(out, "1 descendant") {
		t.Fatalf("expected cascade count, got %q", out)
	}
}

func TestValidateInput(t *testing.T) {
	if err := (&ReadDocument{}).ValidateInput([]byte(`{"id":""}`)); err == nil {
		t.Fatal("read: empty id should fail")
	}
	if err := (&SearchDocuments{}).ValidateInput([]byte(`{"query":""}`)); err == nil {
		t.Fatal("search: empty query should fail")
	}
	if err := (&CreateDocument{}).ValidateInput([]byte(`{"name":""}`)); err == nil {
		t.Fatal("create: empty name should fail")
	}
	if err := (&ListDocuments{}).ValidateInput(nil); err != nil {
		t.Fatalf("list: empty args should be allowed, got %v", err)
	}
}

// TestCreateDocument_DescriptionNoFalseAutoSplit: round-4 bigio lane — the description claimed >1MB
// content "split into child docs" (reads as automatic) but the backend HARD-REJECTS with 413
// DOCUMENT_CONTENT_TOO_LARGE; the agent repeated the false contract to the user and burned a 25-call
// detour trying to make an oversized doc. The description must state rejection, not auto-split.
func TestCreateDocument_DescriptionNoFalseAutoSplit(t *testing.T) {
	d := createDocumentDescription
	if strings.Contains(d, "split into child docs if") {
		t.Errorf("description still implies automatic >1MB splitting (false): %s", d)
	}
	for _, want := range []string{"1MB", "REJECTED", "yourself"} {
		if !strings.Contains(d, want) {
			t.Errorf("description must state the hard 1MB rejection (mention %q); got: %s", want, d)
		}
	}
}

func TestCreateDocument_ContractRequiresCanonicalNameOnFirstCall(t *testing.T) {
	for name, text := range map[string]string{
		"description": createDocumentDescription,
		"schema":      string(createDocumentSchema),
	} {
		for _, want := range []string{"REQUIRED", "every call", "first", "exact requested", "Never omit", "guess"} {
			if !strings.Contains(text, want) {
				t.Errorf("%s must teach the canonical first-call name contract (%q): %s", name, want, text)
			}
		}
	}
	if err := (&CreateDocument{}).ValidateInput([]byte(`{"description":"missing title"}`)); err == nil {
		t.Fatal("create without name must remain a validation failure")
	}
}

func TestCreateDocument_SchemaRequiresCanonicalDataFields(t *testing.T) {
	var schema struct {
		Required   []string `json:"required"`
		Properties map[string]struct {
			Description string `json:"description"`
		} `json:"properties"`
	}
	if err := json.Unmarshal(createDocumentSchema, &schema); err != nil {
		t.Fatalf("decode create schema: %v", err)
	}
	want := map[string]bool{"name": true, "description": true, "content": true, "tags": true}
	got := map[string]bool{}
	for _, field := range schema.Required {
		got[field] = true
	}
	for field := range want {
		if !got[field] {
			t.Errorf("required fields missing %q: %v", field, schema.Required)
		}
	}
	for field, terms := range map[string][]string{
		"description": {"REQUIRED", "exactly", "empty string"},
		"content":     {"REQUIRED", "full Markdown", "empty string"},
		"tags":        {"REQUIRED", "exact", "[]"},
	} {
		text := schema.Properties[field].Description
		for _, term := range terms {
			if !strings.Contains(text, term) {
				t.Errorf("%s schema description must mention %q: %s", field, term, text)
			}
		}
	}
}

func TestEditDocument_SchemaTeachesTagsArrayShape(t *testing.T) {
	var schema struct {
		Properties map[string]struct {
			Type        string `json:"type"`
			Description string `json:"description"`
			Items       struct {
				Type string `json:"type"`
			} `json:"items"`
		} `json:"properties"`
	}
	if err := json.Unmarshal(editDocumentSchema, &schema); err != nil {
		t.Fatalf("decode edit schema: %v", err)
	}
	tags := schema.Properties["tags"]
	if tags.Type != "array" || tags.Items.Type != "string" {
		t.Fatalf("edit tags schema = %#v, want array of strings", tags)
	}
	for _, want := range []string{"Full replacement", "JSON array", "never a single string"} {
		if !strings.Contains(tags.Description, want) {
			t.Errorf("edit tags schema must mention %q: %s", want, tags.Description)
		}
	}
	for _, want := range []string{"JSON array of strings", "never a single string", "tags:["} {
		if !strings.Contains(editDocumentDescription, want) {
			t.Errorf("edit description must mention %q: %s", want, editDocumentDescription)
		}
	}
}

func TestCreateDocument_CallIdentityUsesParentAndExactName(t *testing.T) {
	tool := &CreateDocument{}
	if got := tool.CallIdentity(json.RawMessage(`{"name":"Release Atlas"}`)); got != "document::Release Atlas" {
		t.Fatalf("root identity = %q", got)
	}
	if got := tool.CallIdentity(json.RawMessage(`{"name":"Release Atlas","content":"later"}`)); got != "document::Release Atlas" {
		t.Fatalf("optional fields must not change identity = %q", got)
	}
	if got := tool.CallIdentity(json.RawMessage(`{"name":"Ship Checklist","parentId":"doc_root"}`)); got != "document:doc_root:Ship Checklist" {
		t.Fatalf("child identity = %q", got)
	}
	if got := tool.CallIdentity(json.RawMessage(`{"description":"missing title"}`)); got != "" {
		t.Fatalf("missing name identity = %q, want empty", got)
	}
}

// TestDocumentTools_TeachTheMediaURIForm: an agent that just generated a chart has no way to embed
// it unless the tool TELLS it the scheme exists — the receipt gives an attachmentId, and nothing
// in a bare markdown tool would suggest that `anselm://media/<id>` is the url that renders. This is
// the whole of WRK-082 批F's AI side: the capability is a sentence in a description, and a
// description that loses that sentence loses the capability with no other symptom.
//
// 刚生成完图表的 agent,除非工具**告诉**它这个 scheme 存在,否则它无从把图嵌进去——receipt 给的是
// 一个 attachmentId,而一个只讲 markdown 的工具里没有任何东西会暗示 `anselm://media/<id>` 才是渲得出来
// 的那个 url。这就是批F 的 AI 侧全部:能力是描述里的一句话,而一份丢了这句话的描述会连同能力一起丢掉,
// 且没有任何其它症状。
func TestDocumentTools_TeachTheMediaURIForm(t *testing.T) {
	for name, text := range map[string]string{
		"create_document description": createDocumentDescription,
		"edit_document description":   editDocumentDescription,
		"create_document schema":      string(createDocumentSchema),
		"edit_document schema":        string(editDocumentSchema),
	} {
		if !strings.Contains(text, "anselm://media/") {
			t.Errorf("%s never mentions the media uri form — an agent cannot embed what it is not told about", name)
		}
	}
	// The example must be a real, well-formed id: a placeholder like `<id>` in the EXAMPLE (rather
	// than in the parameter description) is what a model copies verbatim.
	// 例子里必须是一个真实合法的 id:例子里放 `<id>` 这种占位符,正是模型会逐字抄下来的东西。
	if !strings.Contains(createDocumentDescription, "att_0011223344556677") {
		t.Error("the create_document example must show a well-formed attachment id, not a placeholder")
	}
}
