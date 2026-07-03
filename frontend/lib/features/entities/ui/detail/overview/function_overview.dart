import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/contract/entities/function.dart';
import '../../../../../core/design/colors.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/typography.dart';
import '../../../../../core/model/status_state.dart';
import '../../../../../core/ui/an_button.dart';
import '../../../../../core/ui/an_callout.dart';
import '../../../../../core/ui/an_code_editor.dart';
import '../../../../../core/ui/an_fade_collapse.dart';
import '../../../../../core/ui/an_field.dart';
import '../../../../../core/ui/an_info_card.dart';
import '../../../../../core/ui/an_lead_value.dart';
import '../../../../../core/ui/an_row.dart';
import '../../../../../core/ui/an_section.dart';
import '../../../../../core/ui/an_tags.dart';
import '../../../../../core/ui/an_transform_box.dart';
import '../../../../../core/ui/icons.dart';
import '../../../../../i18n/strings.g.dart';
import '../../../data/entity_kind.dart';
import '../../../data/entity_providers.dart';
import '../../../data/entity_format.dart';
import '../../../state/detail/entity_detail_provider.dart';
import '../../../state/selected_entity.dart';
import '../detail_sections.dart';

/// Function 概览。读态:meta(说明 + 标签,手工可编)→ 变换盒 hero(签名即接口)→ 代码(50 行渐隐
/// 收合)→ 环境合卡(envError 直出)。**版本内容(签名/代码/依赖/py)只读、AI-only**(拍板 #4);手工
/// 只编 meta——说明走 `AnField` 就地编辑(hover 铅笔),标签走 [_TagsMetaField](同一 `AnLeadValue` 几何
/// + 同一 hover-铅笔读优先手感),两行标签列对齐、静态不显编辑控件。均 PATCH 不升版本。
class FunctionOverview extends ConsumerWidget {
  const FunctionOverview({required this.fn, super.key});

  final FunctionEntity fn;

  /// 50 code lines at the code style's line box, plus the editor chrome — the collapse threshold.
  /// 代码样式行盒 × 50 行 + 编辑器 chrome = 收合高度。
  static const double _collapsedCodeHeight = 50 * 12 * 1.6 + 44;

  Future<void> _patchMeta(WidgetRef ref, Map<String, dynamic> patch) async {
    await ref.read(entityRepositoryProvider).patchFunctionMeta(fn.id, patch);
    ref.invalidate(entityDetailProvider(EntityRef(EntityKind.function, fn.id)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = context.t.entities.detail;
    final v = fn.activeVersion;
    if (v == null) return insetEmpty(d.state.noActiveVersion);
    final codeLines = '\n'.allMatches(v.code).length + 1;
    final meta = v.dependencies.isEmpty
        ? 'Python ${v.pythonVersion}'
        : 'Python ${v.pythonVersion} · ${d.hero.deps(n: v.dependencies.length)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Meta — the ONLY hand-editable surface (PATCH, no version bump). Both rows ride the same
        // AnLeadValue geometry + hover-pencil idiom → aligned + read-first. 唯一手编面,两行同几何同手感。
        AnSection(variant: AnSectionVariant.plain, children: [
          AnField(
            label: d.kv.desc,
            value: fn.description,
            editable: true,
            wrap: true,
            onChanged: (s) => _patchMeta(ref, {'description': s}),
          ),
          _TagsMetaField(
            label: d.kv.tags,
            tags: fn.tags,
            addLabel: d.addTag,
            onChanged: (next) => _patchMeta(ref, {'tags': next}),
          ),
        ]),
        AnSection(variant: AnSectionVariant.plain, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s16),
            child: AnTransformBox(
              title: fn.name,
              icon: AnIcons.function,
              inputs: [for (final f in v.inputs) AnTransformField(f.name, f.type)],
              outputs: [for (final f in v.outputs) AnTransformField(f.name, f.type)],
              phase: v.envStatus == 'failed' ? AnTransformPhase.failed : AnTransformPhase.idle,
              status: AnStatus.fromRaw(v.envStatus),
              statusLabel: 'env ${v.envStatus}',
              meta: meta,
              emptyInputsLabel: d.hero.noInputs,
              emptyOutputsLabel: d.hero.noOutputs,
            ),
          ),
        ]),
        AnSection(label: d.sec.code, variant: AnSectionVariant.plain, children: [
          AnFadeCollapse(
            collapsible: codeLines > 50,
            collapsedHeight: _collapsedCodeHeight,
            expandLabel: d.codeToggle.expand(n: codeLines),
            collapseLabel: d.codeToggle.collapse,
            child: AnCodeEditor(code: v.code, lang: 'py', wrap: true),
          ),
        ]),
        AnSection(label: d.sec.env, variant: AnSectionVariant.plain, children: [
          if (v.envError != null && v.envError!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AnSpace.s8),
              child: AnCallout(v.envError!, severity: AnCalloutSeverity.danger),
            ),
          AnInfoCard(
            title: d.card.venv,
            icon: AnIcons.byKey('check'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                kvList([
                  (d.kv.python, v.pythonVersion),
                  (d.kv.envId, v.envId),
                  (d.kv.status, v.envStatus),
                  (d.kv.syncedAt, fmtTime(v.envSyncedAt)),
                ]),
                const SizedBox(height: AnSpace.s8),
                if (v.dependencies.isEmpty)
                  Text(d.val.none, style: AnText.meta)
                else
                  for (final dep in v.dependencies) AnRow(label: dep, passive: true),
              ],
            ),
          ),
        ]),
      ],
    );
  }
}

/// A tags meta row that MATCHES [AnField]'s editable geometry (same [AnLeadValue] label-hug + s8 inset
/// + islandHead floor + wrap-left value) and its read-first hover-pencil idiom (the sibling of
/// [AnEditableValue] for a pill control instead of a text field). At rest: read-only pills + a
/// hover-revealed pencil at the label's right. Editing: the pills gain ×/add and the pencil becomes a
/// ✓ done — each add/remove PATCHes live via [onChanged]. Empty + not-editing shows an em-dash, exactly
/// like [AnField]'s empty value. 标签 meta 行:与 AnField 同几何同手感(AnLeadValue + s8 + islandHead +
/// wrap-left,hover 铅笔读优先);静态只读药丸 + hover 铅笔,编辑时药丸出 ×/添加、铅笔变 ✓,增删即时 PATCH。
class _TagsMetaField extends StatefulWidget {
  const _TagsMetaField({
    required this.label,
    required this.tags,
    required this.addLabel,
    required this.onChanged,
  });

  final String label;
  final List<String> tags;
  final String addLabel;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_TagsMetaField> createState() => _TagsMetaFieldState();
}

class _TagsMetaFieldState extends State<_TagsMetaField> {
  bool _editing = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = AnMotionPref.reduced(context);
    final labelText = Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AnText.body.copyWith(color: c.ink));
    final revealPencil = _hovered || _editing;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : AnMotion.fast,
          constraints: const BoxConstraints(minHeight: AnSize.islandHead),
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s4),
          decoration: BoxDecoration(
            color: c.surfaceHover.whenActive(_hovered || _editing),
            borderRadius: BorderRadius.circular(AnRadius.button),
          ),
          child: AnLeadValue(
            leading: labelText,
            // Pencil ↔ ✓ at the label's right, mirroring AnEditableValue's afterLeading anchor. 铅笔/✓ 在标签右。
            afterLeading: _editing
                ? AnButton.iconOnly(
                    AnIcons.check,
                    size: AnButtonSize.sm,
                    semanticLabel: context.t.action.done,
                    onPressed: () => setState(() => _editing = false),
                  )
                : Opacity(
                    opacity: revealPencil ? 1 : 0,
                    child: AnButton.iconOnly(
                      AnIcons.edit,
                      size: AnButtonSize.sm,
                      semanticLabel: context.t.action.edit,
                      onPressed: () => setState(() => _editing = true),
                    ),
                  ),
            wrap: true,
            trailing: _value(c),
          ),
        ),
      ),
    );
  }

  Widget _value(AnColors c) {
    if (!_editing) {
      if (widget.tags.isEmpty) {
        // Empty at rest → em-dash, same as AnField's empty value. 空静态显 —,同 AnField。
        return Text('—', style: AnText.value().copyWith(color: c.inkMuted));
      }
      return AnTags(tags: [for (final t in widget.tags) AnTag(t)], readOnly: true);
    }
    return AnTags(
      tags: [for (final t in widget.tags) AnTag(t)],
      placeholder: widget.addLabel,
      onChanged: (next) => widget.onChanged([for (final t in next) t.label]),
    );
  }
}
