// live_voice_test.go — WRK-082 H9 的真钱验收:参考音色**整条链**,登记 → 合成 → 删除,外加「用完即撤」。
//
// **本文件存在,是因为这一条链上的每一个契约都曾经是我编的,而 mock 全程是绿的。** 今天一天里,真 API
// 推翻了两处:`qwen-tts` 那个 model id 在 customization 端点上**根本不存在**,而登记其实是**异步**的
// (DEPLOYING → OK)。两处都由单元测试覆盖着、两处都绿着。一个假件永远同意代码相信的东西。
//
// live_voice_test.go — the real-money acceptance for the cloned-voice chain (H9): enroll →
// synthesize → delete, plus revoke-on-use.
//
// **This file exists because every contract on this chain was once something I invented, while the
// mocks stayed green.** In one day the real API refuted two of them: the `qwen-tts` model id does
// not exist on the customization endpoint at all, and enrollment is ASYNCHRONOUS (DEPLOYING → OK).
// Both were covered by unit tests. Both were green. A fake always agrees with what the code believes.
//
// **为什么必须打生产网关**:`voice-enrollment` 只收一个**公网可取的 URL**——上游自己来拉那段样本
// (真机实测:data: URI 会被拿去跑 ASR 然后 500)。本地起的网关没有公网名字,故本地跑这条链在物理上
// 不可能。这也是 ADR 0012 第 4 条为「将来某个 provider 确需 URL」留的那扇门第一次被推开。
//
// **Why it must hit the DEPLOYED gateway**: `voice-enrollment` accepts only a publicly fetchable
// URL — the upstream comes and gets the sample itself. A gateway on localhost has no public name,
// so running this chain locally is not a configuration problem but a physical impossibility.
package scenarios

import (
	"bytes"
	"encoding/json"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"github.com/sunweilin/anselm/testend/harness"
)

// liveVoiceGateway is where the managed routes actually live. It is a constant rather than an env
// knob because a wrong value here does not fail — it silently tests nothing (a workspace whose
// provision failed simply has no managed key, and every managed tool then reports itself absent,
// which is a legitimate state the code is designed to produce).
//
// liveVoiceGateway 是受管路由**真正**所在之处。写成常量而非环境旋钮,因为这里填错**不会失败**——它会
// 静默地什么也没测(开通失败的 workspace 只是没有受管 key,而每个受管工具随即报告自己不存在,那是代码
// **刻意**会产生的合法状态)。
const liveVoiceGateway = "https://api.anselm.website/v1"

// liveVoice boots a backend whose free-tier gateway is the deployed one, waits for the managed key
// to land. The managed Anselm model drives the tool call too: this lane must exercise the product's
// actual default gateway, not smuggle a provider secret back into the desktop test.
//
// **Both halves are needed and neither is redundant.** Generation is managed-only after H11, so the
// enroll/synthesize routes and the dialogue model must come from the same deployed Anselm service.
//
// liveVoice 拉起一个「免费档网关 = 已部署那台」的后端，等受管 key 与默认 dialogue 一起就绪。
//
// **两半都需要,哪一半都不多余。** H11 之后登记/合成与 dialogue 都应经受管 install；测试不能再
// 依赖已删除的本机 DASHSCOPE 配置来伪造这条产品路径。
func liveVoice(t *testing.T, name string) *harness.Client {
	t.Helper()
	if os.Getenv("EVALS_VOICE") != "1" {
		t.Skip("set EVALS_VOICE=1 to run the real-money managed voice acceptance")
	}

	srv := harness.Start(t, "ANSELM_GATEWAY_URL="+liveVoiceGateway)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": name}).Field(t, "id")
	wc := c.WS(wsID)

	// The managed row arrives ASYNCHRONOUSLY (creating a workspace fires a provision). Waiting for it
	// and for the default is not optional: without either, generation tools are honestly absent and
	// the assertion below would fail for a reason unrelated to voices.
	// 受管行是**异步**到的(建 workspace 触发一次开通)。按名字等它不是可选项:不等,生成工具就诚实地
	// 不存在,而下面每一条断言都会因为一个与音色毫无关系的原因失败。
	harness.Eventually(t, 30000, "the managed free-tier key lands", func() bool {
		var keys []struct {
			Provider string `json:"provider"`
		}
		wc.GET("/api/v1/api-keys").OK(t, &keys)
		for _, k := range keys {
			if k.Provider == "anselm" {
				return true
			}
		}
		return false
	})

	var ws struct {
		DefaultDialogue *struct {
			APIKeyID string `json:"apiKeyId"`
			ModelID  string `json:"modelId"`
		} `json:"defaultDialogue"`
	}
	wc.GET("/api/v1/workspaces/"+wsID).OK(t, &ws)
	if ws.DefaultDialogue == nil || ws.DefaultDialogue.APIKeyID == "" || ws.DefaultDialogue.ModelID == "" {
		t.Fatalf("managed key became visible before the dialogue default was ready: %+v", ws)
	}
	return wc
}

type liveReadResp struct {
	AttachmentID string `json:"attachmentId"`
	MimeType     string `json:"mimeType"`
	SizeBytes    int64  `json:"sizeBytes"`
	Cached       bool   `json:"cached"`
}

func liveRead(t *testing.T, wc *harness.Client, text, voice string) liveReadResp {
	t.Helper()
	body := map[string]any{"text": text}
	if voice != "" {
		body["voice"] = voice
	}
	var out liveReadResp
	wc.POST("/api/v1/read-aloud:read", body).OK(t, &out)
	return out
}

// TestLiveVoice_SpeechInputASR covers the other half of the speech surface: the local sidecar's
// proof-bound WebSocket must reach the deployed Anselm realtime ASR route, forward a bounded PCM
// frame, and relay the gateway's terminal event. It intentionally does not assert model prose: a
// silent frame is enough to prove the authenticated transport, session lifecycle, and finish path
// without pretending that a text transcript is a deterministic visual-style oracle.
func TestLiveVoice_SpeechInputASR(t *testing.T) {
	wc := liveVoice(t, "live-voice-input")
	wsURL := strings.Replace(wc.BaseURL(), "http://", "ws://", 1) + "/api/v1/speech/asr?language=zh"
	headers := http.Header{}
	headers.Set(harness.HeaderWorkspace, wc.WorkspaceID())
	conn, resp, err := websocket.DefaultDialer.Dial(wsURL, headers)
	if err != nil {
		status := 0
		if resp != nil {
			status = resp.StatusCode
			_ = resp.Body.Close()
		}
		t.Fatalf("managed speech input websocket must open: status=%d", status)
	}
	defer func() { _ = conn.Close() }()
	_ = conn.SetReadDeadline(time.Now().Add(120 * time.Second))

	// 100ms of valid PCM16/16k/mono. The route contract is about transport and lifecycle here;
	// using silence avoids paying a second synthesis just to manufacture a spoken fixture.
	if err := conn.WriteMessage(websocket.BinaryMessage, make([]byte, 3200)); err != nil {
		t.Fatalf("write managed ASR PCM frame: %v", err)
	}
	if err := conn.WriteJSON(map[string]string{"type": "finish"}); err != nil {
		t.Fatalf("finish managed ASR session: %v", err)
	}

	eventTypes := map[string]int{}
	for {
		_, payload, err := conn.ReadMessage()
		if err != nil {
			t.Fatalf("read managed ASR event (types=%v): %v", eventTypes, err)
		}
		var event struct {
			Type string `json:"type"`
			Code string `json:"code"`
		}
		if err := json.Unmarshal(payload, &event); err != nil {
			t.Fatalf("managed ASR returned non-JSON event: %v", err)
		}
		eventTypes[event.Type]++
		if event.Type == "error" {
			t.Fatalf("managed ASR returned an error event code=%s types=%v", event.Code, eventTypes)
		}
		if event.Type == "session.finished" {
			return
		}
	}
}

// TestLiveVoice_EnrollSpeakDelete walks the whole chain with real money and asserts the four things
// no mock can reach.
//
// **The sample is one we synthesized ourselves**, and that is deliberate rather than convenient: it
// is a clean single-speaker clip that exists in this workspace's own attachment store, so the
// enrollment exercises the real "an EXISTING attachment becomes a voice" path end to end without a
// fixture whose provenance would itself need explaining.
//
// TestLiveVoice_EnrollSpeakDelete 用真钱走完整条链,断言四件任何 mock 都够不到的事。
//
// **样本是我们自己合成的**,这是刻意、不是图省事:它是一段干净的单说话人片段、就存在这个 workspace
// 自己的附件库里,故登记走的是真正的「一个**已存在**的附件变成一个音色」那条路,而不必引入一份来历
// 本身还需要解释的 fixture。
func TestLiveVoice_EnrollSpeakDelete(t *testing.T) {
	wc := liveVoice(t, "live-voice")

	// ① A real synthesis in a PRESET voice — the reference clip, and simultaneously proof that the
	//    managed speech route works at all before any cloning is involved.
	//    真实合成(预置音色)——参考片段,同时也证明受管语音路由在**引入克隆之前**就是通的。
	const sample = "落霞与孤鹜齐飞,秋水共长天一色。这是一段用来登记音色的参考录音。"
	ref := liveRead(t, wc, sample, "")
	if ref.AttachmentID == "" || ref.SizeBytes < 4_000 || !strings.HasPrefix(ref.MimeType, "audio/") {
		t.Fatalf("the reference clip must be real audio: %+v", ref)
	}

	// ② Enrollment. It is a `dangerous` tool, so it BLOCKS for a human — and that gate is part of
	//    what is being accepted here, not an obstacle to it: a voice is an identity, and the whole
	//    reason this tool blocks is that nothing should mint one behind a person's back.
	//    登记。它是 `dangerous` 工具,故会**为人阻塞**——而那道闸本身就是这里要验收的东西之一、不是
	//    验收路上的障碍:声音是身份,这个工具之所以要挡,正是因为不该有任何东西背着人去铸一个。
	const voiceName = "acceptance-narrator"
	conv := convCreate(t, wc, "enroll")
	mid := sendMsg(t, wc, conv, "请把附件 "+ref.AttachmentID+" 登记成一个名叫 "+voiceName+
		" 的音色。只调用一次工具,成功后直接告诉我结果,不要重复调用。")

	var pending []struct {
		ToolCallID string `json:"toolCallId"`
		Kind       string `json:"kind"`
		Tool       string `json:"tool"`
	}
	harness.Eventually(t, 60000, "enroll_voice asks a human first", func() bool {
		pending = nil
		wc.GET("/api/v1/conversations/"+conv+"/interactions").OK(t, &pending)
		return len(pending) == 1
	})
	if pending[0].Kind != "danger" || pending[0].Tool != "enroll_voice" {
		t.Fatalf("the blocking interaction must be enroll_voice's danger gate: %+v", pending[0])
	}
	wc.POST("/api/v1/conversations/"+conv+"/interactions/"+pending[0].ToolCallID,
		map[string]any{"action": "approve"}).OK(t, nil)
	// 180s, not the usual 20s: enrollment is ASYNCHRONOUS upstream (DEPLOYING → OK) and the gateway
	// polls it to completion before answering. That fact was bought with real money today.
	// 180s 而非通常的 20s:登记在上游是**异步**的(DEPLOYING → OK),网关会轮询到完成才回答。这个事实
	// 是今天用真钱买来的。
	turn := waitTurn(t, wc, conv, mid, 180000)
	if turn.Status != "completed" {
		t.Fatalf("approved enrollment must complete: %s %s", turn.Status, turn.ErrorMessage)
	}
	// A completed TURN is not a successful ENROLLMENT: a tool that failed hands the model an error
	// and the model then wraps up politely, which reads as success from every angle except the one
	// that matters. So the receipt itself is read here — and printed when it disappoints, because a
	// real-money run that fails must not cost a second run just to learn why.
	// 一个**完成的回合**不等于一次**成功的登记**:失败的工具把错误交给模型,模型随后礼貌地收尾,而那
	// 从**除了要紧的那个**以外的每个角度看都像成功。故这里读的是 receipt 本身——并在它不如人意时打印
	// 出来,因为一次失败的真钱运行不该再花一次运行才知道为什么。
	var enrollReceipt string
	for _, b := range turn.Blocks {
		// The tool's identity is in the block's ATTRS, not its content: a receipt says what happened,
		// not who it happened to. 工具身份在块的 **attrs** 里、不在正文里:receipt 说的是发生了什么、
		// 不是它发生在谁身上。
		if b.Type == "tool_result" && b.Attrs["tool"] == "enroll_voice" {
			enrollReceipt = b.Content
		}
	}
	if enrollReceipt == "" {
		t.Fatalf("no enroll_voice tool_result in the turn: %+v", turn.Blocks)
	}

	// ③ The inventory arithmetic — the number a refusal will later be explained by.
	//    库存算术——日后一次拒绝将由这个数字来解释。
	type inventory struct {
		Items []struct {
			ID         string `json:"id"`
			Name       string `json:"name"`
			UpstreamID string `json:"upstreamId"`
		} `json:"items"`
		Capacity  int `json:"capacity"`
		Remaining int `json:"remaining"`
	}
	var inv inventory
	wc.GET("/api/v1/voices").OK(t, &inv)
	if len(inv.Items) != 1 || inv.Items[0].Name != voiceName {
		t.Fatalf("exactly one enrolled voice named %q expected: %+v\nenroll receipt was: %s",
			voiceName, inv, enrollReceipt)
	}
	if inv.Capacity != 2 || inv.Remaining != 1 {
		t.Fatalf("inventory arithmetic wrong: %+v", inv)
	}
	// The upstream id is what synthesis addresses. Losing it strands a paid registration nothing can
	// reach. 上游 id 是合成时寻址用的东西。丢了它,一个**付过费的**登记就搁浅在那里,再没有东西够得着。
	if inv.Items[0].UpstreamID == "" {
		t.Fatal("the enrolled row carries no upstream id — the paid registration is unreachable")
	}

	// ④ Speaking IN it. Different bytes from the preset-voice clip is the only machine-checkable
	//    evidence that the clone was actually used: a `voice` parameter that was silently ignored
	//    would return audio that plays perfectly and is simply the wrong person.
	//    **用它说话**。与预置音色那段字节不同,是「克隆确实被用上了」唯一机器可判的证据:一个被静默
	//    忽略的 `voice` 参数会返回一段**播得好好的、只是换了个人**的音频。
	cloned := liveRead(t, wc, sample, voiceName)
	if cloned.AttachmentID == "" || cloned.SizeBytes < 4_000 {
		t.Fatalf("synthesis in the cloned voice must be real audio: %+v", cloned)
	}
	if cloned.AttachmentID == ref.AttachmentID {
		t.Fatal("same text in a DIFFERENT voice must not hit the cache — the voice is part of the identity of a synthesis")
	}
	refBytes := wc.DoRaw("GET", "/api/v1/attachments/"+ref.AttachmentID+"/content", "", nil)
	clonedBytes := wc.DoRaw("GET", "/api/v1/attachments/"+cloned.AttachmentID+"/content", "", nil)
	if refBytes.Status != 200 || clonedBytes.Status != 200 {
		t.Fatalf("both clips must round-trip: %d / %d", refBytes.Status, clonedBytes.Status)
	}
	if bytes.Equal(refBytes.Raw, clonedBytes.Raw) {
		t.Fatal("the cloned voice produced byte-identical audio — the voice parameter did not reach the model")
	}

	// ⑤ 用完即撤. Deletion removes the UPSTREAM registration first and the row only after that
	//    succeeded, so a 204 here means the paid state on someone else's servers is really gone —
	//    which is the whole reason this acceptance ends with a delete instead of leaving a voice
	//    behind for the next run to trip over.
	//    删除**先删上游登记**、成功之后才删行,故这里的 204 意味着别人服务器上那份付过费的状态**真的**
	//    没了——这也正是本验收以删除收尾、而不是留一个音色给下一轮绊倒的全部理由。
	del := wc.DoRaw("DELETE", "/api/v1/voices/"+inv.Items[0].ID, "", nil)
	if del.Status != 204 {
		t.Fatalf("delete want 204 got %d: %s", del.Status, del.Raw)
	}
	var after inventory
	wc.GET("/api/v1/voices").OK(t, &after)
	if len(after.Items) != 0 || after.Remaining != 2 {
		t.Fatalf("deletion must return the slot: %+v", after)
	}
}
