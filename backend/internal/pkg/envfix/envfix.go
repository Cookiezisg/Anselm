// Package envfix runs the trinity LLM tools' internal env-fix loop:
// after a sandbox env install fails, ask the main-chat-scenario LLM to
// suggest revised dependencies and retry, up to maxAttempts times. The
// loop is shared by create_function / edit_function / create_handler /
// edit_handler so they have one consistent behaviour (per D-redo-15..21
// in forge_redesign 2026-05-12).
//
// The loop's caller is responsible for the initial install attempt
// (Service.Create / Edit). envfix.RunLoop is only entered when that
// initial attempt failed; the function returns the terminal env state
// (status + error + attempts used + per-attempt history) so the tool
// can include it in the tool_result the main LLM sees.
//
// Package envfix 跑 trinity LLM 工具的内部 env-fix 循环:沙箱 env 装失败后,
// 用主 chat scenario LLM(DeepSeek)建议修后的 deps,最多重试 maxAttempts 次。
// 4 个工具(create/edit × function/handler)共享同一份循环行为,跟
// D-redo-15..21(forge_redesign 2026-05-12)对齐。
//
// 调用方负责初始装环境;envfix.RunLoop 仅在初次装失败时进入,返终态
// (status + error + attemptsUsed + history)让工具拼进 tool_result。
package envfix

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
	llmparsepkg "github.com/sunweilin/forgify/backend/internal/pkg/llmparse"
)

// DefaultMaxAttempts is the default upper bound on env install attempts
// (initial + LLM-suggested retries) — D-redo-16 hard-codes 3.
//
// DefaultMaxAttempts 是装环境尝试次数上限(初次 + LLM 修建议)— D-redo-16 定 3。
const DefaultMaxAttempts = 3

// Attempt records the outcome of one install attempt (initial or retry).
// EnvStatus is "ready" or "failed". EnvError carries the sandbox stderr
// (truncated/wrapped — caller-side decision) when the attempt failed.
//
// Attempt 记一次装环境的结果(初次或重试)。EnvStatus 是 "ready" / "failed";
// 失败时 EnvError 携 sandbox stderr。
type Attempt struct {
	Number    int      `json:"attempt"`
	Deps      []string `json:"deps"`
	EnvStatus string   `json:"envStatus"`
	EnvError  string   `json:"envError,omitempty"`
}

// LoopHooks are tool-supplied side-effect callbacks. Each fires once per
// transition; envfix never calls them more than once with the same args.
// They are best-effort UI signals — failure inside a hook is the tool's
// problem, not envfix's.
//
// LoopHooks 是工具侧副作用回调。每次状态转换调一次,失败 envfix 不管。
type LoopHooks struct {
	// OnAttemptResult fires after each install attempt finishes (success or
	// failure). For the initial attempt, callers should pass the initial
	// outcome via Options.InitialAttempt and NOT call OnAttemptResult for it
	// — envfix calls OnAttemptResult on its first iteration for the initial
	// result so the tool emits one consistent message stream.
	OnAttemptResult func(ctx context.Context, a Attempt)

	// OnFixing fires before each LLM env-fix call (only when going into
	// retry). Gives the tool a chance to emit "AI suggesting deps..." UI.
	OnFixing func(ctx context.Context, attemptNum int)
}

// Options configures one RunLoop call.
//
// Options 配置一次 RunLoop。
type Options struct {
	// Bundle is the resolved main-chat-scenario LLM (D-redo-17:DeepSeek).
	// Must be non-nil — RunLoop returns an error if it is.
	//
	// Bundle 是已解析的主 chat scenario LLM(D-redo-17:DeepSeek)。
	Bundle *llmclientpkg.Bundle

	// InitialAttempt is the result of the initial install run by the
	// caller's Service.Create / Edit. Number should be 1. EnvStatus
	// distinguishes whether we even need to enter the loop:
	//   - "ready" → RunLoop returns immediately (no retries needed)
	//   - "failed" → RunLoop tries up to MaxAttempts-1 retries
	//
	// InitialAttempt 是调用方初次装环境的结果(Number=1)。"ready" 直返,
	// "failed" 进重试循环。
	InitialAttempt Attempt

	// MaxAttempts caps total install attempts (initial + retries). 0 = use
	// DefaultMaxAttempts. Per D-redo-16 hard-coded 3 in production.
	//
	// MaxAttempts 装环境总次数上限(初次 + 重试),0 用 DefaultMaxAttempts。
	MaxAttempts int

	// ApplyDeps is called for each retry. It must:
	//   1. Persist the new deps (typically via Service.Edit with set_dependencies op).
	//   2. Re-install the env synchronously.
	//   3. Return (envStatus, envError) from the post-install Version row.
	// A non-nil error is fatal — the loop exits immediately with that error;
	// the caller treats it like a service-level failure (e.g. sandbox unavailable).
	//
	// ApplyDeps 每次重试调:写新 deps + 同步重装 env + 返终态;返非 nil error
	// 即致命(如 sandbox 不可用),循环立即退出。
	ApplyDeps func(ctx context.Context, deps []string) (envStatus, envError string, err error)

	// Hooks are optional side-effect callbacks for UI. Nil hooks are no-ops.
	//
	// Hooks UI 副作用回调,nil 视为 no-op。
	Hooks LoopHooks
}

// Result is the terminal state after RunLoop completes — the tool packages
// these fields into its tool_result for the main LLM and the UI.
//
// Result 是 RunLoop 终态;工具拼进 tool_result 给主 LLM + UI 看。
type Result struct {
	FinalEnvStatus string    `json:"envStatus"`        // "ready" or "failed"
	FinalEnvError  string    `json:"envError,omitempty"`
	AttemptsUsed   int       `json:"attemptsUsed"`
	History        []Attempt `json:"attemptHistory"`
	// FatalErr is non-nil iff ApplyDeps returned a non-nil error
	// (service-level failure, e.g. ErrSandboxUnavailable). The caller
	// should propagate it as the tool's error return.
	//
	// FatalErr 非 nil 即致命(如 ErrSandboxUnavailable),工具应直接抛。
	FatalErr error `json:"-"`
}

// ErrNoBundle is returned when Options.Bundle is nil.
//
// ErrNoBundle Options.Bundle 为 nil 时返。
var ErrNoBundle = errors.New("envfix: nil LLM bundle")

// RunLoop drives the env-fix loop. The caller has already run the initial
// install and passes the outcome via Options.InitialAttempt; RunLoop owns
// only the retry logic and LLM dialogue.
//
// Flow:
//  1. If InitialAttempt.EnvStatus == "ready" → return immediately.
//  2. Else for attempt := 2..MaxAttempts:
//     a. Hooks.OnFixing(ctx, attempt)
//     b. Ask LLM for new deps. If the call fails, treat per D-redo-21:
//        return failed terminal with AttemptsUsed = attempt-1 (the loop
//        is exiting before this attempt's install runs).
//     c. ApplyDeps(ctx, newDeps). Non-nil fatal err → return with FatalErr.
//     d. Hooks.OnAttemptResult(ctx, thisAttempt).
//     e. If thisAttempt.EnvStatus == "ready" → return success.
//  3. Loop exhausted → return failed terminal with last attempt's error.
//
// RunLoop 推动 env-fix 循环。初次装环境已由调用方完成,RunLoop 仅负责重试 +
// LLM 对话。详流程见英文。
func RunLoop(ctx context.Context, opts Options) Result {
	max := opts.MaxAttempts
	if max <= 0 {
		max = DefaultMaxAttempts
	}
	history := []Attempt{opts.InitialAttempt}

	// Initial outcome surfaced via OnAttemptResult so caller emits one
	// consistent stream of attempt messages.
	// 初次结果通过 OnAttemptResult 抛出,调用方拼成统一流。
	if opts.Hooks.OnAttemptResult != nil {
		opts.Hooks.OnAttemptResult(ctx, opts.InitialAttempt)
	}

	if opts.InitialAttempt.EnvStatus == "ready" {
		return Result{
			FinalEnvStatus: "ready",
			AttemptsUsed:   1,
			History:        history,
		}
	}

	if opts.Bundle == nil {
		return Result{
			FinalEnvStatus: "failed",
			FinalEnvError:  ErrNoBundle.Error(),
			AttemptsUsed:   1,
			History:        history,
			FatalErr:       ErrNoBundle,
		}
	}

	currentDeps := append([]string(nil), opts.InitialAttempt.Deps...)
	currentErr := opts.InitialAttempt.EnvError

	for attempt := 2; attempt <= max; attempt++ {
		if opts.Hooks.OnFixing != nil {
			opts.Hooks.OnFixing(ctx, attempt)
		}

		newDeps, llmErr := suggestDeps(ctx, opts.Bundle, currentDeps, currentErr, history)
		if llmErr != nil {
			// D-redo-21:LLM call failure treated like install failure;
			// loop exits before the would-be install runs.
			return Result{
				FinalEnvStatus: "failed",
				FinalEnvError:  fmt.Sprintf("env-fix LLM call failed: %v", llmErr),
				AttemptsUsed:   attempt - 1,
				History:        history,
			}
		}

		status, errMsg, applyErr := opts.ApplyDeps(ctx, newDeps)
		if applyErr != nil {
			// Service-level fatal (sandbox unavailable, save failure, etc.).
			return Result{
				FinalEnvStatus: "failed",
				FinalEnvError:  applyErr.Error(),
				AttemptsUsed:   attempt,
				History:        history,
				FatalErr:       applyErr,
			}
		}

		a := Attempt{
			Number:    attempt,
			Deps:      newDeps,
			EnvStatus: status,
			EnvError:  errMsg,
		}
		history = append(history, a)
		if opts.Hooks.OnAttemptResult != nil {
			opts.Hooks.OnAttemptResult(ctx, a)
		}

		if status == "ready" {
			return Result{
				FinalEnvStatus: "ready",
				AttemptsUsed:   attempt,
				History:        history,
			}
		}
		currentDeps = newDeps
		currentErr = errMsg
	}

	return Result{
		FinalEnvStatus: "failed",
		FinalEnvError:  currentErr,
		AttemptsUsed:   max,
		History:        history,
	}
}

// suggestDeps asks the main-chat LLM for a revised dependency list given
// the current deps, last install error, and prior attempts. Returns the
// new deps slice or an error if the LLM call / JSON parse fails.
//
// Parsing tries direct json.Unmarshal first (clean LLM output matches the
// prompt's "return JSON only" rule); falls back to llmparsepkg.ExtractJSON
// for fence-wrapped or prose-wrapped variants. We need the fallback because
// ExtractJSON prefers `[...]` over `{...}` when both are present in the same
// string and would pick the inner deps array for `{"deps":[...]}`.
//
// suggestDeps 让主 chat LLM 看当前 deps + 上次 stderr + 历史 attempts,返修后
// 的 deps 列表。先尝试 json.Unmarshal(干净输出);失败则 fallback ExtractJSON
// (兼容 fence / 散文包裹)— ExtractJSON 优先 `[]` 而非 `{}`,会误抓 inner
// deps 数组,所以直 unmarshal 是 fast path。
func suggestDeps(
	ctx context.Context,
	bundle *llmclientpkg.Bundle,
	currentDeps []string,
	lastErr string,
	history []Attempt,
) ([]string, error) {
	prompt := buildPrompt(currentDeps, lastErr, history)

	resp, err := llminfra.Generate(ctx, bundle.Client, llminfra.Request{
		ModelID:  bundle.ModelID,
		Key:      bundle.Key,
		BaseURL:  bundle.BaseURL,
		Messages: []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: prompt}},
	})
	if err != nil {
		return nil, fmt.Errorf("envfix: llm generate: %w", err)
	}

	var out struct {
		Deps []string `json:"deps"`
	}

	// Fast path: prompt asks for "JSON only, no commentary". A well-behaved
	// LLM returns exactly that and we can parse it directly.
	if err := json.Unmarshal([]byte(strings.TrimSpace(resp)), &out); err == nil {
		return out.Deps, nil
	}

	// Fallback: model wrapped in code fence or prose. ExtractJSON handles
	// fences first then bracket-pair extraction.
	jsonStr, ok := llmparsepkg.ExtractJSON(resp)
	if !ok {
		return nil, fmt.Errorf("envfix: no JSON in LLM response: %q", resp)
	}
	if err := json.Unmarshal([]byte(jsonStr), &out); err != nil {
		return nil, fmt.Errorf("envfix: parse deps JSON: %w", err)
	}
	return out.Deps, nil
}

// buildPrompt constructs the env-fix prompt. The contract with the LLM is
// strict: "only adjust the dependency list — do not add new packages, do
// not modify code, return JSON only". Per D-redo-18.
//
// buildPrompt 拼 env-fix prompt。LLM 契约严格:只调整 deps 列表(不加新包 /
// 不改代码),返 JSON。D-redo-18。
func buildPrompt(currentDeps []string, lastErr string, history []Attempt) string {
	var sb strings.Builder
	sb.WriteString("You are fixing a Python venv install that failed. Suggest a revised dependency list.\n\n")
	sb.WriteString("Current dependencies (PEP 508 specifiers):\n")
	if len(currentDeps) == 0 {
		sb.WriteString("  (empty)\n")
	} else {
		for _, d := range currentDeps {
			fmt.Fprintf(&sb, "  - %s\n", d)
		}
	}
	sb.WriteString("\nLast install error (uv/pip stderr):\n")
	if lastErr == "" {
		sb.WriteString("  (no stderr captured)\n")
	} else {
		fmt.Fprintf(&sb, "%s\n", strings.TrimSpace(lastErr))
	}

	if len(history) > 1 {
		sb.WriteString("\nPrior attempts:\n")
		for _, a := range history {
			fmt.Fprintf(&sb, "  attempt %d: deps=%v status=%s err=%q\n",
				a.Number, a.Deps, a.EnvStatus, truncate(a.EnvError, 200))
		}
	}

	sb.WriteString(`
Rules:
- Only fix the dependency list (typos, version conflicts, missing constraints).
- Do NOT add new packages unrelated to the current list.
- Do NOT modify any Python code (code is not your concern here).
- Keep the same packages where possible; just adjust versions or fix names.
- If you cannot determine a fix from the info above, return the deps unchanged.

Return JSON only, no commentary:
{"deps": ["pandas>=2.0", "numpy"]}
`)
	return sb.String()
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}
