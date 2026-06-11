package shell

import (
	"context"
	"encoding/json"
	"fmt"
	errorspkg "github.com/sunweilin/forgify/backend/internal/pkg/errors"
	"regexp"
	"strings"
)

// ErrEmptyBashID: bash_id missing.
//
// ErrEmptyBashID：bash_id 缺失。
var ErrEmptyBashID = errorspkg.New(errorspkg.KindInvalid, "SHELL_EMPTY_BASH_ID", "bash_id is required")

const outputDescription = `Read new stdout/stderr from a background Bash shell (bash_id). Returns only output appended since the last poll, plus a status footer.`

var outputSchema = json.RawMessage(`{
	"type": "object",
	"required": ["bash_id"],
	"properties": {
		"bash_id": {
			"type": "string",
			"description": "ID of the background shell process to poll (returned by Bash with run_in_background:true)."
		},
		"filter": {
			"type": "string",
			"description": "Optional regex; keep only matching lines from the new output."
		}
	}
}`)

// BashOutput implements the BashOutput system tool.
//
// BashOutput 是 BashOutput 系统工具的实现。
type BashOutput struct{ mgr *ProcessManager }

func (t *BashOutput) Name() string                { return "BashOutput" }
func (t *BashOutput) Description() string         { return outputDescription }
func (t *BashOutput) Parameters() json.RawMessage { return outputSchema }

// ValidateInput rejects empty bash_id and invalid regex pre-Execute.
//
// ValidateInput 在 Execute 前拒绝空 bash_id 与非法 regex。
func (t *BashOutput) ValidateInput(args json.RawMessage) error {
	var a struct {
		BashID string `json:"bash_id"`
		Filter string `json:"filter"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("BashOutput: bad args: %w", err)
	}
	if strings.TrimSpace(a.BashID) == "" {
		return ErrEmptyBashID
	}
	if a.Filter != "" {
		if _, err := regexp.Compile(a.Filter); err != nil {
			return fmt.Errorf("BashOutput: filter regex: %w", err)
		}
	}
	return nil
}

// Execute drains new bytes from the named process, optionally filters by regex, and emits
// them with a status footer.
//
// Execute 从命名进程取新字节，按可选 regex 过滤，附状态尾注返回。
func (t *BashOutput) Execute(_ context.Context, argsJSON string) (string, error) {
	var a struct {
		BashID string `json:"bash_id"`
		Filter string `json:"filter"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("BashOutput: %w", err)
	}

	proc, err := t.mgr.Get(a.BashID)
	if err != nil {
		return fmt.Sprintf("Background shell process not found: %s", a.BashID), nil
	}

	newBytes, dropped, status, exitCode := proc.drainNew()
	body := string(newBytes)
	if a.Filter != "" {
		body = filterLines(body, regexp.MustCompile(a.Filter))
	}
	return formatOutputResult(body, dropped, status, exitCode), nil
}

func filterLines(s string, re *regexp.Regexp) string {
	if s == "" {
		return ""
	}
	lines := strings.Split(s, "\n")
	out := lines[:0]
	for _, ln := range lines {
		if re.MatchString(ln) {
			out = append(out, ln)
		}
	}
	return strings.Join(out, "\n")
}

func formatOutputResult(body string, dropped int64, status Status, exitCode int) string {
	var sb strings.Builder
	if body != "" {
		sb.WriteString(body)
		if !strings.HasSuffix(body, "\n") {
			sb.WriteString("\n")
		}
	} else {
		sb.WriteString("(no new output since last poll)\n")
	}
	sb.WriteString("\n")
	if dropped > 0 {
		fmt.Fprintf(&sb, "[note: %d bytes dropped from buffer head before this poll due to ring overflow]\n", dropped)
	}
	switch status {
	case StatusRunning:
		sb.WriteString("[status: running]")
	case StatusExited:
		fmt.Fprintf(&sb, "[status: exited (code %d)]", exitCode)
	case StatusKilled:
		sb.WriteString("[status: killed]")
	case StatusErrored:
		sb.WriteString("[status: errored]")
	default:
		sb.WriteString("[status: unknown]")
	}
	return sb.String()
}
