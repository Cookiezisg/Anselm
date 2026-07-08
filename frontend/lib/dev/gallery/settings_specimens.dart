import 'package:flutter/widgets.dart';

import '../../core/ui/an_meter.dart';
import '../../core/ui/an_scope_badge.dart';
import '../../core/ui/an_secret_field.dart';
import '../../core/ui/an_segmented.dart';
import '../../core/ui/an_setting_row.dart';
import '../../core/ui/an_switch.dart';
import '../../core/ui/icons.dart';
import 'specimen.dart';

// Settings primitives (WRK-062 S0) — the preference pages' vocabulary. Dev-only literals (gallery
// is exempt from i18n). settings 原语(S0):偏好页语汇。gallery 明文豁免 i18n。

/// A tiny stateful host so interactive specimens actually toggle in the gallery. 可交互宿主。
class _Live<T> extends StatefulWidget {
  const _Live({required this.initial, required this.builder});

  final T initial;
  final Widget Function(T value, ValueChanged<T> set) builder;

  @override
  State<_Live<T>> createState() => _LiveState<T>();
}

class _LiveState<T> extends State<_Live<T>> {
  late T value = widget.initial;

  @override
  Widget build(BuildContext context) => widget.builder(value, (v) => setState(() => value = v));
}

final GalleryCategory settingsCategory = GalleryCategory('设置 Settings', AnIcons.gear, [
  GalleryItem('AnSwitch', '布尔开关——kit 唯一正统(30×18 药丸,accent 填充,reduced 直跳)', [
    GallerySpecimen('interactive', (_) => _Live<bool>(
          initial: true,
          builder: (v, set) => AnSwitch(value: v, onChanged: set, semanticLabel: 'demo'),
        )),
    GallerySpecimen('off', (_) => const AnSwitch(value: false, onChanged: _noopBool, semanticLabel: 'off')),
    GallerySpecimen('disabled-on', (_) => const AnSwitch(value: true, semanticLabel: 'locked')),
    GallerySpecimen('disabled-off', (_) => const AnSwitch(value: false, semanticLabel: 'locked')),
  ]),
  GalleryItem('AnSegmented', '分段器 2–4 段——等宽段+白卡滑动(matched-geometry)', [
    GallerySpecimen('三档', (_) => _Live<String>(
          initial: 'important',
          builder: (v, set) => AnSegmented<String>(
            options: const [
              AnSegmentedOption(value: 'all', label: '全部'),
              AnSegmentedOption(value: 'important', label: '仅需处理'),
              AnSegmentedOption(value: 'silent', label: '静音'),
            ],
            value: v,
            onChanged: set,
          ),
        ), span: true),
    GallerySpecimen('两档带图标', (_) => _Live<String>(
          initial: 'enter',
          builder: (v, set) => AnSegmented<String>(
            options: [
              AnSegmentedOption(value: 'enter', label: 'Enter', icon: AnIcons.enter),
              AnSegmentedOption(value: 'cmdEnter', label: '⌘Enter', icon: AnIcons.enter),
            ],
            value: v,
            onChanged: set,
          ),
        )),
    GallerySpecimen('四档禁用', (_) => AnSegmented<int>(
          options: const [
            AnSegmentedOption(value: 0, label: '0.8×'),
            AnSegmentedOption(value: 1, label: '1.0×'),
            AnSegmentedOption(value: 2, label: '1.25×'),
            AnSegmentedOption(value: 3, label: '1.5×'),
          ],
          value: 1,
          onChanged: _noopInt,
          enabled: false,
        ), span: true),
    GallerySpecimen('超长标签', (_) => AnSegmented<int>(
          options: const [
            AnSegmentedOption(value: 0, label: 'a-very-long-segment-label-that-must-ellipsize'),
            AnSegmentedOption(value: 1, label: '短'),
          ],
          value: 0,
          onChanged: _noopInt,
        ), stress: true, maxWidth: 220),
  ]),
  GalleryItem('AnSettingRow', '设置行——标签+次行描述+行尾控件槽;modified 左缘条+hover 单项重置', [
    GallerySpecimen('开关行', (_) => _Live<bool>(
          initial: true,
          builder: (v, set) => AnSettingRow(
            label: '系统通知',
            desc: '窗口未聚焦时经系统通知中心送达',
            child: AnSwitch(value: v, onChanged: set),
          ),
        ), span: true),
    GallerySpecimen('modified+重置', (_) => _Live<bool>(
          initial: false,
          builder: (v, set) => AnSettingRow(
            label: '应用内 toast',
            desc: '右上角浮出提醒',
            modified: true,
            onReset: () => set(true),
            resetLabel: '重置为默认',
            child: AnSwitch(value: v, onChanged: set),
          ),
        ), span: true),
    GallerySpecimen('禁用行', (_) => const AnSettingRow(
          label: '右岛自动登台',
          desc: '等待 V8 W1 落地后启用',
          enabled: false,
          child: AnSwitch(value: true),
        ), span: true),
    GallerySpecimen('超长标签+描述', (_) => AnSettingRow(
          label: 'A' * 60,
          desc: '描述' * 40,
          child: const AnSwitch(value: false, onChanged: _noopBool),
        ), stress: true, span: true),
  ]),
  GalleryItem('AnSecretField', '密钥输入——默认掩码+可见切换;粘贴 trim;三条可兑现承诺', [
    GallerySpecimen('empty', (_) => const AnSecretField(
        placeholder: 'sk-…', revealLabel: 'reveal', concealLabel: 'conceal'), span: true),
    GallerySpecimen('禁用', (_) => const AnSecretField(
        placeholder: 'sk-…', enabled: false, revealLabel: 'reveal', concealLabel: 'conceal'), span: true),
  ]),
  GalleryItem('AnMeter', '用量条——accent→warn(0.85)→danger(0.97);null=空轨', [
    GallerySpecimen('正常', (_) => const AnMeter(ratio: 0.42, label: '2 100 / 5 000 · 8/1 重置'), span: true),
    GallerySpecimen('warn', (_) => const AnMeter(ratio: 0.9, label: '4 500 / 5 000'), span: true),
    GallerySpecimen('danger', (_) => const AnMeter(ratio: 0.99, label: '4 950 / 5 000'), span: true),
    GallerySpecimen('未知', (_) => const AnMeter(ratio: null, label: '——'), span: true),
    GallerySpecimen('零', (_) => const AnMeter(ratio: 0), stress: true, maxWidth: 160),
  ]),
  GalleryItem('AnScopeBadge', '作用域徽——本机/工作区/全机(AnSection 级,禁页头单枚)', [
    GallerySpecimen('三域', (_) => const Wrap(spacing: 8, runSpacing: 8, children: [
          AnScopeBadge(AnSettingScope.device),
          AnScopeBadge(AnSettingScope.workspace),
          AnScopeBadge(AnSettingScope.machine),
        ]), span: true),
  ]),
]);

void _noopBool(bool _) {}
void _noopInt(int _) {}
