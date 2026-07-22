import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/mcp.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/entity/mention_source.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_card.dart';
import '../../../core/ui/an_dialog.dart';
import '../../../core/ui/an_input.dart';
import '../../../core/ui/an_row.dart';
import '../../../core/ui/an_scroll_behavior.dart';
import '../../../core/ui/an_state.dart';
import '../../../core/ui/an_tags.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import '../state/library_state.dart';

// ── pure helpers (unit-tested without pumping UI) ────────────────────────────

/// The MCP authorization name for one server tool — the exact call name the loop's preauth matches
/// (`mcp__<server>__<tool>`; LLM tool names disallow ':'), so the picker stores THIS, not a display
/// form. mcp 工具的授权名 = 回合 preauth 匹配的确切调用名(禁 ':'),故选择器存这个、非展示形。
String mcpAuthToolName(String server, String tool) => 'mcp__${server}__$tool';

/// The pill label for one allowed-tools VALUE: an entity id (fn_/hd_) shows the resolved entity
/// name (from the skill's equip edges), everything else (builtin name, `mcp__…`, a hand-typed scope
/// like `Bash(git:*)`) shows verbatim. The stored value never changes — only the label. 药丸显示:
/// 实体 id 显示解析名(equip 边),其余(内置名/mcp__/手打作用域)显示原文;存的值不变、只变标签。
String skillToolPillLabel(String value, Map<String, String> idToName) =>
    idToName[value] ?? value;

/// The index of the single value removed from [before] to yield [after] (a subsequence one shorter),
/// or -1 if none. POSITION-based — [AnTags] removes by index, so this maps a pill-× back to the
/// underlying value even when two ids resolve to the same display label. 删除定位(按位置):AnTags
/// 按 index 删,此函数把 ×  映射回底层值——即便两个 id 解析成同名也不歧义。
int firstRemovedToolIndex(List<String> before, List<String> after) {
  for (var i = 0; i < before.length; i++) {
    if (i >= after.length || before[i] != after[i]) return i;
  }
  return -1;
}

// ── the field (pills + open-picker affordance) ───────────────────────────────

/// The skill `allowed-tools` editor: [AnTags] pills over the selected values (entity ids show
/// resolved names) plus an «add» affordance that opens the grouped [_ToolPickerSheet]. The inline
/// add-field is OFF (`showAddField: false`) — additions go through the picker (which also carries the
/// free-text fallback), removals stay the pill-×. Reuses the canonical pill primitive; the id→name
/// map rides the skill's equip edges ([skillBindingsProvider]).
///
/// skill allowed-tools 编辑器:AnTags 药丸(实体 id 显示解析名)+ 「添加」入口开分组选择器。内联添加框
/// 关闭——添加走选择器(自由输入兜底也在其中),删除仍是药丸 ×。复用药丸原语;id→名映射走 equip 边。
class SkillToolsField extends ConsumerWidget {
  const SkillToolsField({
    required this.skillName,
    required this.values,
    required this.onChanged,
    super.key,
  });

  final String skillName;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    // Equip edges give id→name for the pill labels (best-effort: an id with no edge yet shows raw).
    // equip 边给 id→名(尽力:尚无边的 id 显示原文)。
    final bindings =
        ref.watch(skillBindingsProvider(skillName)).value ?? const [];
    final idToName = <String, String>{
      for (final b in bindings)
        if (b.toName.isNotEmpty) b.toId: b.toName,
    };
    final labels = [for (final v in values) skillToolPillLabel(v, idToName)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (values.isNotEmpty)
          AnTags(
            tags: [for (final l in labels) AnTag(l)],
            showAddField: false,
            onChanged: (next) {
              // AnTags only removes here (no inline add) → map the removed label position back to
              // the underlying value. AnTags 此处只删→把删除位置映射回底层值。
              final after = [for (final tag in next) tag.label];
              final i = firstRemovedToolIndex(labels, after);
              if (i >= 0) onChanged([...values]..removeAt(i));
            },
          ),
        if (values.isNotEmpty) const SizedBox(height: AnSpace.s6),
        Align(
          alignment: Alignment.centerLeft,
          child: AnButton(
            label: t.library.props.addTool,
            icon: AnIcons.plus,
            size: AnButtonSize.sm,
            onPressed: () => _openPicker(context, ref),
          ),
        ),
      ],
    );
  }

  void _openPicker(BuildContext context, WidgetRef ref) {
    Navigator.of(context, rootNavigator: true).push(
      anPanelRoute<void>(
        scrim: context.colors.scrim,
        reduced: AnMotionPref.reduced(context),
        barrierLabel: context.t.feedback.dialogBarrier,
        builder: (_) => _ToolPickerSheet(
          skillName: skillName,
          initial: values,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── the picker sheet (grouped, searchable, free-text fallback) ───────────────

/// One candidate row's data — a stored [value] + its display [label]/[hint]/[icon]. 候选行数据。
typedef _Cand = ({String value, String label, String? hint, IconData icon});

/// The grouped tool picker: a search box (also the free-text fallback — Enter adds the typed value
/// verbatim, covering scopes like `Bash(git:*)` and any `mcp__…`), over four candidate groups —
/// Builtin ([toolCatalogProvider]) · Functions/Handlers (the shared @-mention source, filtered by
/// type) · MCP tools ([mcpServersForToolsProvider], authorized as `mcp__server__tool`). Add-only:
/// already-selected candidates read as checked; removals happen on the field's pills. The working
/// list is seeded from [initial] and grows per pick (each fires [onChanged]).
///
/// 分组工具选择器:搜索框(兼自由输入兜底——回车按原文加,覆盖 Bash(git:*)/任意 mcp__)+ 四组候选
/// (内置/函数/处理器/MCP);只增(已选=打勾,删在字段药丸上);工作表从 initial 起、每选一项增长并 onChanged。
class _ToolPickerSheet extends ConsumerStatefulWidget {
  const _ToolPickerSheet({
    required this.skillName,
    required this.initial,
    required this.onChanged,
  });

  final String skillName;
  final List<String> initial;
  final ValueChanged<List<String>> onChanged;

  @override
  ConsumerState<_ToolPickerSheet> createState() => _ToolPickerSheetState();
}

class _ToolPickerSheetState extends ConsumerState<_ToolPickerSheet> {
  final _search = TextEditingController();
  final _entityDebounce = Debouncer(AnMotion.autosave);
  late List<String> _working;
  String _query = '';
  List<MentionCandidate> _entities = const [];

  @override
  void initState() {
    super.initState();
    _working = [...widget.initial];
    _loadEntities(
      '',
    ); // seed the fn/hd groups before the first keystroke 先填函数/处理器组
  }

  @override
  void dispose() {
    _entityDebounce.dispose();
    _search.dispose();
    super.dispose();
  }

  void _loadEntities(String query) async {
    try {
      final cands = await ref.read(mentionSourceProvider).search(query);
      if (mounted) setState(() => _entities = cands);
    } catch (_) {
      // A candidate-source hiccup must never break the picker (free-text still works). 候选故障不砸选择器。
    }
  }

  void _onQuery(String q) {
    setState(() => _query = q.trim());
    _entityDebounce.run(() => _loadEntities(_query));
  }

  void _pick(String value) {
    if (_working.contains(value)) {
      return; // add-only; re-pick is a no-op 只增,重选空操作
    }
    setState(() => _working = [..._working, value]);
    widget.onChanged([..._working]);
  }

  /// The search box doubles as the free-text fallback: a non-empty submit adds the typed value
  /// verbatim (a scope / mcp literal the catalogs can't enumerate). 搜索框兼自由输入:非空回车按原文加。
  void _submitLiteral() {
    final v = _search.text.trim();
    if (v.isEmpty) return;
    _pick(v);
    _search.clear();
    setState(() => _query = '');
  }

  bool _matches(String haystack) =>
      _query.isEmpty || haystack.toLowerCase().contains(_query.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final p = t.library.props;
    final c = context.colors;

    // Builtin group — from the /tools catalog, filtered by name/summary. 内置组:/tools 目录,按名/简述筛。
    final builtin = <_Cand>[
      for (final d in ref.watch(toolCatalogProvider).value ?? const [])
        if (_matches(d.name) || _matches(d.summary))
          (value: d.name, label: d.name, hint: d.summary, icon: AnIcons.tool),
    ];
    // Function / Handler groups — from the shared @-mention source (already filtered server-side by
    // the query it was loaded with). 函数/处理器组:共享 @ 候选源(载入时已服务端按 query 筛)。
    final functions = <_Cand>[
      for (final e in _entities)
        if (e.type == 'function')
          (
            value: e.id,
            label: e.name,
            hint: e.description,
            icon: AnIcons.function,
          ),
    ];
    final handlers = <_Cand>[
      for (final e in _entities)
        if (e.type == 'handler')
          (
            value: e.id,
            label: e.name,
            hint: e.description,
            icon: AnIcons.handler,
          ),
    ];
    // MCP group — every installed server's tools, authorized as mcp__server__tool. MCP 组。
    final mcp = <_Cand>[
      for (final s
          in ref.watch(mcpServersForToolsProvider).value ??
              const <McpServerStatus>[])
        for (final tool in s.tools)
          if (_matches(s.name) || _matches(tool.name))
            (
              value: mcpAuthToolName(s.name, tool.name),
              label: '${s.name} / ${tool.name}',
              hint: null,
              icon: AnIcons.mcp,
            ),
    ];

    final groups = <(String, List<_Cand>)>[
      (p.toolPickerBuiltin, builtin),
      (p.toolPickerFunctions, functions),
      (p.toolPickerHandlers, handlers),
      (p.toolPickerMcp, mcp),
    ];
    final anyCandidate = groups.any((g) => g.$2.isNotEmpty);

    // Material(transparency): the sheet lives in a RawDialogRoute, outside any Scaffold — its text
    // fields need a Material ancestor (else the debug yellow underline / no-Material assert). 须 Material 祖先。
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SizedBox(
          width: 460,
          child: AnCard(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(p.toolPickerTitle, style: AnText.h3),
                  const SizedBox(height: AnSpace.s12),
                  AnInput(
                    controller: _search,
                    block: true,
                    autofocus: true,
                    placeholder: p.toolPickerSearch,
                    onChanged: _onQuery,
                    onSubmitted: (_) => _submitLiteral(),
                  ),
                  const SizedBox(height: AnSpace.s6),
                  Text(
                    p.toolPickerHint,
                    style: AnText.meta.copyWith(color: c.inkFaint),
                  ),
                  const SizedBox(height: AnSpace.s8),
                  Flexible(
                    child: ScrollConfiguration(
                      behavior: const AnScrollBehavior(),
                      child: (!anyCandidate && _query.isNotEmpty)
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AnSpace.s16,
                              ),
                              child: AnState(
                                kind: AnStateKind.empty,
                                size: AnStateSize.inset,
                                title: p.toolPickerEmpty,
                              ),
                            )
                          // Eager Column (not a lazy ListView): the candidate set is bounded (builtin
                          // catalog + capped entities + a few MCP tools), and a lazy list would cull
                          // off-screen rows from the tree. 有界候选用即时 Column,懒列表会剔除离屏行。
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Free-text row FIRST when the query names nothing — Enter-equivalent tap.
                                  // 无匹配时置顶自由添加行(等价回车)。
                                  if (_query.isNotEmpty)
                                    AnRow(
                                      icon: AnIcons.plus,
                                      label: p.toolPickerAddLiteral(q: _query),
                                      onSelect: _submitLiteral,
                                    ),
                                  for (final (label, cands) in groups)
                                    if (cands.isNotEmpty) ...[
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          AnSpace.s8,
                                          AnSpace.s8,
                                          0,
                                          AnSpace.s2,
                                        ),
                                        child: Text(
                                          label,
                                          style: AnText.meta.copyWith(
                                            color: c.inkFaint,
                                          ),
                                        ),
                                      ),
                                      for (final cand in cands) _candRow(cand),
                                    ],
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: AnSpace.s12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AnButton(
                      label: p.toolPickerDone,
                      variant: AnButtonVariant.primary,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _candRow(_Cand cand) {
    final selected = _working.contains(cand.value);
    return AnRow(
      icon: cand.icon,
      label: cand.label,
      hint: cand.hint,
      // Selected candidates read as checked and inert — removal is on the field's pills. 已选=打勾且惰性。
      meta: selected ? '✓' : null,
      selected: selected,
      onSelect: selected ? null : () => _pick(cand.value),
    );
  }
}
