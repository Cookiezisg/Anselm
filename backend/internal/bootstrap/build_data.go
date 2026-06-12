package bootstrap

import (
	"fmt"

	cryptodomain "github.com/sunweilin/forgify/backend/internal/domain/crypto"
	cryptoinfra "github.com/sunweilin/forgify/backend/internal/infra/crypto"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	blobfs "github.com/sunweilin/forgify/backend/internal/infra/fs/blob"
	memoryfs "github.com/sunweilin/forgify/backend/internal/infra/fs/memory"
	skillfs "github.com/sunweilin/forgify/backend/internal/infra/fs/skill"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	searchstore "github.com/sunweilin/forgify/backend/internal/infra/search"
	agentstore "github.com/sunweilin/forgify/backend/internal/infra/store/agent"
	apikeystore "github.com/sunweilin/forgify/backend/internal/infra/store/apikey"
	approvalstore "github.com/sunweilin/forgify/backend/internal/infra/store/approval"
	attachmentstore "github.com/sunweilin/forgify/backend/internal/infra/store/attachment"
	controlstore "github.com/sunweilin/forgify/backend/internal/infra/store/control"
	conversationstore "github.com/sunweilin/forgify/backend/internal/infra/store/conversation"
	documentstore "github.com/sunweilin/forgify/backend/internal/infra/store/document"
	flowrunstore "github.com/sunweilin/forgify/backend/internal/infra/store/flowrun"
	functionstore "github.com/sunweilin/forgify/backend/internal/infra/store/function"
	handlerstore "github.com/sunweilin/forgify/backend/internal/infra/store/handler"
	mcpstore "github.com/sunweilin/forgify/backend/internal/infra/store/mcp"
	messagesstore "github.com/sunweilin/forgify/backend/internal/infra/store/messages"
	notificationstore "github.com/sunweilin/forgify/backend/internal/infra/store/notification"
	relationstore "github.com/sunweilin/forgify/backend/internal/infra/store/relation"
	sandboxstore "github.com/sunweilin/forgify/backend/internal/infra/store/sandbox"
	todostore "github.com/sunweilin/forgify/backend/internal/infra/store/todo"
	triggerstore "github.com/sunweilin/forgify/backend/internal/infra/store/trigger"
	workflowstore "github.com/sunweilin/forgify/backend/internal/infra/store/workflow"
	workspacestore "github.com/sunweilin/forgify/backend/internal/infra/store/workspace"
	streaminfra "github.com/sunweilin/forgify/backend/internal/infra/stream"
	ormpkg "github.com/sunweilin/forgify/backend/internal/pkg/orm"
)

// stores holds every orm-backed Repository implementation plus the three file-backed stores
// (memory / skill / blob). The concrete *Store types satisfy their domain Repository interfaces
// when handed to each Service constructor.
//
// stores 持有所有 orm 仓储实现 + 三个文件式 store（memory/skill/blob）。具体 *Store 类型在喂给
// 各 Service 构造器时满足其 domain Repository 接口。
type stores struct {
	workspace    *workspacestore.Store
	apikey       *apikeystore.Store
	relation     *relationstore.Store
	notification *notificationstore.Store
	sandbox      *sandboxstore.Store
	document     *documentstore.Store
	todo         *todostore.Store
	attachment   *attachmentstore.Store
	function     *functionstore.Store
	handler      *handlerstore.Store
	agent        *agentstore.Store
	trigger      *triggerstore.Store
	mcp          *mcpstore.Store
	control      *controlstore.Store
	approval     *approvalstore.Store
	workflow     *workflowstore.Store
	flowrun      *flowrunstore.Store
	conversation *conversationstore.Store
	messages     *messagesstore.Store
	search       *searchstore.Store

	memory *memoryfs.Store
	skill  *skillfs.Store
	blob   *blobfs.Store
}

// infra holds the stateless infrastructure singletons shared across services.
//
// infra 持有跨服务共享的无状态基础设施单例。
type infra struct {
	factory   *llminfra.Factory
	encryptor cryptodomain.Encryptor
}

// buses holds the three (and only three, E1) SSE buses: messages (chat/loop turns), entities
// (the forge eventlog), notifications (the durable inbox). Each *Bus satisfies streamdomain.Bridge.
//
// buses 持有全系统仅三条（E1）SSE 总线：messages（对话/loop 回合）、entities（锻造 eventlog）、
// notifications（持久收件箱）。每个 *Bus 满足 streamdomain.Bridge。
type buses struct {
	messages      *streaminfra.Bus
	entities      *streaminfra.Bus
	notifications *streaminfra.Bus
}

const sseBufSize = 256

// newBuses constructs the three SSE buses.
//
// newBuses 构造三条 SSE 总线。
func newBuses() buses {
	return buses{
		messages:      streaminfra.New(sseBufSize),
		entities:      streaminfra.New(sseBufSize),
		notifications: streaminfra.New(sseBufSize),
	}
}

// openDB opens the SQLite database (DataDir empty → in-memory, for tests) and applies every
// store's schema in one migration pass.
//
// openDB 打开 SQLite（DataDir 空 → 内存库，供测试）并一趟应用每个 store 的 schema。
func openDB(dataDir string) (*ormpkg.DB, error) {
	database, err := dbinfra.Open(dbinfra.Config{DataDir: dataDir})
	if err != nil {
		return nil, fmt.Errorf("bootstrap: open db: %w", err)
	}
	if err := dbinfra.Migrate(database, allSchemas()...); err != nil {
		return nil, fmt.Errorf("bootstrap: migrate: %w", err)
	}
	return database, nil
}

// allSchemas concatenates every orm store's DDL. Order is irrelevant (CREATE TABLE IF NOT
// EXISTS, no cross-table FKs declared at create time).
//
// allSchemas 拼接每个 orm store 的 DDL。顺序无关（CREATE TABLE IF NOT EXISTS、建表期无跨表 FK）。
func allSchemas() []string {
	var s []string
	s = append(s, workspacestore.Schema...)
	s = append(s, apikeystore.Schema...)
	s = append(s, relationstore.Schema...)
	s = append(s, notificationstore.Schema...)
	s = append(s, sandboxstore.Schema...)
	s = append(s, documentstore.Schema...)
	s = append(s, todostore.Schema...)
	s = append(s, attachmentstore.Schema...)
	s = append(s, functionstore.Schema...)
	s = append(s, handlerstore.Schema...)
	s = append(s, agentstore.Schema...)
	s = append(s, triggerstore.Schema...)
	s = append(s, mcpstore.Schema...)
	s = append(s, controlstore.Schema...)
	s = append(s, approvalstore.Schema...)
	s = append(s, workflowstore.Schema...)
	s = append(s, flowrunstore.Schema...)
	s = append(s, conversationstore.Schema...)
	s = append(s, messagesstore.Schema...)
	s = append(s, searchstore.Schema...)
	return s
}

// newEncryptor derives the AES-256 master key from a machine-stable fingerprint (api-key &
// mcp-config secrets are encrypted at rest). A blank Config.Fingerprint (the normal server path)
// resolves the real machine fingerprint — a guessable seed like the data-dir path would make the
// SQLite file decryptable by anyone who copies it; only when the platform offers no fingerprint
// does it fall back to the data dir so the install stays self-consistent.
//
// newEncryptor 从机器稳定指纹派生 AES-256 主密钥（api-key & mcp-config 密文落盘加密）。空
// Config.Fingerprint（服务正常路径）解析真实机器指纹——可猜种子（如 data-dir 路径）会让拷走 SQLite
// 文件的人直接解密；仅当平台拿不到指纹才回退 data dir，使单次安装自洽。
func newEncryptor(fingerprint, dataDir string) (cryptodomain.Encryptor, error) {
	if fingerprint == "" {
		if fp, err := cryptoinfra.MachineFingerprint(); err == nil {
			fingerprint = fp
		} else {
			fingerprint = "forgify-local:" + dataDir
		}
	}
	enc, err := cryptoinfra.NewAESGCMEncryptor(cryptoinfra.DeriveKey(fingerprint))
	if err != nil {
		return nil, fmt.Errorf("bootstrap: encryptor: %w", err)
	}
	return enc, nil
}

// buildStores constructs every store against the shared DB + blob/memory/skill roots under dataDir.
//
// buildStores 用共享 DB + dataDir 下的 blob/memory/skill 根构造每个 store。
func buildStores(database *ormpkg.DB, enc cryptodomain.Encryptor, dataDir string) *stores {
	return &stores{
		workspace:    workspacestore.New(database),
		apikey:       apikeystore.New(database),
		relation:     relationstore.New(database),
		notification: notificationstore.New(database),
		sandbox:      sandboxstore.New(database),
		document:     documentstore.New(database),
		todo:         todostore.New(database),
		attachment:   attachmentstore.New(database),
		function:     functionstore.New(database),
		handler:      handlerstore.New(database),
		agent:        agentstore.New(database),
		trigger:      triggerstore.New(database),
		mcp:          mcpstore.New(database, enc),
		control:      controlstore.New(database),
		approval:     approvalstore.New(database),
		workflow:     workflowstore.New(database),
		flowrun:      flowrunstore.New(database),
		conversation: conversationstore.New(database),
		messages:     messagesstore.New(database),
		search:       searchstore.New(database),

		memory: memoryfs.New(dataDir),
		skill:  skillfs.New(dataDir),
		blob:   blobfs.New(dataDir),
	}
}
