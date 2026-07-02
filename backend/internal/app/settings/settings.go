// Package settings owns <dataDir>/settings.json — today exactly the "limits" block (the
// user-tunable operational ceilings). Load installs the file's values as the live
// limits.Current() source at boot; Patch merges a partial update, validates, persists
// atomically and hot-swaps the source — consumers see new values on their next read,
// no restart.
//
// Package settings 拥有 <dataDir>/settings.json——目前恰是 "limits" 段（用户可调运行上限）。
// Load 在 boot 时把文件值装成活动 limits.Current() 来源；Patch 合并部分更新、校验、原子
// 持久化并热换来源——消费方下一次读取即见新值，无需重启。
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

// fileShape is the settings.json layout (room for future non-limits blocks).
//
// fileShape 是 settings.json 布局（为未来非 limits 段留位）。
type fileShape struct {
	Limits limitspkg.Limits `json:"limits"`
}

// Service loads, serves and patches the settings file.
//
// Service 加载、提供并修补 settings 文件。
type Service struct {
	mu   sync.Mutex
	path string
	cur  limitspkg.Limits
}

// Load reads <dataDir>/settings.json (absent file = pure defaults), installs the result
// as the live limits source, and returns the service. A malformed file is an error —
// silently ignoring a user's hand-edited settings would be worse than failing boot.
//
// Load 读 <dataDir>/settings.json（无文件 = 纯默认），把结果装成活动 limits 来源并返回
// service。文件畸形是错误——静默忽略用户手编的 settings 比 boot 失败更糟。
func Load(dataDir string) (*Service, error) {
	s := &Service{path: filepath.Join(dataDir, "settings.json"), cur: limitspkg.Default()}
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
		if err := validate(s.cur); err != nil {
			return nil, fmt.Errorf("settings: %s: %w", s.path, err)
		}
	}
	s.install()
	return s, nil
}

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
	if err := s.persist(next); err != nil {
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
	if err := s.persist(next); err != nil {
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

// persist writes the file atomically (temp + rename).
//
// persist 原子写文件（临时文件 + rename）。
func (s *Service) persist(l limitspkg.Limits) error {
	b, err := json.MarshalIndent(fileShape{Limits: l}, "", "  ")
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
