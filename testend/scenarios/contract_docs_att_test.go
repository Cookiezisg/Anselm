// contract_docs_att_test.go — Phase 1 契约全扫 · p1_docs_att 批（document 树 + attachment 摄取）。
//
// 覆盖行：A-doc-3/4/6/7/8 · A-att-4/6 · B-doc-1/3/7/10/13 · B-att-1/2/4/5/8/9。
// 事实源：docs/references/backend/domains/{document,attachment,conversation}.md + api.md + error-codes.md。
// 要点：document 树为一趟拿全设计（api.md 未定义 ?parentId 列表分页，N4 张力记账在批次报告）；
// Create 重名自动后缀 vs PATCH 显式改名严格 409；:duplicate BFS 深拷铸新 id；软删整子树留墓碑；
// attachment CAS 按 SHA-256 dedup（多行一 blob）；渲染降级三路（不认 mime / 盘上 blob 缺失 /
// 行被软删）都绝不让回合失败、且诚实报缺；活跃附件作 catalog source 入 system prompt。
package scenarios

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// docsattC_doc 是 document 的线缆形状（domain/document.go 的 JSON 投影）。
type docsattC_doc struct {
	ID        string  `json:"id"`
	ParentID  *string `json:"parentId"`
	Name      string  `json:"name"`
	Path      string  `json:"path"`
	Position  int     `json:"position"`
	Content   string  `json:"content"`
	SizeBytes int64   `json:"sizeBytes"`
}

// docsattC_att 是 attachment 元数据行的线缆形状。
type docsattC_att struct {
	ID        string `json:"id"`
	SHA256    string `json:"sha256"`
	Filename  string `json:"filename"`
	MimeType  string `json:"mimeType"`
	SizeBytes int64  `json:"sizeBytes"`
	Kind      string `json:"kind"`
}

// docsattC_rawGET 发一次不解 N1 envelope 的裸 GET（attachment :id/content 直出原始字节，
// 非 JSON envelope，harness Client.Do 会拒非 envelope 体）。
func docsattC_rawGET(t *testing.T, base, wsID, path string) (int, http.Header, []byte) {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, base+path, nil)
	if err != nil {
		t.Fatalf("raw get %s: %v", path, err)
	}
	req.Header.Set(harness.HeaderWorkspace, wsID)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("raw get %s: %v", path, err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, resp.Header, body
}

// docsattC_blobFiles 列出某 workspace CAS blob 树上的全部 blob 文件（跳过 .tmp）。
// 盘上布局是 attachment.md 声明的契约：<dataDir>/workspaces/<ws>/blobs/<sha[:2]>/<sha>。
func docsattC_blobFiles(t *testing.T, dataDir, wsID string) []string {
	t.Helper()
	root := filepath.Join(dataDir, "workspaces", wsID, "blobs")
	var files []string
	_ = filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil || d == nil || d.IsDir() || strings.HasSuffix(p, ".tmp") {
			return nil
		}
		files = append(files, p)
		return nil
	})
	return files
}

// docsattC_chatSetup 与 chatSetup 同款，但额外暴露 Server（DataDir 盘上取证）与 wsID。
func docsattC_chatSetup(t *testing.T) (*harness.Server, *harness.Client, *harness.LLMMock, string) {
	t.Helper()
	srv := harness.Start(t)
	mock := harness.NewLLMMock(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "docsatt-ws"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "llmmock", "key": "sk-mock", "baseUrl": mock.URL(),
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": dlgModel}).OK(t, nil)
	return srv, wc, mock, wsID
}

// docsattC_lastDumpWith 返回携带指定子串的最后一个 prompt dump（同一 mock 队列多对话共享，
// 用每次发送的唯一 token 定位属于该回合的请求）。
func docsattC_lastDumpWith(t *testing.T, mock *harness.LLMMock, substr string) harness.PromptDump {
	t.Helper()
	var out harness.PromptDump
	found := false
	for _, d := range mock.DumpsFor(dlgModel) {
		if strings.Contains(string(d.Raw), substr) {
			out = d
			found = true
		}
	}
	if !found {
		t.Fatalf("no prompt dump carries %q", substr)
	}
	return out
}

// TestContractDocsAtt_DocumentNameGuardsSoftDelete:
// B-doc-13 标题守卫（≤256、不含 '/'、空名拒）+ 1MB 内容硬拒；
// A-doc-8 严格解码拒未知字段（POST/PATCH 同律）；
// B-doc-1 Create 重名自动后缀 foo→foo 2、PATCH 显式改名严格 DOCUMENT_NAME_CONFLICT；
// B-doc-3 改中层名 → 后裔 path 批量级联重写；
// A-doc-6 软删整子树（子随父灭、不迁孤）+ 列表滤墓碑 + 同名复用零后缀。
func TestContractDocsAtt_DocumentNameGuardsSoftDelete(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "doc-guard-ws"}).Field(t, "id")
	wc := c.WS(wsID)

	// B-doc-13 名守卫：'/' 是 path 分隔符、超长、空名 → 400 DOCUMENT_INVALID_NAME；恰 256 合法。
	wc.Do("POST", "/api/v1/documents", map[string]any{"name": "bad/name"}).Fail(t, 400, "DOCUMENT_INVALID_NAME")
	wc.Do("POST", "/api/v1/documents", map[string]any{"name": strings.Repeat("n", 257)}).Fail(t, 400, "DOCUMENT_INVALID_NAME")
	wc.Do("POST", "/api/v1/documents", map[string]any{"name": "   "}).Fail(t, 400, "DOCUMENT_INVALID_NAME")
	wc.POST("/api/v1/documents", map[string]any{"name": strings.Repeat("n", 256)}).OK(t, nil)
	// 1MB 内容上限：超出硬拒 413、非自动拆分（大载荷程序生成）。
	wc.Do("POST", "/api/v1/documents", map[string]any{
		"name": "huge", "content": strings.Repeat("x", 1<<20+1),
	}).Fail(t, 413, "DOCUMENT_CONTENT_TOO_LARGE")

	// A-doc-8 拒未知字段：POST 与 PATCH 都是严格解码 → 400 INVALID_REQUEST。
	wc.Do("POST", "/api/v1/documents", map[string]any{"name": "x", "bogus": true}).Fail(t, 400, "INVALID_REQUEST")

	// B-doc-1 Create 自动后缀 vs PATCH 严格冲突。
	var foo1, foo2 docsattC_doc
	wc.POST("/api/v1/documents", map[string]any{"name": "foo"}).OK(t, &foo1)
	wc.POST("/api/v1/documents", map[string]any{"name": "foo"}).OK(t, &foo2)
	if foo2.Name != "foo 2" || foo2.Path != "/foo 2" {
		t.Fatalf("second POST of same name must auto-suffix to 'foo 2' (path '/foo 2'), got name=%q path=%q", foo2.Name, foo2.Path)
	}
	if foo1.ID == foo2.ID {
		t.Fatalf("auto-suffixed create must mint a new document")
	}
	wc.Do("PATCH", "/api/v1/documents/"+foo2.ID, map[string]any{"name": "foo"}).Fail(t, 409, "DOCUMENT_NAME_CONFLICT")
	wc.Do("PATCH", "/api/v1/documents/"+foo2.ID, map[string]any{"name": "y", "bogus": 1}).Fail(t, 400, "INVALID_REQUEST") // A-doc-8

	// B-doc-3 三层树 a/b/c，改中层名 → 孙节点 path 跟着换。
	var da, db, dc docsattC_doc
	wc.POST("/api/v1/documents", map[string]any{"name": "cas-a"}).OK(t, &da)
	wc.POST("/api/v1/documents", map[string]any{"name": "cas-b", "parentId": da.ID}).OK(t, &db)
	wc.POST("/api/v1/documents", map[string]any{"name": "cas-c", "parentId": db.ID}).OK(t, &dc)
	if dc.Path != "/cas-a/cas-b/cas-c" {
		t.Fatalf("materialized path must chain ancestors, got %q", dc.Path)
	}
	wc.PATCH("/api/v1/documents/"+db.ID, map[string]any{"name": "cas-b2"}).OK(t, nil)
	var got docsattC_doc
	wc.GET("/api/v1/documents/"+dc.ID).OK(t, &got)
	if got.Path != "/cas-a/cas-b2/cas-c" {
		t.Fatalf("rename must cascade descendant paths, grandchild path=%q", got.Path)
	}

	// A-doc-6 软删整子树：删祖先 → 后裔一并墓碑（404、不迁孤）；列表/树滤墓碑；同名复用零后缀。
	if r := wc.DELETE("/api/v1/documents/" + da.ID); r.Status != 204 {
		t.Fatalf("DELETE must be 204, got %d %s", r.Status, r.Raw)
	}
	wc.Do("GET", "/api/v1/documents/"+da.ID, nil).Fail(t, 404, "DOCUMENT_NOT_FOUND")
	wc.Do("GET", "/api/v1/documents/"+db.ID, nil).Fail(t, 404, "DOCUMENT_NOT_FOUND")
	wc.Do("GET", "/api/v1/documents/"+dc.ID, nil).Fail(t, 404, "DOCUMENT_NOT_FOUND")
	var roots []docsattC_doc
	wc.GET("/api/v1/documents").OK(t, &roots)
	for _, r := range roots {
		if r.ID == da.ID {
			t.Fatalf("root list must filter tombstones")
		}
	}
	var tree []docsattC_doc
	wc.GET("/api/v1/documents/tree").OK(t, &tree)
	for _, n := range tree {
		if n.ID == da.ID || n.ID == db.ID || n.ID == dc.ID {
			t.Fatalf("tree must not carry tombstoned subtree node %s", n.ID)
		}
	}
	var reborn docsattC_doc
	wc.POST("/api/v1/documents", map[string]any{"name": "cas-a"}).OK(t, &reborn)
	if reborn.Name != "cas-a" {
		t.Fatalf("soft-deleted name must be reusable verbatim (no suffix), got %q", reborn.Name)
	}
}

// TestContractDocsAtt_DocumentChildrenDuplicateMove:
// A-doc-3 ?parentId 直接子节点一趟拿全（position ASC；无游标——api.md 树设计无分页）；
// A-doc-4 :duplicate 201 返新根裸实体（名自动去重）+ /tree 无 content 形；
// B-doc-10 深拷三层子树（BFS 铸新 id、parent/path 重映射、content 复制、原树不动）；
// A-doc-7 :move 防环/自指/未知父 + nil parent=移根、:duplicate 显式 parentId 落点与错误路径。
func TestContractDocsAtt_DocumentChildrenDuplicateMove(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "doc-tree-ws"}).Field(t, "id")
	wc := c.WS(wsID)

	// A-doc-3 多子节点：55 个直接子一次全返、创建序 = position ASC、顶层无分页坐标。
	var parent docsattC_doc
	wc.POST("/api/v1/documents", map[string]any{"name": "kids-parent"}).OK(t, &parent)
	for i := 0; i < 55; i++ {
		wc.POST("/api/v1/documents", map[string]any{
			"name": fmt.Sprintf("kid-%02d", i), "parentId": parent.ID,
		}).OK(t, nil)
	}
	r := wc.GET("/api/v1/documents?parentId=" + parent.ID)
	var kids []docsattC_doc
	r.OK(t, &kids)
	if len(kids) != 55 {
		t.Fatalf("children list is a one-shot full set (tree design, api.md), want 55 got %d", len(kids))
	}
	prev := -1
	for i, k := range kids {
		if k.Name != fmt.Sprintf("kid-%02d", i) {
			t.Fatalf("children must come back position ASC (creation order), idx %d got %q", i, k.Name)
		}
		if k.Position <= prev {
			t.Fatalf("sibling positions must strictly increase, idx %d pos %d after %d", i, k.Position, prev)
		}
		prev = k.Position
	}
	if r.NextCursor != "" || r.HasMore {
		t.Fatalf("document children list carries no pagination coordinates (tree design), got cursor=%q hasMore=%v", r.NextCursor, r.HasMore)
	}
	// 传分页参数不改变全量语义（api.md 未定义 cursor/limit，忽略而非报错）。
	var kids2 []docsattC_doc
	wc.GET("/api/v1/documents?parentId="+parent.ID+"&limit=5&cursor=zz").OK(t, &kids2)
	if len(kids2) != 55 {
		t.Fatalf("undocumented cursor/limit params must not truncate the tree list, got %d", len(kids2))
	}
	// 根级列表（空 parentId）只见根，不见子。
	var roots []docsattC_doc
	wc.GET("/api/v1/documents").OK(t, &roots)
	seenParent := false
	for _, rt := range roots {
		if rt.ID == parent.ID {
			seenParent = true
		}
		if strings.HasPrefix(rt.Name, "kid-") {
			t.Fatalf("root list must not include children, saw %q", rt.Name)
		}
	}
	if !seenParent {
		t.Fatalf("root list must include the root-level parent")
	}

	// 三层源树 dup-src / dup-mid / dup-leaf。
	var src, mid, leaf docsattC_doc
	wc.POST("/api/v1/documents", map[string]any{"name": "dup-src", "content": "ROOTBODY"}).OK(t, &src)
	wc.POST("/api/v1/documents", map[string]any{"name": "dup-mid", "parentId": src.ID, "content": "MIDBODY"}).OK(t, &mid)
	wc.POST("/api/v1/documents", map[string]any{"name": "dup-leaf", "parentId": mid.ID, "content": "LEAFBODY"}).OK(t, &leaf)

	// A-doc-7 :move 守卫（树未动前逐打）：挂到后裔=环、挂到自己、未知父。
	wc.Do("POST", "/api/v1/documents/"+src.ID+":move", map[string]any{"parentId": leaf.ID}).Fail(t, 422, "DOCUMENT_INVALID_PARENT")
	wc.Do("POST", "/api/v1/documents/"+src.ID+":move", map[string]any{"parentId": src.ID}).Fail(t, 422, "DOCUMENT_INVALID_PARENT")
	wc.Do("POST", "/api/v1/documents/"+src.ID+":move", map[string]any{"parentId": "doc_ffffffffffffffff"}).Fail(t, 422, "DOCUMENT_PARENT_NOT_FOUND")

	// A-doc-4 + B-doc-10 :duplicate（无 body → 落为源的兄弟）：201 裸实体、新根名去重、深拷全新 id。
	rd := wc.Do("POST", "/api/v1/documents/"+src.ID+":duplicate", nil)
	if rd.Status != 201 {
		t.Fatalf(":duplicate must answer 201 Created with the bare new root, got %d %s", rd.Status, rd.Raw)
	}
	var newRoot docsattC_doc
	rd.OK(t, &newRoot)
	if newRoot.ID == src.ID || !strings.HasPrefix(newRoot.ID, "doc_") {
		t.Fatalf("duplicate must mint a fresh doc_ id, got %q", newRoot.ID)
	}
	if newRoot.Name != "dup-src 2" || newRoot.Path != "/dup-src 2" || newRoot.ParentID != nil {
		t.Fatalf("sibling duplicate must auto-uniquify the new root name, got name=%q path=%q parent=%v", newRoot.Name, newRoot.Path, newRoot.ParentID)
	}
	if newRoot.Content != "ROOTBODY" {
		t.Fatalf("duplicate must copy content, got %q", newRoot.Content)
	}
	var newKids []docsattC_doc
	wc.GET("/api/v1/documents?parentId=" + newRoot.ID).OK(t, &newKids)
	if len(newKids) != 1 || newKids[0].Name != "dup-mid" || newKids[0].Content != "MIDBODY" ||
		newKids[0].ID == mid.ID || newKids[0].Path != "/dup-src 2/dup-mid" {
		t.Fatalf("deep copy child must be a fresh id with remapped parent/path + copied content, got %+v", newKids)
	}
	var newGrand []docsattC_doc
	wc.GET("/api/v1/documents?parentId=" + newKids[0].ID).OK(t, &newGrand)
	if len(newGrand) != 1 || newGrand[0].Name != "dup-leaf" || newGrand[0].Content != "LEAFBODY" ||
		newGrand[0].ID == leaf.ID || newGrand[0].Path != "/dup-src 2/dup-mid/dup-leaf" {
		t.Fatalf("deep copy grandchild must be remapped through the copied parent, got %+v", newGrand)
	}
	// 原树不动。
	var origLeaf docsattC_doc
	wc.GET("/api/v1/documents/" + leaf.ID).OK(t, &origLeaf)
	if origLeaf.Path != "/dup-src/dup-mid/dup-leaf" || origLeaf.ParentID == nil || *origLeaf.ParentID != mid.ID {
		t.Fatalf("duplicate must not touch the source tree, got %+v", origLeaf)
	}

	// A-doc-4 /tree 是 metadata 投影：无 content 键、带 path/sizeBytes。
	var treeRows []map[string]json.RawMessage
	wc.GET("/api/v1/documents/tree").OK(t, &treeRows)
	if len(treeRows) == 0 {
		t.Fatalf("tree must list live nodes")
	}
	for _, row := range treeRows {
		if _, ok := row["content"]; ok {
			t.Fatalf("tree rows must not carry content (metadata only), got keys %v", row)
		}
		if _, ok := row["path"]; !ok {
			t.Fatalf("tree rows must carry path, got %v", row)
		}
		if _, ok := row["sizeBytes"]; !ok {
			t.Fatalf("tree rows must carry sizeBytes, got %v", row)
		}
		// hasContent bool drives the sidebar's empty-page vs written-doc icon (免拉正文).
		if _, ok := row["hasContent"]; !ok {
			t.Fatalf("tree rows must carry hasContent, got %v", row)
		}
	}
	// The dup source has body "ROOTBODY" → hasContent true; assert the bool tracks real content.
	// dup 源正文 "ROOTBODY" → hasContent 真；断言该 bool 跟随真实正文有无。
	for _, row := range treeRows {
		var id string
		_ = json.Unmarshal(row["id"], &id)
		if id != src.ID {
			continue
		}
		var hc bool
		if err := json.Unmarshal(row["hasContent"], &hc); err != nil || !hc {
			t.Fatalf("tree row for a doc with content must report hasContent=true, got %s err=%v", row["hasContent"], err)
		}
	}

	// A-doc-7 :duplicate 显式 parentId 落点 + 错误路径。
	var zone docsattC_doc
	wc.POST("/api/v1/documents", map[string]any{"name": "landing-zone"}).OK(t, &zone)
	rz := wc.Do("POST", "/api/v1/documents/"+mid.ID+":duplicate", map[string]any{"parentId": zone.ID})
	if rz.Status != 201 {
		t.Fatalf(":duplicate with explicit parentId must 201, got %d %s", rz.Status, rz.Raw)
	}
	var zoned docsattC_doc
	rz.OK(t, &zoned)
	if zoned.ParentID == nil || *zoned.ParentID != zone.ID || zoned.Path != "/landing-zone/dup-mid" {
		t.Fatalf("explicit parentId must place the copy under it, got %+v", zoned)
	}
	var zonedKids []docsattC_doc
	wc.GET("/api/v1/documents?parentId=" + zoned.ID).OK(t, &zonedKids)
	if len(zonedKids) != 1 || zonedKids[0].Name != "dup-leaf" || zonedKids[0].Content != "LEAFBODY" {
		t.Fatalf("subtree must ride the relocated duplicate, got %+v", zonedKids)
	}
	wc.Do("POST", "/api/v1/documents/doc_ffffffffffffffff:duplicate", nil).Fail(t, 404, "DOCUMENT_NOT_FOUND")
	wc.Do("POST", "/api/v1/documents/"+mid.ID+":duplicate", map[string]any{"parentId": "doc_ffffffffffffffff"}).Fail(t, 422, "DOCUMENT_PARENT_NOT_FOUND")

	// A-doc-7 :move nil parent = 移根（{} 缺省 parentId 即根），path 重物化。
	var moved docsattC_doc
	wc.POST("/api/v1/documents/"+leaf.ID+":move", map[string]any{}).OK(t, &moved)
	if moved.ParentID != nil || moved.Path != "/dup-leaf" {
		t.Fatalf(":move with omitted parentId must land at root, got %+v", moved)
	}
	// N1：搬空后的父，子列表是 []、绝非 null。
	re := wc.GET("/api/v1/documents?parentId=" + mid.ID)
	re.OK(t, nil)
	if s := strings.TrimSpace(string(re.Data)); s != "[]" {
		t.Fatalf("empty children list must serialize as data:[] (N1), got %q", s)
	}
	// 未知动作 → 404。
	if r := wc.Do("POST", "/api/v1/documents/"+mid.ID+":frobnicate", nil); r.Status != 404 {
		t.Fatalf("unknown :action must 404, got %d %s", r.Status, r.Raw)
	}
}

// TestContractDocsAtt_AttachmentRestAndCASDedup:
// B-att-2 KindFromMIME 六桶（mime 主类型 + charset 剥离 + 扩展名兜底）；
// B-att-8 upload→download 字节 round-trip 矩阵 + 软删后 get/download 双 404；
// A-att-4 N1 形：content 直出原始字节（非 envelope）+ DELETE 204 无体；
// B-att-1 CAS dedup：相同字节两行共享一 blob（sha256 非唯一）、删一行 blob 仍在，删尽两行 →
//   重启触发 boot GC 回收孤儿 blob（GC 是 boot 时对账,非删除时,避免与在飞上传竞态）。
func TestContractDocsAtt_AttachmentRestAndCASDedup(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "att-ws"}).Field(t, "id")
	wc := c.WS(wsID)

	// B-att-2 + B-att-8：kind 分桶矩阵，每件都做字节 round-trip。
	cases := []struct {
		file, mime, wantKind string
		body                 []byte
	}{
		{"shot.png", "image/png", "image", tinyPNG},
		{"song.mp3", "audio/mpeg", "audio", []byte("ID3fakeaudio")},
		{"clip.mp4", "video/mp4", "video", []byte("ftypfakevideo")},
		{"paper.pdf", "application/pdf", "document", buildPDF("kindprobe")},
		{"notes.txt", "text/plain; charset=utf-8", "text", []byte("hello text body")}, // charset 后缀剥离后分桶
		{"data.json", "application/json", "text", []byte(`{"k":1}`)},                  // textual 应用型 mime
		{"slides.pptx", "application/x-unknown", "document", []byte("PKfakepptx")},    // 扩展名兜底
		{"pic.heic", "application/x-unknown", "image", []byte("heicfakebytes")},       // 扩展名兜底
		{"mystery.bin", "application/x-unknown", "other", []byte{0x00, 0x01, 0x02}},   // 双不认 → other
	}
	metas := make([]docsattC_att, len(cases))
	for i, tc := range cases {
		r := wc.Upload(t, "/api/v1/attachments", tc.file, tc.mime, tc.body)
		if r.Status != 201 {
			t.Fatalf("upload %s: want 201, got %d %s", tc.file, r.Status, r.Raw)
		}
		if err := json.Unmarshal(r.Data, &metas[i]); err != nil {
			t.Fatalf("upload %s: decode meta: %v %s", tc.file, err, r.Data)
		}
		m := metas[i]
		if m.Kind != tc.wantKind {
			t.Errorf("KindFromMIME(%s / %q): want %q got %q", tc.file, tc.mime, tc.wantKind, m.Kind)
		}
		if m.Filename != tc.file || m.SizeBytes != int64(len(tc.body)) || m.MimeType != tc.mime {
			t.Errorf("upload %s meta must mirror the wire (filename/size/mime), got %+v", tc.file, m)
		}
		status, hdr, body := docsattC_rawGET(t, srv.BaseURL, wsID, "/api/v1/attachments/"+m.ID+"/content")
		if status != 200 || !bytes.Equal(body, tc.body) {
			t.Fatalf("content round-trip %s: status %d, byte-equal=%v", tc.file, status, bytes.Equal(body, tc.body))
		}
		if ct := hdr.Get("Content-Type"); ct != tc.mime {
			t.Errorf("content %s must stream with the stored mime, want %q got %q", tc.file, tc.mime, ct)
		}
	}

	// B-att-1 CAS dedup：相同字节双上传 → 两行两 id 同 sha，盘上共享一 blob。
	payload := []byte("cas dedup shared bytes payload")
	sum := sha256.Sum256(payload)
	sha := hex.EncodeToString(sum[:])
	var one, two docsattC_att
	r1 := wc.Upload(t, "/api/v1/attachments", "one.txt", "text/plain", payload)
	r2 := wc.Upload(t, "/api/v1/attachments", "two.txt", "text/plain", payload)
	if r1.Status != 201 || r2.Status != 201 {
		t.Fatalf("dedup uploads must both 201, got %d/%d", r1.Status, r2.Status)
	}
	_ = json.Unmarshal(r1.Data, &one)
	_ = json.Unmarshal(r2.Data, &two)
	if one.SHA256 != sha || two.SHA256 != sha {
		t.Fatalf("sha256 column must be the content hash, want %s got %s / %s", sha, one.SHA256, two.SHA256)
	}
	if one.ID == two.ID {
		t.Fatalf("identical bytes must still mint distinct rows (dedup is at the blob, not the row)")
	}
	blobPath := filepath.Join(srv.DataDir, "workspaces", wsID, "blobs", sha[:2], sha)
	if _, err := os.Stat(blobPath); err != nil {
		t.Fatalf("blob must live at <ws>/blobs/<sha[:2]>/<sha>: %v", err)
	}
	// 11 行（矩阵 9 + dedup 2）只落 10 个 blob（矩阵 9 种字节 + 共享 1）——盘上单 blob 的直接证据。
	if files := docsattC_blobFiles(t, srv.DataDir, wsID); len(files) != 10 {
		t.Fatalf("CAS must dedup identical bytes to one blob: want 10 blob files for 11 rows, got %d: %v", len(files), files)
	}

	// A-att-4 DELETE 204 无体；B-att-8 软删后 get/download 双 404 ATTACHMENT_NOT_FOUND。
	delID := metas[4].ID // notes.txt
	if r := wc.DELETE("/api/v1/attachments/" + delID); r.Status != 204 || len(r.Raw) != 0 {
		t.Fatalf("DELETE must be 204 with empty body, got %d %q", r.Status, r.Raw)
	}
	wc.Do("GET", "/api/v1/attachments/"+delID, nil).Fail(t, 404, "ATTACHMENT_NOT_FOUND")
	status, _, body := docsattC_rawGET(t, srv.BaseURL, wsID, "/api/v1/attachments/"+delID+"/content")
	if status != 404 {
		t.Fatalf("download after soft-delete must 404, got %d %s", status, body)
	}
	var env struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if json.Unmarshal(body, &env) != nil || env.Error.Code != "ATTACHMENT_NOT_FOUND" {
		t.Fatalf("download 404 must be the N1 error envelope with ATTACHMENT_NOT_FOUND, got %s", body)
	}

	// B-att-1 删一行：另一行仍活、blob 必须还在（活跃 sha 在保留集内）。
	if r := wc.DELETE("/api/v1/attachments/" + one.ID); r.Status != 204 {
		t.Fatalf("delete first dedup row: got %d", r.Status)
	}
	if _, err := os.Stat(blobPath); err != nil {
		t.Fatalf("blob must survive while a live row still references its sha: %v", err)
	}
	status, _, body = docsattC_rawGET(t, srv.BaseURL, wsID, "/api/v1/attachments/"+two.ID+"/content")
	if status != 200 || !bytes.Equal(body, payload) {
		t.Fatalf("surviving row must still download the shared blob, status %d", status)
	}

	// 删第二行：sha 再无活跃行引用 → 孤儿 blob。GC 在 **boot** 跑（非删除时——删除时扫描会与在飞上传
	// 竞态,见 build.go 注释）,故重启后端触发 boot 对账,孤儿 blob 被回收。会话内累积、重启回收——有界。
	if r := wc.DELETE("/api/v1/attachments/" + two.ID); r.Status != 204 {
		t.Fatalf("delete second dedup row: got %d", r.Status)
	}
	if _, err := os.Stat(blobPath); err != nil {
		t.Fatalf("blob must still exist before the boot GC runs (GC is boot-time, not delete-time): %v", err)
	}
	srv.Restart(t)
	harness.Eventually(t, 15000, "orphan blob reclaimed by boot GC once no live row references its sha", func() bool {
		_, err := os.Stat(blobPath)
		return os.IsNotExist(err)
	})
}

// TestContractDocsAtt_AttachmentChatDegradeFaces:
// B-att-9 活跃附件作 catalog source（### attachment 组、filename + kind/mime/size 描述）入 system prompt；
// B-att-4 不认 mime 的 document（odt 不在 extractor 工具链）→ 占位降级、回合照常 completed；
// B-att-5 盘上 blob 被手删 → 告警跳过（filename 形告缺）、回合绝不失败、原始字节不上线；
// A-att-6 附件被软删后旧对话再续 → 历史重渲诚实报缺（带 att id）、内容不复活。
func TestContractDocsAtt_AttachmentChatDegradeFaces(t *testing.T) {
	srv, wc, mock, wsID := docsattC_chatSetup(t)

	// B-att-9 catalog source。
	uploadAtt(t, wc, "catprobe.txt", "text/plain", []byte("catalog probe body"))
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "noted"})
	conv1 := convCreate(t, wc, "catalog probe")
	if turn := waitTurn(t, wc, conv1, sendMsg(t, wc, conv1, "what files do i have? CATCONV"), 30000); turn.Status != "completed" {
		t.Fatalf("catalog turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	d := docsattC_lastDumpWith(t, mock, "CATCONV")
	if !strings.Contains(d.System, "### attachment") || !strings.Contains(d.System, "catprobe.txt") {
		t.Errorf("live attachments must surface as a catalog group in the system prompt, got %dB system", len(d.System))
	}
	if !strings.Contains(d.System, "text/plain") {
		t.Errorf("catalog attachment entry must describe kind/mime/size, system misses the mime")
	}

	// B-att-4 kind=document 但 mime 不在抽取工具链（odt）→ 占位、completed。
	odtID := uploadAtt(t, wc, "book.odt", "application/vnd.oasis.opendocument.text", []byte("odt-raw-bytes-FAKE"))
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "saw placeholder"})
	conv2 := convCreate(t, wc, "odt degrade")
	mid2 := sendWith(t, wc, conv2, map[string]any{"content": "read it ODTCONV", "attachmentIds": []string{odtID}})
	if turn := waitTurn(t, wc, conv2, mid2, 60000); turn.Status != "completed" {
		t.Fatalf("unsupported-mime attachment must degrade, never fail the turn; got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	raw2 := string(docsattC_lastDumpWith(t, mock, "ODTCONV").Raw)
	if !strings.Contains(raw2, "could not be extracted") {
		t.Errorf("unsupported extraction must degrade to the placeholder note, wire misses it")
	}
	if strings.Contains(raw2, "odt-raw-bytes-FAKE") {
		t.Errorf("degraded document must not leak raw bytes onto the wire")
	}

	// B-att-5 盘上 blob 缺失：手删 CAS 文件后发消息 → completed + filename 形告缺。
	ghostBody := []byte("GHOSTTOKEN payload body")
	ghostID := uploadAtt(t, wc, "ghost.txt", "text/plain", ghostBody)
	gsum := sha256.Sum256(ghostBody)
	gsha := hex.EncodeToString(gsum[:])
	ghostBlob := filepath.Join(srv.DataDir, "workspaces", wsID, "blobs", gsha[:2], gsha)
	if err := os.Remove(ghostBlob); err != nil {
		t.Fatalf("remove blob on disk (simulated corruption): %v", err)
	}
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "missing noted"})
	conv3 := convCreate(t, wc, "ghost blob")
	mid3 := sendWith(t, wc, conv3, map[string]any{"content": "see the file GHOSTCONV", "attachmentIds": []string{ghostID}})
	if turn := waitTurn(t, wc, conv3, mid3, 30000); turn.Status != "completed" {
		t.Fatalf("missing blob must be skipped with a warning, never fail the turn; got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	raw3 := string(docsattC_lastDumpWith(t, mock, "GHOSTCONV").Raw)
	if !strings.Contains(raw3, "is no longer available") || !strings.Contains(raw3, "ghost.txt") {
		t.Errorf("unreadable blob must surface as an honest by-filename note on the wire")
	}
	if strings.Contains(raw3, "GHOSTTOKEN") {
		t.Errorf("content of an unreadable blob must not appear on the wire")
	}

	// A-att-6 软删附件后旧对话再续：第一回合内容内联；删行后第二回合历史重渲带 id 告缺、内容不复活。
	memoBody := []byte("MEMOTOKEN secret content")
	memoID := uploadAtt(t, wc, "memo.txt", "text/plain", memoBody)
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "read it"}, harness.LLMTurn{Text: "second"})
	conv4 := convCreate(t, wc, "dangling ref")
	mid4 := sendWith(t, wc, conv4, map[string]any{"content": "here MEMOCONV1", "attachmentIds": []string{memoID}})
	if turn := waitTurn(t, wc, conv4, mid4, 30000); turn.Status != "completed" {
		t.Fatalf("first memo turn must complete, got %s", turn.Status)
	}
	if raw4 := string(docsattC_lastDumpWith(t, mock, "MEMOCONV1").Raw); !strings.Contains(raw4, "MEMOTOKEN") {
		t.Fatalf("text attachment must inline its content while the row is live")
	}
	if r := wc.DELETE("/api/v1/attachments/" + memoID); r.Status != 204 {
		t.Fatalf("delete memo attachment: got %d", r.Status)
	}
	mid5 := sendMsg(t, wc, conv4, "look again MEMOCONV2")
	if turn := waitTurn(t, wc, conv4, mid5, 30000); turn.Status != "completed" {
		t.Fatalf("continuing after attachment delete must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	raw5 := string(docsattC_lastDumpWith(t, mock, "MEMOCONV2").Raw)
	if !strings.Contains(raw5, "a referenced attachment") || !strings.Contains(raw5, memoID) {
		t.Errorf("history re-render must honestly report the dangling attachment by id")
	}
	if strings.Contains(raw5, "MEMOTOKEN") {
		t.Errorf("soft-deleted attachment content must not resurrect in later turns")
	}
}

// TestContractDocsAtt_DocumentAttachScopeAndIterate:
// B-doc-7 对话挂载单篇不拖子树（挂父后子正文不上线；attach-time eager 校验坏 id 422）；
// A-doc-7 :iterate 202 返 {id}=conversationId、对话真实存在；未知 doc 404。
func TestContractDocsAtt_DocumentAttachScopeAndIterate(t *testing.T) {
	_, wc, mock, _ := docsattC_chatSetup(t)

	var parent, child docsattC_doc
	wc.POST("/api/v1/documents", map[string]any{"name": "attach-parent", "content": "PARENTBODY alpha"}).OK(t, &parent)
	wc.POST("/api/v1/documents", map[string]any{"name": "attach-child", "parentId": parent.ID, "content": "CHILDBODY omega"}).OK(t, &child)

	conv := convCreate(t, wc, "attach scope")
	// 挂载 eager 校验：引用不存在 doc → 422（conversation.md）。
	wc.Do("PATCH", "/api/v1/conversations/"+conv, map[string]any{
		"attachedDocuments": []map[string]any{{"documentId": "doc_ffffffffffffffff"}},
	}).Fail(t, 422, "CONVERSATION_ATTACHED_DOC_NOT_FOUND")
	wc.PATCH("/api/v1/conversations/"+conv, map[string]any{
		"attachedDocuments": []map[string]any{{"documentId": parent.ID}},
	}).OK(t, nil)

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "scoped"})
	if turn := waitTurn(t, wc, conv, sendMsg(t, wc, conv, "read the docs SCOPECONV"), 30000); turn.Status != "completed" {
		t.Fatalf("attach turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	d := docsattC_lastDumpWith(t, mock, "SCOPECONV")
	if !strings.Contains(d.System, "PARENTBODY alpha") || !strings.Contains(d.System, `<document path="/attach-parent"`) {
		t.Errorf("attached doc must inject verbatim into the documents section, got %dB system", len(d.System))
	}
	if strings.Contains(d.System, "CHILDBODY omega") {
		t.Errorf("attach is single-doc by design — the child's body must NOT auto-inject")
	}

	// A-doc-7 :iterate → 202 {id}，返回的 conversation 真实可取；未知 doc 先验 404。
	r := wc.Do("POST", "/api/v1/documents/"+parent.ID+":iterate", map[string]any{"request": "polish the intro"})
	if r.Status != 202 {
		t.Fatalf(":iterate must answer 202 Accepted with {id: conversationId}, got %d %s", r.Status, r.Raw)
	}
	convID := r.Field(t, "id")
	if !strings.HasPrefix(convID, "cv_") {
		t.Fatalf(":iterate must return a conversation id, got %q", convID)
	}
	wc.GET("/api/v1/conversations/" + convID).OK(t, nil)
	wc.Do("POST", "/api/v1/documents/doc_ffffffffffffffff:iterate", map[string]any{"request": "x"}).Fail(t, 404, "DOCUMENT_NOT_FOUND")
}
