package trigger

// Source-specific config accessors + structural validation. CEL SYNTAX is NOT checked
// here (domain must not import cel-go, 原则 #3) — the app layer compiles condition/output
// via pkg/cel at create/edit time and maps a compile error to ErrInvalidCEL.
//
// source 专属配置存取 + 结构校验。**CEL 语法不在此校验**（domain 不准 import cel-go，原则 #3）——
// app 层 create/edit 时用 pkg/cel 编译 condition/output，编译错映射 ErrInvalidCEL。

// Sensor target kinds: the thing the sensor periodically invokes.
//
// Sensor 目标种类：sensor 周期调用的东西。
const (
	SensorTargetFunction = "function"
	SensorTargetHandler  = "handler"
	SensorTargetMCP      = "mcp" // an installed mcp server's tool (TargetID=mcp_ entity id, Method=tool name)
)

// MinSensorIntervalSec floors the probe cadence — a tiny interval would hammer the
// target function/handler. interval=0 is a contradiction for polling (use webhook/fsnotify
// for real-time push instead).
//
// MinSensorIntervalSec 是探测节流下限——过小会打爆目标 function/handler。interval=0 对轮询是矛盾（实时用 webhook/fsnotify）。
const MinSensorIntervalSec = 5

// SensorConfig is the parsed sensor source config.
//
// SensorConfig 是解析后的 sensor source 配置。
type SensorConfig struct {
	TargetKind  string // function | handler | mcp — what to invoke
	TargetID    string // entity id: fn_… / hd… / mcp_…（relation equip 边 + CallTool 都按 id 寻址）
	Method      string // handler: method name · mcp: tool name (function is the whole unit)
	IntervalSec int    // probe cadence in seconds (>= MinSensorIntervalSec)
	Condition   string // CEL bool expr over `payload` (= the invoke return value)
	Output      string // CEL expr building the fire payload from `payload`
}

// ParseSensorConfig reads a sensor Trigger.Config into a typed struct (lenient: JSON
// numbers arrive as float64).
//
// ParseSensorConfig 把 sensor 的 Config 读成强类型结构（宽松：JSON 数字以 float64 到达）。
func ParseSensorConfig(cfg map[string]any) SensorConfig {
	return SensorConfig{
		TargetKind:  asString(cfg["targetKind"]),
		TargetID:    asString(cfg["targetId"]),
		Method:      asString(cfg["method"]),
		IntervalSec: asInt(cfg["intervalSec"]),
		Condition:   asString(cfg["condition"]),
		Output:      asString(cfg["output"]),
	}
}

// Misfire policies (cron only, scheduler 工单⑨, 判决⑥): what to do about cron ticks that were
// due while the app was not running. skip (default) = record each missed tick as a `missed`
// firing, run nothing — a local app must never catch-up-storm. catchup_one = additionally fire
// ONCE for the most recent missed tick (through the normal fan-out path, origin stays cron);
// older ticks are still recorded missed. Lives in the config JSON — no column.
//
// Misfire 策略（仅 cron，scheduler 工单⑨，判决⑥）：app 未运行期间到期的 cron 刻度怎么办。
// skip（默认）= 每个错过点记一条 `missed` firing、什么都不跑——本地 app 绝不能补跑风暴。
// catchup_one = 额外对**最近一个**错过点补一次 fire（照正常扇出径，origin 仍 cron）；更早的仍记 missed。
// 存 config JSON——不加列。
const (
	MisfireSkip       = "skip"
	MisfireCatchupOne = "catchup_one"
)

// MisfirePolicy reads the cron misfire policy from config; absent/empty reads as skip (the default).
//
// MisfirePolicy 从 config 读 cron misfire 策略；缺席/空 = skip（默认）。
func MisfirePolicy(cfg map[string]any) string {
	if p := asString(cfg["misfirePolicy"]); p != "" {
		return p
	}
	return MisfireSkip
}

// CronExpression / WebhookPath / WebhookSecret / FsnotifyPath read the push-source keys.
//
// CronExpression / WebhookPath / WebhookSecret / FsnotifyPath 读 push 型 source 的键。
func CronExpression(cfg map[string]any) string { return asString(cfg["expression"]) }
func WebhookPath(cfg map[string]any) string    { return asString(cfg["path"]) }
func WebhookSecret(cfg map[string]any) string  { return asString(cfg["secret"]) }
func FsnotifyPath(cfg map[string]any) string   { return asString(cfg["path"]) }

// ValidateConfig checks structural validity per kind (presence + interval floor + target
// shape). Returns a domain error suitable for HTTP. CEL syntax is the app layer's job.
//
// ValidateConfig 按 kind 校验结构合法性（必填 + interval 下限 + target 形状），返可冒泡 HTTP 的 domain 错误。
func ValidateConfig(kind string, cfg map[string]any) error {
	switch kind {
	case KindCron:
		if CronExpression(cfg) == "" {
			return ErrInvalidCron
		}
		// Vocabulary-check the misfire policy at create/edit (scheduler 工单⑨) — a typo'd policy
		// must fail loudly here, not silently behave as skip at the next wake. A non-string value
		// is equally rejected (asString would silently read it as "" = skip).
		// misfire 策略在 create/edit 词表校验（scheduler 工单⑨）——写错的策略必须在此大声失败，
		// 不能到下次睡醒才静默按 skip 走。非字符串值同样拒（asString 会静默读成 "" = skip）。
		if v, ok := cfg["misfirePolicy"]; ok {
			s, isStr := v.(string)
			if !isStr || (s != "" && s != MisfireSkip && s != MisfireCatchupOne) {
				return ErrInvalidMisfirePolicy
			}
		}
	case KindWebhook:
		if WebhookPath(cfg) == "" {
			return ErrInvalidConfig
		}
	case KindFsnotify:
		if FsnotifyPath(cfg) == "" {
			return ErrInvalidConfig
		}
	case KindSensor:
		sc := ParseSensorConfig(cfg)
		if sc.TargetKind != SensorTargetFunction && sc.TargetKind != SensorTargetHandler && sc.TargetKind != SensorTargetMCP {
			return ErrSensorTargetRequired
		}
		if sc.TargetID == "" {
			return ErrSensorTargetRequired
		}
		// handler/mcp need a sub-unit name (method / tool); function is the whole callable unit.
		// handler/mcp 需要子单元名（method / tool）；function 整体即可调单元。
		if (sc.TargetKind == SensorTargetHandler || sc.TargetKind == SensorTargetMCP) && sc.Method == "" {
			return ErrSensorTargetRequired
		}
		if sc.Condition == "" || sc.Output == "" {
			return ErrInvalidConfig
		}
		if sc.IntervalSec < MinSensorIntervalSec {
			return ErrInvalidInterval
		}
	default:
		return ErrInvalidKind
	}
	return nil
}

func asString(v any) string {
	s, _ := v.(string)
	return s
}

func asInt(v any) int {
	switch n := v.(type) {
	case int:
		return n
	case int64:
		return int(n)
	case float64:
		return int(n)
	}
	return 0
}
