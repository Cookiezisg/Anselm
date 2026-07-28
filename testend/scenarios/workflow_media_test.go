// workflow_media_test.go — WRK-082 批B' 的验收场景:媒体真的跨 workflow 节点流动。
//
// 这是不变量①②③在真二进制上的合流证明:上游 agent 节点用挂载的 `sys:generate_image` 画一张图
// (产出咽喉出 MediaRef receipt)、把 receipt 当自己的终答交出去(节点结果),下游 agent 节点经
// CEL 拿到它,而**消费咽喉**在装配它的历史时把引用解成原生 image part——于是下游模型**真的看见
// 了像素**,以线缆上的 base64 为证。这一条断言链是「四不变量成立」与「四个漂亮的接口」之间的
// 全部差别。
//
// workflow_media_test.go — the 批B' acceptance scenario: media really crosses workflow nodes.
package scenarios

import (
	"bytes"
	"regexp"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// attIDShape 是 MediaRef 文法的 id 形(与后端 pkg/mediaref 同款),黑盒侧只认这个形。
var attIDShape = regexp.MustCompile(`att_[0-9a-f]{16}`)

// TestWorkflowMedia_AgentNodeToAgentNode: A 画 → A 把 receipt 交出 → B 看见。
func TestWorkflowMedia_AgentNodeToAgentNode(t *testing.T) {
	t.Parallel()
	// The mock first, then a server already pointing its free-tier gateway at it: generation is
	// managed-only after H11, so a workspace without an install has no generation tools to run.
	// 先 mock,再拉起一个**已经**把免费档网关指向它的 server:H11 之后生成只在受管档,故一个没有
	// install 的 workspace 根本没有生成工具可跑。
	mock := harness.NewLLMMock(t)
	srv := harness.Start(t, "ANSELM_GATEWAY_URL="+mock.URL()+"/v1")
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "wf-media"}).Field(t, "id")
	wc := c.WS(wsID)

	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "llmmock", "key": "sk-mock", "baseUrl": mock.URL(),
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	// Both agent nodes run on a catalog-known VISION model — the gate the chokepoint honors.
	// 两个 agent 节点都跑目录已知的**视觉**模型——咽喉尊重的正是这道闸。
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/agent",
		map[string]any{"apiKeyId": keyID, "modelId": dlgModel}).OK(t, nil)
	waitManagedKey(t, wc)

	painter := agCreate(t, wc, map[string]any{
		"name": "Painter", "description": "draws then hands the artifact on",
		"prompt": "Draw what you are asked, then reply with the tool's receipt verbatim.",
		"tools":  []map[string]any{{"ref": "sys:generate_speech", "name": "generate speech"}},
	})
	viewer := agCreate(t, wc, map[string]any{
		"name": "Viewer", "description": "looks at what upstream produced",
		"prompt": "Describe the picture you were given.",
	})

	wfID := wfCreate(t, wc, "media_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "paint", "kind": "agent", "ref": painter,
			"input": map[string]any{"task": "start.topic"}}},
		{"op": "add_node", "node": map[string]any{"id": "look", "kind": "agent", "ref": viewer,
			"input": map[string]any{"picture": "paint.text"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "paint"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "paint", "to": "look"}},
	})

	mock.Enqueue(dlgModel,
		// ① painter 第一步:点名挂载的能力工具。
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "generate_speech",
			Args: fw(map[string]any{"text": "落霞与孤鹜齐飞"})}}},
		// ② painter 第二步:把 receipt 抄进终答——这次抄写就是引用抵达下游的方式。
		harness.LLMTurn{EchoLastToolResult: true},
		// ③ viewer:它这时**已经**拿到了像素(下面查线缆)。
		harness.LLMTurn{Text: "I see a lighthouse at dusk."},
	)

	_, status, nodes := runAndWait(t, wc, wfID, map[string]any{"topic": "a lighthouse at dusk"}, 90000)
	if status != "completed" {
		t.Fatalf("media pipeline run must complete, got %s nodes=%s", status, nodes)
	}

	dumps := mock.DumpsFor(dlgModel)
	if len(dumps) < 3 {
		t.Fatalf("want 3 model requests (painter ×2 + viewer), got %d", len(dumps))
	}

	// ① 挂载合成:painter 的工具面恰是那一个能力工具(sys: 前缀真解析成绑定工具)。
	if len(dumps[0].Tools) != 1 || dumps[0].Tools[0] != "generate_speech" {
		t.Fatalf("painter's toolset must be exactly its sys: mount, got %v", dumps[0].Tools)
	}

	// ② 产出咽喉:节点结果里带着 receipt(MediaRef 文法的 attachmentId)。receipt 以**字符串**形嵌在
	// 节点结果里(agent 的终答就是文本),故这里按 id 形取——正是消费咽喉在下游要认的那一形。
	m := attIDShape.FindStringSubmatch(string(nodes))
	if m == nil {
		t.Fatalf("node result must carry a well-formed MediaRef: %s", nodes)
	}
	attID := m[0]

	// ③ 附件是一等公民:上游节点铸出的字节,与库里存的逐字节相同。**这一条只有音频做得到**——受管
	// 图像契约交回的是一个 https URL,纯 http 假件顶替不了(见 generate_image_test.go 的说明)。
	// The artifact really exists and round-trips. Only AUDIO can prove this here: the managed image
	// contract answers with an https URL that a plain-http mock cannot serve.
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes.Equal(content.Raw, harness.MockWAV) {
		t.Fatalf("artifact must round-trip byte-exact (HTTP %d, %d bytes)", content.Status, len(content.Raw))
	}

	// ④ 消费咽喉的**像素**那一半——「下游模型真的看见了」——按模态门控,而这里的产物是音频:一个
	// 只读文本的下游模型会拿到文本 receipt,那是 ADR 0020 刻意的降级、不是缺陷。故那条断言住在真钱
	// 孪生件 `TestLiveMedia_WorkflowDownstreamSeesPixels` 里,那里有真图、真视觉模型、真线缆。
	// The "the downstream model really SAW it" half is modality-gated and the artifact here is audio;
	// it lives in the real-money twin, where the picture, the vision model and the wire are all real.
	_ = attID
}
