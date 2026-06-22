import 'package:flutter/material.dart';

import '../core/design/colors.dart';
import '../core/design/syntax.dart';
import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../core/ui/ui.dart';

/// Dev-only design gallery — the living spec of the monochrome design language and the full
/// UI kit. Stateful so the form controls are interactive when run via `make fe-gallery`.
/// 设计画廊(仅开发):单色设计语言 + 完整 UI 套件的活规范。有状态,故 `make fe-gallery` 跑时表单可交互。
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  bool _toggle = true;
  bool _check = true;
  String _radio = 'fn';
  int _seg = 0;
  String? _drop = 'agent';
  bool _chip = true;
  final double _progress = 0.6;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: AnSpace.s32, vertical: AnSpace.s48),
            children: [
              Text('Anselm', style: AnText.h1.copyWith(color: c.ink)),
              const SizedBox(height: AnSpace.s4),
              Text('Design gallery · 单色设计语言 — black & white chrome, color only where it means something',
                  style: AnText.body.copyWith(color: c.inkMuted)),
              const SizedBox(height: AnSpace.s48),
              _section(context, 'Surfaces · 表面深度阶梯', _surfaces(context)),
              _section(context, 'Ink · 墨色层级', _ink(context)),
              _section(context, 'Emphasis & lines · 强调与线（无色相）', _emphasis(context)),
              _section(context, 'Status colors · 状态色（功能语义）', _statusColors(context)),
              _section(context, 'Code syntax · 代码高亮', _syntax(context)),
              _section(context, 'Typography · 字阶', _typography(context)),
              _section(context, 'Spacing · 间距（4 网格）', _spacing(context)),
              _section(context, 'Radius · 圆角', _radius(context)),
              _section(context, 'Icons (Lucide) · 图标', _icons(context)),
              _section(context, 'Buttons · 按钮', _buttons(context)),
              _section(context, 'Icon buttons · 图标按钮', _iconButtons(context)),
              _section(context, 'Chips · pills · kbd · kind', _chips(context)),
              _section(context, 'Form controls · 表单控件', _form(context)),
              _section(context, 'List rows · 列表行（32px 密度）', _rows(context)),
              _section(context, 'Badges · 标签', _badges(context)),
              _section(context, 'Status · 状态（靠填充+动效，非颜色）', _status(context)),
              _section(context, 'Feedback · 反馈', _feedback(context)),
              _section(context, 'Data display · 数据展示', _data(context)),
              const SizedBox(height: AnSpace.s48),
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _statusColors(BuildContext context) {
    final c = context.colors;
    return _swatchWrap([
      _swatch(context, 'ok', c.ok),
      _swatch(context, 'okSoft', c.okSoft),
      _swatch(context, 'warn', c.warn),
      _swatch(context, 'warnSoft', c.warnSoft),
      _swatch(context, 'danger', c.danger),
      _swatch(context, 'dangerSoft', c.dangerSoft),
    ]);
  }

  Widget _syntax(BuildContext context) {
    final sx = context.syntax;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _swatchWrap([
          _swatch(context, 'comment', sx.comment),
          _swatch(context, 'keyword', sx.keyword),
          _swatch(context, 'string', sx.string),
          _swatch(context, 'number', sx.number),
          _swatch(context, 'function', sx.function),
        ]),
        const SizedBox(height: AnSpace.s16),
        const AnCodeBlock('def greet(name):\n'
            '    # a friendly hello\n'
            '    return f"hi {name}"  # retries = 42'),
      ],
    );
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
          SizedBox(width: 80, child: Text(name, style: AnText.meta.copyWith(color: c.inkFaint))),
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

  // ── spacing & radius ──
  Widget _spacing(BuildContext context) {
    final c = context.colors;
    const values = <(String, double)>[
      ('s4', AnSpace.s4), ('s8', AnSpace.s8), ('s12', AnSpace.s12), ('s16', AnSpace.s16),
      ('s24', AnSpace.s24), ('s32', AnSpace.s32), ('s48', AnSpace.s48), ('s64', AnSpace.s64),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, v) in values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
            child: Row(children: [
              SizedBox(width: 48, child: Text(name, style: AnText.meta.copyWith(color: c.inkFaint))),
              Container(width: v, height: 10, color: c.ink),
              const SizedBox(width: AnSpace.s8),
              Text('${v.toInt()}', style: AnText.meta.copyWith(color: c.inkMuted)),
            ]),
          ),
      ],
    );
  }

  Widget _radius(BuildContext context) {
    final c = context.colors;
    const values = <(String, double)>[
      ('tag', AnRadius.tag), ('button', AnRadius.button), ('chip', AnRadius.chip),
      ('card', AnRadius.card), ('island', AnRadius.island),
    ];
    return Wrap(
      spacing: AnSpace.s16,
      runSpacing: AnSpace.s16,
      children: [
        for (final (name, r) in values)
          Column(mainAxisSize: MainAxisSize.min, children: [
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
          ]),
      ],
    );
  }

  // ── icons ──
  Widget _icons(BuildContext context) {
    final c = context.colors;
    const items = <(IconData, String)>[
      (AnIcons.function, 'function'), (AnIcons.handler, 'handler'), (AnIcons.agent, 'agent'),
      (AnIcons.workflow, 'workflow'), (AnIcons.trigger, 'trigger'), (AnIcons.control, 'control'),
      (AnIcons.approval, 'approval'), (AnIcons.mcp, 'mcp'), (AnIcons.skill, 'skill'),
      (AnIcons.document, 'document'), (AnIcons.entities, 'entities'), (AnIcons.chat, 'chat'),
      (AnIcons.scheduler, 'scheduler'), (AnIcons.search, 'search'), (AnIcons.settings, 'settings'),
      (AnIcons.run, 'run'), (AnIcons.edit, 'edit'), (AnIcons.iterate, 'iterate'),
      (AnIcons.trash, 'trash'), (AnIcons.add, 'add'), (AnIcons.web, 'web'), (AnIcons.reasoning, 'reasoning'),
    ];
    return Wrap(
      spacing: AnSpace.s24,
      runSpacing: AnSpace.s16,
      children: [
        for (final (icon, name) in items)
          SizedBox(
            width: 64,
            child: Column(children: [
              Icon(icon, size: AnSize.iconLg, color: c.ink),
              const SizedBox(height: AnSpace.s4),
              Text(name, style: AnText.meta.copyWith(color: c.inkMuted), textAlign: TextAlign.center),
            ]),
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
        AnButton(label: 'Run', icon: AnIcons.run, variant: AnButtonVariant.primary, onPressed: () {}),
        const AnButton(label: 'Disabled', variant: AnButtonVariant.primary),
        AnButton(label: 'Small', size: AnButtonSize.small, onPressed: () {}),
        AnButton(label: 'Small primary', size: AnButtonSize.small, variant: AnButtonVariant.primary, onPressed: () {}),
      ],
    );
  }

  Widget _iconButtons(BuildContext context) {
    return Wrap(
      spacing: AnSpace.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AnIconButton(AnIcons.run, tooltip: 'Run', onPressed: () {}),
        AnIconButton(AnIcons.edit, tooltip: 'Edit', onPressed: () {}),
        AnIconButton(AnIcons.iterate, tooltip: 'Iterate', onPressed: () {}),
        AnIconButton(AnIcons.more, tooltip: 'More', onPressed: () {}),
        AnIconButton(AnIcons.trash, tooltip: 'Delete', tone: AnIconButtonTone.danger, onPressed: () {}),
        const AnIconButton(AnIcons.add, tooltip: 'Disabled'),
        AnIconButton(AnIcons.search, size: AnSize.controlSm, onPressed: () {}),
      ],
    );
  }

  Widget _chips(BuildContext context) {
    return Wrap(
      spacing: AnSpace.s12,
      runSpacing: AnSpace.s12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AnChip(label: 'All', selected: _chip, onTap: () => setState(() => _chip = true)),
        AnChip(label: 'Functions', icon: AnIcons.function, selected: !_chip, onTap: () => setState(() => _chip = false)),
        AnRefPill(label: 'greet_user', icon: AnIcons.function, onTap: () {}),
        AnRefPill(label: 'Research agent', icon: AnIcons.agent, onTap: () {}),
        const AnKbd('⌘'),
        const AnKbd('K'),
        AnKindIcon(AnIcons.workflow),
        AnKindIcon(AnIcons.mcp, size: AnSize.controlSm),
      ],
    );
  }

  // ── form ──
  Widget _form(BuildContext context) {
    final c = context.colors;
    Widget labeled(String label, Widget control) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            control,
            const SizedBox(width: AnSpace.s8),
            Text(label, style: AnText.body.copyWith(color: c.ink)),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AnSpace.s24,
          runSpacing: AnSpace.s16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            labeled('Toggle', AnToggle(value: _toggle, onChanged: (v) => setState(() => _toggle = v))),
            labeled('Checkbox', AnCheckbox(value: _check, onChanged: (v) => setState(() => _check = v))),
            labeled('Function', AnRadio<String>(value: 'fn', groupValue: _radio, onChanged: (v) => setState(() => _radio = v))),
            labeled('Agent', AnRadio<String>(value: 'agent', groupValue: _radio, onChanged: (v) => setState(() => _radio = v))),
          ],
        ),
        const SizedBox(height: AnSpace.s16),
        Wrap(
          spacing: AnSpace.s16,
          runSpacing: AnSpace.s16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AnSegmented<int>(
              segments: const [(0, 'Code'), (1, 'Versions'), (2, 'Runs')],
              value: _seg,
              onChanged: (v) => setState(() => _seg = v),
            ),
            SizedBox(
              width: 200,
              child: AnDropdown<String>(
                value: _drop,
                placeholder: 'Pick a kind',
                items: const [('fn', 'Function'), ('agent', 'Agent'), ('wf', 'Workflow')],
                onChanged: (v) => setState(() => _drop = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: AnSpace.s16),
        Row(
          children: [
            const Expanded(child: AnInput(label: 'Name', hint: 'greet_user')),
            const SizedBox(width: AnSpace.s16),
            const Expanded(child: AnSearchField(hint: 'Search entities…')),
          ],
        ),
      ],
    );
  }

  // ── rows ──
  Widget _rows(BuildContext context) {
    return Column(
      children: [
        AnRow(leading: AnIcons.function, title: 'greet_user', trailing: const AnBadge('v3'), onTap: () {}),
        AnRow(leading: AnIcons.agent, title: 'Research agent', trailing: const AnStatusDot(AnStatus.run), selected: true, onTap: () {}),
        AnRow(leading: AnIcons.workflow, title: 'Nightly digest workflow', trailing: const AnStatusDot(AnStatus.done), onTap: () {}),
        AnRow(leading: AnIcons.handler, title: 'Webhook handler', trailing: const AnStatusDot(AnStatus.err), onTap: () {}),
      ],
    );
  }

  Widget _badges(BuildContext context) {
    return Wrap(
      spacing: AnSpace.s8,
      runSpacing: AnSpace.s8,
      children: const [
        AnBadge('v12'),
        AnBadge('Default', variant: AnBadgeVariant.outline),
        AnBadge('Active', variant: AnBadgeVariant.solid, tone: AnBadgeTone.accent),
        AnBadge('Done', tone: AnBadgeTone.ok),
        AnBadge('Waiting', tone: AnBadgeTone.warn),
        AnBadge('Failed', tone: AnBadgeTone.danger),
      ],
    );
  }

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
        _statusItem(context, AnStatus.idle, 'idle 空闲'),
        _statusItem(context, AnStatus.run, 'run 运行中'),
        _statusItem(context, AnStatus.wait, 'wait 等待'),
        _statusItem(context, AnStatus.err, 'err 失败'),
        _statusItem(context, AnStatus.done, 'done 完成'),
      ],
    );
  }

  // ── feedback ──
  Widget _feedback(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnCallout('A node records its result exactly once — re-runs are idempotent.'),
        const SizedBox(height: AnSpace.s8),
        const AnCallout('Environment built successfully.', tone: AnCalloutTone.ok, title: 'Ready'),
        const SizedBox(height: AnSpace.s8),
        const AnCallout('This action deletes failed nodes and replays.', tone: AnCalloutTone.warn),
        const SizedBox(height: AnSpace.s8),
        const AnCallout('Import blacklist violation: stateful import in a function.', tone: AnCalloutTone.danger, title: 'Invalid'),
        const SizedBox(height: AnSpace.s16),
        AnProgress(value: _progress),
        const SizedBox(height: AnSpace.s8),
        const AnProgress(),
        const SizedBox(height: AnSpace.s16),
        Row(children: [
          const AnSpinner(),
          const SizedBox(width: AnSpace.s16),
          const Expanded(child: AnSkeleton(height: 12)),
        ]),
        const SizedBox(height: AnSpace.s16),
        SizedBox(
          height: 140,
          child: AnEmptyState(
            icon: AnIcons.empty,
            title: 'No entities yet',
            hint: 'Create a function, agent, or workflow to get started.',
            action: AnButton(label: 'New entity', icon: AnIcons.add, variant: AnButtonVariant.primary, onPressed: () {}),
          ),
        ),
      ],
    );
  }

  // ── data ──
  Widget _data(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnInfoCard(
          title: 'Overview',
          children: [
            AnKvRow(label: 'Kind', child: const AnBadge('Function', variant: AnBadgeVariant.outline)),
            AnKvRow(label: 'Active', child: const AnBadge('v3', tone: AnBadgeTone.accent)),
            AnKvRow(label: 'Env', child: const AnBadge('ready', tone: AnBadgeTone.ok)),
            const AnKvRow(label: 'Updated', value: '2 minutes ago'),
          ],
        ),
        const SizedBox(height: AnSpace.s16),
        Text('JSON tree', style: AnText.label.copyWith(color: c.inkFaint)),
        const SizedBox(height: AnSpace.s8),
        const AnJsonTree({
          'message': 'Hello, Ada!',
          'len': 11,
          'ok': true,
          'meta': {'retries': 0, 'tags': ['greeting', 'demo']},
        }),
        const SizedBox(height: AnSpace.s16),
        Text('Thin table', style: AnText.label.copyWith(color: c.inkFaint)),
        const SizedBox(height: AnSpace.s8),
        AnThinTable(
          columns: const [AnColumn('Node', flex: 2), AnColumn('Kind'), AnColumn('Status')],
          rows: [
            [Text('fetch', style: AnText.body.copyWith(color: c.ink)), const AnBadge('action', variant: AnBadgeVariant.outline), const AnBadge('Done', tone: AnBadgeTone.ok)],
            [Text('summarize', style: AnText.body.copyWith(color: c.ink)), const AnBadge('agent', variant: AnBadgeVariant.outline), const AnBadge('Running', tone: AnBadgeTone.accent)],
            [Text('approve', style: AnText.body.copyWith(color: c.ink)), const AnBadge('approval', variant: AnBadgeVariant.outline), const AnBadge('Waiting', tone: AnBadgeTone.warn)],
          ],
        ),
      ],
    );
  }
}
