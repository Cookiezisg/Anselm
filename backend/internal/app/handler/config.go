// config.go — Handler config (init_args values) AES-GCM at-rest encryption +
// per-Definition merge-patch update + computed ConfigState (unconfigured /
// partially_configured / ready).
//
// Per D-handler decision: one ciphertext blob per (user, handlerID) covers
// ALL init_args values (sensitive + non-sensitive lumped together for
// simplicity). The schema (InitArgSpec list) declares which keys are
// sensitive; UI / LLM tool result masks them but storage is uniformly encrypted.
//
// config.go —— Handler config(init_args 值)AES-GCM 静态加密 + per-Definition
// JSON Merge Patch 更新 + 计算 ConfigState。整 config JSON 一起加密(不区分
// sensitive/non-sensitive),简化;UI/LLM 工具结果按 schema 标记 mask。

package handler

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	handlerdomain "github.com/sunweilin/forgify/backend/internal/domain/handler"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// LoadConfig fetches encrypted config from DB + decrypts. Returns nil when
// unconfigured (ConfigEncrypted == ""), distinguishing from {} (empty config).
//
// LoadConfig 取加密 config + 解密。未配时返 nil(跟 {} 空 config 区分)。
func (s *Service) LoadConfig(ctx context.Context, handlerID string) (map[string]any, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("handlerapp.LoadConfig: %w", err)
	}
	ciphertext, err := s.repo.GetConfigEncrypted(ctx, handlerID)
	if err != nil {
		return nil, fmt.Errorf("handlerapp.LoadConfig: %w", err)
	}
	if ciphertext == "" {
		return nil, nil
	}
	plaintext, err := s.encryptor.Decrypt(ctx, []byte(ciphertext))
	if err != nil {
		return nil, fmt.Errorf("handlerapp.LoadConfig: %w: %v", handlerdomain.ErrConfigDecryptFailed, err)
	}
	var config map[string]any
	if err := json.Unmarshal(plaintext, &config); err != nil {
		return nil, fmt.Errorf("handlerapp.LoadConfig: unmarshal: %w", err)
	}
	return config, nil
}

// UpdateConfig merges partial into existing config (JSON Merge Patch — nil
// values delete keys), encrypts the whole blob, persists. Publishes a
// "config_updated" notification.
//
// UpdateConfig 合并 partial 到现有 config(JSON Merge Patch,nil 删键),
// 整 blob 加密回写,推 "config_updated" 通知。
func (s *Service) UpdateConfig(ctx context.Context, handlerID string, partial map[string]any) error {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return fmt.Errorf("handlerapp.UpdateConfig: %w", err)
	}
	existing, err := s.LoadConfig(ctx, handlerID)
	if err != nil && !errors.Is(err, handlerdomain.ErrConfigDecryptFailed) {
		return fmt.Errorf("handlerapp.UpdateConfig: load: %w", err)
	}
	if existing == nil {
		existing = map[string]any{}
	}
	merged := mergePatch(existing, partial)

	plaintext, err := json.Marshal(merged)
	if err != nil {
		return fmt.Errorf("handlerapp.UpdateConfig: marshal: %w", err)
	}
	ciphertext, err := s.encryptor.Encrypt(ctx, plaintext)
	if err != nil {
		return fmt.Errorf("handlerapp.UpdateConfig: encrypt: %w", err)
	}
	if err := s.repo.UpdateConfigEncrypted(ctx, handlerID, string(ciphertext)); err != nil {
		return fmt.Errorf("handlerapp.UpdateConfig: persist: %w", err)
	}
	s.publishHandlerEvent(ctx, handlerID, "config_updated", nil)
	return nil
}

// ClearConfig wipes the ciphertext blob to ""(back to unconfigured).
//
// ClearConfig 清密文 blob 到 "" (回未配置)。
func (s *Service) ClearConfig(ctx context.Context, handlerID string) error {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return fmt.Errorf("handlerapp.ClearConfig: %w", err)
	}
	if err := s.repo.ClearConfig(ctx, handlerID); err != nil {
		return fmt.Errorf("handlerapp.ClearConfig: %w", err)
	}
	s.publishHandlerEvent(ctx, handlerID, "config_cleared", nil)
	return nil
}

// ComputeConfigState compares declared init_args schema against actual stored
// config keys, returns one of (ready / partially_configured / unconfigured)
// + the list of missing required keys. attachComputed in CRUD reads this.
//
// ComputeConfigState 比较 declared schema vs 实际 config 键,返
// (ready / partially_configured / unconfigured) + 缺失必填 key 列表。
func (s *Service) ComputeConfigState(ctx context.Context, handlerID string, schema []handlerdomain.InitArgSpec) (string, []string, error) {
	cfg, err := s.LoadConfig(ctx, handlerID)
	if err != nil {
		return handlerdomain.ConfigStateUnconfigured, nil, err
	}

	missing := []string{}
	totalRequired := 0
	for _, arg := range schema {
		if !arg.Required {
			continue
		}
		totalRequired++
		if cfg == nil {
			missing = append(missing, arg.Name)
			continue
		}
		if v, ok := cfg[arg.Name]; !ok || v == nil {
			missing = append(missing, arg.Name)
		}
	}

	switch {
	case len(missing) == 0:
		return handlerdomain.ConfigStateReady, nil, nil
	case len(missing) == totalRequired:
		return handlerdomain.ConfigStateUnconfigured, missing, nil
	default:
		return handlerdomain.ConfigStatePartiallyConfigured, missing, nil
	}
}

// MaskedConfig returns a copy of the loaded config with sensitive values
// (per schema) replaced by "********". For GET / list endpoints that should
// never expose secrets.
//
// MaskedConfig 返加载好 config 的副本,sensitive 字段(按 schema)替为
// "********"。GET/list 端点用,永不暴露 secret。
func (s *Service) MaskedConfig(ctx context.Context, handlerID string, schema []handlerdomain.InitArgSpec) (map[string]any, error) {
	cfg, err := s.LoadConfig(ctx, handlerID)
	if err != nil {
		return nil, err
	}
	if cfg == nil {
		return nil, nil
	}
	sensitive := make(map[string]bool, len(schema))
	for _, a := range schema {
		if a.Sensitive {
			sensitive[a.Name] = true
		}
	}
	out := make(map[string]any, len(cfg))
	for k, v := range cfg {
		if sensitive[k] {
			out[k] = "********"
			continue
		}
		out[k] = v
	}
	return out, nil
}

// publishHandlerEvent is a thin notification helper. Action goes into the
// data envelope; UI subscribes to "handler" entity events and refreshes the
// affected entity.
//
// publishHandlerEvent 是 notification 包装。action 走 data envelope;
// UI 订阅 "handler" entity 事件后刷新对应 entity。
func (s *Service) publishHandlerEvent(ctx context.Context, handlerID, action string, extra map[string]any) {
	envelope := map[string]any{"action": action}
	for k, v := range extra {
		envelope[k] = v
	}
	s.notif.Publish(ctx, "handler", handlerID, envelope, "")
}
