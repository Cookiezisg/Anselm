package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"

	"go.uber.org/zap"

	conversationapp "github.com/sunweilin/anselm/backend/internal/app/conversation"
	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// ConversationHandler serves the 5 /api/v1/conversations/* CRUD endpoints plus the residency
// projection (`GET /{id}/workdir`). The tokensUsed enrichment + the system-prompt-preview endpoint are
// chat data (message_blocks token sum / prompt assembly) and live on ChatHandler, not here.
//
// ConversationHandler 提供 /api/v1/conversations/* 的 5 个 CRUD 端点 + 驻地投影（`GET /{id}/workdir`）。
// tokensUsed 富化 + system-prompt-preview 端点属 chat 数据（message_blocks token 求和 / prompt 拼装），
// 归 ChatHandler。
type ConversationHandler struct {
	svc *conversationapp.Service
	log *zap.Logger
}

// NewConversationHandler constructs the handler.
//
// NewConversationHandler 构造 handler。
func NewConversationHandler(svc *conversationapp.Service, log *zap.Logger) *ConversationHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &ConversationHandler{svc: svc, log: log.Named("handlers.conversation")}
}

// Register wires the endpoints onto mux.
//
// Register 把端点挂到 mux。
func (h *ConversationHandler) Register(mux Registrar) {
	mux.HandleFunc("POST /api/v1/conversations", h.Create)
	mux.HandleFunc("GET /api/v1/conversations", h.List)
	// The literal `workdir-groups` segment must be registered alongside `{id}` — Go's ServeMux prefers the
	// more specific pattern, so a literal never gets swallowed by the wildcard (same shape as
	// `GET /documents/tree` beside `GET /documents/{id}`).
	// 字面段 `workdir-groups` 与 `{id}` 并存——Go ServeMux 取更具体的模式，故字面段绝不被通配吞掉（与
	// `GET /documents/tree` 挨着 `GET /documents/{id}` 同形）。
	mux.HandleFunc("GET /api/v1/conversations/workdir-groups", h.WorkDirGroups)
	mux.HandleFunc("POST /api/v1/conversations:archive-workdir", h.ArchiveWorkDir)
	mux.HandleFunc("POST /api/v1/conversations:delete-workdir", h.DeleteWorkDir)
	mux.HandleFunc("GET /api/v1/conversations/{id}", h.Get)
	mux.HandleFunc("PATCH /api/v1/conversations/{id}", h.Update)
	mux.HandleFunc("DELETE /api/v1/conversations/{id}", h.Delete)
	mux.HandleFunc("GET /api/v1/conversations/{id}/workdir", h.WorkDir)
}

type createConversationRequest struct {
	Title string `json:"title"`
}

// updateConversationRequest uses pointer fields so absent vs explicit values stay distinct.
// hasModelOverride records whether the modelOverride key was present at all (so the handler can
// tell "leave unchanged" from "explicitly set to null").
//
// updateConversationRequest 用指针字段区分「未传」与「显式传值」。hasModelOverride 记录
// modelOverride key 是否出现（区分「不动」与「显式 null 清除」）。
type updateConversationRequest struct {
	Title             *string                            `json:"title,omitempty"`
	SystemPrompt      *string                            `json:"systemPrompt,omitempty"`
	AttachedDocuments *[]documentdomain.AttachedDocument `json:"attachedDocuments,omitempty"`
	Archived          *bool                              `json:"archived,omitempty"`
	Pinned            *bool                              `json:"pinned,omitempty"`
	ModelOverride     *modeldomain.ModelRef              `json:"modelOverride,omitempty"`
	hasModelOverride  bool
	// WorkDir needs no `has` companion: unlike modelOverride, its cleared value is the empty STRING, so
	// `{"workDir":""}` decodes to a non-nil pointer to "" and says "unmount" all by itself. An absent key
	// is the nil pointer = leave unchanged, as with every other field here.
	//
	// WorkDir 不需要 `has` 伴生字段:不同于 modelOverride,它清除后的值是**空字符串**,故 `{"workDir":""}`
	// 解出一个指向 "" 的非 nil 指针、它自己就说出了「退出驻地」。缺键即 nil 指针 = 不动,与此处其余字段一致。
	WorkDir *string `json:"workDir,omitempty"`
}

// UnmarshalJSON detects whether `modelOverride` was present as a key (vs absent), to distinguish
// "leave unchanged" from "explicitly clear to null" — the tristate the per-thread override needs.
// It stays STRICT (DisallowUnknownFields) like decodeJSON: this custom unmarshal shadows the
// transport's strict decoder, so without this a typo'd field (e.g. "titel") would silently no-op
// instead of a 400 — the same silent-drop inconsistency every other PATCH rejects.
//
// UnmarshalJSON 探测 `modelOverride` 是否在 JSON 中出现（区分「不动」与「显式 null 清除」）——
// 即线程级 override 需要的三态。它像 decodeJSON 一样保持**严格**（DisallowUnknownFields）:此自定义
// unmarshal 遮蔽了 transport 的严格解码器,不加则拼错的字段(如 "titel")会静默 no-op 而非 400——正是其余
// PATCH 都拒的静默丢弃不一致。
func (r *updateConversationRequest) UnmarshalJSON(data []byte) error {
	type raw updateConversationRequest
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	if err := dec.Decode((*raw)(r)); err != nil {
		return err
	}
	var m map[string]json.RawMessage
	if err := json.Unmarshal(data, &m); err == nil {
		_, r.hasModelOverride = m["modelOverride"]
	}
	return nil
}

func (h *ConversationHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req createConversationRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	c, err := h.svc.Create(r.Context(), req.Title)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Created(w, c)
}

func (h *ConversationHandler) List(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	// archived: absent/else = active only (default); "true"/"1"/"archived" = archived only; "all" =
	// both (the rail's "show archived" — archived rows carry archived=true for the gray dot).
	// archived：缺省/其余 = 仅活跃（默认）；"true"/"1"/"archived" = 仅归档；"all" = 两者（rail「显示已归档」，归档行带 archived=true 供灰点）。
	var archive conversationdomain.ArchiveScope
	switch q.Get("archived") {
	case "all":
		archive = conversationdomain.ArchiveAll
	case "true", "1", "archived":
		archive = conversationdomain.ArchiveArchived
	default:
		archive = conversationdomain.ArchiveActive
	}
	// sort: "created" = pinned-first then creation order; "name" = pinned-first then title A–Z
	// (case-insensitive); anything else (incl absent) = "activity" (pinned-first then most-recently-
	// active, the default). Each sort keys its own keyset column, so switching sort MUST reset pagination.
	// sort："created" = 置顶优先再创建序；"name" = 置顶优先再 title A–Z（大小写不敏感）；其余（含缺省）= "activity"
	// （置顶优先再最近活跃，默认）。每种排序键各自的 keyset 列，故切换排序**必须重置分页**。
	// pinned: absent = both (the long-standing default); "true"/"1" = pinned only; "false"/"0" = unpinned
	// only. The grouped rail (WD1.5) asks for the two halves separately so each thread renders exactly once.
	// pinned：缺省 = 两者（长期默认）；"true"/"1" = 仅置顶；"false"/"0" = 仅未置顶。分组后的 rail（WD1.5）分别取
	// 两半，使每条线程恰好渲一次。
	var pinned conversationdomain.PinScope
	switch q.Get("pinned") {
	case "true", "1":
		pinned = conversationdomain.PinPinned
	case "false", "0":
		pinned = conversationdomain.PinUnpinned
	default:
		pinned = conversationdomain.PinAny
	}
	// workDir needs the three states a plain Get() cannot tell apart, so it reads PRESENCE with Has(): the
	// key ABSENT = no residency filter at all (every conversation), the key PRESENT AND EMPTY (`?workDir=`)
	// = only the UNMOUNTED threads (the rail's Recents section), a value = only that residency (one rail
	// group). `Get` alone returns "" for both of the first two, which would make the Recents section
	// silently list the whole workspace.
	// workDir 要三个状态，而裸 Get() 分不清，故用 Has() 读**键是否出现**:键**缺席** = 完全不按驻地过滤（每条
	// 对话）、键**出现且为空**（`?workDir=`）= **仅未挂**的线程（rail 的「最近」段）、有值 = 仅该驻地（一个 rail
	// 组）。只用 Get 时前两者都是 ""，那会让「最近」段静默地列出整个 workspace。
	var workDir *string
	if q.Has("workDir") {
		v := q.Get("workDir")
		workDir = &v
	}
	items, next, err := h.svc.List(r.Context(), conversationdomain.ListFilter{
		Cursor:  p.Cursor,
		Limit:   p.Limit,
		Search:  q.Get("search"),
		Archive: archive,
		Sort:    conversationdomain.ListSort(q.Get("sort")),
		Pinned:  pinned,
		WorkDir: workDir,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, items, next, next != "")
}

func (h *ConversationHandler) Get(w http.ResponseWriter, r *http.Request) {
	c, err := h.svc.Get(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, c)
}

// Update is a partial-update PATCH; modelOverride is tristate (absent / null=clear / object=set).
//
// Update 是部分更新 PATCH；modelOverride 三态（缺 / null=清除 / object=设置）。
func (h *ConversationHandler) Update(w http.ResponseWriter, r *http.Request) {
	var req updateConversationRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	in := conversationapp.UpdateInput{
		Title:             req.Title,
		SystemPrompt:      req.SystemPrompt,
		AttachedDocuments: req.AttachedDocuments,
		Archived:          req.Archived,
		Pinned:            req.Pinned,
		WorkDir:           req.WorkDir,
	}
	if req.hasModelOverride {
		in.ModelOverride = &req.ModelOverride // **ModelRef tristate; req.ModelOverride nil = clear
	}
	c, err := h.svc.Update(r.Context(), r.PathValue("id"), in)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, c)
}

// WorkDir returns the residency's live projection for one conversation: the mounted path plus what is
// true about it right now (exists / git repo / branch / dirty). Recomputed per request and cached
// nowhere — the filesystem and git are the truth, so a directory the user just deleted, or a branch they
// just switched in their own terminal, reads as it now IS.
//
// N4: a derived BOUNDED PROJECTION, so no cursor and no `nextCursor`. It is not a stored collection at
// all — it is ONE object computed on demand, in the same class as `GET /storage-stat` rather than the
// trigger-schedule kind that takes real window parameters. It accepts NO parameters, so there is nothing
// to clamp and nothing to 422 over, and it never reports truncation.
//
// An UNMOUNTED conversation returns 200 with the zero projection (empty path, exists=false), not 404:
// "this thread has no residency" is a successful answer to the question, and the button that calls this
// has to render the unmounted state too. Only an unknown conversation is a 404.
//
// WorkDir 返回某对话驻地的活投影：已挂路径 + 此刻关于它为真的东西（存在 / 是否 git 仓库 / 分支 / 脏）。
// 逐请求现算、零缓存——文件系统与 git 才是真相，故用户刚删掉的目录、或刚在自己终端里切的分支，读作它
// **现在的样子**。
//
// N4：派生的**有界投影**，故无游标、无 `nextCursor`。它根本不是已存集合——它是**一个**按需现算的对象，与
// `GET /storage-stat` 同类，而**不是** trigger-schedule 那种收真窗口参数的一类。它**不收任何参数**，故无从
// 钳制、无从 422，也从不上报截断。
//
// **未挂**对话返 200 + 零投影（空路径、exists=false）、**不是** 404：「这条线程没有驻地」是对该问题的一个
// **成功**回答，而调用它的那个按钮也得渲染未挂态。只有对话本身不存在才是 404。
func (h *ConversationHandler) WorkDir(w http.ResponseWriter, r *http.Request) {
	info, err := h.svc.WorkDirInfo(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, info)
}

// WorkDirGroups returns the rail's residency grouping: one row per directory some UNPINNED thread lives
// in, `{workDir, activeCount, archivedCount, lastMessageAt}`, most-recently-active first.
//
// It exists because the rail pages FOREVER. Grouping one page client-side would make membership and counts
// DRIFT as the user scrolls — the head would state a number that changes while nothing changes — so the
// grouping is computed over the whole workspace in one GROUP BY.
//
// The counted set is the UNPINNED threads: a pinned thread is hoisted into the rail's own Pinned section and
// must appear exactly once, so counting it here would make the head's number disagree with the rows under
// it. The same rule governs `:archive-workdir` / `:delete-workdir`, which is what lets ONE number head the
// group AND inventory its confirm dialog.
//
// N4 — a BOUNDED PROJECTION, "zero-parameter" form: no cursor, no `nextCursor`, and NO parameters at all
// (hence nothing to clamp, nothing to 422 over, no truncation to report). It is bounded by how many
// directories a person mounts, which is a human-scale set like `workspaces` — not by how many conversations
// exist. The two counts are reported SEPARATELY rather than behind an `?archived=` scope precisely to keep
// it parameterless: the rail's toggle picks or sums them, and a bulk action (deliberately scope-blind)
// inventories the sum.
//
// WorkDirGroups 返回 rail 的驻地分组:每个住着**未置顶**线程的目录一行，`{workDir, activeCount, archivedCount,
// lastMessageAt}`，最近活跃在前。
//
// 它存在，是因为 rail **无限**翻页。在一窗内做客户端分组会让成员与计数随滚动**漂移**——组头会报出一个在什么
// 都没变时自己会变的数——故分组对整个 workspace 一次 GROUP BY 算出。
//
// 被计数的集合是**未置顶**线程:置顶线程被提到 rail 自己的置顶段、必须恰好出现一次，故在此计入它会让组头的数与
// 它下面的行不一致。`:archive-workdir` / `:delete-workdir` 遵守同一条规则，正是这一点让**一个**数既作组头、
// 又作它的确认框盘点。
//
// N4——**有界投影**的「零参数」形:无游标、无 `nextCursor`、**不收任何参数**（故无从钳制、无从 422、从不上报
// 截断）。它的有界性来自「一个人会挂多少个目录」，那是与 `workspaces` 同量级的人类尺度集合——**不是**来自有多少
// 条对话。两个计数**分开**上报、而不是藏在 `?archived=` 范围之后，正是为了让它保持零参数:rail 的开关自行取其一
// 或求和，而批量动作（刻意对范围盲）盘点二者之和。
func (h *ConversationHandler) WorkDirGroups(w http.ResponseWriter, r *http.Request) {
	groups, err := h.svc.WorkDirGroups(r.Context())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, groups)
}

// workDirActionRequest is the body of both residency-wide actions: which group.
//
// workDirActionRequest 是两个驻地级动作的 body:哪个组。
type workDirActionRequest struct {
	WorkDir string `json:"workDir"`
}

// ArchiveWorkDir handles `POST /api/v1/conversations:archive-workdir` — file away one residency group's
// threads in ONE request. Returns `{workDir, archived}` where `archived` is how many conversations actually
// CHANGED (already-archived rows are not counted twice).
//
// A collection-level `:action` (N5), sibling of `POST /notifications:mark-all-read`. The rail needs it
// rather than a loop of N PATCHes for reasons that are not about speed: a loop can be interrupted half-way,
// leaving a group the user asked to file away neither filed nor unfiled, and a loop's N-th failure has
// nothing honest to report. One statement in one transaction has exactly two outcomes.
//
// An EMPTY `workDir` is refused 400 `INVALID_REQUEST`: the unmounted threads are a legitimate list FILTER
// but not a group — they have no folder head and no ⋯ menu — so accepting it would let one request file away
// every thread in the workspace that never picked a directory. A non-absolute path is 422
// `CONVERSATION_INVALID_WORK_DIR` (WD1's rule: a relative root roots nothing).
//
// ArchiveWorkDir 处理 `POST /api/v1/conversations:archive-workdir`——**一个**请求收起一个驻地组的线程。返回
// `{workDir, archived}`，其中 `archived` 是真正**改变**了的对话数（已归档的行不重复计入）。
//
// 集合级 `:action`（N5），与 `POST /notifications:mark-all-read` 同族。rail 需要它而不是 N 次 PATCH 的循环，
// 理由与速度无关:循环可能半途被打断，把用户要收起的一组留在既非收起也非未收起的状态，而循环的第 N 次失败没有
// 任何诚实的话可报。一个事务里的一条语句恰好只有两种结局。
//
// **空** `workDir` 拒为 400 `INVALID_REQUEST`:未挂的线程是一个正当的列表**过滤**、但不是一个**组**——它们没有
// 文件夹头、没有 ⋯ 菜单——故接受它会让一个请求收起本 workspace 里每一条从未选过目录的线程。非绝对路径为 422
// `CONVERSATION_INVALID_WORK_DIR`（WD1 的规则:相对的根扎不住任何东西）。
func (h *ConversationHandler) ArchiveWorkDir(w http.ResponseWriter, r *http.Request) {
	var req workDirActionRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	n, err := h.svc.ArchiveWorkDir(r.Context(), req.WorkDir)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{"workDir": req.WorkDir, "archived": n})
}

// DeleteWorkDir handles `POST /api/v1/conversations:delete-workdir` — delete one residency group's threads
// in ONE request. Returns `{workDir, deleted}`.
//
// WHAT IT DELETES, exactly: the `deleted_at` stamp on those `conversations` rows, plus each thread's
// relation edges and touchpoint ledger (derived indexes of a thread that no longer exists — the same
// cascade a single DELETE performs). WHAT IT DOES NOT DELETE: any message row. `messages` /
// `message_blocks` are D1 Log tables — no `deleted_at`, never physically deleted — so the transcripts stay
// on disk byte-for-byte. And nothing on the FILESYSTEM: the residency is a string on a row, read here as a
// grouping key; the directory it names is never touched. That is why the UI's word for this action is
// «delete all conversations» and never «delete the directory».
//
// Scope-BLIND across archive states, on purpose: a destructive action must not silently depend on which
// view toggle happens to be on. Pinned threads of that residency are NOT deleted — pinning is the user
// saying "this one matters", and a folder-wide sweep should not carry it off.
//
// DeleteWorkDir 处理 `POST /api/v1/conversations:delete-workdir`——**一个**请求删除一个驻地组的线程。返回
// `{workDir, deleted}`。
//
// **它到底删了什么**:那些 `conversations` 行上的 `deleted_at` 戳，加上每条线程的 relation 边与触点台账（一条
// 已不存在的线程的派生索引——与单条 DELETE 完全相同的级联）。**它没有删什么**:任何消息行。`messages` /
// `message_blocks` 是 D1 Log 表——无 `deleted_at`、绝不物理删——故那些逐字记录**逐字节留在盘上**。以及**文件
// 系统上什么都没动**:驻地是行上的一个字符串，在此被当作分组键读;它点出的那个目录绝不被碰。正因如此，UI 给这个
// 动作的用词是「删除全部对话」、而**绝不是**「删除目录」。
//
// **跨归档态、对范围盲**，刻意如此:一个破坏性动作不该静默地取决于哪个视图开关正好开着。该驻地的**置顶**线程
// **不**被删——置顶是用户在说「这条我在意」，一次目录级的清扫不该把它一并带走。
func (h *ConversationHandler) DeleteWorkDir(w http.ResponseWriter, r *http.Request) {
	var req workDirActionRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	n, err := h.svc.DeleteWorkDir(r.Context(), req.WorkDir)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{"workDir": req.WorkDir, "deleted": n})
}

func (h *ConversationHandler) Delete(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Delete(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}
