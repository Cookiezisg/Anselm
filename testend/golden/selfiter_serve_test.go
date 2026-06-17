// selfiter_serve_test.go is the multi-turn bring-up for the iteration loop (docs/working/iteration).
// Two distinct brains: the AGENT UNDER TEST runs on deepseek (the product's model — it must be
// configured or the agent can't think/call tools/reply); the USER is the orchestrating Claude, who
// curls each turn in BY HAND (6-9 turns) and composes the next from what the agent just did — there
// is NO deepseek user-simulator. A multi-turn conversation must persist across those hand-driven
// turns, so this test boots a deepseek-configured backend and HOLDS it up (the ephemeral per-test
// server would die between turns) — Claude curls against /tmp/anselm_selfiter/serve.json until
// /tmp/anselm_selfiter/serve.stop appears (touch to release) or ~50min. EVALS=1, run in background.
//
// selfiter_serve_test.go 是迭代 loop 的多轮 bring-up。两个不同的"脑子"：**被测 agent** 跑在 deepseek
// 上（产品的模型，不配它 agent 就不能思考/调工具/回话）；**用户是编排的 Claude**，亲手 curl 每一轮
// （6-9 轮）、看 agent 刚干了啥再写下一句——**没有 deepseek 用户模拟器**。多轮对话要跨这些手驱动的轮次
// 持续存在，故本测试拉起一个配好 deepseek 的后端并 HOLD 住（一次性 per-test server 会在轮次间死掉），
// Claude 经 /tmp/anselm_selfiter/serve.json 对它 curl，直到出现 serve.stop（touch 释放）或 ~50min。
package golden

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

func TestSelfIterServe(t *testing.T) {
	baseURL, model, key := realModel(t)
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "selfiter-serve", "language": "en"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "deepseek", "displayName": "deepseek", "key": key, "baseUrl": baseURL,
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	for _, sc := range []string{"dialogue", "utility", "agent"} {
		wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/"+sc,
			map[string]any{"apiKeyId": keyID, "modelId": model}).OK(t, nil)
	}

	out := trajOut(t)
	stop := filepath.Join(out, "serve.stop")
	_ = os.Remove(stop)
	info, _ := json.MarshalIndent(map[string]any{
		"baseURL": srv.BaseURL, "workspaceId": wsID, "model": model,
	}, "", "  ")
	_ = os.WriteFile(filepath.Join(out, "serve.json"), info, 0o644)
	t.Logf("[selfiter-serve] UP base=%s ws=%s model=%s — drive via curl; touch %s to stop", srv.BaseURL, wsID, model, stop)

	deadline := time.Now().Add(50 * time.Minute)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(stop); err == nil {
			t.Log("[selfiter-serve] stop sentinel seen — releasing")
			return
		}
		time.Sleep(time.Second)
	}
}
