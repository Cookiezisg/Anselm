package skill

import (
	"bytes"
	"fmt"

	yaml "go.yaml.in/yaml/v3"

	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
)

// parseFrontmatter splits the leading --- YAML fence from the markdown body and unmarshals
// it. Skill frontmatter has 10+ fields (incl. list-valued allowed-tools/arguments), so a
// real YAML parser is warranted here — unlike memory's three hand-parsed scalars.
//
// parseFrontmatter 把开头的 --- YAML 围栏与 markdown body 分离并解析。skill frontmatter 有
// 10+ 字段（含列表型 allowed-tools/arguments），故值得用真正的 YAML 解析器——不同于 memory
// 那三个手解的标量。
func parseFrontmatter(raw []byte) (skilldomain.Frontmatter, string, error) {
	var fm skilldomain.Frontmatter
	content := bytes.TrimPrefix(raw, []byte{0xEF, 0xBB, 0xBF}) // strip UTF-8 BOM
	content = bytes.ReplaceAll(content, []byte("\r\n"), []byte("\n"))
	if !bytes.HasPrefix(content, []byte("---\n")) {
		return fm, "", fmt.Errorf("missing opening --- fence")
	}
	yamlPart, body, found := bytes.Cut(content[4:], []byte("\n---\n"))
	if !found {
		return fm, "", fmt.Errorf("missing closing --- fence")
	}
	if err := yaml.Unmarshal(yamlPart, &fm); err != nil {
		return fm, "", fmt.Errorf("yaml: %w", err)
	}
	return fm, string(body), nil
}

// renderFrontmatter serializes frontmatter back to the --- fenced YAML header (Save's inverse
// of parseFrontmatter).
//
// renderFrontmatter 把 frontmatter 序列化回 --- 围栏 YAML 头（Save 中 parseFrontmatter 的逆）。
func renderFrontmatter(fm skilldomain.Frontmatter) string {
	out, err := yaml.Marshal(&fm)
	if err != nil {
		return "---\n---\n"
	}
	return "---\n" + string(out) + "---\n"
}
