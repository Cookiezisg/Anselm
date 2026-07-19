package apikey

import "testing"

// The provider CATALOG hides the mock fixture outside dev (WRK-062 S-5) while key creation keeps
// accepting it (T6 testend provisions mock keys without ANSELM_DEV — only the user-facing dropdown
// must not show it). 目录非 dev 藏 mock(S-5);建 key 白名单不动(T6 设施)。
func TestListProviders_MockIsDevOnly(t *testing.T) {
	has := func(list []ProviderMeta, name string) bool {
		for _, m := range list {
			if m.Name == name {
				return true
			}
		}
		return false
	}
	if has(ListProviders(false), "mock") {
		t.Error("mock must be filtered from the non-dev catalog")
	}
	if !has(ListProviders(true), "mock") {
		t.Error("mock must stay listed under dev")
	}
	// The creation whitelist is untouched — mock keys still validate. 建 key 白名单不动。
	if !isValidProvider("mock") {
		t.Error("mock must remain a VALID provider for key creation (testend fixture)")
	}
}
