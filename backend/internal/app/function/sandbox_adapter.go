package function

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	entitystreamapp "github.com/sunweilin/anselm/backend/internal/app/entitystream"
	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	mediaartifactapp "github.com/sunweilin/anselm/backend/internal/app/mediaartifact"
	sandboxapp "github.com/sunweilin/anselm/backend/internal/app/sandbox"
	functiondomain "github.com/sunweilin/anselm/backend/internal/domain/function"
	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	logtailpkg "github.com/sunweilin/anselm/backend/internal/pkg/logtail"
)

// SandboxAdapter satisfies SandboxRunner by delegating spawn + cleanup to sandboxapp
// .Service and writing each version's main.py under the function data dir. Env
// materialization is NOT here — that goes through envfix.Provisioner (whose SandboxPort
// is sandboxapp.Service directly).
//
// SandboxAdapter 把 spawn + 清理委托 sandboxapp.Service、把每个版本 main.py 写到 function
// 数据根目录，满足 SandboxRunner。env 物化不在此——走 envfix.Provisioner（其 SandboxPort 直接
// 是 sandboxapp.Service）。
type SandboxAdapter struct {
	svc      *sandboxapp.Service
	dataDir  string
	entities streamdomain.Bridge // entities stream (SSE-C); nil → no entity-panel run terminal

	// artifacts lands declared media files as first-class attachments (WRK-082 批E). nil → media
	// declarations pass through untouched, which keeps every non-wired caller (tests, REST-only
	// assemblies) correct rather than crashing on a feature they never asked for.
	// artifacts 把被声明的媒体文件落成一等附件(批E)。nil → 媒体声明原样通过,使每个未接线的调用方
	// (测试、只跑 REST 的装配)保持正确,而不是被一个它从没要过的功能弄崩。
	artifacts mediaartifactapp.ArtifactUploader
}

// NewSandboxAdapter binds the adapter to a sandbox service + the function data root. entities (the
// entities stream Bridge, nil-tolerant) carries a run's live stderr to the function panel's terminal
// regardless of who triggered the run (chat / REST / workflow / sensor).
//
// NewSandboxAdapter 把 adapter 绑到 sandbox service + function 数据根。entities（entities 流 Bridge，允许
// nil）把一次运行的实时 stderr 送到 function 面板终端——不论谁触发（chat / REST / workflow / sensor）。
func NewSandboxAdapter(svc *sandboxapp.Service, dataDir string, entities streamdomain.Bridge) *SandboxAdapter {
	return &SandboxAdapter{svc: svc, dataDir: dataDir, entities: entities}
}

// SetArtifactUploader injects the media-artifact landing port post-construction (批E) — the
// attachment service is built later in bootstrap than this adapter.
//
// SetArtifactUploader 后置注入媒体产物落盘端口(批E)——attachment 服务在 bootstrap 里比本 adapter 晚成形。
func (a *SandboxAdapter) SetArtifactUploader(up mediaartifactapp.ArtifactUploader) { a.artifacts = up }

var _ SandboxRunner = (*SandboxAdapter)(nil)

func (a *SandboxAdapter) Ready() bool { return a.svc.IsReady() }

// Run writes main.py (code + stdin/stdout driver) and spawns it in owner's venv. A
// non-zero exit becomes ExecutionResult{OK:false}; an infra failure (incl. evicted env)
// a Go error.
//
// Run 写 main.py（代码 + stdin/stdout driver）并在 owner 的 venv 里 spawn。非零退出返
// ExecutionResult{OK:false}；基础设施失败（含被驱逐的 env）返 Go error。
func (a *SandboxAdapter) Run(ctx context.Context, owner sandboxdomain.Owner, functionID, versionID, code string, input map[string]any) (*functiondomain.ExecutionResult, error) {
	funcName := entryFuncName(code)
	if funcName == "" {
		return nil, fmt.Errorf("functionapp.SandboxAdapter.Run: no top-level def in code")
	}
	verDir := a.versionDir(functionID, versionID)
	if err := os.MkdirAll(verDir, 0o755); err != nil {
		return nil, fmt.Errorf("functionapp.SandboxAdapter.Run: mkdir: %w", err)
	}
	mainPy := filepath.Join(verDir, "main.py")
	if err := writeAtomic(mainPy, []byte(code+buildDriver(funcName)), 0o644); err != nil {
		return nil, fmt.Errorf("functionapp.SandboxAdapter.Run: write main.py: %w", err)
	}
	inputJSON, err := json.Marshal(input)
	if err != nil {
		return nil, fmt.Errorf("functionapp.SandboxAdapter.Run: marshal input: %w", err)
	}

	// One EMPTY directory per run, handed to the code as $ANSELM_OUT and as its cwd, deleted when
	// the run ends (批E, 代拍 E1). A function writes artifacts there with a plain relative name
	// (`plt.savefig("chart.png")`) and never needs an absolute path. Deliberately NOT the residency
	// or the data dir: those hold the USER's real files, and letting a function write products into
	// them is letting it litter the working tree — while a per-run temp dir gives "which files did
	// THIS run produce" a physically unambiguous answer.
	//
	// **每次运行一个空目录**,以 $ANSELM_OUT 与 cwd 两种方式交给代码,运行结束即删(批E,代拍 E1)。
	// 函数用普通相对名写产物、永不需要绝对路径。刻意**不是**驻地、也不是数据目录:那两处是**用户**的真实
	// 文件,让函数往里写产物就是让它在工作树里乱丢;而 run 级临时目录让「哪些文件是**这次**运行产出的」
	// 有一个物理上无歧义的答案。
	outDir, err := os.MkdirTemp("", "anselm-fnout-")
	if err != nil {
		return nil, fmt.Errorf("functionapp.SandboxAdapter.Run: mkdir out: %w", err)
	}
	defer func() { _ = os.RemoveAll(outDir) }()

	// Tee the function's own print() output (the driver routes it to stderr; the JSON result still
	// lands on clean stdout) THREE ways: the messages stream under the run_function tool_call (chat
	// view, ToolProgress), the entities stream's run terminal scoped to this function (panel view,
	// all callers), and a capped logtail collector that persists onto the execution record (the
	// after-the-fact view — :triage and the execution tools read it). All nil-safe.
	//
	// 把函数自己的 print() 输出（driver 引到 stderr；JSON 结果仍走干净 stdout）**三写**：messages 流 run_function
	// tool_call 下（对话视图，ToolProgress）+ entities 流锚到本 function 的 run 终端（面板视图，全 caller）+
	// 限长 logtail 收集器随执行记录落盘（事后视图——:triage 与执行工具读它）。皆 nil 安全。
	prog := loopapp.ToolProgress(ctx)
	defer prog.Close()
	runTerm := entitystreamapp.New(ctx, a.entities, streamdomain.Scope{Kind: streamdomain.KindFunction, ID: functionID}, entitystreamapp.NodeRun, nil)
	logs := logtailpkg.New(logtailpkg.DefaultCap)
	res, spawnErr := a.svc.Spawn(ctx, owner, sandboxdomain.SpawnOpts{
		Cmd:       "python",
		Args:      []string{mainPy},
		Cwd:       outDir,
		Env:       map[string]string{"ANSELM_OUT": outDir},
		Stdin:     inputJSON,
		StreamErr: io.MultiWriter(prog, runTerm, logs),
	})
	if spawnErr != nil {
		runTerm.Close("error", nil)
		return nil, fmt.Errorf("functionapp.SandboxAdapter.Run: %w", spawnErr)
	}
	if res.Ok {
		runTerm.Close("completed", nil)
	} else {
		runTerm.Close("error", nil)
	}

	out := &functiondomain.ExecutionResult{ElapsedMs: res.Duration.Milliseconds(), Logs: logs.String()}
	if !res.Ok {
		msg := strings.TrimSpace(string(res.Stderr))
		if msg == "" {
			msg = fmt.Sprintf("python exit %d", res.ExitCode)
		}
		out.OK = false
		out.ErrorMsg = msg
		return out, nil
	}
	var output any
	if err := json.Unmarshal(res.Stdout, &output); err != nil {
		output = strings.TrimSpace(string(res.Stdout)) // non-JSON stdout → return as string
	}
	// Collect declared media BEFORE the deferred cleanup wipes the directory: a `{"$media": …}`
	// declaration becomes a MediaRef receipt in place, so everything downstream — the consumption
	// chokepoint, the card family, workflow edges — recognizes it without knowing a function made it.
	// 在 defer 清目录之前采集被声明的媒体:`{"$media": …}` 就地变成 MediaRef receipt,于是下游一切
	// ——消费咽喉、一族卡、workflow 的边——都认识它,而无需知道它出自一个 function。
	collected, notes := mediaartifactapp.Collect(ctx, a.artifacts, outDir, mediaartifactapp.SourceFunction, output)
	if len(notes) > 0 {
		// Notes go to the run's logs, never to the result: a skipped artifact is an operator-facing
		// fact, and putting it in the result would change the shape the caller's schema expects.
		// 说明进运行 logs、绝不进结果:被跳过的产物是给人看的事实,塞进结果会改变调用方 schema 期待的形状。
		out.Logs = strings.TrimRight(out.Logs+"\n"+strings.Join(notes, "\n"), "\n")
	}
	out.OK = true
	out.Output = collected
	return out, nil
}

// Destroy removes every env owned by the function and its on-disk code dir.
//
// Destroy 删除 function 拥有的所有 env 与盘上代码目录。
func (a *SandboxAdapter) Destroy(ctx context.Context, functionID string) error {
	envs, err := a.svc.ListEnvs(ctx, sandboxdomain.OwnerKindFunction)
	if err != nil {
		return fmt.Errorf("functionapp.SandboxAdapter.Destroy: list envs: %w", err)
	}
	prefix := functionID + "_"
	for _, e := range envs {
		if !strings.HasPrefix(e.OwnerID, prefix) {
			continue
		}
		if err := a.svc.Destroy(ctx, sandboxdomain.Owner{Kind: sandboxdomain.OwnerKindFunction, ID: e.OwnerID}); err != nil {
			return fmt.Errorf("functionapp.SandboxAdapter.Destroy %s: %w", e.OwnerID, err)
		}
	}
	if err := os.RemoveAll(filepath.Join(a.dataDir, "functions", functionID)); err != nil {
		return fmt.Errorf("functionapp.SandboxAdapter.Destroy: rm code dir: %w", err)
	}
	return nil
}

// DestroyEnv reclaims one per-version env by owner key (delegates to the sandbox service,
// which no-ops if the env was never materialized).
//
// DestroyEnv 按 owner key 回收单个 per-version env（委托 sandbox service，env 从未物化则 no-op）。
func (a *SandboxAdapter) DestroyEnv(ctx context.Context, owner sandboxdomain.Owner) error {
	return a.svc.Destroy(ctx, owner)
}

func (a *SandboxAdapter) versionDir(functionID, versionID string) string {
	return filepath.Join(a.dataDir, "functions", functionID, "versions", versionID)
}

// driverTemplate redirects the function's stdout to stderr for the duration of the call, then
// prints the JSON result to the real stdout. This keeps stdout a clean single JSON document (so
// res.Stdout parses) AND routes the function's own print()s to stderr — which the tool layer
// streams live as progress under the run_function tool_call. Without the redirect a print() would
// interleave on stdout and corrupt the result.
//
// driverTemplate 在调用期间把函数 stdout 重定向到 stderr，再把 JSON 结果打到真正的 stdout。这既让
// stdout 保持单一干净 JSON（res.Stdout 可解析），又把函数自己的 print() 引到 stderr——工具层将其作为
// run_function tool_call 下的实时进度流出。无此重定向，print() 会在 stdout 上交错、破坏结果。
const driverTemplate = `

if __name__ == "__main__":
    import json as _json, sys as _sys
    _input = _json.load(_sys.stdin)
    _real_stdout = _sys.stdout
    _sys.stdout = _sys.stderr
    try:
        _result = {FUNC_NAME}(**_input)
    finally:
        _sys.stdout = _real_stdout
    print(_json.dumps(_result))
`

func buildDriver(funcName string) string {
	return strings.Replace(driverTemplate, "{FUNC_NAME}", funcName, 1)
}

// writeAtomic writes via a unique temp file + rename so concurrent writers never collide.
//
// writeAtomic 经唯一临时文件 + rename 写入，并发写不撞。
func writeAtomic(path string, data []byte, mode os.FileMode) error {
	dir, base := filepath.Split(path)
	f, err := os.CreateTemp(dir, base+".*.tmp")
	if err != nil {
		return err
	}
	tmp := f.Name()
	if _, err := f.Write(data); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err := f.Chmod(mode); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err := f.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	if err := os.Rename(tmp, path); err != nil {
		os.Remove(tmp)
		return err
	}
	return nil
}
