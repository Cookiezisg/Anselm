package handler

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"go.uber.org/zap"

	handlerdomain "github.com/sunweilin/forgify/backend/internal/domain/handler"
)

// LoadConfig fetches + decrypts the init-args config; nil when unconfigured.
//
// LoadConfig 取并解密 init-args config；未配置返 nil。
func (s *Service) LoadConfig(ctx context.Context, handlerID string) (map[string]any, error) {
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

// UpdateConfig applies a JSON Merge Patch, re-encrypts the whole blob, and restarts the
// resident instance so it re-runs __init__ with the new config (the heart of "change
// config → restart"). Restart is best-effort: if config is now complete the instance
// comes back fresh; if still incomplete it stays stopped.
//
// UpdateConfig 应用 JSON Merge Patch、整 blob 重加密回写，并重启常驻实例使其用新 config 重跑
// __init__（「改 config → 重启」的核心）。重启 best-effort：config 配齐则新实例起来，未齐则停着。
func (s *Service) UpdateConfig(ctx context.Context, handlerID string, partial map[string]any) error {
	existing, err := s.LoadConfig(ctx, handlerID)
	if err != nil && !errors.Is(err, handlerdomain.ErrConfigDecryptFailed) {
		return fmt.Errorf("handlerapp.UpdateConfig: %w", err)
	}
	if existing == nil {
		existing = map[string]any{}
	}
	plaintext, err := json.Marshal(mergePatch(existing, partial))
	if err != nil {
		return fmt.Errorf("handlerapp.UpdateConfig: marshal: %w", err)
	}
	ciphertext, err := s.encryptor.Encrypt(ctx, plaintext)
	if err != nil {
		return fmt.Errorf("handlerapp.UpdateConfig: encrypt: %w", err)
	}
	if err := s.repo.UpdateConfigEncrypted(ctx, handlerID, string(ciphertext)); err != nil {
		return fmt.Errorf("handlerapp.UpdateConfig: %w", err)
	}
	s.publish(ctx, "config_updated", handlerID, nil)
	if _, rerr := s.manager.Restart(ctx, handlerID); rerr != nil {
		s.log.Info("handlerapp.UpdateConfig: instance not restarted (likely still needs config)", zap.String("handlerId", handlerID), zap.Error(rerr))
	}
	return nil
}

// ClearConfig wipes the config and stops the resident instance (it can no longer run).
//
// ClearConfig 清空 config 并停常驻实例（已无法运行）。
func (s *Service) ClearConfig(ctx context.Context, handlerID string) error {
	if err := s.repo.ClearConfig(ctx, handlerID); err != nil {
		return fmt.Errorf("handlerapp.ClearConfig: %w", err)
	}
	s.publish(ctx, "config_cleared", handlerID, nil)
	s.manager.Stop(ctx, handlerID)
	return nil
}

// ComputeConfigState compares declared init-args schema against stored config.
//
// ComputeConfigState 比较 declared init-args schema 与已存 config。
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

// MaskedConfig returns the config with sensitive values replaced by "********".
//
// MaskedConfig 返 config 副本，sensitive 字段替换为 "********"。
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
