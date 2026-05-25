package function

import "testing"

func TestFunctionCatalogSource_InvokeTool(t *testing.T) {
	src := (&Service{}).AsCatalogSource()
	if got := src.InvokeTool(); got != "run_function" {
		t.Errorf("InvokeTool() = %q, want %q", got, "run_function")
	}
}
