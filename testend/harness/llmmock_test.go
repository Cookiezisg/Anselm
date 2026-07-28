package harness

import (
	"bytes"
	"image"
	_ "image/png"
	"testing"
)

// MockPNG is used as the mocked upstream's image-generation result. A magic-header check is not
// enough: real provider routes decode the pixels, so a broken PNG would make static media tests
// prove a payload no visual model can consume.
func TestMockPNGDecodes(t *testing.T) {
	cfg, _, err := image.DecodeConfig(bytes.NewReader(MockPNG))
	if err != nil {
		t.Fatalf("MockPNG must be decoder-valid: %v", err)
	}
	if cfg.Width != 1 || cfg.Height != 1 {
		t.Fatalf("MockPNG dimensions = %dx%d, want 1x1", cfg.Width, cfg.Height)
	}
}
