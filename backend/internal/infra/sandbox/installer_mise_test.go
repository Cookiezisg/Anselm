// installer_mise_test.go — pure-function unit tests for MiseInstaller.
//
// We do NOT exercise Install / Locate / ListAvailable here — those shell
// out to mise and download tens of MB of language runtime, which belongs
// in the pipeline test suite (gated by mise embed presence). What's tested
// here: interface compliance, Kind() reporting, ResolveDefault() returning
// the construction-time default verbatim.
//
// installer_mise_test.go ——MiseInstaller 的 pure-function 单测。
//
// 这里不测 Install / Locate / ListAvailable——那些 shell out 到 mise 下几十 MB
// 语言 runtime，归 pipeline 测试套（由 mise embed 存在与否 gate）。这里测：
// 接口契约、Kind() 上报、ResolveDefault() 原样返回构造时默认值。

package sandbox

import (
	"context"
	"testing"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// compile-time interface satisfaction check.
var _ sandboxdomain.RuntimeInstaller = (*MiseInstaller)(nil)

func TestMiseInstaller_Kind(t *testing.T) {
	cases := []string{"python", "node", "rust", "go", "java", "ruby", "php"}
	for _, kind := range cases {
		mi := NewMiseInstaller("/tmp/mise", kind, "1.0")
		if got := mi.Kind(); got != kind {
			t.Errorf("Kind() = %q, want %q", got, kind)
		}
	}
}

func TestMiseInstaller_ResolveDefault_ReturnsConstructionVersion(t *testing.T) {
	cases := map[string]string{
		"3.12":         "3.12",
		"22":           "22",
		"3.12.5":       "3.12.5",
		"stable":       "stable",
		"":             "",
	}
	for input, want := range cases {
		mi := NewMiseInstaller("/tmp/mise", "python", input)
		got, err := mi.ResolveDefault(context.Background())
		if err != nil {
			t.Errorf("ResolveDefault(%q): %v", input, err)
			continue
		}
		if got != want {
			t.Errorf("ResolveDefault(%q) = %q, want %q", input, got, want)
		}
	}
}
