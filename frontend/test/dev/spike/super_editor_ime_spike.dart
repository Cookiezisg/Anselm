// SPIKE (throwaway, WRK-documents): a minimal runnable super_editor to VALIDATE zh_CN IME on real
// desktop — the one gate the headless round-trip test can't cover, and the sharpest reversal risk for a
// Chinese-facing product. This is NOT wired into the app; it is a hands-on veto-test harness.
//
// RUN:  flutter run -t test/dev/spike/super_editor_ime_spike.dart -d macos   (or -d windows / -d linux)
//
// CHECK (type into the editor with a Pinyin IME):
//   1. Composition: does the候选/候选框 (candidate popup) track the caret correctly? Does committing a
//      Chinese word land it at the caret (not offset / duplicated / dropped)?
//   2. Mixed input: type "笔记 notes 备忘" — does switching CN↔EN mid-line stay coherent?
//   3. Editing: arrow-key + backspace through Chinese runs; select + replace a Chinese span.
//   4. Wikilink: the seeded `[[doc_...]]` renders as text (custom chip codec is P3.3, not here).
//   5. Press "导出 markdown" and eyeball the console — your typed Chinese must serialize back intact.
// If composition is broken/offset/dropped on a target platform → super_editor is VETOED there → fleather.
import 'package:anselm/app/window_setup.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

const _seed = '''
# 中文 IME 验证

这是一段中文正文,请用拼音输入法在这里打字,测试候选框跟随光标、提交落点、混排 English 是否正常。

- 列表项一
- 列表项二

引用一篇文档:[[doc_9f2c41aa77b0e310]]

> 引用块也打点中文试试
''';

// The macOS runner hides the native window at launch (MainFlutterWindow.order → hiddenWindowAtLaunch);
// initWindow's show() is the ONLY reveal, so a bare runApp leaves a windowless background app. Reuse the
// project's window bootstrap. macOS 窗口启动即隐藏,须走 initWindow 才现身(否则后台有进程、无窗口)。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initWindow(title: 'super_editor · 中文 IME spike');
  runApp(const _ImeSpikeApp());
}

// Unify CJK + Latin metrics by pinning MiSans (covers both scripts) on the base text style. Appended
// AFTER the defaults so it cascades over every block (headers keep their size — textStyle merges per
// property in super_editor's cascading stylesheet). 把基础字体统一到 MiSans(拉丁+简中同源),消混排跳。
final Stylesheet _miSans = defaultStylesheet.copyWith(
  addRulesAfter: [
    StyleRule(BlockSelector.all, (doc, node) => {
          Styles.textStyle: const TextStyle(fontFamily: 'MiSans'),
        }),
  ],
);

class _ImeSpikeApp extends StatefulWidget {
  const _ImeSpikeApp();

  @override
  State<_ImeSpikeApp> createState() => _ImeSpikeAppState();
}

class _ImeSpikeAppState extends State<_ImeSpikeApp> {
  late final MutableDocument _doc;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;

  @override
  void initState() {
    super.initState();
    _doc = deserializeMarkdownToDocument(_seed, syntax: MarkdownSyntax.normal);
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(document: _doc, composer: _composer);
  }

  void _dump() {
    // Serialize the CURRENT (post-typing) document back to markdown and print it — verify your Chinese
    // input round-trips intact. 把当前(打字后)文档序列化回 markdown 打印,验证中文输入往返完好。
    final md = serializeDocumentToMarkdown(_doc, syntax: MarkdownSyntax.normal);
    debugPrint('\n==== serialized markdown (verify zh_CN survived) ====\n$md\n====================================================\n');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('super_editor · 中文 IME spike'),
          actions: [
            TextButton(onPressed: _dump, child: const Text('导出 markdown (看 console)')),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            // The baseline "jump" when Latin appears is a FONT-FALLBACK metrics mismatch: super_editor's
            // default textStyle has NO fontFamily → Latin renders in Roboto, CJK in the system CJK font,
            // and their ascent/descent differ, so a mixed CJK+Latin line changes height. Pinning ONE font
            // that covers both scripts (MiSans VF — the project's UI face) unifies the metrics → no jump.
            // This is exactly what the real stylesheet (P3.2) does. 混排跳=字体回退度量不一致;统一到 MiSans 即消。
            child: SuperEditor(editor: _editor, stylesheet: _miSans),
          ),
        ),
      ),
    );
  }
}
