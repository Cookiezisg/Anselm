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
	params, err := parseImageParams(derivative.Kind, derivative.ParamsJSON)
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
	if params.MaxEdge > 0 {
		img = resizeMaxEdge(img, params.MaxEdge)
	}
	var out bytes.Buffer
	mimeType := "image/jpeg"
	if shouldEncodePNG(params.Format, img) {
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

func parseImageParams(kind, raw string) (ImageDerivativeParams, error) {
	params := defaultsForImageKind(kind)
	if raw == "" {
		return params, nil
	}
	if err := json.Unmarshal([]byte(raw), &params); err != nil {
		return ImageDerivativeParams{}, fmt.Errorf("mediaapp.ImageProcessor: params: %w", err)
	}
	if params.MaxEdge <= 0 {
		params.MaxEdge = defaultsForImageKind(kind).MaxEdge
	}
	if params.Quality <= 0 {
		params.Quality = defaultsForImageKind(kind).Quality
	}
	if params.Format == "" {
		params.Format = defaultsForImageKind(kind).Format
	}
	return params, nil
}

func defaultsForImageKind(kind string) ImageDerivativeParams {
	switch kind {
	case DerivativeThumbnail:
		return ImageDerivativeParams{MaxEdge: 320, Quality: 82, Format: "auto"}
	case DerivativeModelDetail:
		return ImageDerivativeParams{MaxEdge: 2048, Quality: 92, Format: "auto"}
	default:
		return ImageDerivativeParams{MaxEdge: 2048, Quality: 90, Format: "auto"}
	}
}

func resizeMaxEdge(img image.Image, maxEdge int) image.Image {
	b := img.Bounds()
	w, h := b.Dx(), b.Dy()
	if w <= 0 || h <= 0 || (w <= maxEdge && h <= maxEdge) {
		return img
	}
	if w >= h {
		return imaging.Resize(img, maxEdge, 0, imaging.Lanczos)
	}
	return imaging.Resize(img, 0, maxEdge, imaging.Lanczos)
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

func shouldEncodePNG(format string, img image.Image) bool {
	switch strings.ToLower(strings.TrimSpace(format)) {
	case "png":
		return true
	case "jpeg", "jpg":
		return false
	}
	b := img.Bounds()
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			_, _, _, a := color.NRGBAModel.Convert(img.At(x, y)).RGBA()
			if a != 0xffff {
				return true
			}
		}
	}
	return false
}
