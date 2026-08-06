// Guards for the measurement toolbox: synthesized images with KNOWN geometry, so each
// measurer is proven against ground truth it cannot have memorized. A measurement tool
// with an unproven formula is worse than eyeballing — it drifts silently and uniformly.
//
// 测量脚本箱的守卫:用**已知几何**的合成图,使每个测量器对着它不可能背下来的真值证明自己。
// 公式未经证明的测量工具比肉眼更糟——它静默且整齐划一地漂。
package main

import (
	"image"
	"image/color"
	"testing"
)

func fill(img *image.RGBA, r image.Rectangle, c color.RGBA) {
	for y := r.Min.Y; y < r.Max.Y; y++ {
		for x := r.Min.X; x < r.Max.X; x++ {
			img.Set(x, y, c)
		}
	}
}

func TestPairDiff_KnownChange(t *testing.T) {
	white := color.RGBA{255, 255, 255, 255}
	a := image.NewRGBA(image.Rect(0, 0, 100, 100))
	b := image.NewRGBA(image.Rect(0, 0, 100, 100))
	fill(a, a.Bounds(), white)
	fill(b, b.Bounds(), white)
	// 10×10 block moves — exactly 100+100 pixels differ (old spot + new spot).
	// 10×10 色块移动——恰 100+100 像素变化(旧位 + 新位)。
	fill(a, image.Rect(10, 10, 20, 20), color.RGBA{0, 0, 0, 255})
	fill(b, image.Rect(30, 10, 40, 20), color.RGBA{0, 0, 0, 255})
	frac, box := pairDiff(a, b)
	if want := 200.0 / 10000.0; frac != want {
		t.Fatalf("frac = %v, want %v", frac, want)
	}
	if box != image.Rect(10, 10, 40, 20) {
		t.Fatalf("box = %v", box)
	}
}

func TestPairDiff_EncoderNoiseAbsorbed(t *testing.T) {
	a := image.NewRGBA(image.Rect(0, 0, 10, 10))
	b := image.NewRGBA(image.Rect(0, 0, 10, 10))
	fill(a, a.Bounds(), color.RGBA{100, 100, 100, 255})
	fill(b, b.Bounds(), color.RGBA{104, 104, 104, 255}) // Δ4 < tol 8 — 编码噪声档
	if frac, _ := pairDiff(a, b); frac != 0 {
		t.Fatalf("noise-level delta reported as change: %v", frac)
	}
}

func TestPairDiffROI_IgnoresMotionOutsideTarget(t *testing.T) {
	white := color.RGBA{255, 255, 255, 255}
	a := image.NewRGBA(image.Rect(0, 0, 100, 100))
	b := image.NewRGBA(image.Rect(0, 0, 100, 100))
	fill(a, a.Bounds(), white)
	fill(b, b.Bounds(), white)
	fill(b, image.Rect(80, 80, 90, 90), color.RGBA{0, 0, 0, 255})
	if frac, _ := pairDiffROI(a, b, image.Rect(0, 0, 50, 50)); frac != 0 {
		t.Fatalf("outside motion leaked into ROI: %v", frac)
	}
	fill(b, image.Rect(10, 10, 20, 20), color.RGBA{0, 0, 0, 255})
	frac, box := pairDiffROI(a, b, image.Rect(0, 0, 50, 50))
	if frac != 100.0/2500.0 || box != image.Rect(10, 10, 20, 20) {
		t.Fatalf("ROI diff = %v %v", frac, box)
	}
}

func TestResizeNearestAndPairDiff_KnownSourceLoss(t *testing.T) {
	source := image.NewRGBA(image.Rect(0, 0, 2, 2))
	fill(source, source.Bounds(), color.RGBA{255, 255, 255, 255})
	frame := image.NewRGBA(image.Rect(0, 0, 4, 4))
	fill(frame, frame.Bounds(), color.RGBA{0, 0, 0, 255})

	frac, _ := pairDiff(resizeNearest(source, frame.Bounds()), frame)
	if frac != 1 {
		t.Fatalf("gross source loss = %v, want 1", frac)
	}
}

func TestResizeNearestPreservesMatchingImageAcrossRasters(t *testing.T) {
	source := image.NewRGBA(image.Rect(0, 0, 2, 2))
	fill(source, source.Bounds(), color.RGBA{255, 255, 255, 255})
	frame := image.NewRGBA(image.Rect(0, 0, 4, 4))
	fill(frame, frame.Bounds(), color.RGBA{255, 255, 255, 255})

	frac, box := pairDiff(resizeNearest(source, frame.Bounds()), frame)
	if frac != 0 || !box.Empty() {
		t.Fatalf("matching resized image = %v %v, want 0 and empty box", frac, box)
	}
}

func TestParseROI(t *testing.T) {
	bounds := image.Rect(0, 0, 100, 100)
	got, err := parseROI("10,20,30,40", bounds)
	if err != nil || got != image.Rect(10, 20, 40, 60) {
		t.Fatalf("parseROI = %v, %v", got, err)
	}
	if _, err := parseROI("1,2,0,4", bounds); err == nil {
		t.Fatal("zero-width ROI accepted")
	}
}

func TestLuminanceContrast_WCAGAnchors(t *testing.T) {
	// Black-on-white is the spec's own anchor: exactly 21:1.
	// 黑底白字是规范自身的锚点:恰 21:1。
	lw, _ := luminance("#FFFFFF")
	lb, _ := luminance("#000000")
	ratio := (lw + 0.05) / (lb + 0.05)
	if ratio < 20.99 || ratio > 21.01 {
		t.Fatalf("black/white ratio = %v, want 21", ratio)
	}
}

func TestParseHex(t *testing.T) {
	r, g, b, err := parseHex("#3B82F6")
	if err != nil || r != 0x3B || g != 0x82 || b != 0xF6 {
		t.Fatalf("parseHex: %d %d %d %v", r, g, b, err)
	}
	if _, _, _, err := parseHex("nope"); err == nil {
		t.Fatal("bad hex accepted")
	}
}
