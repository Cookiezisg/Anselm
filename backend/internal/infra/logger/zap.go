// Package logger provides the project-wide zap logger factory.
//
// Package logger 提供项目级 zap logger 工厂。
package logger

import (
	"fmt"
	"os"
	"path/filepath"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
	lumberjack "gopkg.in/natefinch/lumberjack.v2"
)

// New builds the project zap logger: a console core (dev=true → colored console, else
// JSON to stderr) TEE'd with a rotating JSON file at <logDir>/anselm.log — the desktop
// app's support story: "send me the log file" must always be answerable, a windowed
// app's stdout goes nowhere. Empty logDir keeps console-only (tests).
//
// New 构造项目 zap logger：控制台 core（dev=true 彩色控制台，否则 stderr JSON）TEE 上
// <logDir>/anselm.log 的轮转 JSON 文件——桌面 app 的报障故事：「把日志文件发我」必须永远
// 可答，窗口化 app 的 stdout 没人看得见。logDir 为空则只留控制台（测试）。
func New(dev bool, logDir string) (*zap.Logger, error) {
	level := zapcore.InfoLevel
	if dev {
		level = zapcore.DebugLevel
	}

	var consoleEnc zapcore.Encoder
	if dev {
		ec := zap.NewDevelopmentEncoderConfig()
		ec.EncodeLevel = zapcore.CapitalColorLevelEncoder
		consoleEnc = zapcore.NewConsoleEncoder(ec)
	} else {
		ec := zap.NewProductionEncoderConfig()
		ec.TimeKey = "time"
		ec.EncodeTime = zapcore.ISO8601TimeEncoder
		consoleEnc = zapcore.NewJSONEncoder(ec)
	}
	cores := []zapcore.Core{
		zapcore.NewCore(consoleEnc, zapcore.Lock(os.Stderr), level),
	}

	if logDir != "" {
		if err := os.MkdirAll(logDir, 0o755); err != nil {
			return nil, fmt.Errorf("logger: mkdir log dir: %w", err)
		}
		fileEC := zap.NewProductionEncoderConfig()
		fileEC.TimeKey = "time"
		fileEC.EncodeTime = zapcore.ISO8601TimeEncoder
		fileSink := zapcore.AddSync(&lumberjack.Logger{
			Filename:   filepath.Join(logDir, "anselm.log"),
			MaxSize:    10, // MB per file before rotation. 单文件轮转阈值（MB）。
			MaxBackups: 3,
			MaxAge:     28, // days. 天。
			Compress:   true,
		})
		cores = append(cores, zapcore.NewCore(zapcore.NewJSONEncoder(fileEC), fileSink, level))
	}

	// The redaction floor wraps the TEE, so BOTH sinks (stderr and the rotating support-log file)
	// are covered by one pass and no future sink can be added below it. See redact.go for why this
	// is a core wrapper and why it is a floor, not a proof.
	// 脱敏底座包在 TEE 之外:stderr 与轮转支持日志**两个 sink** 一次覆盖,且此后新增的 sink 不可能挂在它
	// 下面。为何做成 core 包装、为何只是底线而非证明,见 redact.go。
	return zap.New(redactCore{Core: zapcore.NewTee(cores...)}), nil
}
