package media

import (
	"bytes"
	"context"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"testing"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	mediadomain "github.com/sunweilin/anselm/backend/internal/domain/media"
)

func TestImageProcessor_ModelDefaultDownscalesOpaqueJPEG(t *testing.T) {
	original := encodeJPEG(t, solidNRGBA(3000, 1200, color.NRGBA{R: 220, G: 40, B: 20, A: 255}))
	result, err := NewImageProcessor().Derive(context.Background(),
		&attachmentdomain.Attachment{ID: "att_1", Kind: attachmentdomain.KindImage},
		original,
		&mediadomain.Derivative{Kind: DerivativeModelDefault, ParamsJSON: `{"maxEdge":1024,"quality":88,"format":"auto"}`},
	)
	if err != nil {
		t.Fatal(err)
	}
	if result.MimeType != "image/jpeg" || result.Width != 1024 || result.Height != 410 {
		t.Fatalf("result = %+v, want jpeg 1024x410", result)
	}
}

func TestImageProcessor_TransparentImageKeepsPNG(t *testing.T) {
	original := encodePNG(t, solidNRGBA(20, 10, color.NRGBA{R: 10, G: 20, B: 30, A: 120}))
	result, err := NewImageProcessor().Derive(context.Background(),
		&attachmentdomain.Attachment{ID: "att_1", Kind: attachmentdomain.KindImage},
		original,
		&mediadomain.Derivative{Kind: DerivativeThumbnail, ParamsJSON: `{"maxEdge":10,"format":"auto"}`},
	)
	if err != nil {
		t.Fatal(err)
	}
	if result.MimeType != "image/png" || result.Width != 10 || result.Height != 5 {
		t.Fatalf("result = %+v, want png 10x5", result)
	}
}

func TestImageProcessor_NormalizedCropBeforeResize(t *testing.T) {
	original := encodeJPEG(t, solidNRGBA(100, 80, color.NRGBA{R: 100, G: 120, B: 140, A: 255}))
	result, err := NewImageProcessor().Derive(context.Background(),
		&attachmentdomain.Attachment{ID: "att_1", Kind: attachmentdomain.KindImage},
		original,
		&mediadomain.Derivative{Kind: DerivativeModelDetail, ParamsJSON: `{"maxEdge":20,"crop":{"x":0.25,"y":0.25,"width":0.5,"height":0.5}}`},
	)
	if err != nil {
		t.Fatal(err)
	}
	if result.Width != 20 || result.Height != 16 {
		t.Fatalf("crop+resize dimensions = %+v, want 20x16", result)
	}
}

func solidNRGBA(w, h int, c color.NRGBA) *image.NRGBA {
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.SetNRGBA(x, y, c)
		}
	}
	return img
}

func encodeJPEG(t *testing.T, img image.Image) []byte {
	t.Helper()
	var b bytes.Buffer
	if err := jpeg.Encode(&b, img, &jpeg.Options{Quality: 95}); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}

func encodePNG(t *testing.T, img image.Image) []byte {
	t.Helper()
	var b bytes.Buffer
	if err := png.Encode(&b, img); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}
