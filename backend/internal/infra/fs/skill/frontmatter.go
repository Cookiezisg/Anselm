package skill

import (
	"bytes"
	"fmt"
	"strings"

	yaml "go.yaml.in/yaml/v3"

	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
)

// parseFrontmatter splits the leading --- YAML fence from the markdown body and produces BOTH
// representations: the typed view (what the app layer consumes) and the raw node tree (what
// fidelity writes patch, so keys outside the typed view — and key order — survive edits,
// WRK-076 D1). The node tree never leaves this package: domain stays yaml-free.
//
// parseFrontmatter 把开头的 --- YAML 围栏与 markdown body 分离，双产出：类型化视图（app 层
// 消费）+ 原文节点树（保真写的手术对象，类型化视图之外的键与键序在编辑中不丢，WRK-076 D1）。
// 节点树不出本包：domain 保持零 yaml 依赖。
func parseFrontmatter(raw []byte) (skilldomain.Frontmatter, string, *yaml.Node, error) {
	var fm skilldomain.Frontmatter
	content := bytes.TrimPrefix(raw, []byte{0xEF, 0xBB, 0xBF}) // strip UTF-8 BOM
	content = bytes.ReplaceAll(content, []byte("\r\n"), []byte("\n"))
	if !bytes.HasPrefix(content, []byte("---\n")) {
		return fm, "", nil, fmt.Errorf("missing opening --- fence")
	}
	yamlPart, body, found := bytes.Cut(content[4:], []byte("\n---\n"))
	if !found {
		// A "---\n---\n…" empty frontmatter leaves no "\n---\n" to cut on — accept the
		// degenerate closing fence at the very start. 空 frontmatter 的退化闭合围栏。
		if rest, ok := bytes.CutPrefix(content[4:], []byte("---\n")); ok {
			yamlPart, body = nil, rest
		} else {
			return fm, "", nil, fmt.Errorf("missing closing --- fence")
		}
	}
	var doc yaml.Node
	if err := yaml.Unmarshal(yamlPart, &doc); err != nil {
		return fm, "", nil, fmt.Errorf("yaml: %w", err)
	}
	root := ensureMappingRoot(&doc)
	if root == nil {
		return fm, "", nil, fmt.Errorf("frontmatter is not a YAML mapping")
	}
	normalizeAllowedTools(root)
	if err := doc.Decode(&fm); err != nil {
		return fm, "", nil, fmt.Errorf("yaml: %w", err)
	}
	return fm, string(body), &doc, nil
}

// ensureMappingRoot returns the document's mapping root, materializing an empty mapping for an
// empty/null frontmatter ("---\n---\n"), and nil when the root is a non-mapping (scalar/sequence).
//
// ensureMappingRoot 返回文档的 mapping 根；空/null frontmatter（"---\n---\n"）就地补一个空
// mapping；根不是 mapping（标量/序列）时返 nil。
func ensureMappingRoot(doc *yaml.Node) *yaml.Node {
	if doc.Kind == 0 || len(doc.Content) == 0 {
		root := &yaml.Node{Kind: yaml.MappingNode, Tag: "!!map"}
		doc.Kind = yaml.DocumentNode
		doc.Content = []*yaml.Node{root}
		return root
	}
	root := doc.Content[0]
	if root.Kind == yaml.MappingNode {
		return root
	}
	// A null scalar root (empty frontmatter parsed as !!null) is upgraded in place; anything
	// else (a real scalar / sequence frontmatter) is malformed. null 根就地升格,其余属坏件。
	if root.Kind == yaml.ScalarNode && root.Tag == "!!null" {
		root.Kind = yaml.MappingNode
		root.Tag = "!!map"
		root.Value = ""
		root.Content = nil
		return root
	}
	return nil
}

// normalizeAllowedTools rewrites a scalar-form `allowed-tools: "a b c"` (the open-spec
// space-separated wire form) into a sequence node IN PLACE, so the typed view's []string
// decode accepts both forms (WRK-076 D4). List form passes through untouched.
//
// normalizeAllowedTools 把标量形态 `allowed-tools: "a b c"`（开放规范的空格分隔线格式）就地
// 改写为序列节点，使类型化视图的 []string 两态皆可解（WRK-076 D4）。列表形态原样通过。
func normalizeAllowedTools(root *yaml.Node) {
	for i := 0; i+1 < len(root.Content); i += 2 {
		k, v := root.Content[i], root.Content[i+1]
		if k.Kind != yaml.ScalarNode || k.Value != "allowed-tools" {
			continue
		}
		if v.Kind != yaml.ScalarNode || v.Tag == "!!null" {
			continue
		}
		items := strings.Fields(v.Value)
		seq := make([]*yaml.Node, 0, len(items))
		for _, it := range items {
			seq = append(seq, &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!str", Value: it})
		}
		v.Kind = yaml.SequenceNode
		v.Tag = "!!seq"
		v.Value = ""
		v.Style = 0
		v.Content = seq
	}
}

// structuredPatch applies the STRUCTURED surface's fields onto the mapping root in place —
// only the keys this surface OWNS are touched (empty value ⇒ key removed, mirroring omitempty);
// license/compatibility/metadata and any unknown keys are never written, so a form edit can't
// strip them (WRK-076 D1). Duplicate keys are all rewritten (yaml.Node keeps duplicates).
//
// structuredPatch 把结构化面的字段就地写进 mapping 根——只碰本面**拥有**的键（空值 ⇒ 删键，
// 对齐 omitempty）；license/compatibility/metadata 与一切未知键永不触碰，表单编辑剥不掉它们
// （WRK-076 D1）。重复键全部改写（yaml.Node 不去重）。
func structuredPatch(root *yaml.Node, fm skilldomain.Frontmatter) {
	setStr := func(key, val string) { patchKey(root, key, val != "", func() *yaml.Node { return scalarNode(val) }) }
	setList := func(key string, vals []string) {
		patchKey(root, key, len(vals) > 0, func() *yaml.Node { return seqNode(vals) })
	}
	setBool := func(key string, val bool) {
		patchKey(root, key, val, func() *yaml.Node {
			return &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!bool", Value: "true"}
		})
	}
	setStr("name", fm.Name)
	setStr("description", fm.Description)
	setList("allowed-tools", fm.AllowedTools)
	setStr("context", fm.Context)
	setStr("agent", fm.Agent)
	setList("arguments", fm.Arguments)
	setBool("disable-model-invocation", fm.DisableModelInvocation)
	setBool("user-invocable", fm.UserInvocable)
	setStr("source", fm.Source)
}

// patchKey sets (or removes, when keep=false) one mapping key. The existing value node is
// rewritten IN PLACE so its attached comments survive; a missing key is appended at the end.
// Duplicate keys need no handling: yaml v3 rejects them at Unmarshal (verified on v3.0.4), so
// a parsed mapping is always well-formed and the first hit is the only hit.
//
// patchKey 设置（keep=false 时移除）一个 mapping 键。已有 value 节点**原地**改写以保留其
// 注释；缺失键追加到末尾。重复键无需处理：yaml v3 在 Unmarshal 即拒（v3.0.4 实测），故解析
// 出的 mapping 恒良构、首个命中即唯一。
func patchKey(root *yaml.Node, key string, keep bool, mk func() *yaml.Node) {
	for i := 0; i+1 < len(root.Content); i += 2 {
		k := root.Content[i]
		if k.Kind != yaml.ScalarNode || k.Value != key {
			continue
		}
		if !keep {
			root.Content = append(root.Content[:i], root.Content[i+2:]...)
			return
		}
		v := root.Content[i+1]
		nv := mk()
		v.Kind, v.Tag, v.Value, v.Style, v.Content = nv.Kind, nv.Tag, nv.Value, nv.Style, nv.Content
		return
	}
	if keep {
		root.Content = append(root.Content, scalarNode(key), mk())
	}
}

func scalarNode(v string) *yaml.Node {
	return &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!str", Value: v}
}

func seqNode(vals []string) *yaml.Node {
	n := &yaml.Node{Kind: yaml.SequenceNode, Tag: "!!seq"}
	for _, v := range vals {
		n.Content = append(n.Content, scalarNode(v))
	}
	return n
}

// encodeFrontmatter serializes the (patched) document back to a --- fenced YAML header.
// SetIndent(2) pins the indent — the encoder's default 4 would reformat pristine files.
//
// encodeFrontmatter 把（手术后的）文档序列化回 --- 围栏 YAML 头。SetIndent(2) 钉住缩进——
// 编码器默认 4 会重排原文。
func encodeFrontmatter(doc *yaml.Node) (string, error) {
	var buf bytes.Buffer
	enc := yaml.NewEncoder(&buf)
	enc.SetIndent(2)
	if err := enc.Encode(doc); err != nil {
		return "", fmt.Errorf("yaml encode: %w", err)
	}
	if err := enc.Close(); err != nil {
		return "", fmt.Errorf("yaml encode: %w", err)
	}
	return "---\n" + buf.String() + "---\n", nil
}

// renderFrontmatter serializes a typed frontmatter from scratch (the CREATE path — no existing
// file to preserve). SetIndent(2) matches encodeFrontmatter.
//
// renderFrontmatter 从零序列化类型化 frontmatter（新建路径——无既有文件可保）。SetIndent(2)
// 与 encodeFrontmatter 一致。
func renderFrontmatter(fm skilldomain.Frontmatter) string {
	var buf bytes.Buffer
	enc := yaml.NewEncoder(&buf)
	enc.SetIndent(2)
	if err := enc.Encode(&fm); err != nil {
		return "---\n---\n"
	}
	if err := enc.Close(); err != nil {
		return "---\n---\n"
	}
	return "---\n" + buf.String() + "---\n"
}

// ParseManifest is the exported thin wrapper for callers outside the store (install preview):
// typed view + body, node tree withheld.
//
// ParseManifest 是给 store 之外调用方（安装预览）的导出薄封装：类型化视图 + 正文，不出节点树。
func ParseManifest(raw []byte) (skilldomain.Frontmatter, string, error) {
	fm, body, _, err := parseFrontmatter(raw)
	return fm, body, err
}
