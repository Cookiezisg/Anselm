package generate

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"regexp"
	"strings"
)

var (
	colorWordPattern   = regexp.MustCompile(`(?i)\b(red|orange|yellow|green|cyan|blue|purple|pink)\b`)
	colorTargetPattern = regexp.MustCompile(`(?i)\b(?:to|into|as)\s+(red|orange|yellow|green|cyan|blue|purple|pink)\b`)
)

type preciseColorSwap struct {
	fromHue float64
	toHue   float64
}

func parsePreciseColorSwap(prompt string) (preciseColorSwap, bool) {
	loc := colorTargetPattern.FindStringSubmatchIndex(prompt)
	if loc == nil {
		return preciseColorSwap{}, false
	}
	before := prompt[:loc[0]]
	words := colorWordPattern.FindAllStringSubmatchIndex(before, -1)
	if len(words) == 0 {
		return preciseColorSwap{}, false
	}
	from := strings.ToLower(prompt[words[len(words)-1][2]:words[len(words)-1][3]])
	to := strings.ToLower(prompt[loc[2]:loc[3]])
	if from == to || len([]rune(before))-len([]rune(prompt[:words[len(words)-1][1]])) > 128 {
		return preciseColorSwap{}, false
	}
	fromHue, fromOK := colorHue(from)
	toHue, toOK := colorHue(to)
	if !fromOK || !toOK {
		return preciseColorSwap{}, false
	}
	return preciseColorSwap{fromHue: fromHue, toHue: toHue}, true
}

func colorHue(name string) (float64, bool) {
	switch name {
	case "red":
		return 0, true
	case "orange":
		return 1.0 / 12.0, true
	case "yellow":
		return 1.0 / 6.0, true
	case "green":
		return 1.0 / 3.0, true
	case "cyan":
		return 0.5, true
	case "blue":
		return 2.0 / 3.0, true
	case "purple":
		return 3.0 / 4.0, true
	case "pink":
		return 11.0 / 12.0, true
	default:
		return 0, false
	}
}

// applyPreciseColorSwap keeps every source pixel outside the detected color mask byte-for-byte
// equivalent and only rotates the matched pixels to the requested hue. It is intentionally narrow:
// broad scene edits remain provider-generated rather than pretending to be pixel-preserving.
func applyPreciseColorSwap(source []byte, prompt string) ([]byte, bool, error) {
	swap, ok := parsePreciseColorSwap(prompt)
	if !ok {
		return nil, false, nil
	}
	src, _, err := image.Decode(bytes.NewReader(source))
	if err != nil {
		return nil, false, err
	}
	bounds := src.Bounds()
	out := image.NewRGBA(bounds)
	matched := 0
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			px := color.NRGBAModel.Convert(src.At(x, y)).(color.NRGBA)
			h, s, v := rgbToHSV(px.R, px.G, px.B)
			if px.A > 0 && s >= 0.22 && hueDistance(h, swap.fromHue) <= 0.12 {
				r, g, b := hsvToRGB(swap.toHue, s, v)
				out.Set(x, y, color.NRGBA{R: r, G: g, B: b, A: px.A})
				matched++
				continue
			}
			out.Set(x, y, px)
		}
	}
	if matched < 16 {
		return nil, false, nil
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, out); err != nil {
		return nil, false, err
	}
	return buf.Bytes(), true, nil
}

func hueDistance(a, b float64) float64 {
	d := a - b
	if d < 0 {
		d = -d
	}
	if d > 0.5 {
		d = 1 - d
	}
	return d
}

func rgbToHSV(r, g, b uint8) (h, s, v float64) {
	rf, gf, bf := float64(r)/255, float64(g)/255, float64(b)/255
	max, min := rf, rf
	if gf > max {
		max = gf
	}
	if bf > max {
		max = bf
	}
	if gf < min {
		min = gf
	}
	if bf < min {
		min = bf
	}
	delta := max - min
	v = max
	if max == 0 {
		return 0, 0, v
	}
	s = delta / max
	if delta == 0 {
		return 0, s, v
	}
	switch max {
	case rf:
		h = (gf - bf) / delta
		if h < 0 {
			h += 6
		}
	case gf:
		h = (bf-rf)/delta + 2
	default:
		h = (rf-gf)/delta + 4
	}
	return h / 6, s, v
}

func hsvToRGB(h, s, v float64) (r, g, b uint8) {
	h = h - float64(int(h))
	i := int(h * 6)
	f := h*6 - float64(i)
	p := v * (1 - s)
	q := v * (1 - f*s)
	t := v * (1 - (1-f)*s)
	var rf, gf, bf float64
	switch i % 6 {
	case 0:
		rf, gf, bf = v, t, p
	case 1:
		rf, gf, bf = q, v, p
	case 2:
		rf, gf, bf = p, v, t
	case 3:
		rf, gf, bf = p, q, v
	case 4:
		rf, gf, bf = t, p, v
	default:
		rf, gf, bf = v, p, q
	}
	return uint8(rf*255 + 0.5), uint8(gf*255 + 0.5), uint8(bf*255 + 0.5)
}
