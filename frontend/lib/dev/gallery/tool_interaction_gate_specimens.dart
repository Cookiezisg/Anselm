import '../../core/contract/interaction.dart';
import '../../features/chat/ui/tool_interaction_gate.dart';
import 'specimen.dart';

// ToolInteractionGate — the HUMAN GATE (WRK-056 F16): the one product-wide shape for "a machine asks a
// human to act". danger variant (a dangerous tool awaiting approval) + ask variant (ask_user awaiting an
// answer) share one island shell; each shown awaiting (live buttons, fail-safe order) and frozen (the
// decision章). Prose is model CONTENT (Chinese), not a UI label. autofocus off so the matrix batteries
// don't grab focus. 人闸:danger/ask 两变体 × awaiting/frozen;衬白 cell(=真实白海洋)。
//
// ToolInteractionGate——人闸:danger(危险调用待批)+ ask(提问待答)共用白岛壳;各显待决(fail-safe 钮排)
// 与冻结(决议章)。中文是模型内容非 UI 标签;autofocus 关(矩阵电池不抢焦)。

const double _gateW = 560;

ToolInteractionGate _danger({InteractionAction? decided}) => ToolInteractionGate(
      kind: GateKind.danger,
      prompt: '清空构建缓存目录并重新安装依赖,好让下一次构建从干净状态开始。',
      toolName: 'Bash',
      evidence: const {
        'command': 'rm -rf /tmp/build-cache && npm ci --no-audit',
        'cwd': '/ws',
        'timeout': '120000',
      },
      decided: decided,
      autofocus: false,
    );

ToolInteractionGate _ask({
  List<String> options = const [],
  bool freeText = false,
  InteractionAction? decided,
  String? answer,
}) =>
    ToolInteractionGate(
      kind: GateKind.ask,
      prompt: '这几张发票的币种不一致,汇总前你希望我按哪种本位币归一?',
      options: options,
      allowFreeText: freeText,
      decided: decided,
      decidedAnswer: answer,
      autofocus: false,
    );

const _options = ['人民币 CNY', '美元 USD', '欧元 EUR'];

final GalleryItem toolInteractionGateGalleryItem = GalleryItem(
  'ToolInteractionGate 人闸',
  '全产品唯一「机器请求人类动手」形状:danger 危险确认门 + ask 提问,共用白岛壳。'
      '待决=fail-safe 钮排(消极左 ghost / 积极右 primary)+ 琥珀 wait 点;冻结=决议章(选中项定格、余淡出)。数字键 1–9 快选(仅持焦点门)。',
  [
    GallerySpecimen('danger · 待决(危险徽 + 自报 + 证物窗 + fail-safe 钮排)',
        (_) => _danger(), span: true, maxWidth: _gateW),
    GallerySpecimen('danger · 冻结 · 已允许',
        (_) => _danger(decided: InteractionAction.approve), span: true, maxWidth: _gateW),
    GallerySpecimen('danger · 冻结 · 已拒绝',
        (_) => _danger(decided: InteractionAction.deny), span: true, maxWidth: _gateW),
    GallerySpecimen('ask · 活化(选项钮 + 自由文本框)',
        (_) => _ask(options: _options, freeText: true), span: true, maxWidth: _gateW),
    GallerySpecimen('ask · 冻结 · 选中章(余淡出)',
        (_) => _ask(options: _options, decided: InteractionAction.accept, answer: '美元 USD'),
        span: true, maxWidth: _gateW),
    GallerySpecimen('ask · 冻结 · 自由答复(引用)',
        (_) => _ask(
            freeText: true, decided: InteractionAction.accept, answer: '按季度平均汇率归一到美元,并附一列原币种金额。'),
        span: true, maxWidth: _gateW),
    GallerySpecimen('ask · 冻结 · 已跳过',
        (_) => _ask(options: _options, decided: InteractionAction.decline), span: true, maxWidth: _gateW),
  ],
);
