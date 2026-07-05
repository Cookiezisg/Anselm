/// The entity-reference codec — bridges the backend's `[[<id>]]` wikilink format (which `pkg/wikilink`
/// parses to build `link` relation edges, backend contract) and the in-editor form super_editor can
/// round-trip. super_editor's inline markdown serializer is hardcoded (only bold/italic/code/**link**), so
/// there is no hook for a bespoke `[[id]]` inline attribution; the ONLY inline attribution it serializes is
/// [LinkAttribution]. So a mention lives in the editor as a link to `anselm-entity:<id>`, and this codec
/// translates that link form ↔ the stored `[[id]]` wire form on the document_ocean load/save seam.
///
/// 实体引用 codec:桥接后端 `[[<id>]]` wikilink(`pkg/wikilink` 解析建 link 边)与 super_editor 能往返的
/// 编辑内表示。super_editor 内联序列化硬编(仅 bold/italic/code/**link**),无自定义 `[[id]]` 内联钩子,唯一
/// 可序列化的内联 attribution 是 LinkAttribution——故 mention 在编辑器里是指向 `anselm-entity:<id>` 的链接,
/// 本 codec 在 load/save 缝上把该链接形 ↔ 存储的 `[[id]]` 线缆形互转。
library;

/// The private URL scheme a mention link carries in-editor (never persisted — collapsed to `[[id]]` on
/// save). mention 链接在编辑器内用的私有 scheme(不落盘,存时塌成 `[[id]]`)。
const String kEntityRefScheme = 'anselm-entity';

/// The strict project-ID shape the backend's wikilink parser accepts: `<prefix>_<16 hex>`. 严格项目 ID 形。
const String _idPattern = r'[a-z]+_[0-9a-f]{16}';

/// `[[<id>]]` — the STORED wire form (what the backend reads to build link edges). 存储线缆形。
final RegExp _wikiRe = RegExp(r'\[\[(' + _idPattern + r')\]\]');

/// `[label](anselm-entity:<id>)` — the in-editor LINK form super_editor serializes. 编辑内链接形。
final RegExp _linkRe = RegExp(r'\[[^\]]*\]\(' + kEntityRefScheme + r':(' + _idPattern + r')\)');

/// All entity IDs referenced by `[[id]]` wikilinks in [markdown] (order-preserving, may repeat). 抽取所有 `[[id]]` 的 id。
List<String> extractEntityRefIds(String markdown) =>
    [for (final m in _wikiRe.allMatches(markdown)) m.group(1)!];

/// LOAD direction: rewrite each stored `[[id]]` into the editor's link form `[name](anselm-entity:id)`,
/// resolving the display name from [names] (falls back to the raw id when unknown). 载入:`[[id]]`→链接形,名从 names 取。
String expandEntityRefs(String markdown, Map<String, String> names) =>
    markdown.replaceAllMapped(_wikiRe, (m) {
      final id = m.group(1)!;
      final name = names[id] ?? id;
      return '[$name]($kEntityRefScheme:$id)';
    });

/// SAVE direction: collapse each editor link form `[name](anselm-entity:id)` back to the stored `[[id]]`
/// wire form (the display name is dropped — the backend stores only the id). 存储:链接形→`[[id]]`(名丢弃)。
String collapseEntityRefs(String markdown) =>
    markdown.replaceAllMapped(_linkRe, (m) => '[[${m.group(1)}]]');
