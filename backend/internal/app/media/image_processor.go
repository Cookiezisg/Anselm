package media

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"math"
	"strings"

	"github.com/disintegration/imaging"
	_ "golang.org/x/image/webp"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	mediadomain "github.com/sunweilin/anselm/backend/internal/domain/media"
)

type ImageProcessor struct{}

var _ Processor = (*ImageProcessor)(nil)

func NewImageProcessor() *ImageProcessor { return &ImageProcessor{} }

func (p *ImageProcessor) Derive(ctx context.Context, attachment *attachmentdomain.Attachment, original []byte, derivative *mediadomain.Derivative) (DerivativeResult, error) {
	if err := ctx.Err(); err != nil {
		return DerivativeResult{}, err
	}
	if attachment.Kind != attachmentdomain.KindImage {
		return DerivativeResult{}, fmt.Errorf("mediaapp.ImageProcessor: unsupported attachment kind %q", attachment.Kind)
	}
	params, err := parseImageParams(derivative.ParamsJSON)
	if err != nil {
		return DerivativeResult{}, err
	}
	img, err := imaging.Decode(bytes.NewReader(original), imaging.AutoOrientation(true))
	if err != nil {
		return DerivativeResult{}, fmt.Errorf("mediaapp.ImageProcessor: decode: %w", err)
	}
	if params.Crop != nil {
		img, err = cropNormalized(img, *params.Crop)
		if err != nil {
			return DerivativeResult{}, err
		}
	}
	traits := inspectImage(img)
	params = applyImageDefaults(derivative.Kind, params, traits)
	img = resizeToFit(img, params)
	var out bytes.Buffer
	mimeType := "image/jpeg"
	if shouldEncodePNG(params.Format, img, traits) {
		mimeType = "image/png"
		err = imaging.Encode(&out, img, imaging.PNG)
	} else {
		err = imaging.Encode(&out, img, imaging.JPEG, imaging.JPEGQuality(params.Quality))
	}
	if err != nil {
		return DerivativeResult{}, fmt.Errorf("mediaapp.ImageProcessor: encode: %w", err)
	}
	bounds := img.Bounds()
	return DerivativeResult{
		Data:     out.Bytes(),
		MimeType: mimeType,
		Width:    bounds.Dx(),
		Height:   bounds.Dy(),
	}, nil
}

func (p *ImageProcessor) Perceive(context.Context, *attachmentdomain.Attachment, []byte, *mediadomain.Perception) (PerceptionResult, error) {
	return PerceptionResult{}, fmt.Errorf("mediaapp.ImageProcessor: perception is not implemented")
}

func parseImageParams(raw string) (ImageDerivativeParams, error) {
	params := ImageDerivativeParams{}
	if raw == "" {
		return params, nil
	}
	if err := json.Unmarshal([]byte(raw), &params); err != nil {
		return ImageDerivativeParams{}, fmt.Errorf("mediaapp.ImageProcessor: params: %w", err)
	}
	return params, nil
}

type imageTraits struct {
	long    bool
	graphic bool
	alpha   bool
}

func applyImageDefaults(kind string, params ImageDerivativeParams, traits imageTraits) ImageDerivativeParams {
	def := defaultsForImageKind(kind, traits)
	if params.MaxEdge <= 0 {
		params.MaxEdge = def.MaxEdge
	}
	if params.MaxWidth <= 0 {
		params.MaxWidth = def.MaxWidth
	}
	if params.MaxHeight <= 0 {
		params.MaxHeight = def.MaxHeight
	}
	if params.Quality <= 0 {
		params.Quality = def.Quality
	}
	if params.Format == "" {
		params.Format = def.Format
	}
	return params
}

func defaultsForImageKind(kind string, traits imageTraits) ImageDerivativeParams {
	switch kind {
	case DerivativeThumbnail:
		return ImageDerivativeParams{MaxEdge: 320, Quality: 82, Format: "auto"}
	case DerivativeModelDetail:
		return ImageDerivativeParams{MaxEdge: 2048, Quality: 92, Format: "auto"}
	default:
		if traits.long {
			return ImageDerivativeParams{MaxWidth: 1536, MaxHeight: 8192, Quality: 90, Format: "auto"}
		}
		return ImageDerivativeParams{MaxEdge: 2048, Quality: 90, Format: "auto"}
	}
}

func resizeToFit(img image.Image, params ImageDerivativeParams) image.Image {
	b := img.Bounds()
	w, h := b.Dx(), b.Dy()
	if w <= 0 || h <= 0 {
		return img
	}
	maxW, maxH := params.MaxWidth, params.MaxHeight
	if params.MaxEdge > 0 {
		if maxW <= 0 || params.MaxEdge < maxW {
			maxW = params.MaxEdge
		}
		if maxH <= 0 || params.MaxEdge < maxH {
			maxH = params.MaxEdge
		}
	}
	if maxW <= 0 {
		maxW = w
	}
	if maxH <= 0 {
		maxH = h
	}
	scale := math.Min(float64(maxW)/float64(w), float64(maxH)/float64(h))
	if scale >= 1 {
		return img
	}
	return imaging.Resize(img, max(1, int(math.Round(float64(w)*scale))), max(1, int(math.Round(float64(h)*scale))), imaging.Lanczos)
}

func cropNormalized(img image.Image, crop ImageCrop) (image.Image, error) {
	if crop.Width <= 0 || crop.Height <= 0 {
		return nil, fmt.Errorf("mediaapp.ImageProcessor: invalid crop")
	}
	b := img.Bounds()
	w, h := float64(b.Dx()), float64(b.Dy())
	x0 := clamp01(crop.X)
	y0 := clamp01(crop.Y)
	x1 := clamp01(crop.X + crop.Width)
	y1 := clamp01(crop.Y + crop.Height)
	if x1 <= x0 || y1 <= y0 {
		return nil, fmt.Errorf("mediaapp.ImageProcessor: empty crop")
	}
	rect := image.Rect(
		b.Min.X+int(math.Floor(x0*w)),
		b.Min.Y+int(math.Floor(y0*h)),
		b.Min.X+int(math.Ceil(x1*w)),
		b.Min.Y+int(math.Ceil(y1*h)),
	).Intersect(b)
	if rect.Empty() {
		return nil, fmt.Errorf("mediaapp.ImageProcessor: empty crop")
	}
	return imaging.Crop(img, rect), nil
}

func clamp01(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 1
	}
	return v
}

func inspectImage(img image.Image) imageTraits {
	b := img.Bounds()
	w, h := b.Dx(), b.Dy()
	if w <= 0 || h <= 0 {
		return imageTraits{}
	}
	long := float64(max(w, h))/float64(min(w, h)) >= 3
	stepX := max(1, w/64)
	stepY := max(1, h/64)
	seen := map[uint32]struct{}{}
	samples := 0
	alpha := false
	for y := b.Min.Y; y < b.Max.Y; y += stepY {
		for x := b.Min.X; x < b.Max.X; x += stepX {
			r, g, bb, a := color.NRGBAModel.Convert(img.At(x, y)).RGBA()
			if a != 0xffff {
				alpha = true
			}
			key := uint32((r>>13)<<6 | (g>>13)<<3 | (bb >> 13))
			seen[key] = struct{}{}
			samples++
		}
	}
	diversity := float64(len(seen)) / float64(max(1, min(samples, 512)))
	return imageTraits{long: long, graphic: alpha || diversity < 0.35, alpha: alpha}
}

func shouldEncodePNG(format string, img image.Image, traits imageTraits) bool {
	switch strings.ToLower(strings.TrimSpace(format)) {
	case "png":
		return true
	case "jpeg", "jpg":
		return false
	}
	return traits.alpha || traits.graphic
}
