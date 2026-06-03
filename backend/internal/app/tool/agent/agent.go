// Package agent provides LLM-callable tools for the Agent entity (quadrinity 4th member).
// The tool surface mirrors function 1:1 (one file per tool): create / edit / delete / get / search /
// revert / invoke (real run) / get_execution / search_executions. Accept happens via UI/HTTP (no
// LLM accept tool — same as function).
//
// Package agent 提供 Agent 实体的 LLM 工具，工具面与 function 1:1（一文件一工具）。
package agent

import (
	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// AgentTools returns the agent forging + execution tools (mirrors function.FunctionTools surface).
//
// AgentTools 返 agent 锻造 + 执行工具（对标 function.FunctionTools）。
func AgentTools(svc *agentapp.Service) []toolapp.Tool {
	return []toolapp.Tool{
		&SearchAgents{svc: svc},
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

// containsSub is a simple case-insensitive substring check.
func containsSub(s, sub string) bool {
	if sub == "" {
		return true
	}
	ls, lsub := toLower(s), toLower(sub)
	for i := 0; i <= len(ls)-len(lsub); i++ {
		if ls[i:i+len(lsub)] == lsub {
			return true
		}
	}
	return false
}

func toLower(s string) string {
	b := make([]byte, len(s))
	for i := range s {
		c := s[i]
		if c >= 'A' && c <= 'Z' {
			c += 32
		}
		b[i] = c
	}
	return string(b)
}
