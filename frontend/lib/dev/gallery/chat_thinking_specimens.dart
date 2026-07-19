import '../../features/chat/ui/chat_thinking.dart';
import 'specimen.dart';

// ChatThinking — the reasoning block's "whisper + prose tail" grammar (NOT a tool_call card). Shown on
// the gallery's white cell (= the real white ocean). Labels are English for now (i18n later, user's
// call); dev strings are i18n-exempt. The streaming body is the live-tail family's BARE prose face
// (bottom-pinned proseClamp + top fade on overflow) — best seen with prose past the clamp.
//
// ChatThinking——推理块的「低语+prose 尾」语法(非 tool_call 卡)。衬白 cell(=真实白海洋)。标签暂英文
// (dev 串豁免)。流式体=活尾族 prose 无框脸(贴底 proseClamp+溢出顶渐隐),正文超钳才看得出。

const double _thinkW = 620;

// A long reasoning stream (Chinese prose is model CONTENT, not a UI label) — wraps past the prose
// clamp so the tail bottom-pins + top-fades. 长推理流(中文是模型内容非 UI 标签),超钳→贴底+顶渐隐。
const String _long =
    '用户想按季度汇总发票总额。我得先确认 sync_inventory 这个 function 的输出结构——它返回的是逐行的 line items 还是'
    '已经聚合过的。如果是逐行的,我要先按 issue_date 把每条落到对应季度桶里,再对每桶的 amount 求和。跨年的边界要小心:'
    'Q4 和次年 Q1 不能混。退款行(amount 为负)默认应计入,因为它冲减当季营收。还要考虑币种——若有多币种,得先归一到本位币'
    '再汇总,否则数字没有可比性。另外税额要不要单独拆出来?用户没明说,但财务口径通常看不含税的净额,我倾向默认给净额、'
    '再把含税总额作为附加列。时间范围也得定——是本财年还是滚动 12 个月?先按本财年,给个参数让用户能切。最后把结果按季度'
    '升序排列,附上环比变化,并标出波动超过 10% 的季度供用户重点关注,顺便生成一张简单的季度趋势图放在右岛。';

const String _short = '用户想按季度汇总发票,我先拉出行项目再按季度聚合求和。';

ChatThinking _thinking({
  required String text,
  required bool streaming,
  bool expanded = false,
}) =>
    ChatThinking(
      text: text,
      streaming: streaming,
      initiallyExpanded: expanded,
      liveLabel: 'thinking',
      settledLabel: 'thought for 12s',
    );

final GalleryItem chatThinkingGalleryItem = GalleryItem(
  'ChatThinking 推理块',
  '低语 + 左 rail + 活尾族 prose 无框脸:思考中贴底钳高(proseClamp,最新字恒可见)、溢出顶缘渐隐;想完收成一行 thought for Ns · expand',
  [
    GallerySpecimen('思考中 · prose 尾(超钳 → 贴底示新,顶缘渐隐)',
        (_) => _thinking(text: _long, streaming: true), span: true, maxWidth: _thinkW),
    GallerySpecimen('思考中 · 短(未满钳,全显不裁不渐隐)',
        (_) => _thinking(text: _short, streaming: true), span: true, maxWidth: _thinkW),
    GallerySpecimen('想完 · 收起(默认一行,railless)',
        (_) => _thinking(text: _long, streaming: false), span: true, maxWidth: _thinkW),
    GallerySpecimen('想完 · 展开(rail 上回看全文)',
        (_) => _thinking(text: _long, streaming: false, expanded: true), span: true, maxWidth: _thinkW),
  ],
);
