// registry.go — value types for the bundled MCP server marketplace.
// The actual []RegistryEntry data lives in app/mcp/registry.go (D5-2)
// because it's a known-list of built-ins; the types here are the
// contract for both the embedded V1 catalog and a future remote/file-
// loaded V2 source (per mcp.md §5.5 strategy-pattern note).
//
// registry.go ——内置 MCP server marketplace 的值类型。实际 []RegistryEntry
// 数据在 app/mcp/registry.go（D5-2）——是已知内置清单；这里的类型是 V1
// embed 与 V2 远程/文件加载的共享契约（mcp.md §5.5 strategy pattern）。
package mcp

// RegistryEntry is one marketplace listing the user can install via the
// install wizard (UI fills RequiredEnv / RequiredArgs, backend writes
// mcp.json + delegates lazy install to sandboxapp). V1 ships 6 bundled
// entries (5 visible + 1 hidden test); user-added custom servers don't
// need a RegistryEntry — they go straight into mcp.json.
//
// RegistryEntry 是 marketplace 一个可装条目，UI 填 RequiredEnv /
// RequiredArgs → 后端写 mcp.json + 经 sandboxapp 懒装。V1 内置 6 项
// （5 可见 + 1 hidden test）；用户自加的自定义 server 无需 RegistryEntry
// ——直接进 mcp.json。
type RegistryEntry struct {
	Name                 string            `json:"name"`         // mcp.json server key
	DisplayName          string            `json:"displayName"`  // UI label
	Description          string            `json:"description"`
	Category             string            `json:"category"`     // data / web / doc / browser / demo / docs / ...
	Homepage             string            `json:"homepage,omitempty"`
	License              string            `json:"license,omitempty"`
	Runtime              string            `json:"runtime"`      // node / python / binary
	Bundled              bool              `json:"bundled"`      // V1 marketplace recommendation
	Hidden               bool              `json:"hidden,omitempty"` // marketplace UI hides it (dev/test)
	InstallCmd           InstallCmd        `json:"installCmd"`
	PostInstallSteps     []PostInstallStep `json:"postInstallSteps,omitempty"`
	RequiredEnv          []EnvRequirement  `json:"requiredEnv,omitempty"`
	RequiredArgs         []ArgRequirement  `json:"requiredArgs,omitempty"`
	DefaultTimeoutSec    int               `json:"defaultTimeoutSec,omitempty"` // 0 = use global 30s
	OnlineOnly           bool              `json:"onlineOnly,omitempty"`        // requires sustained internet
	UnsupportedPlatforms []string          `json:"unsupportedPlatforms,omitempty"` // GOOS values to hide on
	Notes                string            `json:"notes,omitempty"`
}

// InstallCmd is what the install wizard runs to make the server
// available. Args may contain "${name}" tokens that get substituted
// from RequiredArgs at install time (e.g. "${dbPath}" for the SQLite
// server's --db-path arg).
//
// InstallCmd 是 install 向导跑的命令。Args 可含 "${name}" token，
// 安装时从 RequiredArgs 替换（例：SQLite server 的 --db-path 用
// "${dbPath}"）。
type InstallCmd struct {
	Command string   `json:"command"` // npx / uvx / ...
	Args    []string `json:"args"`
}

// PostInstallStep is an extra command run after InstallCmd succeeds —
// e.g. Playwright needs `playwright install chromium` to download the
// browser binary. StreamProgress controls whether the UI shows a
// progress bar for long-running steps.
//
// PostInstallStep 是 InstallCmd 成功后的额外命令——如 Playwright 需
// `playwright install chromium` 下载浏览器二进制。StreamProgress 控制
// UI 是否显示长任务进度条。
type PostInstallStep struct {
	Description    string   `json:"description"` // UI label, e.g. "Downloading Chromium (~150MB)"
	Command        string   `json:"command"`
	Args           []string `json:"args"`
	StreamProgress bool     `json:"streamProgress"`
}

// EnvRequirement is one env var the user must provide before install
// (typically a credential). Secret=true makes the UI mask the input
// field; SetupURL points the user at where to get the value (e.g.
// GitHub's PAT settings page).
//
// EnvRequirement 是用户必填的一个 env 变量（通常是凭证）。Secret=true
// 让 UI mask 输入；SetupURL 指向获取链接（如 GitHub PAT 设置页）。
type EnvRequirement struct {
	Name        string `json:"name"`        // GITHUB_PERSONAL_ACCESS_TOKEN
	Description string `json:"description"`
	SetupURL    string `json:"setupUrl,omitempty"`
	Secret      bool   `json:"secret"`
}

// ArgRequirement is a value the user must supply at install time that
// gets substituted into InstallCmd.Args via the "${name}" template
// (Type drives the UI input widget — path / url / string).
//
// ArgRequirement 是用户安装时必填的一个值，通过 "${name}" 模板替换进
// InstallCmd.Args（Type 驱动 UI 输入控件——path / url / string）。
type ArgRequirement struct {
	Name        string `json:"name"`        // dbPath / rootPath / ...
	Description string `json:"description"`
	Type        string `json:"type"`        // path / url / string
	Default     string `json:"default,omitempty"`
}
