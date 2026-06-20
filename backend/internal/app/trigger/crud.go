package trigger

import (
	"context"
	"strings"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	croninfra "github.com/sunweilin/anselm/backend/internal/infra/trigger/cron"
	celpkg "github.com/sunweilin/anselm/backend/internal/pkg/cel"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	schemapkg "github.com/sunweilin/anselm/backend/internal/pkg/schema"
)

// CreateInput is a new trigger's fields.
//
// CreateInput 是新建 trigger 的字段。
type CreateInput struct {
	Name        string
	Description string
	Kind        string
	Config      map[string]any
	Outputs     []schemapkg.Field
}

// EditInput patches a trigger; nil pointers / nil Config leave fields unchanged. Kind is
// immutable (change of source kind = delete + recreate).
//
// EditInput 局部更新；nil 指针 / nil Config 不改。Kind 不可变（换 source 种类 = 删了重建）。
type EditInput struct {
	Name        *string
	Description *string
	Config      map[string]any
	Outputs     []schemapkg.Field
}

// Create validates + persists a new trigger and syncs its relation edges. It does NOT attach
// a listener — a listener starts only when an active workflow references it (Attach).
//
// Create 校验 + 持久化新 trigger 并同步关系边。**不挂 listener**——listener 仅在 active workflow 引用时启动。
func (s *Service) Create(ctx context.Context, in CreateInput) (*triggerdomain.Trigger, error) {
	if err := s.validate(ctx, in.Kind, in.Config); err != nil {
		return nil, err
	}
	cfg := in.Config
	if cfg == nil {
		cfg = map[string]any{}
	}
	t := &triggerdomain.Trigger{
		ID:          idgenpkg.New("trg"),
		Name:        in.Name,
		Description: in.Description,
		Kind:        in.Kind,
		Config:      cfg,
		Outputs:     in.Outputs,
	}
	// cron/webhook/fsnotify deliver a FIXED fire payload — stamp the canonical Outputs so the
	// declaration cannot drift from what the listener actually emits (an author-supplied list is
	// ignored for these kinds). sensor keeps its author-defined output shape (from config.output).
	//
	// cron/webhook/fsnotify 交付固定 fire payload——盖上规范 Outputs 使声明永不与 listener emit 漂移
	// （这些 kind 忽略作者所填）。sensor 保留 config.output 的作者自定义输出形状。
	if co := triggerdomain.CanonicalOutputs(t.Kind); co != nil {
		t.Outputs = co
	}
	if err := s.repo.SaveTrigger(ctx, t); err != nil {
		return nil, err
	}
	s.notifySearch(ctx, t.ID)
	s.syncSensorBinding(ctx, t)
	s.syncBuiltEdge(ctx, t.ID)
	return t, nil
}

// Edit patches name/description/config (not kind), re-validates, and re-registers the listener
// if the trigger is currently hot (so a config change takes effect immediately).
//
// Edit 改 name/description/config（不改 kind），重校验，若 trigger 正热则重注册 listener（config 立即生效）。
func (s *Service) Edit(ctx context.Context, id string, in EditInput) (*triggerdomain.Trigger, error) {
	t, err := s.repo.GetTrigger(ctx, id)
	if err != nil {
		return nil, err
	}
	if in.Name != nil {
		t.Name = *in.Name
	}
	if in.Description != nil {
		t.Description = *in.Description
	}
	if in.Config != nil {
		t.Config = in.Config
	}
	if in.Outputs != nil {
		t.Outputs = in.Outputs
	}
	// Same as Create: a fixed-payload kind's Outputs is canonical, never the author's (see Create).
	//
	// 同 Create：固定 payload 的 kind 其 Outputs 是规范值、非作者所填（见 Create）。
	if co := triggerdomain.CanonicalOutputs(t.Kind); co != nil {
		t.Outputs = co
	}
	if err := s.validate(ctx, t.Kind, t.Config); err != nil {
		return nil, err
	}
	if err := s.repo.SaveTrigger(ctx, t); err != nil {
		return nil, err
	}
	s.notifySearch(ctx, t.ID)
	s.syncSensorBinding(ctx, t)
	s.restartIfListening(t)
	s.attachRuntime(t)
	return t, nil
}

// Delete stops any hot listener, soft-deletes the trigger, and purges its relation edges.
//
// Delete 停掉热 listener、软删 trigger、清除关系边。
func (s *Service) Delete(ctx context.Context, id string) error {
	s.mu.Lock()
	if e, ok := s.listeners[id]; ok {
		if l := s.listenerFor(e.kind); l != nil {
			l.Unregister(id)
		}
		delete(s.listeners, id)
	}
	s.mu.Unlock()
	if err := s.repo.DeleteTrigger(ctx, id); err != nil {
		return err
	}
	s.notifySearch(ctx, id)
	s.purgeRelations(ctx, id)
	return nil
}

// Get returns a trigger with its runtime RefCount/Listening attached.
//
// Get 返回 trigger 并附加运行时 RefCount/Listening。
func (s *Service) Get(ctx context.Context, id string) (*triggerdomain.Trigger, error) {
	t, err := s.repo.GetTrigger(ctx, id)
	if err != nil {
		return nil, err
	}
	s.attachRuntime(t)
	if lf, lerr := s.repo.LastFiredAt(ctx, t.ID); lerr == nil {
		t.LastFiredAt = lf
	}
	return t, nil
}

// List pages triggers with runtime state attached.
//
// List 分页 trigger 并附加运行时状态。
func (s *Service) List(ctx context.Context, filter triggerdomain.ListFilter) ([]*triggerdomain.Trigger, string, error) {
	ts, next, err := s.repo.ListTriggers(ctx, filter)
	if err != nil {
		return nil, "", err
	}
	for _, t := range ts {
		s.attachRuntime(t)
		// Project "fired N ago" from the activation log (best-effort; few triggers per workspace,
		// one indexed lookup each — no N+1 concern at single-user scale).
		// 从 activation 日志投影「N 前 fire」（best-effort；每 workspace 触发器少、各一次索引查询——
		// 单用户规模无 N+1 之虞）。
		if lf, lerr := s.repo.LastFiredAt(ctx, t.ID); lerr == nil {
			t.LastFiredAt = lf
		}
	}
	return ts, next, nil
}

// ListAll returns every trigger (used by the catalog source).
//
// ListAll 返回所有 trigger（catalog source 用）。
func (s *Service) ListAll(ctx context.Context) ([]*triggerdomain.Trigger, error) {
	return s.repo.ListAllTriggers(ctx)
}

// Search returns triggers whose name / description / kind contain query (case-insensitive);
// an empty query returns all. Runtime state is attached. Backs the search_triggers tool.
//
// Search 返回 name/description/kind 含 query（大小写不敏感）的 trigger；空 query 返全部，附运行时状态。
func (s *Service) Search(ctx context.Context, query string) ([]*triggerdomain.Trigger, error) {
	ts, err := s.repo.ListAllTriggers(ctx)
	if err != nil {
		return nil, err
	}
	q := strings.ToLower(strings.TrimSpace(query))
	out := make([]*triggerdomain.Trigger, 0, len(ts))
	for _, t := range ts {
		if q == "" || strings.Contains(strings.ToLower(t.Name), q) ||
			strings.Contains(strings.ToLower(t.Description), q) ||
			strings.Contains(strings.ToLower(t.Kind), q) {
			s.attachRuntime(t)
			out = append(out, t)
		}
	}
	return out, nil
}

// SearchActivations / GetActivation expose the action log for the search_activations /
// get_activation tools ("why didn't it fire?").
//
// SearchActivations / GetActivation 暴露动作日志，供 search_activations / get_activation 工具（"为什么没触发"）。
func (s *Service) SearchActivations(ctx context.Context, filter triggerdomain.ActivationFilter) ([]*triggerdomain.Activation, string, error) {
	return s.repo.SearchActivations(ctx, filter)
}

func (s *Service) GetActivation(ctx context.Context, id string) (*triggerdomain.Activation, error) {
	return s.repo.GetActivation(ctx, id)
}

// SearchFirings pages a trigger's firing inbox — where a fired activation's run-or-not
// disposition (started / skipped / superseded / shed) becomes visible ("it fired, why
// didn't it run?").
//
// SearchFirings 分页 trigger 的 firing 收件箱——触发后「跑没跑、为什么没跑」的处置
// （started/skipped/superseded/shed）在这里可见。
func (s *Service) SearchFirings(ctx context.Context, filter triggerdomain.FiringFilter) ([]*triggerdomain.Firing, string, error) {
	return s.repo.SearchFirings(ctx, filter)
}

// validate checks kind + structural config (domain) then source-specific syntax: cron
// expression parse and sensor CEL compile (condition/output). CEL/cron syntax can't live in
// the domain (no cel-go/robfig import), so it's verified here and mapped to a domain error.
//
// validate 校验 kind + 结构 config（domain），再做 source 专属语法：cron 表达式解析、sensor CEL 编译。
// CEL/cron 语法不能放 domain（不能 import cel-go/robfig），故在此校验并映射成 domain 错误。
func (s *Service) validate(ctx context.Context, kind string, config map[string]any) error {
	if !triggerdomain.IsValidKind(kind) {
		return triggerdomain.ErrInvalidKind
	}
	if err := triggerdomain.ValidateConfig(kind, config); err != nil {
		return err
	}
	switch kind {
	case triggerdomain.KindCron:
		if err := croninfra.Validate(triggerdomain.CronExpression(config)); err != nil {
			return triggerdomain.ErrInvalidCron
		}
	case triggerdomain.KindSensor:
		sc := triggerdomain.ParseSensorConfig(config)
		// A sensor's condition/output are evaluated at runtime over `payload` ONLY (the probe's
		// return value — the listener binds {payload}), so validate against exactly that namespace:
		// a ctx.x / input.x ref is rejected at create/edit, not silently at the first probe.
		//
		// sensor 的 condition/output 运行时只在 `payload` 上求值（探测返回值——listener 绑 {payload}），
		// 故恰在该命名空间上校验：ctx.x / input.x 引用在 create/edit 即被拒、而非首次探测时静默崩。
		// Carry the real cel-go reason so the agent fixes the sensor CEL instead of guessing (cf F8).
		// 把真 cel-go 因带进错误，使 agent 直接修 sensor CEL 而非猜（参 F8）。
		if _, err := celpkg.CompileFor([]string{"payload"}, sc.Condition); err != nil {
			return triggerdomain.ErrInvalidCEL.WithDetails(map[string]any{"field": "condition", "cel": sc.Condition, "reason": err.Error()})
		}
		if _, err := celpkg.CompileFor([]string{"payload"}, sc.Output); err != nil {
			return triggerdomain.ErrInvalidCEL.WithDetails(map[string]any{"field": "output", "cel": sc.Output, "reason": err.Error()})
		}
		// Eager target-existence check (F102, eager-validation family): reject a sensor whose probe
		// target (fn/hd/mcp) doesn't exist at create/edit, rather than letting it bind a dangling equip
		// edge and only fail loudly at the first probe. nil validator (unwired test) skips.
		// 目标存在性 eager 校验（F102，eager 校验家族）：sensor 的探测目标（fn/hd/mcp）不存在时在 create/edit
		// 即拒，而非绑上 dangling equip 边、首次探测才大声失败。validator 为 nil（未接线的测试）则跳过。
		if s.sensorTargets != nil {
			if err := s.sensorTargets.ValidateSensorTarget(ctx, sc.TargetKind, sc.TargetID, sc.Method); err != nil {
				return triggerdomain.ErrSensorTargetNotFound.WithDetails(map[string]any{
					"targetKind": sc.TargetKind, "targetId": sc.TargetID, "reason": err.Error()})
			}
		}
	}
	return nil
}
