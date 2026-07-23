package contextmgr

import (
	"context"

	checkpointapp "github.com/sunweilin/anselm/backend/internal/app/contextcheckpoint"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

const promptCheckpointHotGroups = 3

// CompactPrompt semantically folds an old, protocol-complete prefix into one
// continuation checkpoint and retains the newest complete tool-call groups
// verbatim. It mutates only the in-memory prompt projection; durable messages
// and blocks remain untouched.
func (s *Service) CompactPrompt(ctx context.Context, history []llminfra.LLMMessage, targetTokens int) ([]llminfra.LLMMessage, error) {
	bundle, err := s.deps.Resolver.ResolveUtility(ctx)
	if err != nil {
		return history, err
	}
	return checkpointapp.Compact(ctx, bundle.Client, bundle.Request, history, targetTokens, promptCheckpointHotGroups)
}
