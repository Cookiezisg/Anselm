package bootstrap

import (
	"context"
	"net/http"
	"os"
	"path/filepath"

	"go.uber.org/zap"

	agentapp "github.com/sunweilin/anselm/backend/internal/app/agent"
	aispawnapp "github.com/sunweilin/anselm/backend/internal/app/aispawn"
	apikeyapp "github.com/sunweilin/anselm/backend/internal/app/apikey"
	approvalapp "github.com/sunweilin/anselm/backend/internal/app/approval"
	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	catalogapp "github.com/sunweilin/anselm/backend/internal/app/catalog"
	chatapp "github.com/sunweilin/anselm/backend/internal/app/chat"
	contextmgrapp "github.com/sunweilin/anselm/backend/internal/app/contextmgr"
	controlapp "github.com/sunweilin/anselm/backend/internal/app/control"
	conversationapp "github.com/sunweilin/anselm/backend/internal/app/conversation"
	documentapp "github.com/sunweilin/anselm/backend/internal/app/document"
	envfixapp "github.com/sunweilin/anselm/backend/internal/app/envfix"
	freetierapp "github.com/sunweilin/anselm/backend/internal/app/freetier"
	functionapp "github.com/sunweilin/anselm/backend/internal/app/function"
	handlerapp "github.com/sunweilin/anselm/backend/internal/app/handler"
	mcpapp "github.com/sunweilin/anselm/backend/internal/app/mcp"
	mediaapp "github.com/sunweilin/anselm/backend/internal/app/media"
	memoryapp "github.com/sunweilin/anselm/backend/internal/app/memory"
	modelapp "github.com/sunweilin/anselm/backend/internal/app/model"
	modelprofileapp "github.com/sunweilin/anselm/backend/internal/app/modelprofile"
	notificationapp "github.com/sunweilin/anselm/backend/internal/app/notification"
	relationapp "github.com/sunweilin/anselm/backend/internal/app/relation"
	sandboxapp "github.com/sunweilin/anselm/backend/internal/app/sandbox"
	schedulerapp "github.com/sunweilin/anselm/backend/internal/app/scheduler"
	searchapp "github.com/sunweilin/anselm/backend/internal/app/search"
	settingsapp "github.com/sunweilin/anselm/backend/internal/app/settings"
	skillapp "github.com/sunweilin/anselm/backend/internal/app/skill"
	speechapp "github.com/sunweilin/anselm/backend/internal/app/speech"
	storageapp "github.com/sunweilin/anselm/backend/internal/app/storage"
	subagentapp "github.com/sunweilin/anselm/backend/internal/app/subagent"
	todoapp "github.com/sunweilin/anselm/backend/internal/app/todo"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	agenttool "github.com/sunweilin/anselm/backend/internal/app/tool/agent"
	approvaltool "github.com/sunweilin/anselm/backend/internal/app/tool/approval"
	asktool "github.com/sunweilin/anselm/backend/internal/app/tool/ask"
	attachmenttool "github.com/sunweilin/anselm/backend/internal/app/tool/attachment"
	blockstool "github.com/sunweilin/anselm/backend/internal/app/tool/blocks"
	controltool "github.com/sunweilin/anselm/backend/internal/app/tool/control"
	conversationtool "github.com/sunweilin/anselm/backend/internal/app/tool/conversation"
	documenttool "github.com/sunweilin/anselm/backend/internal/app/tool/document"
	filesystemtool "github.com/sunweilin/anselm/backend/internal/app/tool/filesystem"
	functiontool "github.com/sunweilin/anselm/backend/internal/app/tool/function"
	handlertool "github.com/sunweilin/anselm/backend/internal/app/tool/handler"
	mcptool "github.com/sunweilin/anselm/backend/internal/app/tool/mcp"
	memorytool "github.com/sunweilin/anselm/backend/internal/app/tool/memory"
	modeltool "github.com/sunweilin/anselm/backend/internal/app/tool/model"
	mounttool "github.com/sunweilin/anselm/backend/internal/app/tool/mount"
	relationtool "github.com/sunweilin/anselm/backend/internal/app/tool/relation"
	searchtool "github.com/sunweilin/anselm/backend/internal/app/tool/search"
	shelltool "github.com/sunweilin/anselm/backend/internal/app/tool/shell"
	skilltool "github.com/sunweilin/anselm/backend/internal/app/tool/skill"
	subagenttool "github.com/sunweilin/anselm/backend/internal/app/tool/subagent"
	todotool "github.com/sunweilin/anselm/backend/internal/app/tool/todo"
	triggertool "github.com/sunweilin/anselm/backend/internal/app/tool/trigger"
	webtool "github.com/sunweilin/anselm/backend/internal/app/tool/web"
	workflowtool "github.com/sunweilin/anselm/backend/internal/app/tool/workflow"
	touchpointapp "github.com/sunweilin/anselm/backend/internal/app/touchpoint"
	triggerapp "github.com/sunweilin/anselm/backend/internal/app/trigger"
	workflowapp "github.com/sunweilin/anselm/backend/internal/app/workflow"
	workspaceapp "github.com/sunweilin/anselm/backend/internal/app/workspace"
	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
	touchpointdomain "github.com/sunweilin/anselm/backend/internal/domain/touchpoint"
	cryptoinfra "github.com/sunweilin/anselm/backend/internal/infra/crypto"
	skillfs "github.com/sunweilin/anselm/backend/internal/infra/fs/skill"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	mcpinfra "github.com/sunweilin/anselm/backend/internal/infra/mcp"
	sandboxinfra "github.com/sunweilin/anselm/backend/internal/infra/sandbox"
	searchengine "github.com/sunweilin/anselm/backend/internal/infra/search/engine"
	pathguardpkg "github.com/sunweilin/anselm/backend/internal/pkg/pathguard"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// services holds every constructed app Service — the handlers read these, and the boot/shutdown
// sequence calls lifecycle methods on the few that own background work (sandbox/handler/mcp/
// trigger/scheduler/chat).
//
// services 持有所有构造好的 app Service——handler 读它们，boot/shutdown 序列对少数持后台工作的
// （sandbox/handler/mcp/trigger/scheduler/chat）调生命周期方法。
type services struct {
	workspace     *workspaceapp.Service
	apikey        *apikeyapp.Service
	freetier      *freetierapp.Provisioner
	freetierQuota *freetierapp.QuotaReader
	speech        *speechapp.Service
	modelCaps     *modelapp.CapabilityService
	modelProfile  *modelprofileapp.Service
	media         *mediaapp.Service
	relation      *relationapp.Service
	catalog       *catalogapp.Service
	notification  *notificationapp.Service
	memory        *memoryapp.Service
	sandbox       *sandboxapp.Service
	document      *documentapp.Service
	todo          *todoapp.Service
	touchpoint    *touchpointapp.Service
	attachment    *attachmentapp.Service
	function      *functionapp.Service
	handler       *handlerapp.Service
	agent         *agentapp.Service
	trigger       *triggerapp.Service
	mcp           *mcpapp.Service
	skill         *skillapp.Service
	control       *controlapp.Service
	approval      *approvalapp.Service
	workflow      *workflowapp.Service
	scheduler     *schedulerapp.Service
	settings      *settingsapp.Service
	storage       *storageapp.Service
	conversation  *conversationapp.Service
	chat          *chatapp.Service
	subagent      *subagentapp.Service
	contextmgr    *contextmgrapp.Service
	aispawn       *aispawnapp.Service
	search        *searchapp.Service
	shellMgr      *shelltool.ProcessManager // owns run_in_background children; Stop() reaps them on shutdown (R1)

	// toolCatalog is the authorizable-tool descriptors (name + one-line summary) served read-only by
	// GET /api/v1/tools — the allowed-tools picker's BUILTIN candidates (entity ids + MCP tools come
	// from their own live endpoints). 可授权工具目录(名+一行简述),GET /tools;选择器内置候选。
	toolCatalog []toolapp.Descriptor
	// toolNames is the final toolset's name inventory, retained for the touchpoint catalog's
	// exhaustiveness gate test (every tool must declare its ledger stance).
	// toolNames 是定型工具集的名字清单,留给 touchpoint 目录穷尽性门禁测试(每个工具必须表态)。
	toolNames []string
}

// toolsetHolder is a mutable ToolsProvider: the subagent Service and agent invoke-deps read the
// toolset lazily (at spawn / invoke time), but the toolset isn't final until the Subagent tool is
// appended — which itself needs the subagent Service. The holder breaks that cycle.
//
// toolsetHolder 是可变 ToolsProvider：subagent Service 与 agent invoke-deps 懒读工具集（spawn / invoke
// 时），但工具集要等 Subagent 工具追加后才定型——而那又需 subagent Service。holder 破此环。
type toolsetHolder struct{ tools []toolapp.Tool }

func (h *toolsetHolder) Tools() []toolapp.Tool { return h.tools }

// buildServices constructs all 28 app Services in dependency order, wires every cross-Service
// adapter, the toolset, and all post-construction injection (relation syncers / catalog
// sources / mention resolvers / invoke deps / ref resolver). mux is the shared ServeMux trigger
// registers webhook routes on; dataDir roots the file-backed stores + sandbox.
//
// buildServices 按依赖序构造全部 28 个 app Service，接好每个跨 Service 适配器、工具集，
// 以及所有装配后注入。mux 是 trigger 注册 webhook 路由的共享 mux；dataDir 是文件式 store + sandbox 的根。
func buildServices(st *stores, inf infra, bus buses, mux *http.ServeMux, dataDir string, log *zap.Logger) *services {
	// --- Tier 0: leaves (no app-Service dependencies) ---
	notif := notificationapp.NewService(st.notification, bus.notifications, log)
	ws := workspaceapp.NewService(st.workspace, log)
	keys := apikeyapp.NewService(st.apikey, inf.encryptor, apikeyapp.NewHTTPTester(inf.proofHTTP), log)
	freetier := freetierapp.NewProvisioner(keys, ws, llminfra.NewInstallClient(inf.proofHTTP, inf.proofPublicKey), cryptoinfra.MachineFingerprint, log)
	freetierQuota := freetierapp.NewQuotaReader(keys, llminfra.NewQuotaClient(inf.proofHTTP), log)
	speech := speechapp.New(keys)
	modelCaps := modelapp.NewCapabilityService(keys, log)
	modelProfile := modelprofileapp.NewService(st.modelprofile, log)
	cat := catalogapp.NewService(log)
	mem := memoryapp.NewService(st.memory, notif, log)
	sbx := sandboxapp.NewService(st.sandbox, dataDir, notif, log)
	// search: one engine behind every surface (omni/vertical/blocks/RAG); sources and
	// notifiers wire post-construction, the worker starts at App.Boot.
	// search：所有出口背后的同一个引擎（综搜/垂搜/积木/RAG）；source 与 notifier 在装配后
	// 接线，worker 于 App.Boot 启动。
	searchSvc := searchapp.NewService(st.search, log)
	searchSvc.SetEmbeddingProviders(searchengine.NewBuiltin(sbx, log), func(baseURL, model string) searchdomain.EmbeddingProvider {
		return searchengine.NewOllama(baseURL, model)
	})
	searchSvc.SetSifter(&llmSifter{picker: ws, keys: keys, factory: inf.factory})

	// model-resolution chain (one core, four scenario wrappers) + caps/window lookup.
	lookup := NewModelInfoLookup(modelCaps)
	resolvers := NewModelResolvers(ws, keys, inf.factory, lookup)

	// envfix provisions a function/handler's sandbox env on demand (LLM-driven repair loop).
	prov := envfixapp.NewProvisioner(sbx, ws, keys, inf.factory, log)

	// --- Tier 1: entities (relation injected post-construction; nil-tolerant at build) ---
	doc := documentapp.NewService(st.document, notif, log)
	todo := todoapp.NewService(st.todo, bus.messages, log)
	att := attachmentapp.NewService(st.attachment, st.blob, attachmentapp.NewSandboxExtractor(sbx), log)
	media := mediaapp.NewService(att, st.media, st.mediaArtifacts, log)
	media.SetProcessor(mediaapp.NewImageProcessor())
	fn := functionapp.NewService(st.function, prov, functionapp.NewSandboxAdapter(sbx, dataDir, bus.entities), notif, log)
	fn.SetEntitiesBridge(bus.entities) // SSE-C: env 物化尝试行 tee 到 function 构建终端（不分入口）
	hd := handlerapp.NewService(st.handler, prov, handlerapp.NewSandboxAdapter(sbx, dataDir), inf.encryptor, handlerapp.DefaultClientFactory, notif, log)
	hd.SetEntitiesBridge(bus.entities) // SSE-C: Call tees method yields to the handler's run terminal
	ag := agentapp.NewService(st.agent, notif, log)
	ctl := controlapp.NewService(st.control, notif, log)
	apf := approvalapp.NewService(st.approval, notif, log)
	mcp := mcpapp.NewService(st.mcp, mcpinfra.NewCuratedCatalog(mcpinfra.NewGitHubRegistrySource(dataDir, log)), sbx, log)
	mcp.SetEntitiesBridge(bus.entities) // SSE-C: CallTool tees progress to the server's run terminal
	conv := conversationapp.NewService(st.conversation, notif, log)
	trg := triggerapp.NewService(st.trigger, mux, NewSensorInvoker(fn, hd, mcp), log)
	trg.SetEntitiesBridge(bus.entities)                                 // SSE-C: every fan-out emits a fire signal to the trigger panel
	trg.SetSensorTargetValidator(NewSensorTargetValidator(fn, hd, mcp)) // F102: reject a sensor whose fn/hd/mcp target is dangling at create/edit
	wf := workflowapp.NewService(st.workflow, nil, notif, log)          // resolver set below

	// --- durable workflow interpreter (before the toolset: the flowrun-observability tools read it) ---
	// --- durable workflow 解释器（先于 toolset：flowrun 可观测工具要读它）---
	sched := schedulerapp.NewService(st.flowrun, wf, ctl, apf, NewDispatcher(fn, hd, mcp, ag), st.trigger, log)
	sched.SetEntitiesBridge(bus.entities) // SSE-C: Advance streams node progress to the workflow panel

	// --- subagent + skill: subagent reads the toolset lazily via the holder ---
	holder := &toolsetHolder{}
	subagentSvc := subagentapp.NewService(subagentapp.Deps{
		Messages: st.messages,
		Resolver: resolvers.Subagent(),
		Tools:    holder,
		Bridge:   bus.messages,
	}, log)
	skill := skillapp.NewService(st.skill, subagentSvc, notif, log)

	// relation: built with every entity's name resolver (read-time hydration), then injected back
	// into each entity as its RelationSyncer (edge sync on create/edit/delete).
	rel := relationapp.NewService(relationapp.Config{
		Repo: st.relation,
		Namers: map[string]relationapp.Namer{
			relationdomain.EntityKindFunction:     fn,
			relationdomain.EntityKindHandler:      hd,
			relationdomain.EntityKindAgent:        ag, // workflow→agent equip / conversation→agent built 边的目标端 hydrate
			relationdomain.EntityKindControl:      ctl,
			relationdomain.EntityKindApproval:     apf,
			relationdomain.EntityKindWorkflow:     wf,
			relationdomain.EntityKindTrigger:      trg,
			relationdomain.EntityKindMCP:          mcp,
			relationdomain.EntityKindSkill:        skill,
			relationdomain.EntityKindDocument:     doc,
			relationdomain.EntityKindConversation: conv,
		},
		Notif: notif, // durable dependency-broken notification on entity delete (F161)
		Log:   log,
	})

	// touchpoint: the conversation context ledger. Namers mirror relation's registration (the
	// SAME source-domain resolvers — one vocabulary) plus the ledger-only attachment namer;
	// live signals ride the messages stream (conversation-anchored, like todo).
	// touchpoint:对话上下文台账。Namers 镜像 relation 的注册(同一批 source-domain resolver——
	// 一份词表)+ 台账独有的 attachment namer;实时信号走 messages 流(锚定对话,同 todo)。
	tp := touchpointapp.NewService(touchpointapp.Config{
		Repo:   st.touchpoint,
		Bridge: bus.messages,
		Namers: map[string]touchpointapp.Namer{
			relationdomain.EntityKindFunction:     fn,
			relationdomain.EntityKindHandler:      hd,
			relationdomain.EntityKindAgent:        ag,
			relationdomain.EntityKindControl:      ctl,
			relationdomain.EntityKindApproval:     apf,
			relationdomain.EntityKindWorkflow:     wf,
			relationdomain.EntityKindTrigger:      trg,
			relationdomain.EntityKindMCP:          mcp,
			relationdomain.EntityKindSkill:        skill,
			relationdomain.EntityKindDocument:     doc,
			relationdomain.EntityKindConversation: conv,
			touchpointdomain.ItemKindAttachment:   att,
		},
		Log: log,
	})
	conv.SetTouchpointPurger(tp)

	// --- toolset: Resident (filesystem/search/shell) + Lazy (entity tools + web) ---
	// The skills subtree is exempted from the ~/.anselm deny rule so the LLM's filesystem tools
	// reach bundled skill files (progressive disclosure layer 3, WRK-076 B2); the predicate
	// resolves symlinks so an installed skill can't smuggle a link out of the tree.
	// skills 子树从 ~/.anselm 黑名单精确豁免，使 LLM filesystem 工具触达捆绑文件（渐进披露第 3
	// 层，WRK-076 B2）；谓词先解 symlink，安装的 skill 无法用链接走私出树。
	guard := pathguardpkg.NewDefaultWithAllow(func(abs string) bool {
		return skillfs.IsInSkillsTree(dataDir, abs)
	})
	// Capture the struct, not just .Tools: its Manager owns every run_in_background child's process
	// group, and App.Shutdown must call Manager.Stop() to reap them — else backgrounded jobs (and
	// their whole trees) orphan on every backend exit (R1). The pid manifest under dataDir is the
	// crash half: Boot's ReapStaleOnBoot reaps groups that survived an ungraceful exit (T3).
	// 留住整个 struct 而非只 .Tools：Manager 持每个后台子进程的进程组，Shutdown 须调 Manager.Stop() 回收（R1）。
	// dataDir 下的 pid 清单是崩溃半：Boot 的 ReapStaleOnBoot 收割熬过非优雅退出的进程组（T3）。
	shellPidDir := ""
	if dataDir != "" {
		shellPidDir = filepath.Join(dataDir, "shellpids")
	}
	shellTools := shelltool.NewShellTools(shellPidDir)
	toolset := toolapp.Toolset{
		Resident: concat(
			filesystemtool.FilesystemTools(guard),
			searchtool.SearchTools(guard, log),
			shellTools.Tools,
			[]toolapp.Tool{asktool.New()}, // ask_user — agent asks the human (blocks on the humanloop broker)
			todotool.TodoTools(todo),      // todo_write — the checklist's only write path (the HTTP board is read-only)
		),
		Lazy: concat(
			functiontool.FunctionTools(fn, searchSvc, rel),
			handlertool.HandlerTools(hd, searchSvc, rel),
			agenttool.AgentTools(ag, searchSvc, rel),
			controltool.ControlTools(ctl, searchSvc, rel),
			approvaltool.ApprovalTools(apf, searchSvc, rel),
			workflowtool.WorkflowTools(wf, searchSvc, sched, rel),
			triggertool.TriggerTools(trg, searchSvc, rel),
			documenttool.DocumentTools(doc, searchSvc),
			attachmenttool.AttachmentTools(att),
			memorytool.MemoryTools(mem),
			modeltool.ModelConfigTools(ws, keys, modelCaps),
			mcptool.MCPTools(mcp),
			skilltool.SkillTools(skill, sbx, rel),
			blockstool.BlocksTools(searchSvc),
			conversationtool.ConversationTools(searchSvc, conv),
			relationtool.RelationTools(rel),
			webtool.WebTools(ws, keys, inf.factory, ws, ws, log),
		),
	}
	// Append the Subagent tool (depth-1 guard: the subagent registry always filters it out, so a
	// subagent can never spawn another) + get_subagent_trace (reads a subagent run's hidden trace
	// back from the parent's sub-messages — a subagent's tool set never includes it, no point
	// reading its own siblings). Then publish the final set to the lazy holder.
	toolset.Lazy = append(toolset.Lazy,
		subagenttool.New(subagentSvc, subagentapp.NewRegistry().Names()),
		subagenttool.NewTraceTool(st.messages),
	)
	holder.tools = toolset.All()
	toolNames := make([]string, 0, len(holder.tools))
	for _, t := range holder.tools {
		toolNames = append(toolNames, t.Name())
	}
	// The authorizable-tool catalog snapshot (name + one-line summary), fixed at boot like the
	// toolset itself. 可授权工具目录快照,随工具集在启动时定型。
	toolCatalog := toolset.Catalog()

	// --- context compaction + chat (the dialogue surface) ---
	ctxmgr := contextmgrapp.NewService(contextmgrapp.Deps{
		Messages:      st.messages,
		Conversations: NewConversationSummary(conv),
		Resolver:      resolvers.ContextmgrUtility(),
		Windows:       lookup.WindowResolver(),
	}, log)
	chat := chatapp.NewService(st.messages, chatapp.Deps{
		Conversations: conv,
		Resolver:      resolvers.Chat(),
		Attachments:   NewAttachmentRenderer(att, llminfra.NewMediaClient(inf.proofHTTP), media),
		Toolset:       toolset,
		// Per-request MCP dynamic tools for the ctx workspace (F52): chat ranks + offers them via
		// search_tools just like static lazy tools. Error → no MCP tools (best-effort, never fails a turn).
		DynamicTools: func(ctx context.Context) []toolapp.Tool {
			tools, err := mcptool.DynamicTools(ctx, mcp)
			if err != nil {
				return nil
			}
			return tools
		},
		Memory:          mem,
		Catalog:         cat,
		Documents:       NewDocumentRenderer(doc),
		Todo:            todo,
		Bridge:          bus.messages,
		EntitiesBridge:  bus.entities,
		Titler:          conv,
		Compactor:       ctxmgr,
		RuntimeProfiles: modelProfile,
		Touchpoints:     tp,
		SkillPreauth:    skill, // @skill 激活的预授权半（WRK-076）；内容半走 mention resolver
	}, log)

	// D1 execution lifecycle: workflow drives the trigger binder (activate/stage/deactivate/kill engage
	// or release the listener) + the scheduler runner (trigger/kill drive runs); the scheduler drives
	// workflow's drain reconciler (a draining workflow goes inactive when its last run settles).
	// runnerAdapter bridges the primitive Runner port onto scheduler.StartInput so workflow never
	// imports the scheduler. Re-attach of active workflows on boot is App.Boot's job.
	//
	// D1 执行生命周期：workflow 驱动 trigger binder（激活/试运行/关激活/杀 挂或摘监听）+ 调度器 runner
	// （触发/杀 驱动 run）；调度器驱动 workflow 的排空 reconciler（draining workflow 最后一个 run 结算→inactive）。
	// runnerAdapter 把原生 Runner 端口桥到 scheduler.StartInput，使 workflow 绝不 import 调度器。boot 时重挂
	// active workflow 是 App.Boot 的事。
	wf.SetExecutionPorts(trg, runnerAdapter{sched: sched})
	sched.SetLifecycleReconciler(wf)
	sched.SetNotifier(notif) // run_failed / approval_pending 唤回用户；completed 熄 attention
	// Deleting a conversation cancels its in-flight generation (chat satisfies the port;
	// post-build injection breaks the chat→conversation→chat cycle).
	// 删对话连带取消在途生成（chat 满足该端口；后注入破 chat→conversation→chat 环）。
	conv.SetGenerationCanceler(chat)
	// List/Get derive each row's isGenerating from chat's in-flight registry (same post-build port).
	// List/Get 据 chat 在途登记派生每行 isGenerating（同款后注入端口）。
	conv.SetGeneratingQuerier(chat)
	// List/Get also derive each row's awaitingInput from chat's humanloop broker (pending interactions),
	// so the rail can show a "needs you" dot — same post-build port pattern.
	// List/Get 同样据 chat 的 humanloop broker（待决 interaction）派生每行 awaitingInput，使 rail 显「等你」点——同款后注入端口。
	conv.SetAwaitingInputQuerier(chat)
	// Update validates attachedDocuments against live documents (reject a dangling/deleted doc id at
	// attach time, 422 — F168-M5). doc was built before conv and does not depend on it, so no cycle.
	// Update 据存活文档校验 attachedDocuments（attach 时拒悬挂/已删 doc id，422——F168-M5）。doc 先于 conv
	// 构造且不依赖它，无环。
	conv.SetDocumentResolver(doc)

	// Reject a model override / scenario default pointing at a non-existent apiKeyId at WRITE time
	// (API_KEY_NOT_FOUND) instead of only at invoke (F153). apikey (keys) depends on none of these
	// three, so wiring it as their existence checker introduces no cycle.
	// 在**写**时拒绝指向不存在 apiKeyId 的 model override / scenario 默认（API_KEY_NOT_FOUND），而非只在
	// invoke 时（F153）。apikey（keys）不依赖这三者，作其存在性 checker 注入无环。
	ag.SetKeyChecker(keys)
	conv.SetKeyChecker(keys)
	ws.SetKeyChecker(keys)
	// A setting is configurable only when the exact probed key/model pair publishes its native
	// contract. This prevents stale or crafted clients from persisting options an adapter would
	// otherwise silently discard; empty options still keep unknown models usable.
	// 设置只有在精确已探测 key/model 对公开其原生契约时才可配置。此举阻止陈旧或伪造客户端持久化
	// adapter 原本会静默丢弃的参数；空 options 仍使未知模型可用。
	ag.SetOptionValidator(modelCaps)
	conv.SetOptionValidator(modelCaps)
	ws.SetOptionValidator(modelCaps)
	// stats ports: blob walk + chat's in-flight snapshot (WRK-062 S-11). stats 端口。
	ws.SetStatsPorts(st.blob, chat.GeneratingIDs)

	// apikey delete-guard (RefScanner): refuse to delete a key still referenced, so the
	// reference never dangles. Two real sources — a workspace's scenario default models /
	// search key, and an agent's pinned modelOverride; both implement RefScanner structurally.
	// Without these the guard consults an empty scanner list and API_KEY_IN_USE can never fire.
	//
	// apikey 删除守卫（RefScanner）：仍被引用的 key 拒删，引用绝不悬空。两个真实来源——workspace
	// 的 scenario 默认模型 / 搜索 key，与 agent 钉死的 modelOverride；二者结构上满足 RefScanner。
	// 缺这两行则守卫询问空 scanner 列、API_KEY_IN_USE 永不触发。
	keys.AddRefScanner(ws)
	keys.AddRefScanner(ag)

	// Workspace delete cascades: kill every workflow's automation (detach
	// listeners + cancel in-flight runs + inactive — idempotent on already-inactive ones, and
	// it also reaps manually-triggered runs), stop the workspace's resident handler/mcp
	// processes, then remove its on-disk tree (skills / memories). All on a Detached(target)
	// ctx — the DELETE request may arrive from a DIFFERENT workspace. Best-effort: the row
	// delete that follows is what makes the data unreachable.
	//
	// workspace 删除级联：杀每个 workflow 的自动化（摘监听 + 取消在途 run +
	// inactive——对已 inactive 幂等，且连手动触发的 run 一并收割）、停本 workspace 常驻
	// handler/mcp 进程、删盘上文件树（skills / memories）。全程用 Detached(目标) ctx——
	// DELETE 请求可能来自**另一个** workspace。best-effort：随后的删行才是数据不可达的根因。
	ws.SetReaper(func(_ context.Context, wsID string) {
		wsCtx := reqctxpkg.Detached(wsID)
		if wfs, err := wf.ListAll(wsCtx); err == nil {
			for _, w := range wfs {
				if _, kerr := wf.Kill(wsCtx, w.ID); kerr != nil {
					log.Warn("workspace reaper: kill workflow failed",
						zap.String("workspaceId", wsID), zap.String("workflowId", w.ID), zap.Error(kerr))
				}
			}
		} else {
			log.Warn("workspace reaper: list workflows failed", zap.String("workspaceId", wsID), zap.Error(err))
		}
		hd.StopWorkspaceInstances(wsCtx)
		mcp.DisconnectWorkspace(wsCtx)
		if perr := searchSvc.PurgeWorkspace(wsCtx, wsID); perr != nil {
			log.Warn("workspace reaper: purge search index failed", zap.String("workspaceId", wsID), zap.Error(perr))
		}
		if dataDir != "" {
			if rerr := os.RemoveAll(filepath.Join(dataDir, "workspaces", wsID)); rerr != nil {
				log.Warn("workspace reaper: remove file tree failed", zap.String("workspaceId", wsID), zap.Error(rerr))
			}
		}
	})

	// Provision the built-in free-tier credential for a newly created workspace in the background.
	// The Boot loop only covers workspaces that exist at startup; a fresh data dir has none, so this
	// hook is the load-bearing first-run path. Async + best-effort (EnsureForWorkspace always returns
	// nil): never block or fail Create on a slow/down gateway — a failure just means no free tier
	// until the next Boot re-provisions. Detached(wsID) seeds the workspace the row is isolated by.
	//
	// 为新建 workspace 在后台开通内置免费档凭证。Boot 循环只覆盖启动时已存在的；全新 data dir 一个没有，
	// 故此钩子是首启的承载路径。异步 + best-effort（EnsureForWorkspace 恒返 nil）：绝不因网关慢/挂而阻塞或
	// 失败 Create——失败只是没免费档、下次 Boot 重开通。Detached(wsID) 种受管行隔离所依的 workspace。
	ws.SetOnCreated(func(_ context.Context, wsID string) {
		go freetier.EnsureForWorkspace(reqctxpkg.Detached(wsID))
	})

	// === post-construction injection ===
	// agent's ReAct deps: LLM resolver + mount synthesis (the agent's tool universe is exactly its
	// fn_/hd_/mcp mounts — never the system-tool registry) + skill guide + knowledge prefix.
	// agent 的 ReAct 依赖：LLM resolver + 挂载合成（agent 的工具宇宙恰是其 fn_/hd_/mcp 挂载——绝非系统
	// 工具表）+ skill 指南 + knowledge 前缀。
	ag.SetInvokeDeps(agentapp.InvokeDeps{
		Resolver:       resolvers.Agent(),
		Mounts:         mounttool.NewResolver(fn, hd, mcp),
		Skill:          skill,
		Knowledge:      NewKnowledgeProvider(doc),
		EntitiesBridge: bus.entities, // SSE-C: agent run mirrors its ReAct trace to the agent panel
	})
	// workflow ref resolution (CapabilityCheck + pin closure determinism).
	wf.SetResolver(NewRefResolver(fn, hd, ag, ctl, apf, trg, mcp))

	fn.SetRelationSyncer(rel)
	hd.SetRelationSyncer(rel)
	ag.SetRelationSyncer(rel)
	ctl.SetRelationSyncer(rel)
	apf.SetRelationSyncer(rel)
	wf.SetRelationSyncer(rel)
	trg.SetRelationSyncer(rel)
	mcp.SetRelationSyncer(rel)
	skill.SetRelationSyncer(rel)
	doc.SetRelationSyncer(rel)
	conv.SetRelationSyncer(rel)

	// catalog: the LLM-facing "what entities exist" menu, aggregated from each build source.
	cat.RegisterSource(fn.AsCatalogSource())
	cat.RegisterSource(hd.AsCatalogSource())
	cat.RegisterSource(ag.AsCatalogSource())
	cat.RegisterSource(ctl.AsCatalogSource())
	cat.RegisterSource(apf.AsCatalogSource())
	cat.RegisterSource(wf.AsCatalogSource())
	cat.RegisterSource(trg.AsCatalogSource())
	cat.RegisterSource(mcp.AsCatalogSource())
	cat.RegisterSource(skill.AsCatalogSource())
	cat.RegisterSource(doc.AsCatalogSource())
	cat.RegisterSource(att.AsCatalogSource())

	// chat @mention resolvers (freeze-on-send snapshot, eight mentionable build kinds).
	chat.RegisterMentionResolver(doc.AsMentionResolver())
	chat.RegisterMentionResolver(fn.AsMentionResolver())
	chat.RegisterMentionResolver(hd.AsMentionResolver())
	chat.RegisterMentionResolver(wf.AsMentionResolver())
	chat.RegisterMentionResolver(ag.AsMentionResolver())
	chat.RegisterMentionResolver(trg.AsMentionResolver())
	chat.RegisterMentionResolver(ctl.AsMentionResolver())
	chat.RegisterMentionResolver(apf.AsMentionResolver())
	chat.RegisterMentionResolver(skill.AsMentionResolver()) // @skill = 激活（WRK-076）

	// search wiring: 12 entity projections in, one notifier out to every writer
	// (incl. chat/subagent message completion — anchor routes the incremental path).
	// search 接线：12 个实体投影接入，一个 notifier 发给所有写者（含 chat/subagent 的
	// message 完成——anchor 路由增量路径）。
	searchSvc.RegisterSource(fn.SearchSource())
	searchSvc.RegisterSource(hd.SearchSource())
	searchSvc.RegisterSource(ag.SearchSource())
	searchSvc.RegisterSource(wf.SearchSource())
	searchSvc.RegisterSource(trg.SearchSource())
	searchSvc.RegisterSource(ctl.SearchSource())
	searchSvc.RegisterSource(apf.SearchSource())
	searchSvc.RegisterSource(doc.SearchSource())
	searchSvc.RegisterSource(conv.SearchSource(st.messages))
	searchSvc.RegisterSource(mem.SearchSource())
	searchSvc.RegisterSource(skill.SearchSource())
	searchSvc.RegisterSource(mcp.SearchSource())
	sn := searchSvc.Notifier()
	fn.SetSearchNotifier(sn)
	hd.SetSearchNotifier(sn)
	ag.SetSearchNotifier(sn)
	wf.SetSearchNotifier(sn)
	trg.SetSearchNotifier(sn)
	ctl.SetSearchNotifier(sn)
	apf.SetSearchNotifier(sn)
	doc.SetSearchNotifier(sn)
	conv.SetSearchNotifier(sn)
	mem.SetSearchNotifier(sn)
	skill.SetSearchNotifier(sn)
	mcp.SetSearchNotifier(sn)
	chat.SetSearchNotifier(sn)
	subagentSvc.SetSearchNotifier(sn)
	// events.md 的 mcp.{installed,updated,removed,reconnected} 族——缺此线整族哑火。
	mcp.SetNotifier(notif)

	s := &services{
		workspace: ws, apikey: keys, modelCaps: modelCaps, modelProfile: modelProfile, media: media, relation: rel, catalog: cat,
		notification: notif, memory: mem, sandbox: sbx, document: doc, todo: todo,
		touchpoint: tp, toolNames: toolNames, toolCatalog: toolCatalog,
		attachment: att, function: fn, handler: hd, agent: ag, trigger: trg, mcp: mcp,
		skill: skill, control: ctl, approval: apf, workflow: wf, scheduler: sched,
		conversation: conv, chat: chat, subagent: subagentSvc, contextmgr: ctxmgr,
		search: searchSvc, shellMgr: shellTools.Manager, freetier: freetier, freetierQuota: freetierQuota, speech: speech,
	}
	// aispawn composes conversation + chat + a prefix-dispatched execution renderer; built
	// last since it reads the assembled services.
	//
	// aispawn 组合 conversation + chat + 前缀分发执行渲染器；最后建（它读已装配的 services）。
	s.aispawn = newAispawn(s, log)
	// Let :iterate validate its target exists before spawning (chat owns the mention resolvers).
	// 让 :iterate 在 spawn 前确认目标存在（chat 持 mention resolver）。
	s.aispawn.SetMentionValidator(s.chat)
	return s
}

// registerSandboxStack registers the four self-built runtime installers (python/node/uv/dotnet, each
// fetching its pinned tarball straight from upstream on first use) + the docker installer + the four
// env managers. No mise, no embed, no bootstrap gate — the installers carry no host state.
// PythonEnvManager takes the Service as its ToolRegistry.
//
// registerSandboxStack 注册四个自研运行时 installer（python/node/uv/dotnet，各自首次使用时直接从上游拉
// 钉死的 tarball）+ docker installer + 4 个 env manager。无 mise、无内嵌、无 bootstrap 门控——installer
// 不持有宿主状态。PythonEnvManager 以 Service 作 ToolRegistry。
func registerSandboxStack(svc *sandboxapp.Service) {
	for _, inst := range sandboxinfra.DirectInstallers() {
		svc.RegisterInstaller(inst)
	}
	// Search embedder artifacts (llama-server + GGUF model) ride the same
	// installer registry — one download discipline for everything (§decisions/0001).
	// 搜索 embedder 产物（llama-server + GGUF 模型）走同一 installer 注册表——
	// 全部下载共用一套纪律（§decisions/0001）。
	for _, inst := range sandboxinfra.EngineInstallers() {
		svc.RegisterInstaller(inst)
	}
	svc.RegisterInstaller(sandboxinfra.NewDockerInstaller())
	svc.RegisterEnvManager(sandboxinfra.NewPythonEnvManager(svc))
	svc.RegisterEnvManager(sandboxinfra.NewNodeEnvManager())
	svc.RegisterEnvManager(sandboxinfra.NewDockerEnvManager())
	svc.RegisterEnvManager(sandboxinfra.NewDotnetEnvManager())
}

// concat flattens tool groups into one slice.
//
// concat 把多个工具组展平成一个切片。
func concat(groups ...[]toolapp.Tool) []toolapp.Tool {
	var out []toolapp.Tool
	for _, g := range groups {
		out = append(out, g...)
	}
	return out
}
