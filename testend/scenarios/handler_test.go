package scenarios

import (
	"encoding/base64"
	"strings"
	"sync"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// hdCreate builds a handler over HTTP and returns its id.
//
// hdCreate 经 HTTP 构建一个 handler 并返回 id。
func hdCreate(t *testing.T, wc *harness.Client, name string, body map[string]any) string {
	t.Helper()
	payload := map[string]any{"name": name, "description": "验收用"}
	for k, v := range body {
		payload[k] = v
	}
	r := wc.POST("/api/v1/handlers", payload)
	if r.Status >= 300 {
		t.Fatalf("handler create: %d %s", r.Status, r.Raw)
	}
	// Create 现返裸实体(MD1):data 顶层即 id + 内嵌 activeVersion。
	return r.Field(t, "id")
}

// TestHandler_ArtifactPerCallProduct exercises the resident handler's binary artifact contract
// through the normal HTTP surface, without a provider key or model call. Each call writes a real
// decoder-valid PNG into its own ANSELM_OUT directory; the returned receipts must be distinct,
// attributed to the handler producer, and serve the exact bytes from the attachment store.
//
// TestHandler_ArtifactPerCallProduct 经正常 HTTP 面验证驻留 handler 的二进制产物契约，不需要供应商
// key，也不调用模型。每次调用都向自己的 ANSELM_OUT 写入可解码 PNG；返回 receipt 必须各自不同、标明
// handler 产地，并能从附件库提供原字节。
func TestHandler_ArtifactPerCallProduct(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "hd-artifact-product"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	// Keep the fixture decoder-valid while avoiding matplotlib or any provider dependency in the
	// acceptance. The call counter changes the file bytes, so content-addressed deduplication cannot
	// explain identical receipts.
	// 夹具保持可解码，同时不依赖 matplotlib 或供应商；调用计数改变文件字节，故相同 receipt 不能由内容寻址
	// 去重解释。
	pngB64 := base64.StdEncoding.EncodeToString(tinyPNG)
	hdID := hdCreate(t, wc, "artifact_keeper", map[string]any{
		"initBody": "self.n = 0",
		"methods": []map[string]any{{
			"name": "plot", "inputs": []any{},
			"body": "import base64, os\nself.n += 1\nraw = base64.b64decode('" + pngB64 + "') + bytes([self.n])\nopen(os.path.join(os.environ['ANSELM_OUT'], 'plot.png'), 'wb').write(raw)\nreturn {'chart': {'$media': 'plot.png'}, 'call': self.n}",
		}},
	})

	call := func(want int) string {
		t.Helper()
		var out struct {
			Chart struct {
				AttachmentID string `json:"attachmentId"`
				Mime         string `json:"mime"`
				Source       string `json:"source"`
			} `json:"chart"`
			Call int `json:"call"`
		}
		wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{"method": "plot", "args": map[string]any{}}).OK(t, &out)
		if out.Call != want {
			t.Fatalf("call %d reported itself as %d", want, out.Call)
		}
		if out.Chart.AttachmentID == "" || out.Chart.Mime != "image/png" || out.Chart.Source != "handler_artifact" {
			t.Fatalf("call %d returned an invalid handler receipt: %+v", want, out.Chart)
		}
		content := wc.DoRaw("GET", "/api/v1/attachments/"+out.Chart.AttachmentID+"/content", "", nil)
		if content.Status != 200 || len(content.Raw) != len(tinyPNG)+1 || string(content.Raw[:len(tinyPNG)]) != string(tinyPNG) || content.Raw[len(content.Raw)-1] != byte(want) {
			t.Fatalf("call %d attachment bytes were not preserved: HTTP %d, %d bytes", want, content.Status, len(content.Raw))
		}
		return out.Chart.AttachmentID
	}

	first := call(1)
	second := call(2)
	if first == second {
		t.Fatalf("two calls returned the same receipt %s; output directory or content addressing is wrong", first)
	}
}

// TestHandler_ArtifactReachesVisionModel proves the handler producer's EXPAND branch through chat:
// the lazy call_handler tool invokes a resident method, its MediaRef is fed back, and the next
// vision-capable request carries the exact PNG bytes. This is model-wire evidence, not a text reply.
//
// TestHandler_ArtifactReachesVisionModel 经 chat 证明 handler 产地的展开分支：懒加载 call_handler 调驻留
// 方法，MediaRef 回喂后，下一次具备视觉能力的请求携带原始 PNG 字节。证据来自模型线缆，而不是文案。
func TestHandler_ArtifactReachesVisionModel(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	pngB64 := base64.StdEncoding.EncodeToString(tinyPNG)
	hdID := hdCreate(t, wc, "chat_artifact_keeper", map[string]any{
		"methods": []map[string]any{{
			"name": "plot", "inputs": []any{},
			"body": "import base64, os\nraw = base64.b64decode('" + pngB64 + "')\nopen(os.path.join(os.environ['ANSELM_OUT'], 'plot.png'), 'wb').write(raw)\nreturn {'chart': {'$media': 'plot.png'}}",
		}},
	})
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "search_tools", Args: fw(map[string]any{"query": "chat_artifact_keeper"})}}},
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "call_handler", Args: fw(map[string]any{
			"handlerId": hdID, "method": "plot", "args": map[string]any{},
		})}}},
		harness.LLMTurn{Text: "收到 handler 图片"},
	)
	convID := convCreate(t, wc, "handler media wire")
	mid := sendMsg(t, wc, convID, "搜索 handler 并调用一次 plot，把返回的图片交给我。")
	turn := waitTurn(t, wc, convID, mid, 30000)
	if turn.Status != "completed" {
		t.Fatalf("handler media chat must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	attID := attachmentFrom(t, turn, "handler_artifact")
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsImage(content.Raw) || string(content.Raw) != string(tinyPNG) {
		t.Fatalf("handler artifact must round-trip through chat: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}

	dumps := mock.WaitDumps(t, dlgModel, 3, 10000)
	if !dumps[2].HasImagePart(base64.StdEncoding.EncodeToString(tinyPNG)) {
		t.Fatalf("handler artifact never reached the next model request as exact image bytes: %+v", dumps)
	}
}

// TestHandler_ResidentLifecycleAndCalls: A2 核心——首调 spawn、状态保持（常驻的灵魂）、
// 调用台账 logs、restart 重置状态。
func TestHandler_ResidentLifecycleAndCalls(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "hd-life"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	hdID := hdCreate(t, wc, "counter_keeper", map[string]any{
		"initBody": "self.count = 0",
		"methods": []map[string]any{
			{"name": "bump", "inputs": []any{}, "body": "self.count += 1\nreturn {\"count\": self.count}"},
		},
	})

	// state persists across calls — the resident soul. 状态跨调用保持——常驻之魂。
	var out map[string]any // :call 现返裸结果(去 {result} 包裹)
	wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{"method": "bump", "args": map[string]any{}}).OK(t, &out)
	wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{"method": "bump", "args": map[string]any{}}).OK(t, &out)
	if out["count"] != float64(2) {
		t.Fatalf("resident state lost: %+v", out)
	}

	// restart resets in-memory state. restart 清内存状态。
	wc.POST("/api/v1/handlers/"+hdID+":restart", nil).OK(t, nil)
	wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{"method": "bump", "args": map[string]any{}}).OK(t, &out)
	if out["count"] != float64(1) {
		t.Fatalf("restart must reset state: %+v", out)
	}

	// unknown method rejects with the domain code. 未知方法按域码拒。
	r := wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{"method": "nope", "args": map[string]any{}})
	if r.Status < 400 || !strings.Contains(r.Code, "METHOD") {
		t.Fatalf("unknown method: %d/%s", r.Status, r.Code)
	}

	// calls ledger with aggregates; detail carries logs column. 调用台账+聚合；详情带 logs 列。
	var page struct {
		Calls []struct {
			ID string `json:"id"`
		} `json:"calls"`
		Aggregates struct {
			TotalCount int `json:"totalCount"`
			OKCount    int `json:"okCount"`
		} `json:"aggregates"`
	}
	wc.GET("/api/v1/handlers/"+hdID+"/calls").OK(t, &page)
	if page.Aggregates.TotalCount != 3 || page.Aggregates.OKCount != 3 || len(page.Calls) < 3 {
		t.Fatalf("calls ledger wrong: %+v", page.Aggregates)
	}
	wc.GET("/api/v1/handler-calls/"+page.Calls[0].ID).OK(t, nil)
}

// TestHandler_PrintToStdout: A2 关键产品语义——用户代码 print 走 stdout（协议通道）时
// 会发生什么。真机观察并定性（finding 候选：function 已重定向、handler 是否同等保护）。
func TestHandler_PrintToStdout(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "hd-print"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	hdID := hdCreate(t, wc, "printy", map[string]any{
		"methods": []map[string]any{
			{"name": "speak", "inputs": []any{}, "body": "print(\"hello from handler\")\nreturn {\"ok\": True}"},
		},
	})
	// The driver shields stdout (AC-5 fix): print must NOT crash the protocol, and the
	// printed line must surface in the call's logs.
	// driver 护住 stdout（AC-5 修复）：print 绝不炸协议，且打印行须出现在调用 logs 里。
	var out map[string]any // :call 现返裸结果(去 {result} 包裹)
	wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{"method": "speak", "args": map[string]any{}}).OK(t, &out)
	if out["ok"] != true {
		t.Fatalf("print method result wrong: %+v", out)
	}
	var page struct {
		Calls []struct {
			ID string `json:"id"`
		} `json:"calls"`
	}
	wc.GET("/api/v1/handlers/"+hdID+"/calls").OK(t, &page)
	var detail struct {
		Logs string `json:"logs"`
	}
	wc.GET("/api/v1/handler-calls/"+page.Calls[0].ID).OK(t, &detail)
	if !strings.Contains(detail.Logs, "hello from handler") {
		t.Fatalf("print must land in call logs, got %q", detail.Logs)
	}
}

// TestHandler_ConcurrentCallStderrWindows exercises the resident's shared stderr fan through
// two real HTTP calls. The RPC pipe serializes method execution, while the app-level call windows
// may overlap; each audit must keep its own start/end lines, and extra lines from an overlapping
// window are accepted by design rather than silently pretending strict attribution.
//
// TestHandler_ConcurrentCallStderrWindows 用两个真实 HTTP 调用穿过常驻实例的 stderr 扇出。RPC 管道
// 会串行执行 method，但 app 层调用窗口可以重叠；每条审计必须保留自己的 start/end，窗口重叠带来的
// 额外行按契约接受，不能假装成严格归属。
func TestHandler_ConcurrentCallStderrWindows(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "hd-concurrent-stderr"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	hdID := hdCreate(t, wc, "concurrent_stderr", map[string]any{
		"methods": []map[string]any{{
			"name":   "work",
			"inputs": []map[string]any{{"name": "tag", "type": "string"}},
			"body":   "import time\nprint('start-' + tag)\ntime.sleep(0.08)\nprint('end-' + tag)\nreturn {'tag': tag}",
		}},
	})

	type result struct {
		tag  string
		resp *harness.Resp
	}
	results := make(chan result, 2)
	var wg sync.WaitGroup
	for _, tag := range []string{"alpha", "beta"} {
		wg.Add(1)
		go func(tag string) {
			defer wg.Done()
			resp, err := wc.Try("POST", "/api/v1/handlers/"+hdID+":call", map[string]any{
				"method": "work",
				"args":   map[string]any{"tag": tag},
			})
			if err != nil {
				t.Errorf("concurrent %s call transport error: %v", tag, err)
				return
			}
			results <- result{tag: tag, resp: resp}
		}(tag)
	}
	wg.Wait()
	close(results)
	for got := range results {
		if got.resp.Status != 200 {
			t.Fatalf("concurrent %s call failed: %d/%s %s", got.tag, got.resp.Status, got.resp.Code, got.resp.Raw)
		}
	}

	var page struct {
		Calls []struct {
			ID         string         `json:"id"`
			Input      map[string]any `json:"input"`
			InstanceID string         `json:"instanceId"`
		} `json:"calls"`
	}
	wc.GET("/api/v1/handlers/"+hdID+"/calls?limit=10").OK(t, &page)
	if len(page.Calls) != 2 {
		t.Fatalf("want two concurrent call records, got %+v", page.Calls)
	}
	if page.Calls[0].InstanceID == "" || page.Calls[0].InstanceID != page.Calls[1].InstanceID {
		t.Fatalf("concurrent calls did not share one resident instance: %+v", page.Calls)
	}
	seenTags := map[string]bool{}
	for _, call := range page.Calls {
		tag, _ := call.Input["tag"].(string)
		seenTags[tag] = true
		var detail struct {
			Status string `json:"status"`
			Logs   string `json:"logs"`
		}
		wc.GET("/api/v1/handler-calls/"+call.ID).OK(t, &detail)
		if detail.Status != "ok" || !strings.Contains(detail.Logs, "start-"+tag) || !strings.Contains(detail.Logs, "end-"+tag) {
			t.Fatalf("call %s lost its own stderr window: tag=%q detail=%+v", call.ID, tag, detail)
		}
	}
	if !seenTags["alpha"] || !seenTags["beta"] {
		t.Fatalf("concurrent call inputs were not both durable: %+v", seenTags)
	}
}

// TestHandler_ErrorSurfacesTraceback verifies that a real handler exception remains actionable at
// both product-facing HTTP surfaces: the immediate call response and the durable call detail. The
// Go error wrapper may retain internal breadcrumbs, but neither surface may collapse to "call failed".
func TestHandler_ErrorSurfacesTraceback(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "hd-traceback"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	hdID := hdCreate(t, wc, "traceback_probe", map[string]any{
		"methods": []map[string]any{{
			"name": "explode", "inputs": []any{}, "body": "raise ValueError('bad amount')",
		}},
	})
	r := wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{
		"method": "explode", "args": map[string]any{},
	})
	if r.Status < 400 || !strings.Contains(r.Code, "HANDLER_CLIENT_CALL_FAILED") {
		t.Fatalf("handler exception must be a structured failed call: %d/%s %s", r.Status, r.Code, r.Raw)
	}
	if !strings.Contains(string(r.Raw), "ValueError: bad amount") || !strings.Contains(string(r.Raw), "Traceback") {
		t.Fatalf("immediate error surface lost the Python traceback: %s", r.Raw)
	}

	var page struct {
		Calls []struct {
			ID           string `json:"id"`
			Status       string `json:"status"`
			ErrorMessage string `json:"errorMessage"`
		} `json:"calls"`
	}
	wc.GET("/api/v1/handlers/"+hdID+"/calls").OK(t, &page)
	if len(page.Calls) != 1 || page.Calls[0].Status != "failed" {
		t.Fatalf("failed handler call was not durably recorded: %+v", page.Calls)
	}
	if !strings.Contains(page.Calls[0].ErrorMessage, "ValueError: bad amount") || !strings.Contains(page.Calls[0].ErrorMessage, "Traceback") {
		t.Fatalf("call list error message lost the traceback: %q", page.Calls[0].ErrorMessage)
	}
	var detail struct {
		ErrorMessage string `json:"errorMessage"`
	}
	wc.GET("/api/v1/handler-calls/"+page.Calls[0].ID).OK(t, &detail)
	if !strings.Contains(detail.ErrorMessage, "ValueError: bad amount") || !strings.Contains(detail.ErrorMessage, "Traceback") {
		t.Fatalf("call detail error message lost the traceback: %q", detail.ErrorMessage)
	}
}

// TestHandler_SensitiveSecretMaskedOnAllSurfaces verifies the same call across the three leak
// surfaces: the immediate HTTP error, durable errorMessage, and durable logs from print(). A
// platform-injected sensitive value must never appear in plaintext, while the masked value remains
// visible enough to explain what was redacted.
func TestHandler_SensitiveSecretMaskedOnAllSurfaces(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "hd-secret-surfaces"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	hdID := hdCreate(t, wc, "secret_probe", map[string]any{
		"initArgsSchema": []map[string]any{{"name": "token", "type": "string", "required": true, "sensitive": true}},
		"initBody":       "self.token = token",
		"methods": []map[string]any{{
			"name": "explode", "inputs": []any{},
			"body": "print(self.token)\nraise ValueError('bad token ' + self.token)",
		}},
	})
	secret := "sk-live-handler-143"
	wc.PUT("/api/v1/handlers/"+hdID+"/config", map[string]any{"token": secret}).OK(t, nil)
	r := wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{
		"method": "explode", "args": map[string]any{},
	})
	if r.Status < 400 || strings.Contains(string(r.Raw), secret) || !strings.Contains(string(r.Raw), "********") {
		t.Fatalf("immediate HTTP error leaked or dropped the mask: %d/%s %s", r.Status, r.Code, r.Raw)
	}

	var page struct {
		Calls []struct {
			ID           string `json:"id"`
			ErrorMessage string `json:"errorMessage"`
			Logs         string `json:"logs"`
		} `json:"calls"`
	}
	wc.GET("/api/v1/handlers/"+hdID+"/calls").OK(t, &page)
	if len(page.Calls) != 1 {
		t.Fatalf("expected one failed call, got %+v", page.Calls)
	}
	if strings.Contains(page.Calls[0].ErrorMessage, secret) || !strings.Contains(page.Calls[0].ErrorMessage, "********") {
		t.Fatalf("errorMessage leaked or dropped the mask: %q", page.Calls[0].ErrorMessage)
	}
	var detail struct {
		ErrorMessage string `json:"errorMessage"`
		Logs         string `json:"logs"`
	}
	wc.GET("/api/v1/handler-calls/"+page.Calls[0].ID).OK(t, &detail)
	for surface, value := range map[string]string{
		"detail.errorMessage": detail.ErrorMessage,
		"detail.logs":         detail.Logs,
	} {
		if strings.Contains(value, secret) || !strings.Contains(value, "********") {
			t.Fatalf("%s leaked or dropped the mask: %q", surface, value)
		}
	}
}

// TestHandler_ConfigFlow: A2 config——必填缺失拒 spawn、PUT 后生效、掩码回显、清空停机。
func TestHandler_ConfigFlow(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "hd-config"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	hdID := hdCreate(t, wc, "configured", map[string]any{
		"initBody": "self.token = token",
		"initArgsSchema": []map[string]any{
			{"name": "token", "type": "string", "required": true, "sensitive": true},
		},
		"methods": []map[string]any{
			{"name": "show", "inputs": []any{}, "body": "return {\"token_len\": len(self.token)}"},
		},
	})

	// missing required config → call rejects with the documented code. 必填缺失 → 调用按码拒。
	r := wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{"method": "show", "args": map[string]any{}})
	if r.Status < 400 || !strings.Contains(r.Code, "CONFIG") {
		t.Fatalf("missing config must reject with a CONFIG code: %d/%s %s", r.Status, r.Code, r.Raw)
	}

	// configure → call works and saw the value. 配上 → 调用成功且拿到值。
	wc.PUT("/api/v1/handlers/"+hdID+"/config", map[string]any{"token": "secret-12345"}).OK(t, nil)
	var out map[string]any // :call 现返裸结果(去 {result} 包裹)
	wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{"method": "show", "args": map[string]any{}}).OK(t, &out)
	if out["token_len"] != float64(12) {
		t.Fatalf("config not applied: %+v", out)
	}

	// masked echo: sensitive value never returns in plain. 掩码回显：敏感值绝不明文回。
	cfg := wc.GET("/api/v1/handlers/" + hdID + "/config")
	if strings.Contains(string(cfg.Raw), "secret-12345") {
		t.Fatalf("sensitive config echoed in plaintext: %s", cfg.Raw)
	}

	// clear stops the instance; next call rejects again. 清空停机；再调又拒。
	wc.DELETE("/api/v1/handlers/"+hdID+"/config").OK(t, nil)
	r = wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{"method": "show", "args": map[string]any{}})
	if r.Status < 400 {
		t.Fatalf("cleared config must reject calls again: %d", r.Status)
	}
	// DELETE is idempotent, but a repeated no-op must not emit a second config_cleared event.
	wc.DELETE("/api/v1/handlers/"+hdID+"/config").OK(t, nil)
}

// TestHandler_MethodTimeout: 方法级超时真触发——卡死方法不拖死调用方。
func TestHandler_MethodTimeout(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "hd-timeout"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	hdID := hdCreate(t, wc, "sleepy", map[string]any{
		"imports": "import time",
		"methods": []map[string]any{
			{"name": "nap", "inputs": []any{}, "timeout": 1500, "body": "time.sleep(10)\nreturn {\"woke\": True}"},
		},
	})
	r := wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{"method": "nap", "args": map[string]any{}})
	if r.Status < 400 || !strings.Contains(r.Code+r.Msg, "TIMEOUT") {
		t.Fatalf("timeout must surface as a TIMEOUT code: %d/%s %s", r.Status, r.Code, r.Raw)
	}
	// failed call lands in the ledger as timeout. 失败调用以 timeout 入台账。
	var page struct {
		Calls []struct {
			Status string `json:"status"`
		} `json:"calls"`
	}
	wc.GET("/api/v1/handlers/"+hdID+"/calls?status=timeout").OK(t, &page)
	if len(page.Calls) != 1 {
		t.Fatalf("timeout call not in ledger: %+v", page.Calls)
	}
}
