package main

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDeterministicLocalFixtures(t *testing.T) {
	dir := t.TempDir()
	paths := map[string]func(string) error{
		"text.png":  writeTextScreenshot,
		"long.png":  writeLongImage,
		"gold.pdf":  writePDF,
		"gold.docx": writeDOCX,
		"music.wav": writeMusicWAV,
	}
	for name, generate := range paths {
		if err := generate(filepath.Join(dir, name)); err != nil {
			t.Fatalf("%s: %v", name, err)
		}
	}
	for _, name := range []string{"text.png", "long.png"} {
		f, err := os.Open(filepath.Join(dir, name))
		if err != nil {
			t.Fatal(err)
		}
		if _, err := png.Decode(f); err != nil {
			t.Fatalf("%s decode: %v", name, err)
		}
		_ = f.Close()
	}
	pdf, _ := os.ReadFile(filepath.Join(dir, "gold.pdf"))
	if !bytes.HasPrefix(pdf, []byte("%PDF-1.4")) || !bytes.Contains(pdf, []byte("271828")) {
		t.Fatal("generated PDF lost its format or sentinel")
	}
	docx, err := zip.OpenReader(filepath.Join(dir, "gold.docx"))
	if err != nil {
		t.Fatal(err)
	}
	defer docx.Close()
	var document string
	for _, file := range docx.File {
		if file.Name == "word/document.xml" {
			r, err := file.Open()
			if err != nil {
				t.Fatal(err)
			}
			raw := new(bytes.Buffer)
			_, _ = raw.ReadFrom(r)
			_ = r.Close()
			document = raw.String()
		}
	}
	if !strings.Contains(document, "OFFICE SENTINEL 161803") {
		t.Fatal("generated DOCX lost its sentinel")
	}
	wav, _ := os.ReadFile(filepath.Join(dir, "music.wav"))
	if len(wav) < 44 || string(wav[:4]) != "RIFF" || string(wav[8:12]) != "WAVE" {
		t.Fatal("generated music is not a WAV file")
	}

	wantSHA256 := map[string]string{
		"text.png":  "d9e25c4c819767e254e4efb43867a048abe037041c10c28a82cb9a594b3a33f7",
		"long.png":  "ae0af9ab792ad0b03cb0fc6ab413637c60807d504eabab4ea6042a477c950341",
		"gold.pdf":  "a6a646004b46bf3f7190b08d1a06b0347841dbe8abe025231e86e78ae99efd15",
		"gold.docx": "bf0e75b380b71f3c67f067289ff900393111c211137e7ab196153c252441b60a",
		"music.wav": "5db8951b455ed97dddfff04149d9cb8cb649496dbf480e68ebbd70d321bfb864",
	}
	for name, want := range wantSHA256 {
		raw, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			t.Fatal(err)
		}
		sum := sha256.Sum256(raw)
		if got := hex.EncodeToString(sum[:]); got != want {
			t.Fatalf("%s sha256 = %s, want %s", name, got, want)
		}
	}
}
