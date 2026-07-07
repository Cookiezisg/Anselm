// A1 manual-verification harness for the new webview AnDocEditor — the Chinese-IME + no-freeze gate
// that killed super_editor. Run:  flutter run -d macos -t lib/dev/doc_editor_harness_main.dart
// (close the real anselm app first; they share a bundle id). NOT wired into AppShell.
//
// 手动验证台:真 WKWebView 里跑新编辑器,验中文 IME + 不卡死(咬死 super_editor 的那关)。
import 'package:flutter/material.dart';

import '../app/window_setup.dart';
import '../core/design/typography.dart';
import '../core/doc_editor/an_doc_editor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initWindow(title: '文档编辑器 harness');
  runApp(const _HarnessApp());
}

const _sample = '''# 项目说明

这是 **重点**,还有 *强调* 和 `内联代码`。你可以直接打字,不用敲符号。

## 步骤

1. 第一步
2. 第二步
3. 第三步

- 无序 A
  - 嵌套 B

```dart
void main() {
  print("你好,世界");
}
```

| 列 A | 列 B |
| --- | --- |
| 1 | 2 |

> 引用第一行
> 引用第二行

- [ ] 待办未完成
- [x] 待办已完成''';

class _HarnessApp extends StatelessWidget {
  const _HarnessApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
        home: const _HarnessPage(),
      );
}

class _HarnessPage extends StatefulWidget {
  const _HarnessPage();
  @override
  State<_HarnessPage> createState() => _HarnessPageState();
}

class _HarnessPageState extends State<_HarnessPage> {
  final _key = GlobalKey<AnDocEditorState>();
  String _readback = '(点「读取 markdown」看 round-trip 结果;下方是编辑器实时回调)';
  String _lastChange = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AnDocEditor（webview）harness'),
        actions: [
          TextButton(
            onPressed: () async {
              final md = await _key.currentState?.headingRects();
              setState(() => _readback = '标题几何: $md');
            },
            child: const Text('标题几何'),
          ),
          TextButton(
            onPressed: () => setState(() => _readback = _lastChange.isEmpty ? '(还没编辑)' : _lastChange),
            child: const Text('读取 markdown'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: AnDocEditor(
              key: _key,
              initialMarkdown: _sample,
              name: '产品需求文档',
              description: '一个连贯的 demo 文档,用来验证编辑器的排版节奏与中文输入。',
              tags: const ['需求', 'v1', '草稿'],
              onChanged: (md) => _lastChange = md,
              onMetaChanged: (m) => _lastChange = 'META: $m',
            ),
          ),
          const Divider(height: 1),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              color: const Color(0xFFF6F6F8),
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: SelectableText(_readback, style: AnText.code),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
