// generate_video_test.go — WRK-082 H4 black-box: the MANAGED video path over the REAL binary.
//
// Video is the only generation capability whose upstream conversation takes two requests, and the
// only one whose managed route the user put in the free tier after the fact ("视频要进免费档的").
// So what this file proves is precisely what changed: a workspace whose ONLY key is the managed
// free tier now SEES generate_video, and calling it really walks the gateway's two-request wire.
//
// **What it deliberately does not prove, and why.** The success path ends in downloading the
// artifact from an https URL, and both the desktop and the gateway refuse plaintext artifact
// fetches as an iron rule. Making that assertion here would mean either weakening the https rule
// for a test or planting a CA into the child process (which crypto/x509 honors on Linux and not on
// macOS — a test that is green in CI and red on the author's machine is worse than no test). The
// artifact round-trip is proven instead by the in-package video test, which uses a TLS server and
// a client that trusts it, and by the real-money acceptance. What lives HERE is everything that
// only the real binary can show: injection, the two-request wire, and honest failure.
//
// generate_video 黑盒(H4):真二进制上跑**受管**视频路径。
//
// 视频是唯一一个上游对话需要**两次请求**的生成能力,也是唯一一个受管路由被用户事后放进免费档的
// (「视频要进免费档的」)。故本文件证的正是**变了的那部分**:一个**唯一**的 key 是受管免费档的
// workspace 现在**看得见** generate_video,而调用它会真的走完网关那条两次请求的线缆。
//
// **它刻意不证什么,以及为什么**。成功路径的末端是从一个 https URL 下载产物,而桌面与网关都把
// 「拒绝明文取产物」当铁律。要在这里断言那一步,只能二选一:为了一个测试削弱 https 律,或者把一张 CA
// 塞进子进程(crypto/x509 在 Linux 上认它、在 macOS 上不认——一个在 CI 绿、在作者机器上红的测试,
// 比没有测试更糟)。产物往返改由 in-package 视频测试(它用 TLS 服务器 + 信任它的 client)与真钱验收
// 来证。留在**这里**的,是只有真二进制才能展示的:注入、两次请求的线缆、诚实失败。
package scenarios

import (
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// managedVideoSetup builds a workspace whose ONLY key is the managed free tier, pointed at the
// llmmock playing the gateway. It is the exact shape of a user who never entered a key.
//
// managedVideoSetup 造一个**唯一** key 是受管免费档的 workspace,指向扮演网关的 llmmock。它正是
// 一个从没输入过 key 的用户的形状。
func managedVideoSetup(t *testing.T) (*harness.Client, *harness.LLMMock) {
	t.Helper()
	srv := harness.Start(t)
	mock := harness.NewLLMMock(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "managed-video-ws"}).Field(t, "id")
	wc := c.WS(wsID)

	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "anselm", "displayName": "managed", "key": "ins_testend", "baseUrl": mock.GatewayURL(),
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": dlgModel}).OK(t, nil)
	return wc, mock
}

// TestGenerateVideo_ManagedTierOffersTheTool: the inversion H4 exists for. Before the user
// overturned P8 this same workspace saw image and speech but never video; now it sees all three,
// because a capability the free tier serves must be a capability the free tier ADVERTISES.
//
// TestGenerateVideo_ManagedTierOffersTheTool:H4 存在的理由——那次反转。在用户推翻 P8 之前,同一个
// workspace 看得见图像与语音、却**永远看不见**视频;现在三个全见,因为免费档**供应**的能力必须是
// 免费档**宣告**的能力。
func TestGenerateVideo_ManagedTierOffersTheTool(t *testing.T) {
	t.Parallel()
	wc, mock := managedVideoSetup(t)

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "sure"})
	convID := convCreate(t, wc, "what can you do")
	mid := sendMsg(t, wc, convID, "hello")
	if turn := waitTurn(t, wc, convID, mid, 60000); turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	offered := map[string]bool{}
	for _, name := range mock.DumpsFor(dlgModel)[0].Tools {
		offered[name] = true
	}
	for _, name := range []string{"generate_image", "generate_speech", "generate_video"} {
		if !offered[name] {
			t.Fatalf("the managed free tier must offer %s; tools = %v", name, mock.DumpsFor(dlgModel)[0].Tools)
		}
	}
}

// TestGenerateVideo_ManagedWireIsTwoRequests drives a real call and proves the desktop walked the
// gateway's contract: it submitted (and the gateway's 202 was accepted as success, not read as a
// failure) and then polled the handle. A dialect that treated 202 as an error would never reach
// the poll at all, so the terminal phase arriving is itself the proof that both halves ran.
//
// TestGenerateVideo_ManagedWireIsTwoRequests 驱动一次真调用,并证明桌面端走完了网关的契约:它提交了
// (且网关的 **202** 被当成成功、而不是被读成失败),然后轮询了那个句柄。一个把 202 当错误的方言
// **根本到不了**轮询,故终态的到达本身就是「两半都跑了」的证明。
func TestGenerateVideo_ManagedWireIsTwoRequests(t *testing.T) {
	t.Parallel()
	wc, mock := managedVideoSetup(t)
	mock.SetVideoPhase("failed")

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "generate_video",
			Args: map[string]any{"prompt": "a cat walking through tall grass", "seconds": 5}}}},
		harness.LLMTurn{Text: "抱歉,这次没生成成功。"},
	)
	convID := convCreate(t, wc, "make a video")
	mid := sendMsg(t, wc, convID, "帮我生成一段猫走路的视频")
	turn := waitTurn(t, wc, convID, mid, 120000)
	// The TURN completes even though the generation failed: a failed tool is a result the model
	// answers about, not a broken conversation.
	// 尽管生成失败,**回合**仍然完成:一个失败的工具是一条模型要据以作答的结果,不是一场坏掉的对话。
	if turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	// ① The submit really carried the prompt to the gateway wire.
	if prompts := mock.VideoPrompts(); len(prompts) != 1 || prompts[0] != "a cat walking through tall grass" {
		t.Fatalf("gateway video prompts = %v", prompts)
	}
	// ② The failure reached the model as a tool result rather than killing the turn.
	failed := false
	for _, b := range turn.Blocks {
		if b.Type == "tool_result" && strings.Contains(strings.ToLower(b.Content), "fail") {
			failed = true
		}
	}
	if !failed {
		t.Fatalf("the generation failure must surface as a tool_result: %+v", turn.Blocks)
	}
	// ③ The model got a second turn to answer about it.
	if dumps := mock.DumpsFor(dlgModel); len(dumps) < 2 {
		t.Fatalf("the model must be asked again after a failed tool: dumps=%d", len(dumps))
	}
}

// TestGenerateVideo_HonestAbsenceWithoutAKey: with a text-only key the tool must not exist. This is
// the OTHER half of the contract — video entering the free tier must not mean video appearing for
// a workspace that has no route to it.
//
// TestGenerateVideo_HonestAbsenceWithoutAKey:只有一把纯文本 key 时工具必须不存在。这是契约的**另一半**
// ——视频进免费档,不该意味着一个根本没有路由的 workspace 也会看见它。
func TestGenerateVideo_HonestAbsenceWithoutAKey(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	mock := harness.NewLLMMock(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "video-absent-ws"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "deepseek", "displayName": "llmmock-ds", "key": "sk-mock", "baseUrl": mock.URL(),
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": dlgModel}).OK(t, nil)

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "plain answer"})
	convID := convCreate(t, wc, "no-video-route")
	mid := sendMsg(t, wc, convID, "make me a video")
	if turn := waitTurn(t, wc, convID, mid, 60000); turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s", turn.Status)
	}
	for _, name := range mock.DumpsFor(dlgModel)[0].Tools {
		if name == "generate_video" {
			t.Fatal("generate_video offered to a workspace with no video-capable key")
		}
	}
}
