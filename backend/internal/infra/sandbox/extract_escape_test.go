package sandbox

import (
	"archive/tar"
	"archive/zip"
	"compress/gzip"
	"os"
	"path/filepath"
	"testing"
)

// A runtime archive must not be able to plant a link out of its destination: a symlink whose
// target escapes, or a hardlink whose source does, is the classic write-through-a-link primitive
// (the checksum is fetched from the same origin as the archive, so a compromised mirror controls
// both). Relative intra-tree links stay allowed — that is how bin/npm and bin/python3 ship.
// 运行时归档不能往目标目录外植链接:目标越界的符号链接、源越界的硬链接,是经典的「经链接写出去」原语
// (校验和与归档同源,镜像被攻破则两者都可控)。树内相对链接仍放行——bin/npm、bin/python3 就是这么发的。
func TestExtractTar_RejectsEscapingLinks(t *testing.T) {
	cases := []struct {
		name string
		hdr  tar.Header
		ok   bool
	}{
		{"relative intra-tree symlink", tar.Header{Name: "root/bin/py", Typeflag: tar.TypeSymlink, Linkname: "python3.12"}, true},
		{"parent-relative intra-tree symlink", tar.Header{Name: "root/bin/npm", Typeflag: tar.TypeSymlink, Linkname: "../lib/npm"}, true},
		{"absolute symlink", tar.Header{Name: "root/bin/evil", Typeflag: tar.TypeSymlink, Linkname: "/etc"}, false},
		{"escaping symlink", tar.Header{Name: "root/bin/evil", Typeflag: tar.TypeSymlink, Linkname: "../../../../tmp"}, false},
		{"escaping hardlink", tar.Header{Name: "root/bin/evil", Typeflag: tar.TypeLink, Linkname: "../../outside"}, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			src := filepath.Join(dir, "a.tgz")
			writeTgz(t, src, []tar.Header{
				{Name: "root/bin/python3.12", Typeflag: tar.TypeReg, Mode: 0o755, Size: 0},
				{Name: "root/lib/npm", Typeflag: tar.TypeReg, Mode: 0o755, Size: 0},
				tc.hdr,
			})
			dst := filepath.Join(dir, "dst")
			err := extractTarGzTree(src, dst, 1)
			if tc.ok && err != nil {
				t.Fatalf("legitimate link rejected: %v", err)
			}
			if !tc.ok && err == nil {
				t.Fatalf("escaping link accepted")
			}
		})
	}
}

func TestExtractZip_RejectsEscapingSymlink(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "a.zip")
	f, err := os.Create(src)
	if err != nil {
		t.Fatal(err)
	}
	zw := zip.NewWriter(f)
	h := &zip.FileHeader{Name: "root/bin/evil"}
	h.SetMode(os.ModeSymlink | 0o777)
	w, err := zw.CreateHeader(h)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := w.Write([]byte("../../../../tmp")); err != nil {
		t.Fatal(err)
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	_ = f.Close()
	if err := extractZipTree(src, filepath.Join(dir, "dst"), 1); err == nil {
		t.Fatal("escaping zip symlink accepted")
	}
}

func writeTgz(t *testing.T, path string, headers []tar.Header) {
	t.Helper()
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	gz := gzip.NewWriter(f)
	tw := tar.NewWriter(gz)
	for i := range headers {
		if err := tw.WriteHeader(&headers[i]); err != nil {
			t.Fatal(err)
		}
	}
	if err := tw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := gz.Close(); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
}
