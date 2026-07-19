import 'package:anselm/app/window_setup.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/editor/an_editor.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:flutter/material.dart';

/// Manual harness for the native super_editor editor (E1+):
///   flutter run -d macos -t lib/dev/editor_harness_main.dart
///
/// A plain white reading column hosting [AnEditor], for hand-testing what widget-tests can't: real CJK
/// IME composition (系统拼音/搜狗 组字长句 + 组字中退格), rapid clicking, double/triple-tap select, and
/// interaction smoothness — the class of things the last rebuild froze on. 手动验证台(真机 IME/交互)。
Future<void> main() async {
  // MainFlutterWindow hides itself at launch (hiddenWindowAtLaunch); initWindow's windowManager.show()
  // is the ONLY reveal — without it the app runs windowless. 隐藏窗口的唯一显示钥匙,缺它则无窗口。
  WidgetsFlutterBinding.ensureInitialized();
  await initWindow(title: '原生编辑器 harness');
  runApp(const _EditorHarnessApp());
}

/// The harness's own seed content (dev fixture — NOT production; it lives here, not in the editor). Walks
/// the block ladder so hand-testing sees the An prose voice. 手动验证台的种子(dev 固件,不在生产编辑器里)。
const String _harnessSeed = '''
# 产品需求文档

原生 super_editor 编辑器 —— 每个块都是真 Flutter widget,用我们自己的 An 原语绘制,与产品其它面像素级一致。在这里直接打字,试试中文输入、双击选词、三击选段、狂点都不卡死。

## 设计目标

视觉是第一标准:正文 15/1.6 的阅读声、标题阶梯靠字号与颜色分层,而非更重的字重。

行内格式:**加粗**(w400 两字重)、*斜体*、~~删除线~~、行内代码 `print()`、以及[一条链接](https://anselm.website)。

### 实现要点

这是第三层标题下的正文,用来验证跨块选区、光标落位与块间节奏。

> 引用是静默的旁白 —— 一条 2px 左边条 + 降一档的墨色。

```python
def main():
    print("你好, super_editor")
```

### 列表

- 无序项一 —— 圆点是 inkMuted 的静默标记。
- 无序项二 —— 连续项收紧节奏。
1. 有序项一 —— 序号随 reading 正文声。
2. 有序项二。
''';

class _EditorHarnessApp extends StatelessWidget {
  const _EditorHarnessApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7), // canvas
        body: Row(
          children: [
            const Spacer(),
            // A bounded 760 white column — SuperEditor owns its own vertical scroll, so it needs a
            // bounded height (the Row gives full height on the cross axis). 720 阅读列 + 白底。
            SizedBox(
              width: 760,
              child: ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnEditor(initialMarkdown: _harnessSeed, mentionSource: _HarnessMentionSource()),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// A fixture entity source so the harness can exercise `@` mentions without a backend. 假实体源(无后端)。
class _HarnessMentionSource implements MentionSource {
  static const _all = [
    MentionCandidate(type: 'workflow', id: 'wf_00000000000000a1', name: '每日销量对账', description: '每日跑一次的对账流程'),
    MentionCandidate(type: 'function', id: 'fn_00000000000000b2', name: '汇总日报', description: '把当日数据汇成一页'),
    MentionCandidate(type: 'agent', id: 'ag_00000000000000c3', name: '数据分析助手', description: '回答自然语言的数据问题'),
    MentionCandidate(type: 'handler', id: 'hd_00000000000000d4', name: '飞书通知', description: '把结果推到群'),
    MentionCandidate(type: 'document', id: 'doc_0000000000000e5', name: '产品需求文档', description: '本编辑器要展示的文档'),
  ];

  @override
  Future<List<MentionCandidate>> search(String query) async {
    if (query.isEmpty) return _all;
    return _all.where((c) => c.name.contains(query) || c.id.contains(query)).toList();
  }

  @override
  Future<Map<String, String>> resolveNames(List<String> ids) async => const {};
}
