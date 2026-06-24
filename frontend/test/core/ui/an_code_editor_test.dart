import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// AnCodeEditor = the code block / light-editing primitive. Highlight rendering + no-overflow layout are
// covered by the matrix + a real run; here: the state machine (read-only / edit / inline), gutter,
// copy, callbacks, and the a11y container label. AnCodeEditor 状态机 + gutter + copy + a11y 契约。
void main() {
  Widget host(Widget child, {double width = 420}) => TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
        ),
      );

  testWidgets('read-only renders selectable code + language label, no edit field', (tester) async {
    await tester.pumpWidget(host(const AnCodeEditor(code: 'def f():\n    pass', lang: 'py')));
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('Python'), findsOneWidget); // normalized lang label 规范大小写
    expect(find.byType(TextField), findsNothing); // not editing
  });

  testWidgets('gutter shows one line number per logical line', (tester) async {
    await tester.pumpWidget(host(const AnCodeEditor(code: 'a\nb\nc', lang: 'py')));
    expect(find.text('1\n2\n3'), findsOneWidget); // the right-aligned multi-line gutter 行号槽
  });

  testWidgets('inline is frameless: no bar (copy) / no gutter', (tester) async {
    await tester.pumpWidget(host(const AnCodeEditor(code: 'input.x > 0', lang: 'cel', inline: true)));
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byTooltip('Copy'), findsNothing); // no bar 无顶栏
    expect(find.text('1'), findsNothing); // no gutter 无行号
  });

  testWidgets('editable: pencil enters edit; typing fires onInput; Save commits via onChanged + exits', (tester) async {
    String? input;
    String? committed;
    await tester.pumpWidget(host(AnCodeEditor(
      code: 'x = 1',
      lang: 'py',
      editable: true,
      onInput: (v) => input = v,
      onChanged: (v) => committed = v,
    )));
    expect(find.byType(TextField), findsNothing); // read-only first
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget); // now editing

    await tester.enterText(find.byType(TextField), 'x = 2');
    expect(input, 'x = 2'); // per-keystroke

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(committed, 'x = 2'); // committed
    expect(find.byType(TextField), findsNothing); // back to read-only
  });

  testWidgets('editing: typing newlines refreshes the gutter line numbers (no freeze) [review HIGH]', (tester) async {
    await tester.pumpWidget(host(const AnCodeEditor(code: 'x', lang: 'py', editable: true)));
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget); // 1 line on entry 进编辑 1 行
    await tester.enterText(find.byType(TextField), 'a\nb\nc'); // 3 lines
    await tester.pump();
    expect(find.text('1\n2\n3'), findsOneWidget, reason: 'gutter tracks the edited text per keystroke');
  });

  testWidgets('editing: Tab inserts 4 spaces (indent) instead of moving focus out', (tester) async {
    await tester.pumpWidget(host(const AnCodeEditor(code: 'x', lang: 'cel', inline: true, editable: true)));
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final ctrl = tester.widget<TextField>(find.byType(TextField)).controller!;
    expect(ctrl.text, 'ab    '); // 4 spaces appended at the caret 末尾插 4 空格
  });

  testWidgets('copy failure flips to the failed tooltip (honest, no false success)', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') throw PlatformException(code: 'denied');
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(host(const AnCodeEditor(code: 'x', lang: 'py')));
    await tester.tap(find.byTooltip('Copy'));
    await tester.pump();
    expect(find.byTooltip('Copy failed'), findsOneWidget); // failure surfaced 失败可见
    expect(find.byTooltip('Copied'), findsNothing); // not falsely successful 不谎报成功
  });

  testWidgets('editable: Cancel exits without committing', (tester) async {
    String? committed;
    await tester.pumpWidget(host(AnCodeEditor(code: 'orig', lang: 'py', editable: true, onChanged: (v) => committed = v)));
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'changed');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(committed, isNull); // never committed
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('inline + editable is always editing (run-terminal args, no bar)', (tester) async {
    await tester.pumpWidget(host(const AnCodeEditor(code: 'a=1', lang: 'cel', inline: true, editable: true)));
    expect(find.byType(TextField), findsOneWidget); // always editing
    expect(find.byTooltip('Edit'), findsNothing); // no bar
  });

  testWidgets('copy writes the code to the clipboard', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(host(const AnCodeEditor(code: 'copy me', lang: 'py')));
    await tester.tap(find.byTooltip('Copy'));
    await tester.pumpAndSettle();
    expect(copied, ['copy me']);
    expect(find.byTooltip('Copied'), findsOneWidget); // feedback: icon/tooltip flips 复制反馈
  });

  testWidgets('a11y: the frame is a container labelled with language + line count', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const AnCodeEditor(code: 'a\nb', lang: 'py')));
    expect(find.bySemanticsLabel(RegExp('Code block, Python, 2 lines')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('empty code does not crash and renders the frame', (tester) async {
    await tester.pumpWidget(host(const AnCodeEditor(code: '', lang: 'py')));
    expect(tester.takeException(), isNull);
    expect(find.byType(AnCodeEditor), findsOneWidget);
  });

  testWidgets('wrap toggle flips without error', (tester) async {
    await tester.pumpWidget(host(const AnCodeEditor(code: 'a very long line that would scroll', lang: 'py')));
    await tester.tap(find.byTooltip('Wrap'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
