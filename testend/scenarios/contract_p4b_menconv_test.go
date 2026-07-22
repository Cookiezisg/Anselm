// contract_p4b_menconv_test.go — Phase 4b 全量重测：@提及 (E2-mention) + conversation LLM 工具
// (E2-conv) 的确定性 llmmock 锁死。既有测锁了 function-mention 冻结 (TestChatR3_MentionFreeze)、
// rail 排序/归档/未读 (TestChat_Rail*) 与 search_conversations 回忆窗 (TestSearchLLM_SearchConversationsTool)；
// 本文件补的是那些测的真空：非文档实体 (agent) 的冻结、已删/未知实体的诚实降级、一条消息多提及+附件
// 共存、list_conversations 的无排序能力缺口 / includeArchived 诚实 / 与 search 的分工 / 深页游标忠实。
//
// 断言以 docs/references/backend/domains/{conversation,chat}.md 契约为准。list_conversations /
// search_conversations 是 LLM 工具——用 driveTool 喂脚本工具调用，断言回喂给模型的 tool RSLT（纯 JSON）。
package scenarios

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// lastDump 返回发给 dialogue 模型的最后一个请求的原始线缆 JSON（模型视角）。
func lastDump(mock *harness.LLMMock) string {
	ds := mock.DumpsFor(dlgModel)
	return string(ds[len(ds)-1].Raw)
}

// ───────────────────────── E2-mention ─────────────────────────

// TestP4bMenConv_AgentMentionFreeze: E2-men-1 — 非文档实体 (agent) 的 @提及冻结。既有
// TestChatR3_MentionFreeze 锁了 function（代码快照）；agent 走另一条 resolver（快照 name+description）。
// 发送时把 agent 描述冻进 user 回合 Attrs；之后 PATCH 改活的 agent 描述为 V2，同对话后续回合的历史
// 快照仍是 V1（freeze-on-send，实体再改不影响已发回合的语境）。
func TestP4bMenConv_AgentMentionFreeze(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	agID := agCreate(t, wc, map[string]any{
		"name": "planner_ag", "description": "AGENT-SNAP-V1 handles planning",
		"prompt": "you plan things",
	})

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "I see the agent"})
	convID := convCreate(t, wc, "agent mention freeze")
	mid := sendWith(t, wc, convID, map[string]any{
		"content":  "hand off to this agent",
		"mentions": []map[string]any{{"type": "agent", "id": agID}},
	})
	if turn := waitTurn(t, wc, convID, mid, 30000); turn.Status != "completed" {
		t.Fatalf("agent mention turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	raw1 := string(mock.DumpsFor(dlgModel)[0].Raw)
	if !strings.Contains(raw1, "AGENT-SNAP-V1") {
		t.Fatalf("agent mention must inline the description snapshot at send time: %s", raw1)
	}
	if !strings.Contains(raw1, "planner_ag") {
		t.Fatal("agent mention snapshot must carry the agent name (name+description snapshot)")
	}

	// Mutate the LIVE agent description → V2 (PATCH meta, no version bump). Live Get now returns V2,
	// so if the mention re-resolved live the second turn would leak V2 — the freeze must prevent it.
	// 改活的 agent 描述为 V2（PATCH 元数据，不升版本）。活 Get 现返 V2——若 mention 走 live 解析，第二
	// 回合会泄 V2；冻结必须挡住。
	wc.PATCH("/api/v1/agents/"+agID, map[string]any{"description": "AGENT-SNAP-V2 rewritten role"}).OK(t, nil)
	var live struct {
		Description string `json:"description"`
	}
	wc.GET("/api/v1/agents/"+agID).OK(t, &live)
	if !strings.Contains(live.Description, "AGENT-SNAP-V2") {
		t.Fatalf("precondition: live agent description must now read V2, got %q", live.Description)
	}

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "still the old snapshot"})
	mid2 := sendMsg(t, wc, convID, "what did that agent's description say earlier?")
	if turn := waitTurn(t, wc, convID, mid2, 30000); turn.Status != "completed" {
		t.Fatalf("second turn must complete, got %s", turn.Status)
	}
	// The live agent is now V2 (the system-prompt entity catalog legitimately reflects V2), so the ONLY
	// place the V1 string can still survive is the frozen mention snapshot in turn 1's user message. Its
	// presence in the replayed history proves freeze-on-send: the sent turn's @-reference did not
	// re-resolve to the edited entity. (We deliberately do NOT assert V2-absent: V2 rightly rides the
	// live catalog — the freeze is about the mention snapshot, not the catalog.)
	// 活的 agent 现为 V2（system prompt 实体目录理应反映 V2），故 V1 串唯一可能的幸存处 = 回合 1 user 消息里
	// 的冻结 mention 快照。它在重放历史中在场即证 freeze-on-send：已发回合的 @引用没有重解析到被改实体。
	// （刻意不断言 V2 缺席：V2 理应随活目录——冻结管的是 mention 快照、非目录。）
	raw2 := lastDump(mock)
	if !strings.Contains(raw2, "AGENT-SNAP-V1") {
		t.Fatalf("frozen agent mention must still read V1 in replayed history after the live agent moved to V2: %s", raw2)
	}
}

// TestP4bMenConv_DeletedAndUnknownMentionDegrade: E2-men-2 — 已删实体 + 非可提及类型的诚实降级。
// 一个 @提及解析失败（软删的 function：resolver 报错）或无 resolver（skill：非可提及类型）时，降级为
// 「(unavailable)」stub 快照——坏的 @引用绝不阻断发消息，且被删实体的内容绝不经冻结快照复活。
func TestP4bMenConv_DeletedAndUnknownMentionDegrade(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	fnID := fnCreate(t, wc, "doomed_fn", "def doomed_fn() -> dict:\n    return {\"v\": \"DELETEDMARKER-XYZ\"}\n")
	wc.DELETE("/api/v1/functions/"+fnID).OK(t, nil)
	wc.Do("GET", "/api/v1/functions/"+fnID, nil).Fail(t, 404, "FUNCTION_NOT_FOUND")

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "I note one reference is gone"})
	convID := convCreate(t, wc, "deleted mention")
	mid := sendWith(t, wc, convID, map[string]any{
		"content": "look at these two references",
		"mentions": []map[string]any{
			{"type": "function", "id": fnID},               // soft-deleted → resolver errors → stub
			{"type": "skill", "id": "nonexistent-skill01"}, // skill IS mentionable now, but this one doesn't exist → resolver errors → stub
		},
	})
	// A broken/deleted @-reference must NEVER block sending — it degrades, it does not fail the turn.
	// 坏/已删 @引用绝不挡发送——降级、不让回合失败。
	if turn := waitTurn(t, wc, convID, mid, 30000); turn.Status != "completed" {
		t.Fatalf("a broken/deleted mention must not block the turn, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	raw := string(mock.DumpsFor(dlgModel)[0].Raw)
	// Honest degradation: the mention is present but marked (unavailable), not silently dropped.
	// 诚实降级：mention 在场但标 (unavailable)，非静默丢弃。
	if !strings.Contains(raw, "(unavailable)") {
		t.Fatalf("a deleted/unknown mention must degrade to an honest (unavailable) marker: %s", raw)
	}
	// A soft-deleted entity's body must NOT resurface through a frozen snapshot.
	// 软删实体的正文不得经冻结快照复活。
	if strings.Contains(raw, "DELETEDMARKER-XYZ") {
		t.Fatal("a soft-deleted entity's content must not resurface through its mention snapshot")
	}
}

// TestP4bMenConv_MultiMentionPlusAttachment: E2-men-3 — 一条消息多提及 + 附件共存。两个提及
// (function + agent) 各自冻结快照、附件内联，三份载荷都进模型视角；注入顺序 = 输入顺序（function
// 的 <mention> 块在 agent 之前）。
func TestP4bMenConv_MultiMentionPlusAttachment(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	// Two function mentions carry their marker in CODE (catalog-invisible — the entity catalog lists
	// name+description, never code), so the marker appears ONLY inside the mention block and its relative
	// position is a clean witness of injection order. The agent mention adds cross-type coexistence.
	// 两个 function 提及的 marker 在代码里（目录不可见——目录列 name+description、绝不列 code），故 marker 只
	// 现于 mention 块、其相对位置是注入顺序的干净证据。agent 提及补跨类型共存。
	fnAlpha := fnCreate(t, wc, "combo_alpha", "def combo_alpha() -> dict:\n    return {\"v\": \"MENTA-ALPHA\"}\n")
	fnBeta := fnCreate(t, wc, "combo_beta", "def combo_beta() -> dict:\n    return {\"v\": \"MENTB-BETA\"}\n")
	agID := agCreate(t, wc, map[string]any{
		"name": "combo_ag", "description": "MENTAGENT-M3 assistant persona", "prompt": "x",
	})
	txtID := uploadAtt(t, wc, "combo.txt", "text/plain", []byte("MENTTXT-M3 file body"))

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "saw them all"})
	convID := convCreate(t, wc, "combo")
	mid := sendWith(t, wc, convID, map[string]any{
		"content": "combine these",
		"mentions": []map[string]any{
			{"type": "function", "id": fnAlpha},
			{"type": "function", "id": fnBeta},
			{"type": "agent", "id": agID},
		},
		"attachmentIds": []string{txtID},
	})
	if turn := waitTurn(t, wc, convID, mid, 30000); turn.Status != "completed" {
		t.Fatalf("multi-mention+attachment turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	raw := string(mock.DumpsFor(dlgModel)[0].Raw)
	// Coexistence: all three frozen mentions + the inlined attachment ride the one user turn.
	// 共存：三个冻结提及 + 内联附件都在这一个 user 回合。
	for _, marker := range []string{"MENTA-ALPHA", "MENTB-BETA", "MENTAGENT-M3", "MENTTXT-M3"} {
		if !strings.Contains(raw, marker) {
			t.Fatalf("model view must carry %s (all mentions + the inlined attachment coexist): %s", marker, raw)
		}
	}
	// Injection order = input order: the first function mention precedes the second (both catalog-invisible,
	// so their positions are the mention block's true order).
	// 注入顺序 = 输入顺序：第一个 function 提及在第二个之前（都目录不可见、位置即 mention 块真实顺序）。
	if strings.Index(raw, "MENTA-ALPHA") > strings.Index(raw, "MENTB-BETA") {
		t.Fatal("frozen mentions must inject in input order (fnAlpha before fnBeta)")
	}
}

// ───────────────────────── E2-conv ─────────────────────────

// convToolRows 解析 list_conversations 的工具 RSLT（纯 JSON）。
type convToolRows struct {
	Conversations []struct {
		ConversationID string `json:"conversationId"`
		Archived       bool   `json:"archived"`
		Pinned         bool   `json:"pinned"`
	} `json:"conversations"`
	Count      int    `json:"count"`
	NextCursor string `json:"nextCursor"`
}

func parseConvTool(t *testing.T, out string) convToolRows {
	t.Helper()
	var r convToolRows
	if err := json.Unmarshal([]byte(out), &r); err != nil {
		t.Fatalf("list_conversations RSLT must be pure JSON: %v (%s)", err, out)
	}
	return r
}

// filterMine 保留属于 mine 的 conversationId，按 RSLT 原序。
func filterMine(r convToolRows, mine map[string]bool) []string {
	var seq []string
	for _, cv := range r.Conversations {
		if mine[cv.ConversationID] {
			seq = append(seq, cv.ConversationID)
		}
	}
	return seq
}

// httpConvOrder 取 HTTP rail 列表某排序下、属于 mine 的对话 id 序（与 tool 面对照能力缺口）。
func httpConvOrder(t *testing.T, wc *harness.Client, query string, mine map[string]bool) []string {
	t.Helper()
	var rows []convRow
	wc.GET("/api/v1/conversations"+query).OK(t, &rows)
	var seq []string
	for _, r := range rows {
		if mine[r.ID] {
			seq = append(seq, r.ID)
		}
	}
	return seq
}

// TestP4bMenConv_ListNoSortCapability: E2-conv-1 — list_conversations 无排序能力（缺口 vs 诚实）。
// 工具复用 Service.List 的默认 activity 排序、不暴露 Sort 参数：传 sort:"name" 是 no-op（与默认同序），
// 故 agent 无法经工具「按名列对话」——而同一 HTTP 端点 ?sort=name（rail 用）能确定地按名排。工具 ==
// 默认 activity 枚举（忠实近况序），排序是 rail/UI 关注点。判定：honest-but-gapped（LOW，非缺陷）。
func TestP4bMenConv_ListNoSortCapability(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	// 故意非字母创建序；标题 apple<mango<zebra 使 name 排序确定可断。
	idApple := convCreate(t, wc, "conv-apple")
	idMango := convCreate(t, wc, "conv-mango")
	idZebra := convCreate(t, wc, "conv-zebra")
	mine := map[string]bool{idApple: true, idMango: true, idZebra: true}

	relOrder := func(args map[string]any) []string {
		r := parseConvTool(t, driveTool(t, wc, mock, "list_conversations", args))
		return filterMine(r, mine)
	}
	plain := relOrder(map[string]any{"limit": 50})
	sorted := relOrder(map[string]any{"limit": 50, "sort": "name"})

	if len(plain) != 3 {
		t.Fatalf("list_conversations must faithfully enumerate all three of my conversations, got %v", plain)
	}
	// The tool exposes NO sort control: a sort:"name" arg is silently ignored (unknown field) → same
	// order as default. Collision-proof: both queries hit identical data + identical ORDER BY.
	// 工具无排序控制：sort:"name" 被静默忽略（未知字段）→ 与默认同序。碰撞免疫：两次查询同数据同 ORDER BY。
	if fmt.Sprint(plain) != fmt.Sprint(sorted) {
		t.Fatalf("list_conversations has no sort param; sort:name must be a no-op, got default=%v sorted=%v", plain, sorted)
	}
	// The tool IS the HTTP default (activity) enumeration — same Service.List default sort.
	// 工具即 HTTP 默认 (activity) 枚举——同 Service.List 默认排序。
	httpDefault := httpConvOrder(t, wc, "?limit=50", mine)
	if fmt.Sprint(plain) != fmt.Sprint(httpDefault) {
		t.Fatalf("tool order must equal the HTTP default activity list, got tool=%v http=%v", plain, httpDefault)
	}
	// The HTTP endpoint (what the rail uses) CAN name-sort — deterministically apple<mango<zebra —
	// but the tool cannot request it. That asymmetry is the capability gap.
	// HTTP 端点（rail 用的）能确定地按名排（apple<mango<zebra），工具却无法请求它——这个不对称即能力缺口。
	httpByName := httpConvOrder(t, wc, "?sort=name&limit=50", mine)
	if fmt.Sprint(httpByName) != fmt.Sprint([]string{idApple, idMango, idZebra}) {
		t.Fatalf("HTTP ?sort=name must order apple<mango<zebra (NOCASE title), got %v", httpByName)
	}
}

// TestP4bMenConv_ListIncludeArchivedHonest: E2-conv-2 — includeArchived 混排时归档标志诚实呈现。
// 默认枚举仅活跃（归档排除）；includeArchived:true → ArchiveAll（活跃+归档同列），归档行诚实携带
// archived=true，使 agent 能分辨其归档态（不静默混同）。
func TestP4bMenConv_ListIncludeArchivedHonest(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	active := convCreate(t, wc, "active-thread")
	arch := convCreate(t, wc, "archived-thread")
	wc.PATCH("/api/v1/conversations/"+arch, map[string]any{"archived": true}).OK(t, nil)

	byID := func(r convToolRows) map[string]bool {
		m := map[string]bool{}
		for _, cv := range r.Conversations {
			m[cv.ConversationID] = true
		}
		return m
	}

	// Default: archived excluded (active-only enumeration). 默认：归档排除。
	def := parseConvTool(t, driveTool(t, wc, mock, "list_conversations", map[string]any{"limit": 50}))
	present := byID(def)
	if present[arch] {
		t.Fatal("default list_conversations must exclude archived threads")
	}
	if !present[active] {
		t.Fatal("default list_conversations must include the active thread")
	}

	// includeArchived:true → both, and the archived row honestly carries archived=true.
	all := parseConvTool(t, driveTool(t, wc, mock, "list_conversations", map[string]any{"limit": 50, "includeArchived": true}))
	sawActive, sawArch, archFlag := false, false, false
	for _, cv := range all.Conversations {
		switch cv.ConversationID {
		case active:
			sawActive = true
		case arch:
			sawArch = true
			archFlag = cv.Archived
		}
	}
	if !sawActive || !sawArch {
		t.Fatalf("includeArchived must return BOTH active and archived, got active=%v archived=%v", sawActive, sawArch)
	}
	if !archFlag {
		t.Fatal("the archived row must honestly carry archived=true so the agent can tell it is archived")
	}
}

// TestP4bMenConv_SearchVsListDivision: E2-conv-3 — search（内容回忆）vs list（忠实枚举）的分工 (F146)。
// search_conversations 只返消息内容匹配查询的线程、静默漏掉无匹配文本的对话——绝不能当作完整列表；
// list_conversations 才是完整枚举。锁死机制：给 A 落独特词、B 落不相干词，search 命中 A 漏 B，list 二者都返。
// （agent 该选哪个工具属真模型判断，交 evals；此处锁的是两工具的物理分工。）
func TestP4bMenConv_SearchVsListDivision(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "Recorded the pineappleq7 rollout plan."})
	convA := convCreate(t, wc, "rollout planning")
	midA := sendMsg(t, wc, convA, "note the rollout")
	if turn := waitTurn(t, wc, convA, midA, 20000); turn.Status != "completed" {
		t.Fatalf("conv A turn must complete, got %s", turn.Status)
	}
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "Recorded the zqwidget9 hardware note."})
	convB := convCreate(t, wc, "hardware notes")
	midB := sendMsg(t, wc, convB, "note the hardware")
	if turn := waitTurn(t, wc, convB, midB, 20000); turn.Status != "completed" {
		t.Fatalf("conv B turn must complete, got %s", turn.Status)
	}
	waitIndexed(t, wc, "pineappleq7", "conversation")

	// search_conversations = CONTENT recall: matches A, MISSES B (no matching text). Presenting these
	// hits as a complete list would silently drop B — the F146 hazard.
	// search = 内容回忆：命中 A、漏 B（无匹配文本）。把命中当完整列表会静默丢 B——F146 隐患。
	sres := driveTool(t, wc, mock, "search_conversations", map[string]any{"query": "pineappleq7"})
	if !strings.Contains(sres, convA) {
		t.Fatalf("search_conversations must recall conv A by its content token: %s", sres)
	}
	if strings.Contains(sres, convB) {
		t.Fatalf("search must MISS conv B (no matching text) — it is recall, not enumeration (F146): %s", sres)
	}

	// list_conversations = faithful ENUMERATION: BOTH present, including B which search missed.
	// list = 忠实枚举：二者都在，含 search 漏掉的 B。
	lres := driveTool(t, wc, mock, "list_conversations", map[string]any{"limit": 50})
	if !strings.Contains(lres, convA) || !strings.Contains(lres, convB) {
		t.Fatalf("list_conversations must enumerate BOTH conversations (the complete set search cannot give): %s", lres)
	}
}

// TestP4bMenConv_ListCursorWalkFaithful: E2-conv-5 — 55 对话的 nextCursor 忠实走完（F146 深面）。
// 每页不超 limit；首页 nextCursor 非空（一页不是全集）；游标续翻把全部 55 条恰好各枚举一次（不漏/不重）。
// keyset 游标在 (last_message_at,id) 复合键上行进，故即便近同刻创建也不漏/不重。
func TestP4bMenConv_ListCursorWalkFaithful(t *testing.T) {
	t.Parallel()
	wc, mock := chatSetup(t, false)
	const total = 55
	mine := map[string]bool{}
	for i := 0; i < total; i++ {
		mine[convCreate(t, wc, fmt.Sprintf("bulk-%02d", i))] = true
	}

	drive := func(cursor string) convToolRows {
		args := map[string]any{"limit": 20}
		if cursor != "" {
			args["cursor"] = cursor
		}
		return parseConvTool(t, driveTool(t, wc, mock, "list_conversations", args))
	}

	seen := map[string]int{}
	cursor := ""
	pages, firstCount := 0, -1
	for {
		r := drive(cursor)
		if r.Count > 20 {
			t.Fatalf("a page must never exceed the limit (20), got count=%d", r.Count)
		}
		if firstCount < 0 {
			firstCount = r.Count
		}
		for _, cv := range r.Conversations {
			seen[cv.ConversationID]++
		}
		pages++
		if pages > 12 {
			t.Fatal("cursor walk did not terminate within 12 pages — nextCursor may be looping")
		}
		if r.NextCursor == "" {
			break
		}
		cursor = r.NextCursor
	}
	// A single page is NOT the whole set — nextCursor surfaced for a reason (an agent must not mistake
	// page 1 for all conversations). 一页不是全集——nextCursor 有其存在意义。
	if firstCount >= total {
		t.Fatalf("first page (%d) must not contain the entire set of %d (F146)", firstCount, total)
	}
	// Every one of my 55 conversations enumerated exactly once across the walk (no miss, no dup).
	// 我的 55 条各恰好枚举一次（不漏/不重）。
	missed, dup := 0, 0
	for id := range mine {
		switch seen[id] {
		case 0:
			missed++
		case 1:
		default:
			dup++
		}
	}
	if missed != 0 || dup != 0 {
		t.Fatalf("faithful walk must surface each conversation exactly once: %d missed, %d duplicated (of %d)", missed, dup, total)
	}
}
