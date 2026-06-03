// Package agent provides LLM-callable tools for the Agent entity (quadrinity 4th member).
// The tool surface mirrors function 1:1 (one file per tool): create / edit / delete / get / search /
// revert / invoke (real run) / get_execution / search_executions. Accept happens via UI/HTTP (no
// LLM accept tool — same as function).
//
// Package agent 提供 Agent 实体的 LLM 工具，工具面与 function 1:1（一文件一工具）。
package agent

import (
	"go.uber.org/zap"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// AgentTools returns the agent forging + execution tools (mirrors function.FunctionTools surface).
// LLM deps (picker/keys/factory) power search_agents' relevance ranking (mirrors search_function).
//
// AgentTools 返 agent 锻造 + 执行工具（对标 function.FunctionTools）。
func AgentTools(svc *agentapp.Service, picker modeldomain.ModelPicker, keys apikeydomain.KeyProvider, factory *llminfra.Factory, log *zap.Logger) []toolapp.Tool {
	return []toolapp.Tool{
		&SearchAgents{svc: svc, picker: picker, keys: keys, factory: factory, log: log},
		&GetAgent{svc: svc},
		&CreateAgent{svc: svc},
		&EditAgent{svc: svc},
		&RevertAgent{svc: svc},
		&DeleteAgent{svc: svc},
		&InvokeAgent{svc: svc},
		&SearchAgentExecutions{svc: svc},
		&GetAgentExecution{svc: svc},
	}
}
