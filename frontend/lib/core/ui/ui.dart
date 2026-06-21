/// The Anselm UI kit — the closed set of primitives that features compose from. Features
/// MUST build their UI from these (and the design tokens), never bespoke colors/metrics:
/// this single-source rule is what keeps the visual language unified at app scale.
/// Anselm UI 套件——feature 组合的封闭原语集。feature 只许用它们(+ design token)搭 UI,绝不内联
/// 配色/度量:这条单一来源规则,是 app 尺度下视觉语言统一的保证。
library;

export 'an_badge.dart';
export 'an_button.dart';
export 'an_card.dart';
export 'an_input.dart';
export 'an_row.dart';
export 'an_status_dot.dart';
