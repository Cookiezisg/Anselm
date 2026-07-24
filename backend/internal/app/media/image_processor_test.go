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
	original := encodeJPEG(t, noisyNRGBA(3000, 1200))
	result, err := NewImageProcessor().Derive(context.Background(),
		&attachmentdomain.Attachment{ID: "att_1", Kind: attachmentdomain.KindImage},
		original,
		&mediadomain.Derivative{Kind: DerivativeModelDefault, ParamsJSON: `{"maxEdge":1024,"quality":88,"format":"auto"}`},
	)
	if err != nil {
		t.Fatal(err)
	}
	if result.MimeType != "image/jpeg" || result.Width != 1024 || result.Height != 410 {
		t.Fatalf("result = %s %dx%d, want jpeg 1024x410", result.MimeType, result.Width, result.Height)
	}
}

func TestImageProcessor_ModelDefaultScreenshotKeepsPNG(t *testing.T) {
	original := encodePNG(t, checkerNRGBA(1200, 800))
	result, err := NewImageProcessor().Derive(context.Background(),
		&attachmentdomain.Attachment{ID: "att_1", Kind: attachmentdomain.KindImage},
		original,
		&mediadomain.Derivative{Kind: DerivativeModelDefault, ParamsJSON: `{"version":2,"format":"auto"}`},
	)
	if err != nil {
		t.Fatal(err)
	}
	if result.MimeType != "image/png" || result.Width != 1200 || result.Height != 800 {
		t.Fatalf("screenshot result = %s %dx%d, want png 1200x800", result.MimeType, result.Width, result.Height)
	}
}

func TestImageProcessor_ModelDefaultLongImageDoesNotCrushReadableWidth(t *testing.T) {
	original := encodePNG(t, checkerNRGBA(900, 9000))
	result, err := NewImageProcessor().Derive(context.Background(),
		&attachmentdomain.Attachment{ID: "att_1", Kind: attachmentdomain.KindImage},
		original,
		&mediadomain.Derivative{Kind: DerivativeModelDefault, ParamsJSON: `{"version":2,"format":"auto"}`},
	)
	if err != nil {
		t.Fatal(err)
	}
	if result.MimeType != "image/png" || result.Height != 8192 || result.Width < 800 {
		t.Fatalf("long image result = %s %dx%d, want png height-capped with readable width", result.MimeType, result.Width, result.Height)
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
		t.Fatalf("result = %s %dx%d, want png 10x5", result.MimeType, result.Width, result.Height)
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
		t.Fatalf("crop+resize dimensions = %s %dx%d, want 20x16", result.MimeType, result.Width, result.Height)
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

func checkerNRGBA(w, h int) *image.NRGBA {
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if (x/16+y/16)%2 == 0 {
				img.SetNRGBA(x, y, color.NRGBA{R: 245, G: 245, B: 245, A: 255})
			} else {
				img.SetNRGBA(x, y, color.NRGBA{R: 30, G: 30, B: 30, A: 255})
			}
		}
	}
	return img
}

func noisyNRGBA(w, h int) *image.NRGBA {
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.SetNRGBA(x, y, color.NRGBA{
				R: uint8((x*37 + y*11) % 256),
				G: uint8((x*17 + y*43) % 256),
				B: uint8((x*13 + y*29) % 256),
				A: 255,
			})
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
