package main

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"flag"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"io"
	"math"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

type remoteFixture struct {
	name, url, sha256 string
}

var remoteFixtures = []remoteFixture{
	{
		name:   "photo.jpeg",
		url:    "https://help-static-aliyun-doc.aliyuncs.com/file-manage-files/zh-CN/20241022/emyrja/dog_and_girl.jpeg",
		sha256: "9eeaa87013b4e800930e8a411b58ff9e2fd5383906b1a022f4a712720af34cc2",
	},
	{
		name:   "speech.wav",
		url:    "https://help-static-aliyun-doc.aliyuncs.com/file-manage-files/zh-CN/20250211/tixcef/cherry.wav",
		sha256: "9265eff0f665ec1067f806491afddf3e5434c4519441f39ca8047ac0ae309b1e",
	},
	{
		name:   "short.mp4",
		url:    "https://help-static-aliyun-doc.aliyuncs.com/file-manage-files/zh-CN/20241115/cqqkru/1.mp4",
		sha256: "848ae8897c34cd7f776a00e82f42635266edc077afb0106bb02644a1557bc210",
	},
}

func main() {
	out := flag.String("out", ".cache/multimodal-fixtures", "materialized fixture directory")
	flag.Parse()
	if err := materialize(*out); err != nil {
		fmt.Fprintln(os.Stderr, "materialize:", err)
		os.Exit(1)
	}
	fmt.Println(filepath.Clean(*out))
}

func materialize(out string) error {
	if err := os.MkdirAll(out, 0o755); err != nil {
		return err
	}
	if err := writeTextScreenshot(filepath.Join(out, "text-screenshot.png")); err != nil {
		return err
	}
	if err := writeLongImage(filepath.Join(out, "long-image.png")); err != nil {
		return err
	}
	if err := writePDF(filepath.Join(out, "gold.pdf")); err != nil {
		return err
	}
	if err := writeDOCX(filepath.Join(out, "gold.docx")); err != nil {
		return err
	}
	if err := writeMusicWAV(filepath.Join(out, "music.wav")); err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	for _, fixture := range remoteFixtures {
		if err := downloadVerified(ctx, filepath.Join(out, fixture.name), fixture); err != nil {
			return err
		}
	}
	return deriveLongVideo(ctx, filepath.Join(out, "short.mp4"), filepath.Join(out, "long.mp4"))
}

func downloadVerified(ctx context.Context, dst string, fixture remoteFixture) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fixture.url, nil)
	if err != nil {
		return err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("%s: %w", fixture.name, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%s: HTTP %s", fixture.name, resp.Status)
	}
	const maxFixtureBytes = 64 << 20
	raw, err := io.ReadAll(io.LimitReader(resp.Body, maxFixtureBytes+1))
	if err != nil {
		return err
	}
	if len(raw) > maxFixtureBytes {
		return fmt.Errorf("%s: response exceeds %d bytes", fixture.name, maxFixtureBytes)
	}
	sum := sha256.Sum256(raw)
	if got := hex.EncodeToString(sum[:]); got != fixture.sha256 {
		return fmt.Errorf("%s: sha256 %s, want %s", fixture.name, got, fixture.sha256)
	}
	return os.WriteFile(dst, raw, 0o644)
}

func deriveLongVideo(ctx context.Context, source, dst string) error {
	ffmpeg, err := exec.LookPath("ffmpeg")
	if err != nil {
		return errors.New("ffmpeg is required to derive long.mp4")
	}
	cmd := exec.CommandContext(ctx, ffmpeg,
		"-hide_banner", "-loglevel", "error", "-y",
		"-stream_loop", "9", "-i", source, "-map_metadata", "-1",
		"-c", "copy", "-movflags", "+faststart", dst,
	)
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("derive long.mp4: %w: %s", err, strings.TrimSpace(string(output)))
	}
	return nil
}

func writeTextScreenshot(path string) error {
	img := image.NewRGBA(image.Rect(0, 0, 1280, 720))
	fill(img, img.Bounds(), color.RGBA{248, 250, 252, 255})
	fill(img, image.Rect(70, 70, 1210, 650), color.RGBA{255, 255, 255, 255})
	drawText(img, 125, 165, 14, "ANSELM GOLD", color.RGBA{22, 35, 55, 255})
	drawText(img, 245, 340, 20, "314159", color.RGBA{220, 38, 38, 255})
	drawText(img, 185, 540, 8, "CONTEXT SAFE", color.RGBA{55, 65, 81, 255})
	return encodePNG(path, img)
}

func writeLongImage(path string) error {
	img := image.NewRGBA(image.Rect(0, 0, 768, 4096))
	fill(img, img.Bounds(), color.RGBA{245, 247, 250, 255})
	for i := 1; i <= 12; i++ {
		top := 40 + (i-1)*334
		shade := uint8(210 + (i%3)*14)
		fill(img, image.Rect(40, top, 728, top+280), color.RGBA{shade, 232, 245, 255})
		drawText(img, 90, top+80, 7, fmt.Sprintf("SECTION %02d", i), color.RGBA{17, 24, 39, 255})
		drawText(img, 90, top+185, 4, "ANSELM LONG IMAGE", color.RGBA{75, 85, 99, 255})
	}
	return encodePNG(path, img)
}

func encodePNG(path string, img image.Image) error {
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return err
	}
	return os.WriteFile(path, buf.Bytes(), 0o644)
}

func fill(img *image.RGBA, rect image.Rectangle, c color.RGBA) {
	for y := rect.Min.Y; y < rect.Max.Y; y++ {
		for x := rect.Min.X; x < rect.Max.X; x++ {
			img.SetRGBA(x, y, c)
		}
	}
}

var glyphs = map[rune][]string{
	' ': {"00000", "00000", "00000", "00000", "00000", "00000", "00000"},
	'A': {"01110", "10001", "10001", "11111", "10001", "10001", "10001"},
	'C': {"01111", "10000", "10000", "10000", "10000", "10000", "01111"},
	'D': {"11110", "10001", "10001", "10001", "10001", "10001", "11110"},
	'E': {"11111", "10000", "10000", "11110", "10000", "10000", "11111"},
	'F': {"11111", "10000", "10000", "11110", "10000", "10000", "10000"},
	'G': {"01111", "10000", "10000", "10111", "10001", "10001", "01110"},
	'I': {"11111", "00100", "00100", "00100", "00100", "00100", "11111"},
	'L': {"10000", "10000", "10000", "10000", "10000", "10000", "11111"},
	'M': {"10001", "11011", "10101", "10101", "10001", "10001", "10001"},
	'N': {"10001", "11001", "10101", "10011", "10001", "10001", "10001"},
	'O': {"01110", "10001", "10001", "10001", "10001", "10001", "01110"},
	'R': {"11110", "10001", "10001", "11110", "10100", "10010", "10001"},
	'S': {"01111", "10000", "10000", "01110", "00001", "00001", "11110"},
	'T': {"11111", "00100", "00100", "00100", "00100", "00100", "00100"},
	'X': {"10001", "10001", "01010", "00100", "01010", "10001", "10001"},
	'0': {"01110", "10001", "10011", "10101", "11001", "10001", "01110"},
	'1': {"00100", "01100", "00100", "00100", "00100", "00100", "01110"},
	'2': {"01110", "10001", "00001", "00010", "00100", "01000", "11111"},
	'3': {"11110", "00001", "00001", "01110", "00001", "00001", "11110"},
	'4': {"00010", "00110", "01010", "10010", "11111", "00010", "00010"},
	'5': {"11111", "10000", "10000", "11110", "00001", "00001", "11110"},
	'6': {"01110", "10000", "10000", "11110", "10001", "10001", "01110"},
	'7': {"11111", "00001", "00010", "00100", "01000", "01000", "01000"},
	'8': {"01110", "10001", "10001", "01110", "10001", "10001", "01110"},
	'9': {"01110", "10001", "10001", "01111", "00001", "00001", "01110"},
}

func drawText(img *image.RGBA, x, y, scale int, text string, c color.RGBA) {
	cursor := x
	for _, char := range text {
		glyph, ok := glyphs[char]
		if !ok {
			glyph = glyphs[' ']
		}
		for row, line := range glyph {
			for col, bit := range line {
				if bit == '1' {
					fill(img, image.Rect(cursor+col*scale, y+row*scale, cursor+(col+1)*scale, y+(row+1)*scale), c)
				}
			}
		}
		cursor += 6 * scale
	}
}

func writePDF(path string) error {
	stream := "BT /F1 20 Tf 72 680 Td (ANSELM PDF GOLD SENTINEL 271828 PAGE 1) Tj ET\n"
	objects := []string{
		"<< /Type /Catalog /Pages 2 0 R >>",
		"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
		"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
		fmt.Sprintf("<< /Length %d >>\nstream\n%sendstream", len(stream), stream),
		"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
	}
	var out bytes.Buffer
	out.WriteString("%PDF-1.4\n")
	offsets := make([]int, len(objects)+1)
	for i, object := range objects {
		offsets[i+1] = out.Len()
		fmt.Fprintf(&out, "%d 0 obj\n%s\nendobj\n", i+1, object)
	}
	xref := out.Len()
	fmt.Fprintf(&out, "xref\n0 %d\n0000000000 65535 f \n", len(objects)+1)
	for i := 1; i <= len(objects); i++ {
		fmt.Fprintf(&out, "%010d 00000 n \n", offsets[i])
	}
	fmt.Fprintf(&out, "trailer << /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n", len(objects)+1, xref)
	return os.WriteFile(path, out.Bytes(), 0o644)
}

func writeDOCX(path string) error {
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	files := map[string]string{
		"[Content_Types].xml": `<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>`,
		"_rels/.rels":         `<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>`,
		"word/document.xml":   `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>ANSELM OFFICE SENTINEL 161803</w:t></w:r></w:p><w:sectPr/></w:body></w:document>`,
	}
	for _, name := range []string{"[Content_Types].xml", "_rels/.rels", "word/document.xml"} {
		w, err := zw.Create(name)
		if err != nil {
			return err
		}
		if _, err := io.WriteString(w, files[name]); err != nil {
			return err
		}
	}
	if err := zw.Close(); err != nil {
		return err
	}
	return os.WriteFile(path, buf.Bytes(), 0o644)
}

func writeMusicWAV(path string) error {
	const sampleRate = 16_000
	const seconds = 9
	samples := make([]int16, sampleRate*seconds)
	frequencies := []float64{261.63, 329.63, 392.00}
	for i := range samples {
		note := (i / sampleRate) % len(frequencies)
		phase := 2 * math.Pi * frequencies[note] * float64(i) / sampleRate
		samples[i] = int16(math.Sin(phase) * 7_000)
	}
	var data bytes.Buffer
	for _, sample := range samples {
		if err := binary.Write(&data, binary.LittleEndian, sample); err != nil {
			return err
		}
	}
	var out bytes.Buffer
	out.WriteString("RIFF")
	_ = binary.Write(&out, binary.LittleEndian, uint32(36+data.Len()))
	out.WriteString("WAVEfmt ")
	_ = binary.Write(&out, binary.LittleEndian, uint32(16))
	_ = binary.Write(&out, binary.LittleEndian, uint16(1))
	_ = binary.Write(&out, binary.LittleEndian, uint16(1))
	_ = binary.Write(&out, binary.LittleEndian, uint32(sampleRate))
	_ = binary.Write(&out, binary.LittleEndian, uint32(sampleRate*2))
	_ = binary.Write(&out, binary.LittleEndian, uint16(2))
	_ = binary.Write(&out, binary.LittleEndian, uint16(16))
	out.WriteString("data")
	_ = binary.Write(&out, binary.LittleEndian, uint32(data.Len()))
	out.Write(data.Bytes())
	return os.WriteFile(path, out.Bytes(), 0o644)
}
