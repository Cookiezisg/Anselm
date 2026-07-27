// live_media_test.go — WRK-082 H7: the REAL-MONEY acceptance, on the real binary, against a real
// provider, with the wire kept.
//
// Every other media scenario in this package runs against llmmock — and a fake always agrees with
// whatever the code believes. These four spend actual money at a real model and a real generation
// API, and then assert on the bytes that came back and on the requests that went out. They are
// gated behind EVALS_MEDIA=1 and never run in `make verify` (T5: real-model金标 stays out of the
// gate), exactly like `make -C backend evals`.
//
// **Why a recording proxy rather than just calling the real API.** 终点验收 §0.2 ② requires the
// downstream model to REALLY SEE what upstream produced, and says in as many words: 不采信模型自述.
// Against a real model the only reachable evidence used to be its own reply — and "I see a
// lighthouse" is precisely what a model says when it was handed a sentence instead of pixels. The
// proxy keeps the money and the model real while putting the wire back on the record.
//
// live_media_test.go —— H7 **真钱验收**:真二进制、真供应商、线缆留底。
//
// 本包里其余每个媒体场景都跑在 llmmock 上——而假件总是同意代码所相信的一切。这四个在真模型与真生成 API
// 上花真钱,然后对**回来的字节**与**出去的请求**下断言。由 EVALS_MEDIA=1 门控、绝不进 `make verify`
// (T5:真模型金标不入门禁),与 `make -C backend evals` 同一档。
//
// **为什么要录制代理、而不是直接调真 API**:终点验收 ② 要求下游模型**真的看见**上游的产出,并明写
// **不采信模型自述**。对着真模型,此前唯一能拿到的证据就是它自己的回答——而「我看见一座灯塔」正是一个
// **收到一句话而非像素**的模型会说的话。代理让钱和模型保持真实,同时把线缆放回案卷。
package scenarios

import (
	"encoding/base64"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

// liveModel is the ONE model that satisfies both halves of this acceptance: it calls tools (so the
// generation tools can be exercised at all) AND takes image input (so "the model really saw it" is
// a question the chokepoint will even attempt — it gates on the resolved model's modalities).
// A text-only model would make every media assertion vacuously pass by never being offered pixels.
//
// liveModel 是唯一同时满足本验收**三**条的模型:它**会调工具**(否则生成工具根本跑不起来)、**吃图像
// 输入**(否则「模型真的看见了」这个问题咽喉根本不会去尝试——它按解析模型的模态门控)、且**调完会收尾**。
// 一个纯文本模型会让每条媒体断言**因为从未被喂过像素而空洞地通过**。
//
// **第三条是花钱买来的。** 本文件最初用 `qwen3-vl-plus`:它满足前两条,却在拿到 `generate_image` 的
// receipt 之后**必定再调一次**,一路撞满 10 步预算——一个节点烧掉十张真图。用一次 chat 调用重放完全相同的
// 历史,零图片成本地复现了它,再跑七组对照排除了我们这侧的每一个嫌疑:补上 system prompt 里那处黏连的句号、
// 在指令里明写「工具已成功、不要重调」、给 receipt 加人话前缀、去掉 `Input data` 代码块——**四组全都照常
// 重调**;而**换模型**立刻就好(`qwen-vl-plus` / `qwen3.7-max` / `qwen3-vl-flash` 都正常收尾,`qwen-vl-max`
// 同病)。所以那是模型的行为,不是我们的装配。
//
// **留下的产品事实**:一条不走运的模型选择**能**把一个花钱的生成工具循环到步数预算耗尽,而系统里没有任何
// 逐运行的支出上限拦它——见 H10(支出可见性)。挑 `qwen3-vl-flash` 而非它的原因是后者不在能力目录里,
// 咽喉因此不敢给它喂像素,整条断言会因为**错误的理由**通过。
const liveModel = "qwen3-vl-plus"

// livePainterModel is what the workflow's UPSTREAM agent runs on, and it is a different model on
// purpose. The two roles need different things and no single available model does both: the painter
// must CALL a tool and then STOP, the viewer must SEE an image. `qwen3-vl-plus` sees but will not
// stop; `qwen-vl-plus` stops but refuses to call the tool at all ("抱歉，我无法直接生成图像");
// `qwen-vl-max` loops like qwen3-vl-plus. `qwen3.7-max` calls and stops, and the painter never needs
// vision — ADR 0017 hands the generating model a receipt, never its own pixels.
//
// livePainterModel 是 workflow **上游** agent 跑的模型,而且**故意**与下游不同。两个角色要的东西不一样,
// 且没有任何一个可用模型两样都行:画的那个必须**会调工具并且会停**,看的那个必须**看得见图**。
// `qwen3-vl-plus` 看得见但停不下来;`qwen-vl-plus` 停得下来却根本不肯调工具(「抱歉,我无法直接生成
// 图像」);`qwen-vl-max` 与 qwen3-vl-plus 同病。`qwen3.7-max` 会调也会停,而画的那个**根本不需要视觉**
// ——ADR 0017 只把 receipt 交给生成的模型,绝不把它自己的像素还给它。
const livePainterModel = "qwen3.7-max"

// dashScopeGenPath is the one native path every DashScope generation dialect posts to (image and
// speech alike). Counting calls to it is how a cache proves it did not spend.
//
// dashScopeGenPath 是 DashScope 各生成方言(图与语音同)共用的那条原生路径。数它的调用次数,正是缓存
// 证明自己没花钱的方式。
const dashScopeGenPath = "/multimodal-generation/generation"

// liveQwen boots the real backend behind a recording proxy in front of the real DashScope.
//
// liveQwen 在真 DashScope 前面的录制代理背后拉起真后端。
func liveQwen(t *testing.T, name string) (wc *harness.Client, rec *harness.Recorder, keyID string) {
	t.Helper()
	if os.Getenv("EVALS_MEDIA") != "1" {
		t.Skip("set EVALS_MEDIA=1 (with DASHSCOPE_API_KEY) to run the real-money media acceptance")
	}
	key := os.Getenv("DASHSCOPE_API_KEY")
	if key == "" {
		// Fatal, not Skip. Asking for the real-money run and silently getting nothing is the exact
		// failure mode this whole file exists to end.
		// **Fatal 而非 Skip**。要了真钱验收却静默地什么也没跑,正是本文件存在所要终结的那种失败。
		t.Fatal("EVALS_MEDIA=1 but DASHSCOPE_API_KEY is empty — a skipped real-money run is a silent pass")
	}
	base := os.Getenv("ANSELM_DASHSCOPE_BASE")
	if base == "" {
		base = "https://dashscope-intl.aliyuncs.com"
	}

	srv := harness.Start(t)
	rec = harness.NewRecorder(t, base)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": name}).Field(t, "id")
	wc = c.WS(wsID)

	// The credential base points at the PROXY. Every dialect follows from it: chat posts under
	// /compatible-mode/v1, and the generation router derives the native origin by stripping that
	// suffix — so image, speech and video land on the same proxy without a second seam.
	// 凭证 base 指向**代理**。其余方言随之而定:聊天走 /compatible-mode/v1,而生成路由**剥掉该后缀**
	// 推出原生 origin——于是图、语音、视频全落在同一个代理上,不需要第二条缝。
	keyID = wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "qwen", "displayName": "live-dashscope", "key": key,
		"baseUrl": rec.URL() + "/compatible-mode/v1",
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": liveModel}).OK(t, nil)
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/agent",
		map[string]any{"apiKeyId": keyID, "modelId": liveModel}).OK(t, nil)
	return wc, rec, keyID
}

// attachmentFrom pulls the single attachment id a turn's tool_result minted.
//
// attachmentFrom 取出一个回合的 tool_result 铸出的那个附件 id。
func attachmentFrom(t *testing.T, turn chatMsg, tool string) string {
	t.Helper()
	for _, b := range turn.Blocks {
		if b.Type == "tool_result" && strings.Contains(b.Content, `"source":"`+tool+`"`) {
			if m := attIDShape.FindString(b.Content); m != "" {
				return m
			}
		}
	}
	t.Fatalf("no %s receipt with an attachment id in the turn's blocks: %+v", tool, turn.Blocks)
	return ""
}

// TestLiveMedia_ChatImage is 终点验收 ①'s machine-checkable half: a real model, asked in Chinese to
// draw, really calls the tool, a real image comes back, and it lands as a first-class attachment
// whose bytes round-trip.
//
// It also proves ADR 0017 with real money, which no fake could: the generation family returns a
// RECEIPT ONLY — the model that wrote the prompt does not get the pixels back. Both halves are
// asserted, because "the receipt is there" is satisfied by an implementation that ALSO ships the
// bytes, and that implementation is the one that killed a whole turn on a 3.2MB video after paying
// for it.
//
// TestLiveMedia_ChatImage 是终点验收 ① 里机器可判的那半:真模型、被用中文要求画画、**真的**调了工具、
// 回来一张真图、落成一等附件且字节往返一致。
//
// 它还用真钱证明了 ADR 0017——这是假件做不到的:生成族**只回 receipt 不回字节**,写下那条 prompt 的模型
// 拿不回像素。**两半都断言**,因为「receipt 在」也能被一个**同时把字节也发回去**的实现满足,而正是那个
// 实现在**已付费之后**用一段 3.2MB 的视频打死了一整轮。
func TestLiveMedia_ChatImage(t *testing.T) {
	t.Parallel()
	wc, rec, _ := liveQwen(t, "live-image")

	convID := convCreate(t, wc, "真钱画图")
	mid := sendMsg(t, wc, convID, "画一座黄昏的红色灯塔,然后用一句话说说你画了什么。")
	turn := waitTurn(t, wc, convID, mid, 180000)
	if turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	attID := attachmentFrom(t, turn, "generate_image")
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || len(content.Raw) < 20_000 {
		t.Fatalf("generated image must round-trip as real bytes: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
	// A real decoder's output, not an error page that happened to be persisted.
	// 真解码器的产物,而非一张碰巧被存下来的错误页。
	if !bytes2IsImage(content.Raw) {
		t.Fatalf("artifact is not a real image (first bytes: % x)", content.Raw[:min(12, len(content.Raw))])
	}

	dumps := rec.DumpsFor(liveModel)
	if len(dumps) < 2 {
		t.Fatalf("want at least 2 model requests (tool call + answer), got %d", len(dumps))
	}
	if len(dumps[0].Tools) == 0 || !containsStr(dumps[0].Tools, "generate_image") {
		t.Fatalf("generate_image was never offered to the model: %v", dumps[0].Tools)
	}
	last := dumps[len(dumps)-1]
	if !strings.Contains(string(last.Raw), attID) {
		t.Fatalf("the model's next view must carry the receipt %s", attID)
	}
	if strings.Contains(string(last.Raw), base64.StdEncoding.EncodeToString(content.Raw)) {
		t.Fatal("ADR 0017 violated: the generating model was fed its own pixels back")
	}
}

// TestLiveMedia_WorkflowDownstreamSeesPixels is 终点验收 ②, on real money, with the wire as proof.
// Painter agent draws for real; viewer agent — a SEPARATE model request that never wrote the prompt
// — must receive a native image part carrying those exact bytes. ADR 0017 splits precisely here:
// the generating turn gets a receipt, the downstream agent gets pixels.
//
// TestLiveMedia_WorkflowDownstreamSeesPixels 是终点验收 ②,真钱,以线缆为证。painter 真的画;
// viewer——**另一个**模型请求、它从没写过那条 prompt——必须收到带着**那些字节**的原生 image part。
// ADR 0017 恰好在此处分岔:生成的那一轮拿 receipt,下游 agent 拿像素。
func TestLiveMedia_WorkflowDownstreamSeesPixels(t *testing.T) {
	t.Parallel()
	wc, rec, keyID := liveQwen(t, "live-wf")

	painter := agCreate(t, wc, map[string]any{
		"name": "Painter", "description": "draws, then hands the artifact on",
		"prompt": "把被要求的东西画出来,然后把工具返回的 receipt 原样写进你的最终回答。",
		"tools":  []map[string]any{{"ref": "sys:generate_image", "name": "generate image"}},
		// Pinned to a model that calls the tool and then STOPS — see livePainterModel. This is not
		// tuning: the default model loops the paid tool to the step budget, which cost ten real
		// images before it was understood.
		// 钉在一个**会调工具、然后会停**的模型上——见 livePainterModel。这不是调参:默认模型会把那个
		// **花钱的**工具循环到步数预算耗尽,弄明白之前已经烧掉十张真图。
		"modelOverride": map[string]any{"apiKeyId": keyID, "modelId": livePainterModel},
	})
	viewer := agCreate(t, wc, map[string]any{
		"name": "Viewer", "description": "looks at what upstream produced",
		"prompt": "用一句话描述你收到的那张图。",
	})
	wfID := wfCreate(t, wc, "live_media_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "paint", "kind": "agent", "ref": painter,
			"input": map[string]any{"task": "start.topic"}}},
		{"op": "add_node", "node": map[string]any{"id": "look", "kind": "agent", "ref": viewer,
			"input": map[string]any{"picture": "paint.text"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "paint"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "paint", "to": "look"}},
	})

	_, status, nodes := runAndWait(t, wc, wfID, map[string]any{"topic": "一座黄昏的红色灯塔"}, 300000)
	if status != "completed" {
		traceModel(t, rec)
		t.Fatalf("live media pipeline must complete, got %s nodes=%s", status, nodes)
	}
	attID := attIDShape.FindString(string(nodes))
	if attID == "" {
		t.Fatalf("node results carry no MediaRef — the receipt never crossed the node boundary: %s", nodes)
	}
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsImage(content.Raw) {
		t.Fatalf("artifact must be a real image (HTTP %d, %d bytes)", content.Status, len(content.Raw))
	}

	// The requirement, verbatim: the downstream model got a NATIVE image part carrying THESE bytes.
	// 要求原文:下游模型拿到了带着**这些字节**的**原生** image part。
	b64 := base64.StdEncoding.EncodeToString(content.Raw)
	var seen bool
	for _, d := range rec.DumpsFor(liveModel) {
		if d.HasImagePart(b64) {
			seen = true
			break
		}
	}
	if !seen {
		t.Fatal("no model request carried the generated pixels — downstream 'saw' the image only in its own words")
	}
}

// TestLiveMedia_SpeechAndCache is 终点验收 ④ with real money AND the money assertion. Synthesis is
// real; the repeat listen must not reach the provider at all. That last fact is invisible in the
// response (both listens return identical bytes) — it exists only as a call that never happened,
// which is exactly what the recorder can count and an artifact assertion cannot.
//
// TestLiveMedia_SpeechAndCache 是终点验收 ④,真钱 **加上**那条关于钱的断言。合成是真的;**重听必须
// 完全不碰供应商**。最后这个事实在响应里看不见(两次重听返回一模一样的字节)——它只作为**一次没有发生的
// 调用**存在,而那正是录制器数得出、产物断言数不出的东西。
func TestLiveMedia_SpeechAndCache(t *testing.T) {
	t.Parallel()
	wc, rec, _ := liveQwen(t, "live-speech")

	type readResp struct {
		AttachmentID string `json:"attachmentId"`
		MimeType     string `json:"mimeType"`
		SizeBytes    int64  `json:"sizeBytes"`
		Cached       bool   `json:"cached"`
	}
	read := func(text string) readResp {
		t.Helper()
		var out readResp
		wc.POST("/api/v1/read-aloud:read", map[string]any{"text": text}).OK(t, &out)
		return out
	}

	first := read("落霞与孤鹜齐飞,秋水共长天一色。")
	if first.Cached || first.AttachmentID == "" || first.SizeBytes < 4_000 {
		t.Fatalf("first read must be a real synthesis with real audio: %+v", first)
	}
	if n := rec.CallsTo(dashScopeGenPath); n != 1 {
		t.Fatalf("upstream generation calls after the first read = %d, want 1", n)
	}

	again := read("落霞与孤鹜齐飞,秋水共长天一色。")
	if !again.Cached || again.AttachmentID != first.AttachmentID {
		t.Fatalf("repeat listen must serve the cached artifact: %+v (first %s)", again, first.AttachmentID)
	}
	if n := rec.CallsTo(dashScopeGenPath); n != 1 {
		t.Fatalf("upstream calls after a REPEAT listen = %d, want still 1 — the cache did not prevent the spend", n)
	}

	other := read("孤帆远影碧空尽,唯见长江天际流。")
	if other.Cached || other.AttachmentID == first.AttachmentID {
		t.Fatalf("different text must be a different artifact: %+v", other)
	}
	if n := rec.CallsTo(dashScopeGenPath); n != 2 {
		t.Fatalf("upstream calls after new text = %d, want 2", n)
	}

	// Zero tokens: read-aloud never touches the chat model, on real money as on the fake.
	// 零 token:朗读一次都不碰聊天模型——真钱上与假件上同样成立。
	if d := rec.DumpsFor(liveModel); len(d) != 0 {
		t.Fatalf("read-aloud made %d chat requests — it must cost no tokens at all", len(d))
	}

	content := wc.DoRaw("GET", "/api/v1/attachments/"+first.AttachmentID+"/content", "", nil)
	if content.Status != 200 || int64(len(content.Raw)) != first.SizeBytes {
		t.Fatalf("audio must round-trip byte-exact: HTTP %d, %d bytes vs reported %d",
			content.Status, len(content.Raw), first.SizeBytes)
	}
}

// TestLiveMedia_VideoDirect is 终点验收 ⑤ on the DIRECT-CONNECT side. The managed half was proven
// against the deployed gateway (H3); this walks the other dialect — submit / poll / fetch — with a
// real key, and ends with a real MP4 in the attachment store.
//
// The three-verb shape is asserted on the wire, not inferred from the artifact: exactly one submit,
// at least one poll. A single-request implementation that happened to work would look identical
// from the artifact's side, and would break the moment a generation took longer than one timeout.
//
// TestLiveMedia_VideoDirect 是终点验收 ⑤ 的**直连**侧。受管那半已在部署好的网关上证过(H3);这条走
// 另一种方言——提交/轮询/取回——用真 key,最后附件库里躺着一段真 MP4。
//
// 三动词形态在**线缆上**断言、不从产物**推断**:恰好一次提交、至少一次轮询。一个碰巧能用的单请求实现,
// 从产物那侧看**一模一样**,并会在生成时间超过一次超时的那一刻碎掉。
func TestLiveMedia_VideoDirect(t *testing.T) {
	t.Parallel()
	wc, rec, _ := liveQwen(t, "live-video")

	convID := convCreate(t, wc, "真钱出片")
	mid := sendMsg(t, wc, convID, "生成一段 5 秒的视频:黄昏的海面上,一座红色灯塔的光束缓缓扫过。生成完告诉我一句话就行。")
	// 25 minutes, and that is not padding. A 720P clip on the real queue did not finish inside 15,
	// and the tool correctly kept polling — DashScope offers no resolution below 720P for wan2.7,
	// so there is no cheaper/faster shape to ask for.
	// 25 分钟,而且这不是留富余。真队列上一段 720P 片子 15 分钟没跑完,而工具**正确地**继续轮询——
	// wan2.7 在 DashScope 上没有低于 720P 的档,故没有更便宜更快的形状可要。
	// **The danger gate really fires here, and that is the point.** H5.6 put cost into the danger
	// vocabulary precisely so a call that spends real money at a rate worth asking about reads as
	// `dangerous` — and a real model, told to generate a video, self-reports exactly that. The loop
	// then BLOCKS on a human decision. A test that never decides sits in `streaming` forever, which
	// is what the first three runs of this scenario did: 25 minutes with a single chat request on
	// the wire and no video submit at all, while the provider itself finishes the same job in 122
	// seconds (measured directly). The turn was not hung — it was waiting for a person.
	//
	// So this approves, like a user clicking through, and ASSERTS the gate appeared. Auto-approving
	// silently would throw away the strongest evidence H5.6 works on a real paid call.
	//
	// **人闸在这里真的响了,而这正是要点。** H5.6 把成本放进 danger 词表,正是为了让一次「以用户会想被
	// 问一句的费率花钱」的调用读作 `dangerous`——而一个真模型被要求生成视频时,自报的就是它。循环随即
	// **阻塞**等人决定。一个从不决定的测试会永远停在 `streaming`,这正是本场景前三次跑的样子:25 分钟、
	// 线缆上只有一次 chat 请求、视频提交一次也没发生,而供应商自己做完同一件事只要 122 秒(直接测过)。
	// **那一轮没有卡死——它在等人。**
	//
	// 所以这里像用户点确认一样批准,并**断言闸出现过**。静默自动批准会扔掉「H5.6 在一次真花钱的调用上
	// 确实有效」这个最强的证据。
	gateFired := make(chan string, 4)
	stop, approverDone := make(chan struct{}), make(chan struct{})
	// The approver MUST be joined before the test returns. A poller left running past the body hits
	// the harness's torn-down server, and the client's connection error is a t.Fatalf from a
	// non-test goroutine — which failed this scenario once while its actual assertions had passed.
	// 批准协程**必须**在测试返回前被 join。跑过主体的轮询会撞上已拆除的 server,而 client 的连接错误是
	// 从非测试 goroutine 发出的 t.Fatalf——它曾在**断言本身已经通过**的情况下把本场景判失败一次。
	defer func() { close(stop); <-approverDone }()
	go func() {
		defer close(approverDone)
		for {
			var pending []struct {
				ToolCallID string `json:"toolCallId"`
				Kind       string `json:"kind"`
				Tool       string `json:"tool"`
			}
			wc.GET("/api/v1/conversations/"+convID+"/interactions").OK(t, &pending)
			for _, p := range pending {
				select {
				case gateFired <- p.Kind + ":" + p.Tool:
				default:
				}
				wc.POST("/api/v1/conversations/"+convID+"/interactions/"+p.ToolCallID,
					map[string]any{"action": "approve"})
			}
			select {
			case <-stop:
				return
			case <-time.After(time.Second):
			}
		}
	}()

	// Poll WITHOUT the fatal-on-timeout helper: when a long tool hangs, the only useful thing a
	// test can do is show what the turn and the upstream actually did, and waitTurn's Fatalf ends
	// the test before any of that can be printed.
	// **不**用超时即 Fatal 的那个 helper:一个长工具卡住时,测试唯一有用的动作是把「这一轮和上游到底
	// 做了什么」摊出来,而 waitTurn 的 Fatalf 会在那之前就结束测试。
	var turn chatMsg
	deadline := time.Now().Add(8 * time.Minute)
	for time.Now().Before(deadline) {
		for _, m := range listMsgs(t, wc, convID) {
			if m.ID == mid {
				turn = m
			}
		}
		if turn.Status != "" && turn.Status != "pending" && turn.Status != "streaming" {
			break
		}
		time.Sleep(2 * time.Second)
	}
	if turn.Status != "completed" {
		traceModel(t, rec)
		for _, b := range turn.Blocks {
			body := b.Content
			if len(body) > 300 {
				body = body[:300] + "…"
			}
			t.Logf("block %-12s %s", b.Type, body)
		}
		for _, c := range rec.Calls() {
			t.Logf("upstream %s %s", c.Method, c.Path)
		}
		t.Fatalf("turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	select {
	case what := <-gateFired:
		if what != "danger:generate_video" {
			t.Fatalf("the interaction that blocked the turn was %q, want danger:generate_video", what)
		}
	default:
		t.Fatal("no danger gate fired for a real paid video generation — H5.6's cost-aware danger vocabulary did not reach the wire")
	}

	attID := attachmentFrom(t, turn, "generate_video")
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || len(content.Raw) < 200_000 {
		t.Fatalf("generated video must round-trip as real bytes: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
	if !bytes2IsMP4(content.Raw) {
		t.Fatalf("artifact is not an MP4 (first bytes: % x)", content.Raw[:min(16, len(content.Raw))])
	}

	if n := rec.CallsTo("/video-synthesis"); n != 1 {
		t.Fatalf("submits = %d, want exactly 1 — video is paid for at submit", n)
	}
	if n := rec.CallsTo("/api/v1/tasks/"); n < 1 {
		t.Fatalf("polls = %d, want at least 1 — the async shape was not walked", n)
	}
}

// bytes2IsImage / bytes2IsMP4 sniff the container so an error page persisted as an "artifact" fails
// loudly instead of passing a size check.
//
// bytes2IsImage / bytes2IsMP4 嗅探容器,使一张被当成「产物」存下来的错误页**大声失败**,而不是通过一个
// 大小检查。
func bytes2IsImage(b []byte) bool {
	switch {
	case len(b) > 8 && string(b[1:4]) == "PNG":
		return true
	case len(b) > 3 && b[0] == 0xFF && b[1] == 0xD8: // JPEG
		return true
	case len(b) > 12 && string(b[8:12]) == "WEBP":
		return true
	}
	return false
}

func bytes2IsMP4(b []byte) bool {
	return len(b) > 12 && string(b[4:8]) == "ftyp"
}

func containsStr(xs []string, want string) bool {
	for _, x := range xs {
		if x == want {
			return true
		}
	}
	return false
}

// traceModel prints what the model actually did, turn by turn. A real-model failure that only says
// "the run failed" is unusable: the question is always WHICH message made it do that, and against a
// live provider there is no second chance to look — the next run is a different conversation and
// another bill.
//
// traceModel 逐轮打印模型**到底做了什么**。一个只说「跑失败了」的真模型失败是没法用的:要问的永远是
// **哪条消息**让它这么做,而对着真供应商没有第二次机会去看——下一次运行是另一段对话、另一笔账。
func traceModel(t *testing.T, rec *harness.Recorder) {
	t.Helper()
	for i, d := range rec.Dumps() {
		sys := d.System
		if len(sys) > 400 {
			sys = sys[:400] + "…"
		}
		t.Logf("── request %d (model=%s, tools=%v)\n   system    %s", i, d.Model, d.Tools, sys)
		for _, m := range d.Messages {
			body := m.Content
			if len(body) > 240 {
				body = body[:240] + "…"
			}
			t.Logf("   %-9s %s %s", m.Role, strings.Join(m.ToolNames, ","), body)
		}
	}
}

// TestLiveMedia_DocumentImageInjected is 终点验收 ⑥ on real money: an image the model generated,
// embedded in a document it wrote, and then SEEN by a later conversation that @-mentions that
// document.
//
// This is the THIRD consumption entry and the only one where the media arrives as markdown inside a
// system prompt — a place that has no content parts at all. Without the expansion the model receives
// the literal string `![…](anselm://media/att_…)` and never a pixel, while answering fluently enough
// that nobody notices. Hence the assertion is on the wire, never on the answer.
//
// TestLiveMedia_DocumentImageInjected 是终点验收 ⑥ 的真钱版:模型生成的一张图,嵌进它自己写的文档,
// 然后被后来一段 @ 了该文档的对话**真的看见**。
//
// 这是**第三个**消费入口,也是唯一一个媒体以 markdown 形式抵达 **system prompt** 的入口——而那里根本
// 没有 content part。少了展开,模型收到的是字面字符串 `![…](anselm://media/att_…)`、一个像素也没有,
// 却仍能答得很流畅、以至于没人会发现。故断言只看线缆、绝不看回答。
func TestLiveMedia_DocumentImageInjected(t *testing.T) {
	t.Parallel()
	wc, rec, _ := liveQwen(t, "live-doc")

	// Turn 1: generate a real image and put it in a document, both by the model's own tool calls.
	// 第一轮:模型自己调工具生成真图、并把它放进一份文档。
	convID := convCreate(t, wc, "画完存进文档")
	mid := sendMsg(t, wc, convID,
		"先画一座黄昏的红色灯塔,然后用 create_document 建一份名为 lighthouse-note 的文档,"+
			"正文里用 markdown 图片把刚画的图嵌进去(url 用 anselm://media/<attachmentId>),再简单说一句。")
	turn := waitTurn(t, wc, convID, mid, 300000)
	if turn.Status != "completed" {
		traceModel(t, rec)
		t.Fatalf("turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	attID := attachmentFrom(t, turn, "generate_image")

	var docs []struct {
		ID      string `json:"id"`
		Name    string `json:"name"`
		Content string `json:"content"`
	}
	wc.GET("/api/v1/documents").OK(t, &docs)
	var docID string
	for _, d := range docs {
		var full struct {
			ID      string `json:"id"`
			Content string `json:"content"`
		}
		wc.GET("/api/v1/documents/"+d.ID).OK(t, &full)
		if strings.Contains(full.Content, "anselm://media/"+attID) {
			docID = full.ID
			break
		}
	}
	if docID == "" {
		t.Fatalf("no document embeds anselm://media/%s — the reference never reached the library", attID)
	}

	// Turn 2: a NEW conversation with that document attached. Nothing here mentions the image; the
	// only path to the pixels is the document-injection chokepoint.
	// 第二轮:**新**对话,附上那份文档。这里没有任何东西提到图;通往像素的唯一路径就是文档注入咽喉。
	before := len(rec.Dumps())
	conv2 := convCreate(t, wc, "读文档")
	wc.PATCH("/api/v1/conversations/"+conv2, map[string]any{
		"attachedDocuments": []map[string]any{{"documentId": docID}},
	}).OK(t, nil)
	mid2 := sendMsg(t, wc, conv2, "看看这份笔记里的图,用一句话说它画的是什么。")
	turn2 := waitTurn(t, wc, conv2, mid2, 300000)
	if turn2.Status != "completed" {
		traceModel(t, rec)
		t.Fatalf("second turn must complete, got %s err=%s/%s", turn2.Status, turn2.ErrorCode, turn2.ErrorMessage)
	}

	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsImage(content.Raw) {
		t.Fatalf("artifact must be a real image (HTTP %d, %d bytes)", content.Status, len(content.Raw))
	}
	b64 := base64.StdEncoding.EncodeToString(content.Raw)
	for _, d := range rec.Dumps()[before:] {
		if d.HasImagePart(b64) {
			return
		}
	}
	t.Fatal("the @-mentioned document's image never reached the model as pixels — it saw markdown text only")
}

// TestLiveMedia_FunctionChartSeenByModel is the end-to-end link the other four do NOT cover: a
// producer that is NOT a generation tool, feeding the consumption chokepoint's EXPAND branch, with a
// real model on the far end.
//
// The whole chain runs for real: the model calls run_function → the REAL sandbox installs matplotlib
// and executes REAL Python → the script writes a PNG into ANSELM_OUT and declares it with
// `{"$media": …}` → the collector swaps that declaration for a receipt → and the model's NEXT turn
// must carry the PIXELS, because ADR 0017 expands what the model has NOT seen (a function's output
// is evidence; a generation tool's output is the model's own prompt coming back).
//
// That last clause is why this test is not redundant with ①. ① proves the SKIP branch (generation →
// receipt only). Nothing else proves the EXPAND branch against a real model, and the two branches
// are opposite decisions made in the same function.
//
// TestLiveMedia_FunctionChartSeenByModel 是另外四条**没有覆盖**的那一环:一个**不是生成工具**的产地,
// 喂给消费咽喉的**展开**分支,而远端是一个真模型。
//
// 整条链都是真的:模型调 run_function → **真沙箱**装 matplotlib、跑**真 Python** → 脚本把 PNG 写进
// ANSELM_OUT 并用 `{"$media": …}` 声明 → 采集器把声明换成 receipt → 而模型的**下一轮必须带着像素**,
// 因为 ADR 0017 展开的是模型**没见过**的东西(函数的产出是**证据**;生成工具的产出是模型自己的 prompt
// 绕回来)。
//
// 最后这句正是它与 ① 不重复的原因:① 证的是**跳过**分支(生成族只回 receipt),而**展开**分支此前对着
// 真模型一次也没被证过——两个分支是同一个函数里方向相反的两个决定。
func TestLiveMedia_FunctionChartSeenByModel(t *testing.T) {
	t.Parallel()
	wc, rec, _ := liveQwen(t, "live-fn-chart")

	// Real matplotlib, real Agg backend, real PNG bytes on disk. ANSELM_OUT is the run's own
	// artifact directory — the same contract the docs state, exercised rather than assumed.
	// 真 matplotlib、真 Agg 后端、盘上真 PNG 字节。ANSELM_OUT 是本次运行自己的产物目录——文档写的
	// 就是这个契约,这里是**跑它**而不是假定它。
	code := `import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

def chart(points: int) -> dict:
    xs = list(range(points))
    ys = [x * x for x in xs]
    fig, ax = plt.subplots(figsize=(4, 3), dpi=120)
    ax.plot(xs, ys, marker="o")
    ax.set_title("squares")
    out = os.path.join(os.environ["ANSELM_OUT"], "chart.png")
    fig.savefig(out)
    plt.close(fig)
    return {"chart": {"$media": "chart.png"}, "points": points}
`
	fnID := wc.POST("/api/v1/functions", map[string]any{
		"name": "square_chart", "description": "plots y=x^2 and returns the chart image",
		"code": code, "dependencies": []string{"matplotlib"},
	}).Field(t, "id")

	convID := convCreate(t, wc, "函数出图给我看")
	mid := sendMsg(t, wc, convID,
		"用 run_function 跑一下 square_chart 这个函数,points 传 6。跑完看看它返回的那张图,"+
			"用一句话说图里的曲线是什么形状。")
	// First run installs matplotlib into the shared sandbox env (uv, real download) — give it room.
	// 首跑要把 matplotlib 装进共享沙箱 env(uv、真下载)——给足时间。
	turn := waitTurn(t, wc, convID, mid, 600000)
	if turn.Status != "completed" {
		traceModel(t, rec)
		t.Fatalf("turn must complete, got %s err=%s/%s (fn %s)", turn.Status, turn.ErrorCode, turn.ErrorMessage, fnID)
	}

	// The receipt a function artifact carries says `function_artifact` — the PRODUCER, not the tool
	// that happened to run it. That distinction is what ADR 0017 keys on.
	// 函数产物的 receipt 写的是 `function_artifact`——**产地**,而不是碰巧跑了它的那个工具。ADR 0017
	// 判的正是这个区分。
	attID := attachmentFrom(t, turn, "function_artifact")
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsImage(content.Raw) || len(content.Raw) < 3_000 {
		t.Fatalf("the function's chart must land as a real PNG: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}

	// THE assertion: the model was handed the chart's pixels, not a sentence about a chart.
	// **那条**断言:模型拿到的是图表的**像素**,不是一句关于图表的话。
	b64 := base64.StdEncoding.EncodeToString(content.Raw)
	for _, d := range rec.Dumps() {
		if d.HasImagePart(b64) {
			return
		}
	}
	traceModel(t, rec)
	t.Fatal("the function's chart never reached the model as pixels — ADR 0017's expand branch is broken for real producers")
}

// TestLiveMedia_HandlerArtifactPerCall closes the last producer the other scenarios reach: a
// HANDLER, which is the one production site whose artifact directory is not a property of the
// process but of the CALL. A function is a fresh run per invocation, so "this run's artifacts" is
// trivially well-defined; a handler is a resident instance serving many calls over one stdio pipe,
// so the out dir has to travel WITH each call (H5: StreamCall's outDir + the driver's `out` field)
// or "this call's artifacts" is not a well-defined set at all.
//
// So it calls TWICE and requires two DIFFERENT artifacts, each attributed to its own call. One call
// would pass even if the directory were process-global.
//
// TestLiveMedia_HandlerArtifactPerCall 补上另外几条够不到的最后一个产地:**handler**——它是唯一一个
// 产物目录不属于**进程**、而属于**调用**的产地。function 每次调用都是一次全新运行,故「这次运行的产物」
// 天然良定义;handler 是长跑实例、一条 stdio 管道服务多次调用,故目录必须**随每次调用一起走**(H5:
// StreamCall 的 outDir + driver 的 `out` 字段),否则「这次调用的产物」根本不是一个良定义的集合。
//
// 所以它调**两次**,并要求两件**不同**的产物、各归各的调用。只调一次的话,目录哪怕是进程级全局的也会过。
func TestLiveMedia_HandlerArtifactPerCall(t *testing.T) {
	t.Parallel()
	wc, _, _ := liveQwen(t, "live-hd-chart")

	hdID := hdCreate(t, wc, "chart_keeper", map[string]any{
		"initBody":     "self.n = 0",
		"dependencies": []string{"matplotlib"},
		"methods": []map[string]any{{
			"name": "plot", "inputs": []any{},
			"body": `import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
self.n += 1
fig, ax = plt.subplots(figsize=(3, 2), dpi=100)
ax.plot([0, 1, 2], [0, self.n, self.n * 2])
ax.set_title("call %d" % self.n)
out = os.path.join(os.environ["ANSELM_OUT"], "plot.png")
fig.savefig(out)
plt.close(fig)
return {"chart": {"$media": "plot.png"}, "call": self.n}`,
		}},
	})

	call := func(n int) (string, int64) {
		t.Helper()
		var out struct {
			Chart struct {
				AttachmentID string `json:"attachmentId"`
				SizeBytes    int64  `json:"sizeBytes"`
				Mime         string `json:"mime"`
			} `json:"chart"`
			Call int `json:"call"`
		}
		wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{"method": "plot"}).OK(t, &out)
		if out.Call != n {
			t.Fatalf("call %d reported itself as %d — the resident instance lost its state", n, out.Call)
		}
		if out.Chart.AttachmentID == "" || out.Chart.Mime != "image/png" {
			t.Fatalf("call %d produced no chart receipt: %+v", n, out.Chart)
		}
		return out.Chart.AttachmentID, out.Chart.SizeBytes
	}

	first, _ := call(1)
	second, _ := call(2)
	if first == second {
		// Same id means the second call re-collected the FIRST call's file: the out dir did not
		// travel with the call. (Content-addressed dedup cannot explain it — the two charts differ.)
		// 同一个 id 意味着第二次调用把**第一次**的文件又采了一遍:目录没有随调用走。
		// (内容寻址去重解释不了它——两张图不一样。)
		t.Fatalf("both calls yielded %s — the artifact directory is not per-call", first)
	}
	for i, id := range []string{first, second} {
		content := wc.DoRaw("GET", "/api/v1/attachments/"+id+"/content", "", nil)
		if content.Status != 200 || !bytes2IsImage(content.Raw) || len(content.Raw) < 2_000 {
			t.Fatalf("call %d's chart must be a real PNG: HTTP %d, %d bytes", i+1, content.Status, len(content.Raw))
		}
	}
}

// TestLiveMedia_McpImageSeenByModel closes the sixth and last production site. An MCP server is the
// one producer whose bytes cross a process boundary we do not own: the server hands back an MCP
// `image` content block over stdio, the binary collector mints a receipt, and the expansion
// chokepoint must put those exact pixels in front of the model. 终点验收 ③ says it in as many words
// — "MCP 工具返图模型看得见(不再是 [image: png] 占位符)".
//
// TestLiveMedia_McpImageSeenByModel 补上第六个、也是最后一个产地。MCP server 是唯一一个字节要穿过
// **我们不拥有的**进程边界的产地:server 经 stdio 递回一个 MCP `image` 内容块,二进制采集器铸出 receipt,
// 而展开咽喉必须把**那些**像素放到模型面前。终点验收 ③ 的原话就是这条。
func TestLiveMedia_McpImageSeenByModel(t *testing.T) {
	t.Parallel()
	wc, rec, _ := liveQwen(t, "live-mcp-image")

	script := writeScriptedMCP(t)
	wc.PUT("/api/v1/mcp-servers/shots", map[string]any{
		"description": "returns a picture", "command": "python3", "args": []string{script},
	}).OK(t, nil)

	convID := convCreate(t, wc, "MCP 返图")
	mid := sendMsg(t, wc, convID,
		"调用 shots 这个 MCP server 的 snapshot 工具拿一张图,然后用一句话描述你看到的图。")
	turn := waitTurn(t, wc, convID, mid, 300000)
	if turn.Status != "completed" {
		traceModel(t, rec)
		t.Fatalf("turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	attID := attachmentFrom(t, turn, "mcp_artifact")
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsImage(content.Raw) {
		t.Fatalf("the MCP image must land as a real PNG: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
	b64 := base64.StdEncoding.EncodeToString(content.Raw)
	for _, d := range rec.Dumps() {
		if d.HasImagePart(b64) {
			return
		}
	}
	traceModel(t, rec)
	t.Fatal("the MCP tool's image never reached the model as pixels — it saw a placeholder, which is exactly what 终点验收 ③ forbids")
}
