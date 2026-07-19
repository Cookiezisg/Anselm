// Package settings owns <dataDir>/settings.json — three blocks: "limits" (the user-tunable
// operational ceilings), "network" (the outbound proxy) and "retention" (the run-history
// retention line, scheduler 工单⑬). Load installs the file's values as the live limits.Current()
// source at boot; Patch merges a partial update, validates, persists atomically and hot-swaps the
// source — consumers see new values on their next read, no restart.
//
// The whole file is MACHINE-level: Load takes only a dataDir, the Service holds ONE copy of each
// block, and boot reads it before any workspace exists. Every workspace reads and mutates the same
// values (the uniform auth gate's workspace header is identity, not an isolation axis) — for a
// single-user local app that global semantics is correct, not a per-workspace bug (F162).
//
// Package settings 拥有 <dataDir>/settings.json——三段："limits"（用户可调运行上限）、"network"
// （出站代理）、"retention"（run 历史保留线，scheduler 工单⑬）。Load 在 boot 时把文件值装成活动
// limits.Current() 来源；Patch 合并部分更新、校验、原子持久化并热换来源——消费方下一次读取即见新值，
// 无需重启。
//
// 整个文件是**机器级**：Load 只吃 dataDir，Service 每段只持**一份**副本，boot 在任何 workspace 存在前
// 就读它。所有 workspace 读写的都是同一份值（统一 auth 门的 workspace header 是身份、非隔离轴）——对
// 单用户本地 app，这个全局语义是**正确**的，不是 per-workspace bug（F162）。
package settings

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
)

// ErrLimitsInvalid rejects a PATCH whose values are out of range (negative ceilings, a
// trigger ratio outside (0,1)).
//
// ErrLimitsInvalid 拒绝取值越界的 PATCH（负上限、trigger ratio 不在 (0,1)）。
var ErrLimitsInvalid = errorspkg.New(errorspkg.KindInvalid, "SETTINGS_LIMITS_INVALID", "limits values out of range")

// ErrRetentionInvalid rejects a PATCH whose retention line is physically nonsensical (a negative
// day count). The 30/90/180/forever value set the desktop UI offers is a PRODUCT decision and is
// deliberately NOT enforced here: any non-negative day count sweeps correctly, so rejecting 60
// would be validation theatre (设计原则 #6).
//
// ErrRetentionInvalid 拒绝保留线物理上讲不通的 PATCH（负天数）。桌面 UI 给的 30/90/180/永久 值集是
// **产品**决策、此处刻意**不**强制：任何非负天数都能正确清理，故拒绝 60 是校验剧场（设计原则 #6）。
var ErrRetentionInvalid = errorspkg.New(errorspkg.KindInvalid, "SETTINGS_RETENTION_INVALID", "runRetentionDays must be 0 (keep forever) or a positive number of days")

// DefaultRunRetentionDays is the server-held default retention line (scheduler 判决④). 90 days
// comfortably clears every statistics window (≤7d), so the defaults never fight each other.
//
// DefaultRunRetentionDays 是服务端自持的默认保留线（scheduler 判决④）。90 天宽裕地越过所有统计窗口
// （≤7d），故默认之间绝不打架。
const DefaultRunRetentionDays = 90

// fileShape is the settings.json layout. Retention is a POINTER so an absent block is
// distinguishable from an explicit {"runRetentionDays": 0} — 0 means "keep forever", so a
// value-typed block would read a fresh install's absence as "never clean" (and, worse, would make
// an explicit forever indistinguishable from unset on the next boot).
//
// fileShape 是 settings.json 布局。Retention 是**指针**，使「段缺席」与显式 {"runRetentionDays": 0}
// 可区分——0 = 「永久保留」，故值类型的段会把全新安装的缺席读成「永不清理」（更糟：会让显式的「永久」
// 与「未设置」在下次 boot 时不可区分）。
type fileShape struct {
	Limits    limitspkg.Limits `json:"limits"`
	Network   Network          `json:"network,omitempty"`
	Retention *Retention       `json:"retention,omitempty"`
}

// Retention is the settings.json "retention" block (scheduler 工单⑬, 判决④): the run-history
// retention line. RunRetentionDays counts back from a finished run's completed_at — the same
// window semantics flowrun-stats' completedSince uses, so "kept" means "reached its terminal
// inside the window" and a long run that just failed is fresh, not old. 0 = keep forever (the
// sweep never runs). Data governance, machine-level like its sibling blocks.
//
// Retention 是 settings.json 的 "retention" 段（scheduler 工单⑬、判决④）：run 历史保留线。
// RunRetentionDays 从终态 run 的 completed_at 往回数——与 flowrun-stats 的 completedSince 同一窗口
// 语义，故「保留」= 「在窗内**落定**」，跑了很久刚失败的 run 是新鲜的、不是旧的。0 = 永久保留
// （清理绝不跑）。数据治理，与兄弟段一样机器级。
type Retention struct {
	RunRetentionDays int `json:"runRetentionDays"`
}

// Network is the settings.json "network" block (WRK-062 工单⑩): an OUTBOUND HTTP proxy the sidecar
// uses to reach LLM / MCP / search providers. Applied to the process environment at boot (Go's
// http.ProxyFromEnvironment reads it) — hence "restart to take effect". Empty = direct.
//
// Network 是 settings.json 的 "network" 段(工单⑩):sidecar 出站到 LLM/MCP/搜索 provider 的 HTTP 代理。
// boot 时应用到进程环境(Go 的 http.ProxyFromEnvironment 读它)——故「重启生效」;空=直连。
type Network struct {
	HTTPProxy  string `json:"httpProxy,omitempty"`
	HTTPSProxy string `json:"httpsProxy,omitempty"`
	NoProxy    string `json:"noProxy,omitempty"`
}

// Service loads, serves and patches the settings file.
//
// Service 加载、提供并修补 settings 文件。
type Service struct {
	mu   sync.Mutex
	path string
	cur  limitspkg.Limits
	net  Network
	ret  Retention
	// onRetentionChanged is fired (outside mu) after a retention PATCH persists, so the sweeper can
	// act on the new line NOW rather than at its next slow tick — tightening the line to 30d must
	// visibly reclaim runs, not appear broken for hours. Wired by bootstrap (the workspace
	// SetOnCreated hook precedent); nil = nobody listening (tests, and every read path).
	// onRetentionChanged 在 retention PATCH 落盘后触发（在 mu 之外），使清理器**立刻**按新线动作、而非
	// 等它下一个慢 tick——把线收到 30d 必须看得见地回收 run，而不是几小时里像坏了。由 bootstrap 接线
	// （workspace SetOnCreated 钩子先例）；nil = 无人监听（测试，以及所有读路径）。
	onRetentionChanged func()
}

// Load reads <dataDir>/settings.json (absent file = pure defaults), installs the result
// as the live limits source, and returns the service. A malformed file is an error —
// silently ignoring a user's hand-edited settings would be worse than failing boot.
//
// Load 读 <dataDir>/settings.json（无文件 = 纯默认），把结果装成活动 limits 来源并返回
// service。文件畸形是错误——静默忽略用户手编的 settings 比 boot 失败更糟。
func Load(dataDir string) (*Service, error) {
	s := &Service{
		path: filepath.Join(dataDir, "settings.json"),
		cur:  limitspkg.Default(),
		ret:  Retention{RunRetentionDays: DefaultRunRetentionDays},
	}
	raw, err := os.ReadFile(s.path)
	switch {
	case os.IsNotExist(err):
		// pure defaults. 纯默认。
	case err != nil:
		return nil, fmt.Errorf("settings: read %s: %w", s.path, err)
	default:
		var f fileShape
		if err := json.Unmarshal(raw, &f); err != nil {
			return nil, fmt.Errorf("settings: parse %s: %w", s.path, err)
		}
		s.cur = limitspkg.WithDefaults(f.Limits)
		s.net = f.Network
		// Absent block = default; present block is taken VERBATIM (no zero-fill) — an explicit 0
		// is "forever" and must survive a round trip, which is exactly why the block is a pointer.
		// 段缺席 = 默认；段在场即**逐字**取用（不补零）——显式的 0 是「永久」、必须往返存活，这正是
		// 该段用指针的原因。
		if f.Retention != nil {
			s.ret = *f.Retention
		}
		if err := validate(s.cur); err != nil {
			return nil, fmt.Errorf("settings: %s: %w", s.path, err)
		}
		if err := validateRetention(s.ret); err != nil {
			return nil, fmt.Errorf("settings: %s: %w", s.path, err)
		}
	}
	s.install()
	s.applyProxy()
	return s, nil
}

// SetOnRetentionChanged registers the hook fired after a retention PATCH persists (bootstrap wires
// the sweep kick). Called once at assembly, before serving — hence no lock.
//
// SetOnRetentionChanged 注册 retention PATCH 落盘后触发的钩子（bootstrap 接清理踢一脚）。装配期调一次、
// 服务开始前——故不加锁。
func (s *Service) SetOnRetentionChanged(fn func()) { s.onRetentionChanged = fn }

// Limits returns the live values.
//
// Limits 返活动值。
func (s *Service) Limits() limitspkg.Limits {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.cur
}

// LimitsSchema returns the per-field metadata (key/group/default/min/max/unit/desc) for the
// tunable limits — a static projection of pkg/limits served read-only so the UI renders
// ranges and defaults from the backend instead of hardcoding (and drifting from) the constants.
//
// LimitsSchema 返回可调上限的逐字段元数据——pkg/limits 的静态投影,只读透出使 UI 从后端渲染范围/
// 默认,而非硬编(并漂离)常量。
func (s *Service) LimitsSchema() []limitspkg.FieldSpec { return limitspkg.Schema() }

// DataDir returns the resolved data directory (the parent of settings.json) — surfaced
// read-only so the desktop UI can show where this local-first app persists everything
// and offer "open in file manager". Immutable after Load, so no lock.
//
// DataDir 返回解析后的数据目录（settings.json 的父目录）——只读透出本地优先 app 的落盘位置,
// 供桌面 UI 显示并「在文件管理器打开」。Load 后不变,无需加锁。
func (s *Service) DataDir() string { return filepath.Dir(s.path) }

// PatchLimits merges a partial JSON object over the current limits (absent fields keep
// their value), validates, persists atomically and hot-swaps the live source.
//
// PatchLimits 把部分 JSON 对象合并到当前 limits 上（缺省字段保持），校验、原子持久化并
// 热换活动来源。
func (s *Service) PatchLimits(patch json.RawMessage) (limitspkg.Limits, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	// Fill defaults on the BASE (defensive — current limits should already be complete), THEN apply the
	// patch, THEN validate. Crucially WithDefaults must NOT run AFTER the unmarshal: it refills every
	// zero field from Default(), which would mask an EXPLICIT out-of-range 0 in the patch (every limit
	// has a positive minimum — validate rejects <=0) and silently reset it instead of returning 400.
	// A client lowering functionRunSec to 0 got a 200 + a silent snap-back to 300 (present-zero-vs-absent
	// bug, sibling of F115).
	// 先在 BASE 上补默认（防御性——当前 limits 本应完整），再套 patch，再校验。关键：WithDefaults 绝不能在
	// unmarshal 之后跑——它会把每个零值字段从 Default() 回填，从而掩盖 patch 里显式的越界 0（每个 limit 都有
	// 正下限、validate 拒 <=0）、静默重置而非返 400。客户端把 functionRunSec 降到 0 本会得 200 + 静默弹回 300。
	next := limitspkg.WithDefaults(s.cur)
	// Strict decode (DisallowUnknownFields): a typo'd key (e.g. {"agent":{"maxStep":2}} — the field
	// is maxStepS) must 400, not silently no-op with 200. Every other write path rejects unknown
	// fields via decodeJSON; limits is edited through this app-layer path, so the strictness lives here.
	// 严格解码：拼错的键(如 {"agent":{"maxStep":2}}——字段是 maxStepS)必须 400,而非静默 no-op 返 200。
	// 其余写路径都经 decodeJSON 拒未知字段;limits 走这条 app 层路径,故严格性落在这里。
	dec := json.NewDecoder(bytes.NewReader(patch))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&next); err != nil {
		return limitspkg.Limits{}, fmt.Errorf("%w: %v", ErrLimitsInvalid, err)
	}
	if err := validate(next); err != nil {
		return limitspkg.Limits{}, err
	}
	if err := s.persist(next, s.net, s.ret); err != nil {
		return limitspkg.Limits{}, err
	}
	s.cur = next
	s.install()
	return next, nil
}

// ResetLimits restores the canonical defaults (limits.Default()), persists atomically and
// hot-swaps — the server-owned "restore defaults" so a client never has to hardcode (and
// drift from) the default values. Default() is always valid, so no validate step; cur is
// swapped only after persist succeeds, same as PatchLimits.
//
// ResetLimits 恢复规范默认（limits.Default()）、原子持久化并热换——服务端自持的「恢复默认」,
// 使客户端无须硬编默认值（也就不会漂）。Default() 恒合法,无需校验;cur 仅在 persist 成功后
// 才换,与 PatchLimits 一致。
func (s *Service) ResetLimits() (limitspkg.Limits, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	next := limitspkg.Default()
	if err := s.persist(next, s.net, s.ret); err != nil {
		return limitspkg.Limits{}, err
	}
	s.cur = next
	s.install()
	return next, nil
}

// install swaps the package-level limits source to this service's current value.
//
// install 把包级 limits 来源换成本 service 当前值。
func (s *Service) install() {
	cur := s.cur
	limitspkg.SetProvider(func() limitspkg.Limits { return cur })
}

// Net returns the live network config. Net 返活动网络配置。
func (s *Service) Net() Network {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.net
}

// PatchNetwork replaces the network config, persists atomically and applies the proxy env. The
// change is fully in effect only after a sidecar restart (existing HTTP clients cache the proxy);
// the desktop UI says so. PatchNetwork 替换网络配置、原子持久化并应用代理 env;完整生效须重启 sidecar。
func (s *Service) PatchNetwork(n Network) (Network, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := s.persist(s.cur, n, s.ret); err != nil {
		return Network{}, err
	}
	s.net = n
	s.applyProxy()
	return n, nil
}

// Retention returns the live retention line. Read fresh by the sweeper every tick, so a PATCH is
// hot by construction — no provider swap needed (unlike limits, whose consumers read a package-level
// source). Retention 返活动保留线。清理器每 tick 现读，故 PATCH 天然热生效——无需换 provider。
func (s *Service) Retention() Retention {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.ret
}

// PatchRetention merges a partial JSON object over the CURRENT retention (absent fields keep their
// value), validates, persists atomically and kicks the sweep.
//
// The merge base is the current value, NOT the defaults: seeding from defaults would resurrect the
// present-zero-vs-absent bug PatchLimits documents — here inverted and nastier, since 0 is the
// MEANINGFUL "forever" rather than an out-of-range value validate would catch. Seeded from current,
// {} is a faithful no-op and {"runRetentionDays":0} faithfully means forever.
//
// PatchRetention 把部分 JSON 对象合并到**当前** retention 上（缺省字段保持），校验、原子持久化并踢一脚
// 清理。
//
// 合并基底是当前值、**不是**默认值：从默认值起底会复活 PatchLimits 记载的 present-zero-vs-absent bug——
// 在这里是反过来的、更阴险，因为 0 是**有意义**的「永久」、而非 validate 逮得住的越界值。从当前值起底，
// {} 忠实地是 no-op、{"runRetentionDays":0} 忠实地表示永久。
func (s *Service) PatchRetention(patch json.RawMessage) (Retention, error) {
	next, err := func() (Retention, error) {
		s.mu.Lock()
		defer s.mu.Unlock()
		next := s.ret
		// Strict decode, same stance as PatchLimits: a typo'd key must 400, not silently no-op with 200.
		// 严格解码，与 PatchLimits 同立场：拼错的键必须 400，而非静默 no-op 返 200。
		dec := json.NewDecoder(bytes.NewReader(patch))
		dec.DisallowUnknownFields()
		if err := dec.Decode(&next); err != nil {
			return Retention{}, fmt.Errorf("%w: %v", ErrRetentionInvalid, err)
		}
		if err := validateRetention(next); err != nil {
			return Retention{}, err
		}
		if err := s.persist(s.cur, s.net, next); err != nil {
			return Retention{}, err
		}
		s.ret = next
		return next, nil
	}()
	if err != nil {
		return Retention{}, err
	}
	// Fire OUTSIDE mu: the hook enqueues a sweep whose worker reads Retention() back, and holding mu
	// across a callback we do not own invites a deadlock.
	// 在 mu **之外**触发：钩子入队的清理，其 worker 会回读 Retention()，握着 mu 跨调一个我们不拥有的
	// 回调是在招惹死锁。
	if s.onRetentionChanged != nil {
		s.onRetentionChanged()
	}
	return next, nil
}

// applyProxy pushes the configured proxy into the process environment so Go's
// http.ProxyFromEnvironment (used by the default transport) routes outbound calls through it. Empty
// fields are cleared. Caller holds mu (or is single-threaded boot). applyProxy 把代理写进进程环境。
func (s *Service) applyProxy() {
	set := func(key, val string) {
		if val == "" {
			_ = os.Unsetenv(key)
			return
		}
		_ = os.Setenv(key, val)
	}
	set("HTTP_PROXY", s.net.HTTPProxy)
	set("HTTPS_PROXY", s.net.HTTPSProxy)
	set("NO_PROXY", s.net.NoProxy)
}

// persist writes the file atomically (temp + rename). Every block is written together — patching
// one must never drop another.
//
// persist 原子写文件（临时文件 + rename）。所有段一起写——修补一段绝不能丢另一段。
func (s *Service) persist(l limitspkg.Limits, n Network, r Retention) error {
	b, err := json.MarshalIndent(fileShape{Limits: l, Network: n, Retention: &r}, "", "  ")
	if err != nil {
		return fmt.Errorf("settings: marshal: %w", err)
	}
	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, append(b, '\n'), 0o644); err != nil {
		return fmt.Errorf("settings: write: %w", err)
	}
	if err := os.Rename(tmp, s.path); err != nil {
		os.Remove(tmp)
		return fmt.Errorf("settings: rename: %w", err)
	}
	return nil
}

// validate enforces physical sanity: every ceiling positive, ratio in (0,1).
//
// validate 守物理合法性：上限全正、ratio 在 (0,1)。
func validate(l limitspkg.Limits) error {
	ints := []int{
		l.Agent.MaxSteps, l.Agent.InvokeMaxTurns,
		l.Timeout.LLMIdleSec, l.Timeout.LLMStreamMaxSec, l.Timeout.MCPCallSec, l.Timeout.BashDefaultTimeoutSec, l.Timeout.FunctionRunSec, l.Timeout.AgentInvokeSec, l.Timeout.HandlerCallSec, l.Timeout.ChatTurnSec,
		l.Tools.ReadDefaultLines, l.Tools.BashOutputCapKB, l.Tools.ToolResultCapKB,
		l.Guards.AttachmentMaxMB, l.Guards.WebhookBodyMaxMB,
	}
	for _, v := range ints {
		if v <= 0 {
			return ErrLimitsInvalid
		}
	}
	if l.Context.TriggerRatio <= 0 || l.Context.TriggerRatio >= 1 {
		return ErrLimitsInvalid
	}
	return nil
}

// validateRetention enforces the ONE physical constraint: a retention line cannot run backwards.
// Everything ≥ 0 sweeps correctly (0 = forever), so nothing else is checked here — the UI's
// 30/90/180/forever choice set is a product affordance, not a physical bound (设计原则 #6).
//
// validateRetention 守**唯一**的物理约束：保留线不能倒着走。≥0 的一切都能正确清理（0=永久），故此处
// 不再多查——UI 的 30/90/180/永久 值集是产品可供性、不是物理界限（设计原则 #6）。
func validateRetention(r Retention) error {
	if r.RunRetentionDays < 0 {
		return ErrRetentionInvalid
	}
	return nil
}
