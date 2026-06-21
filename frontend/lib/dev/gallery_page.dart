import 'package:flutter/material.dart';

import '../core/design/colors.dart';
import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../core/ui/ui.dart';

/// Dev-only design gallery — the living spec of the monochrome design language and the UI
/// kit, mirroring the demo's reference gallery in spirit. Run via `lib/dev/gallery_main.dart`
/// (no backend needed). It is also the surface to eyeball every token + primitive state.
/// 仅开发用的设计画廊——单色设计语言与 UI 套件的活规范(精神对标 demo 的 reference 画廊)。经
/// `lib/dev/gallery_main.dart` 运行(无需后端)。也是逐一肉眼验收 token + 原语状态的面。
class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: AnSpace.s32, vertical: AnSpace.s48),
            children: [
              Text('Anselm', style: AnText.h1.copyWith(color: c.ink)),
              const SizedBox(height: AnSpace.s4),
              Text('Design gallery · 单色设计语言 — black & white, no accent hue',
                  style: AnText.body.copyWith(color: c.inkMuted)),
              const SizedBox(height: AnSpace.s48),
              _section(context, 'Surfaces · 表面深度阶梯', _surfaces(context)),
              _section(context, 'Ink · 墨色层级', _ink(context)),
              _section(context, 'Emphasis & lines · 强调与线（无色相）', _emphasis(context)),
              _section(context, 'Functional · 唯一功能色（可删为纯黑白）', _functional(context)),
              _section(context, 'Typography · 字阶', _typography(context)),
              _section(context, 'Spacing · 间距（4 网格）', _spacing(context)),
              _section(context, 'Radius · 圆角', _radius(context)),
              _section(context, 'Buttons · 按钮', _buttons(context)),
              _section(context, 'List rows · 列表行（32px 密度）', _rows(context)),
              _section(context, 'Badges · 标签', _badges(context)),
              _section(context, 'Status · 状态（靠填充+动效，非颜色）', _status(context)),
              _section(context, 'Inputs · 输入', _inputs(context)),
              const SizedBox(height: AnSpace.s48),
            ],
          ),
        ),
      ),
    );
  }

  // ── section frame ──
  Widget _section(BuildContext context, String title, Widget body) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AnText.label.copyWith(color: c.inkFaint)),
          const SizedBox(height: AnSpace.s12),
          AnCard(child: body),
        ],
      ),
    );
  }

  // ── swatches ──
  Widget _swatch(BuildContext context, String name, Color color) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AnRadius.button),
            border: Border.all(color: c.line, width: AnSize.hairline),
          ),
        ),
        const SizedBox(height: AnSpace.s4),
        Text(name, style: AnText.meta.copyWith(color: c.inkMuted)),
      ],
    );
  }

  Widget _swatchWrap(List<Widget> swatches) =>
      Wrap(spacing: AnSpace.s12, runSpacing: AnSpace.s16, children: swatches);

  Widget _surfaces(BuildContext context) {
    final c = context.colors;
    return _swatchWrap([
      _swatch(context, 'desk', c.desk),
      _swatch(context, 'canvas', c.canvas),
      _swatch(context, 'surface', c.surface),
      _swatch(context, 'subtle', c.surfaceSubtle),
      _swatch(context, 'hover', c.surfaceHover),
      _swatch(context, 'active', c.surfaceActive),
    ]);
  }

  Widget _ink(BuildContext context) {
    final c = context.colors;
    return _swatchWrap([
      _swatch(context, 'ink', c.ink),
      _swatch(context, 'inkMuted', c.inkMuted),
      _swatch(context, 'inkFaint', c.inkFaint),
      _swatch(context, 'onAccent', c.onAccent),
    ]);
  }

  Widget _emphasis(BuildContext context) {
    final c = context.colors;
    return _swatchWrap([
      _swatch(context, 'accent (ink)', c.accent),
      _swatch(context, 'accentHover', c.accentHover),
      _swatch(context, 'accentSoft', c.accentSoft),
      _swatch(context, 'accentLine', c.accentLine),
      _swatch(context, 'line', c.line),
      _swatch(context, 'lineStrong', c.lineStrong),
    ]);
  }

  Widget _functional(BuildContext context) {
    final c = context.colors;
    return _swatchWrap([
      _swatch(context, 'danger', c.danger),
      _swatch(context, 'dangerSoft', c.dangerSoft),
    ]);
  }

  // ── typography ──
  Widget _typeRow(BuildContext context, String name, TextStyle style, String sample) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 80,
            child: Text(name, style: AnText.meta.copyWith(color: c.inkFaint)),
          ),
          Expanded(child: Text(sample, style: style.copyWith(color: c.ink))),
        ],
      ),
    );
  }

  Widget _typography(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _typeRow(context, 'h1 / 32', AnText.h1, 'Quadrinity'),
        _typeRow(context, 'h2 / 24', AnText.h2, 'Durable execution'),
        _typeRow(context, 'h3 / 20', AnText.h3, 'Workflow graph'),
        _typeRow(context, 'strong / 16', AnText.strong, 'Active version'),
        _typeRow(context, 'body / 13', AnText.body, 'The fresh process runs once per call.'),
        _typeRow(context, 'prose / 13', AnText.bodyProse, 'A node records its result exactly once.'),
        _typeRow(context, 'label / 12', AnText.label, 'INPUTS'),
        _typeRow(context, 'meta / 12', AnText.meta, 'updated 2 minutes ago'),
        _typeRow(context, 'mono / 13', AnText.mono, 'def greet(name): ...'),
      ],
    );
  }

  // ── spacing ──
  Widget _spacing(BuildContext context) {
    final c = context.colors;
    const values = <(String, double)>[
      ('s4', AnSpace.s4),
      ('s8', AnSpace.s8),
      ('s12', AnSpace.s12),
      ('s16', AnSpace.s16),
      ('s24', AnSpace.s24),
      ('s32', AnSpace.s32),
      ('s48', AnSpace.s48),
      ('s64', AnSpace.s64),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, v) in values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(name, style: AnText.meta.copyWith(color: c.inkFaint)),
                ),
                Container(width: v, height: 10, color: c.ink),
                const SizedBox(width: AnSpace.s8),
                Text('${v.toInt()}', style: AnText.meta.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
      ],
    );
  }

  // ── radius ──
  Widget _radius(BuildContext context) {
    final c = context.colors;
    const values = <(String, double)>[
      ('tag', AnRadius.tag),
      ('button', AnRadius.button),
      ('chip', AnRadius.chip),
      ('card', AnRadius.card),
      ('island', AnRadius.island),
    ];
    return Wrap(
      spacing: AnSpace.s16,
      runSpacing: AnSpace.s16,
      children: [
        for (final (name, r) in values)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.surfaceActive,
                  borderRadius: BorderRadius.circular(r),
                  border: Border.all(color: c.lineStrong, width: AnSize.hairline),
                ),
              ),
              const SizedBox(height: AnSpace.s4),
              Text(name, style: AnText.meta.copyWith(color: c.inkMuted)),
            ],
          ),
      ],
    );
  }

  // ── buttons ──
  Widget _buttons(BuildContext context) {
    return Wrap(
      spacing: AnSpace.s12,
      runSpacing: AnSpace.s12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AnButton(label: 'Primary', variant: AnButtonVariant.primary, onPressed: () {}),
        AnButton(label: 'Secondary', onPressed: () {}),
        AnButton(label: 'Ghost', variant: AnButtonVariant.ghost, onPressed: () {}),
        AnButton(label: 'Delete', variant: AnButtonVariant.danger, onPressed: () {}),
        AnButton(
            label: 'Run',
            icon: Icons.play_arrow_rounded,
            variant: AnButtonVariant.primary,
            onPressed: () {}),
        const AnButton(label: 'Disabled', variant: AnButtonVariant.primary),
        AnButton(label: 'Small', size: AnButtonSize.small, onPressed: () {}),
        AnButton(
            label: 'Small primary',
            size: AnButtonSize.small,
            variant: AnButtonVariant.primary,
            onPressed: () {}),
      ],
    );
  }

  // ── rows ──
  Widget _rows(BuildContext context) {
    return Column(
      children: [
        AnRow(
          leading: Icons.functions,
          title: 'greet_user',
          trailing: const AnBadge('v3'),
          onTap: () {},
        ),
        AnRow(
          leading: Icons.smart_toy_outlined,
          title: 'Research agent',
          trailing: const AnStatusDot(AnStatus.running),
          selected: true,
          onTap: () {},
        ),
        AnRow(
          leading: Icons.account_tree_outlined,
          title: 'Nightly digest workflow',
          trailing: const AnStatusDot(AnStatus.done),
          onTap: () {},
        ),
        AnRow(
          leading: Icons.dns_outlined,
          title: 'Webhook handler',
          trailing: const AnStatusDot(AnStatus.failed),
          onTap: () {},
        ),
      ],
    );
  }

  // ── badges ──
  Widget _badges(BuildContext context) {
    return Wrap(
      spacing: AnSpace.s8,
      runSpacing: AnSpace.s8,
      children: const [
        AnBadge('Active', variant: AnBadgeVariant.solid),
        AnBadge('Draft'),
        AnBadge('v12', variant: AnBadgeVariant.outline),
        AnBadge('Failed', variant: AnBadgeVariant.soft, tone: AnBadgeTone.danger),
      ],
    );
  }

  // ── status ──
  Widget _statusItem(BuildContext context, AnStatus s, String label) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 16, child: Center(child: AnStatusDot(s))),
        const SizedBox(height: AnSpace.s8),
        Text(label, style: AnText.meta.copyWith(color: c.inkMuted)),
      ],
    );
  }

  Widget _status(BuildContext context) {
    return Wrap(
      spacing: AnSpace.s32,
      runSpacing: AnSpace.s16,
      children: [
        _statusItem(context, AnStatus.idle, 'idle'),
        _statusItem(context, AnStatus.running, 'running'),
        _statusItem(context, AnStatus.done, 'done'),
        _statusItem(context, AnStatus.failed, 'failed'),
      ],
    );
  }

  // ── inputs ──
  Widget _inputs(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        AnInput(label: 'Name', hint: 'greet_user'),
        SizedBox(height: AnSpace.s16),
        AnInput(hint: 'Search entities…'),
        SizedBox(height: AnSpace.s16),
        AnInput(label: 'Disabled', hint: 'not editable', enabled: false),
      ],
    );
  }
}
