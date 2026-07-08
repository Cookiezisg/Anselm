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
                  child: AnEditor(mentionSource: _HarnessMentionSource()),
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
