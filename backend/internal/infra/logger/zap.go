// Package logger provides the project-wide zap logger factory.
//
// Package logger 提供项目级 zap logger 工厂。
package logger

import (
	"fmt"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

// New builds the project zap logger: dev=true → colored console, else JSON.
//
// New 构造项目 zap logger：dev=true 用彩色控制台，否则 JSON。
func New(dev bool) (*zap.Logger, error) {
	var cfg zap.Config
	if dev {
		cfg = zap.NewDevelopmentConfig()
		cfg.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
	} else {
		cfg = zap.NewProductionConfig()
		cfg.EncoderConfig.TimeKey = "time"
		cfg.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	}

	log, err := cfg.Build()
	if err != nil {
		return nil, fmt.Errorf("build zap logger: %w", err)
	}
	return log, nil
}
