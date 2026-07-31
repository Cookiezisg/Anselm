// measure is the acceptance rig's measurement toolbox (WRK-087 §4.2): every visual judgment
// that CAN be a number MUST be a number, because a measured law never drifts with the judge's
// form. Four sub-commands over PNG frames/screenshots:
//
//	diff     — consecutive-frame changed-pixel fraction + bounding box (jump/flicker forensics)
//	regions  — connected components of a target color: rect + per-row heights (highlight
//	           uniformity: "等高吗、有缝吗" answered in pixels, not vibes)
//	contrast — WCAG 2.x contrast ratio of two colors
//	latency  — first frame after an action frame that differs beyond threshold → milliseconds
//
// measure 是验收台架的测量脚本箱(WRK-087 §4.2):凡能成为数字的视觉判断必须成为数字——被测量的
// 法条不随裁判当天状态漂移。四个子命令吃 PNG 帧/截图:
//
//	diff     — 相邻帧变化像素占比 + 变化包围盒(跳变/闪的取证)
//	regions  — 目标色连通域:矩形 + 逐行高度(高亮等高:「等高吗、有缝吗」用像素回答,不用感觉)
//	contrast — WCAG 2.x 双色对比度
//	latency  — 动作帧之后首个越阈变化帧 → 毫秒
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"image"
	"image/png"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	switch os.Args[1] {
	case "diff":
		cmdDiff(os.Args[2:])
	case "regions":
		cmdRegions(os.Args[2:])
	case "contrast":
		cmdContrast(os.Args[2:])
	case "latency":
		cmdLatency(os.Args[2:])
	default:
		usage()
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, `usage: measure <diff|regions|contrast|latency> [flags]
	  diff     -dir <frames/> [-roi x,y,w,h] [-threshold 0.0005]
	  regions  -img <shot.png> -color '#RRGGBB' [-tol 24] [-min 16]
	  contrast -fg '#RRGGBB' -bg '#RRGGBB'
	  latency  -dir <frames/> -fps 60 -action <frameIndex> [-roi x,y,w,h] [-threshold 0.0005]`)
	os.Exit(2)
}

func loadPNG(path string) (*image.RGBA, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	img, err := png.Decode(f)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	b := img.Bounds()
	out := image.NewRGBA(b)
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			out.Set(x, y, img.At(x, y))
		}
	}
	return out, nil
}

func framePaths(dir string) []string {
	entries, err := os.ReadDir(dir)
	if err != nil {
		fatal(err)
	}
	var out []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".png") {
			out = append(out, filepath.Join(dir, e.Name()))
		}
	}
	sort.Strings(out)
	if len(out) < 2 {
		fatal(fmt.Errorf("need ≥2 frames in %s", dir))
	}
	return out
}

// pairDiff reports the changed-pixel fraction and changed bounding box between two frames.
// A per-channel tolerance of 8 absorbs video-encoder noise — without it every h264 frame
// "changes" everywhere and the numbers say nothing.
//
// pairDiff 报告两帧的变化像素占比与变化包围盒。每通道容差 8 吸收视频编码噪声——不设则每个
// h264 帧「处处在变」,数字什么都说明不了。
func pairDiff(a, b *image.RGBA) (frac float64, box image.Rectangle) {
	return pairDiffROI(a, b, a.Bounds())
}

func pairDiffROI(a, b *image.RGBA, roi image.Rectangle) (frac float64, box image.Rectangle) {
	const tol = 8
	bounds := a.Bounds()
	if b.Bounds() != bounds {
		return 1, bounds
	}
	roi = roi.Intersect(bounds)
	if roi.Empty() {
		return 0, image.Rectangle{}
	}
	changed := 0
	minX, minY, maxX, maxY := roi.Max.X, roi.Max.Y, roi.Min.X-1, roi.Min.Y-1
	for y := roi.Min.Y; y < roi.Max.Y; y++ {
		ai := a.PixOffset(roi.Min.X, y)
		bi := b.PixOffset(roi.Min.X, y)
		for x := roi.Min.X; x < roi.Max.X; x++ {
			if absInt(int(a.Pix[ai])-int(b.Pix[bi])) > tol ||
				absInt(int(a.Pix[ai+1])-int(b.Pix[bi+1])) > tol ||
				absInt(int(a.Pix[ai+2])-int(b.Pix[bi+2])) > tol {
				changed++
				if x < minX {
					minX = x
				}
				if x > maxX {
					maxX = x
				}
				if y < minY {
					minY = y
				}
				if y > maxY {
					maxY = y
				}
			}
			ai += 4
			bi += 4
		}
	}
	total := roi.Dx() * roi.Dy()
	if changed == 0 {
		return 0, image.Rectangle{}
	}
	return float64(changed) / float64(total), image.Rect(minX, minY, maxX+1, maxY+1)
}

func absInt(v int) int {
	if v < 0 {
		return -v
	}
	return v
}

type diffRow struct {
	From string  `json:"from"`
	To   string  `json:"to"`
	Frac float64 `json:"changedFrac"`
	Box  string  `json:"box,omitempty"`
}

func cmdDiff(args []string) {
	fs := flag.NewFlagSet("diff", flag.ExitOnError)
	dir := fs.String("dir", "", "frame directory (sorted *.png)")
	roiArg := fs.String("roi", "", "optional region x,y,w,h; excludes clocks, cursor, and unrelated animation")
	threshold := fs.Float64("threshold", 0.0005, "report pairs with changedFrac above this")
	_ = fs.Parse(args)
	if *dir == "" {
		usage()
	}
	paths := framePaths(*dir)
	prev, err := loadPNG(paths[0])
	if err != nil {
		fatal(err)
	}
	enc := json.NewEncoder(os.Stdout)
	roi, err := parseROI(*roiArg, prev.Bounds())
	if err != nil {
		fatal(err)
	}
	for i := 1; i < len(paths); i++ {
		cur, err := loadPNG(paths[i])
		if err != nil {
			fatal(err)
		}
		frac, box := pairDiffROI(prev, cur, roi)
		if frac > *threshold {
			_ = enc.Encode(diffRow{
				From: filepath.Base(paths[i-1]), To: filepath.Base(paths[i]),
				Frac: round5(frac), Box: box.String(),
			})
		}
		prev = cur
	}
}

type regionRow struct {
	X      int `json:"x"`
	Y      int `json:"y"`
	W      int `json:"w"`
	H      int `json:"h"`
	Pixels int `json:"pixels"`
}

// cmdRegions extracts connected components of pixels within tol of the target color and prints
// each component's rect. For a text-selection highlight the verdict reads directly off the
// output: uniform heights and shared x-edges = clean; ragged heights or vertical gaps = defect.
//
// cmdRegions 提取「与目标色距离 ≤ tol」像素的连通域,逐域打印矩形。对文本选区高亮,裁决直接
// 从输出读出:各域等高且 x 边对齐 = 干净;高度参差或纵向留缝 = 缺陷。
func cmdRegions(args []string) {
	fs := flag.NewFlagSet("regions", flag.ExitOnError)
	img := fs.String("img", "", "screenshot PNG")
	colorHex := fs.String("color", "", "target color '#RRGGBB'")
	tol := fs.Int("tol", 24, "per-channel tolerance")
	minPix := fs.Int("min", 16, "ignore components smaller than this many pixels")
	_ = fs.Parse(args)
	if *img == "" || *colorHex == "" {
		usage()
	}
	tr, tg, tb, err := parseHex(*colorHex)
	if err != nil {
		fatal(err)
	}
	pic, err := loadPNG(*img)
	if err != nil {
		fatal(err)
	}
	b := pic.Bounds()
	w, h := b.Dx(), b.Dy()
	mask := make([]bool, w*h)
	for y := range h {
		i := pic.PixOffset(b.Min.X, b.Min.Y+y)
		for x := range w {
			if absInt(int(pic.Pix[i])-tr) <= *tol &&
				absInt(int(pic.Pix[i+1])-tg) <= *tol &&
				absInt(int(pic.Pix[i+2])-tb) <= *tol {
				mask[y*w+x] = true
			}
			i += 4
		}
	}
	seen := make([]bool, w*h)
	enc := json.NewEncoder(os.Stdout)
	var stack []int
	for start := 0; start < w*h; start++ {
		if !mask[start] || seen[start] {
			continue
		}
		minX, minY, maxX, maxY, count := w, h, 0, 0, 0
		stack = append(stack[:0], start)
		seen[start] = true
		for len(stack) > 0 {
			p := stack[len(stack)-1]
			stack = stack[:len(stack)-1]
			px, py := p%w, p/w
			count++
			if px < minX {
				minX = px
			}
			if px > maxX {
				maxX = px
			}
			if py < minY {
				minY = py
			}
			if py > maxY {
				maxY = py
			}
			for _, q := range [4]int{p - 1, p + 1, p - w, p + w} {
				if q < 0 || q >= w*h || seen[q] || !mask[q] {
					continue
				}
				// left/right neighbors must stay on the same row — index math wraps rows otherwise.
				// 左右邻必须同行——否则下标算术会跨行回卷。
				if (q == p-1 || q == p+1) && q/w != py {
					continue
				}
				seen[q] = true
				stack = append(stack, q)
			}
		}
		if count >= *minPix {
			_ = enc.Encode(regionRow{X: minX, Y: minY, W: maxX - minX + 1, H: maxY - minY + 1, Pixels: count})
		}
	}
}

func parseHex(s string) (r, g, b int, err error) {
	s = strings.TrimPrefix(strings.TrimSpace(s), "#")
	if len(s) != 6 {
		return 0, 0, 0, fmt.Errorf("color must be #RRGGBB, got %q", s)
	}
	v, err := strconv.ParseUint(s, 16, 32)
	if err != nil {
		return 0, 0, 0, err
	}
	return int(v >> 16 & 0xff), int(v >> 8 & 0xff), int(v & 0xff), nil
}

// cmdContrast prints the WCAG 2.x contrast ratio (relative luminance formula, the spec's own).
//
// cmdContrast 打印 WCAG 2.x 对比度(相对亮度公式,规范原文那一个)。
func cmdContrast(args []string) {
	fs := flag.NewFlagSet("contrast", flag.ExitOnError)
	fg := fs.String("fg", "", "foreground '#RRGGBB'")
	bg := fs.String("bg", "", "background '#RRGGBB'")
	_ = fs.Parse(args)
	if *fg == "" || *bg == "" {
		usage()
	}
	l1, err := luminance(*fg)
	if err != nil {
		fatal(err)
	}
	l2, err := luminance(*bg)
	if err != nil {
		fatal(err)
	}
	if l1 < l2 {
		l1, l2 = l2, l1
	}
	ratio := (l1 + 0.05) / (l2 + 0.05)
	fmt.Printf("%.2f:1 (AA normal ≥4.5, AA large ≥3.0, AAA normal ≥7.0)\n", ratio)
}

func luminance(hex string) (float64, error) {
	r, g, b, err := parseHex(hex)
	if err != nil {
		return 0, err
	}
	lin := func(c int) float64 {
		s := float64(c) / 255
		if s <= 0.04045 {
			return s / 12.92
		}
		return math.Pow((s+0.055)/1.055, 2.4)
	}
	return 0.2126*lin(r) + 0.7152*lin(g) + 0.0722*lin(b), nil
}

// cmdLatency finds the first frame after the action frame that differs beyond threshold and
// converts the frame distance to milliseconds. The action frame itself is the baseline — the
// question is "how long until the UI visibly reacted", not "how long until it settled".
//
// cmdLatency 找动作帧之后首个越阈变化帧,把帧距换算成毫秒。基线是动作帧自己——问题是「UI 多久
// **可见地**反应了」,不是「多久稳定了」。
func cmdLatency(args []string) {
	fs := flag.NewFlagSet("latency", flag.ExitOnError)
	dir := fs.String("dir", "", "frame directory (sorted *.png)")
	fps := fs.Float64("fps", 60, "extraction fps of the frame directory")
	action := fs.Int("action", -1, "0-based index of the action frame")
	threshold := fs.Float64("threshold", 0.0005, "changedFrac that counts as visible feedback")
	roiArg := fs.String("roi", "", "optional region x,y,w,h; excludes unrelated motion")
	_ = fs.Parse(args)
	if *dir == "" || *action < 0 {
		usage()
	}
	paths := framePaths(*dir)
	if *action >= len(paths)-1 {
		fatal(fmt.Errorf("action index %d out of range (%d frames)", *action, len(paths)))
	}
	base, err := loadPNG(paths[*action])
	if err != nil {
		fatal(err)
	}
	roi, err := parseROI(*roiArg, base.Bounds())
	if err != nil {
		fatal(err)
	}
	for i := *action + 1; i < len(paths); i++ {
		cur, err := loadPNG(paths[i])
		if err != nil {
			fatal(err)
		}
		frac, box := pairDiffROI(base, cur, roi)
		if frac > *threshold {
			ms := float64(i-*action) / *fps * 1000
			fmt.Printf(`{"feedbackFrame":%d,"latencyMs":%.1f,"changedFrac":%.5f,"box":%q}`+"\n",
				i, ms, frac, box.String())
			return
		}
	}
	fmt.Println(`{"feedbackFrame":-1,"latencyMs":-1,"note":"no visible feedback in window"}`)
}

func parseROI(raw string, bounds image.Rectangle) (image.Rectangle, error) {
	if strings.TrimSpace(raw) == "" {
		return bounds, nil
	}
	parts := strings.Split(raw, ",")
	if len(parts) != 4 {
		return image.Rectangle{}, fmt.Errorf("roi must be x,y,w,h, got %q", raw)
	}
	values := make([]int, 4)
	for i, part := range parts {
		v, err := strconv.Atoi(strings.TrimSpace(part))
		if err != nil {
			return image.Rectangle{}, fmt.Errorf("roi must be x,y,w,h, got %q", raw)
		}
		values[i] = v
	}
	if values[2] <= 0 || values[3] <= 0 {
		return image.Rectangle{}, fmt.Errorf("roi width and height must be positive")
	}
	roi := image.Rect(values[0], values[1], values[0]+values[2], values[1]+values[3]).Intersect(bounds)
	if roi.Empty() {
		return image.Rectangle{}, fmt.Errorf("roi %q does not intersect image bounds %v", raw, bounds)
	}
	return roi, nil
}

func round5(v float64) float64 { return math.Round(v*1e5) / 1e5 }

func fatal(err error) {
	fmt.Fprintln(os.Stderr, "measure:", err)
	os.Exit(1)
}
