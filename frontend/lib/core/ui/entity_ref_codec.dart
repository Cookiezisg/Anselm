/// `[[<id>]]` wikilink extraction — the stored wire form the backend's `pkg/wikilink` parses to build
/// `link` relation edges. The native editor (core/editor/an_editor_markdown.dart) owns the full
/// pill ↔ `[[id]]` round-trip; this helper only SCANS a markdown string for referenced ids, so the
/// documents ocean can batch-resolve display names BEFORE the editor loads (mention pills rehydrate
/// from the resolved map, unknown ids fall back to the raw id).
///
/// `[[<id>]]` wikilink 抽取——后端 `pkg/wikilink` 解析建 link 边的存储线缆形。药丸 ↔ `[[id]]` 的完整
/// 往返归原生编辑器(core/editor/an_editor_markdown.dart);本助手只**扫描** markdown 里引用到的 id,
/// 让 documents 海洋在编辑器载入前批量解析显示名(药丸据解析表重水合,未知 id 回落裸 id)。
library;

/// The strict project-ID shape the backend's wikilink parser accepts: `<prefix>_<16 hex>`. 严格项目 ID 形。
const String _idPattern = r'[a-z]+_[0-9a-f]{16}';

/// `[[<id>]]` — the STORED wire form (what the backend reads to build link edges). 存储线缆形。
final RegExp _wikiRe = RegExp(r'\[\[(' + _idPattern + r')\]\]');

/// All entity IDs referenced by `[[id]]` wikilinks in [markdown] (order-preserving, may repeat). 抽取所有 `[[id]]` 的 id。
List<String> extractEntityRefIds(String markdown) => [
  for (final m in _wikiRe.allMatches(markdown)) m.group(1)!,
];
