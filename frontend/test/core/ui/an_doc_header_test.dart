import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_doc_header.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/core/ui/an_chip.dart';
import 'package:anselm/core/ui/an_inline_edit.dart';
import 'package:anselm/core/ui/an_tags.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A-113: the reading-scale document header, extracted from the documents feature into a gallery
/// primitive. These lock the contract the feature relied on: crumb + renamable title + description +
/// (documents-only) tags, and the metadata callback shape `{name?|description?|tags?}`.
/// A-113:阅读尺度文档头原语——锁住 feature 依赖的契约(面包屑+可改名标题+描述+仅文档标签 + 元数据回调形)。
void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  // AnInlineEdit reads context.t (the edit affordance) → the whole tree needs a TranslationProvider, and
  // the header must sit in a WIDTH-bounded column (the inline-edit Row is unbounded otherwise). 头需
  // TranslationProvider(内联编辑读 context.t)+ 定宽列(否则内联编辑 Row 无界)。
  Widget host(Widget child) => TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(body: Align(alignment: Alignment.topCenter, child: SizedBox(width: 640, child: child))),
        ),
      );

  testWidgets('renders crumb + title + description', (tester) async {
    await tester.pumpWidget(host(const AnDocHeader(
      crumb: 'Documents',
      name: 'Architecture Notes',
      description: 'design memo',
    )));
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Architecture Notes'), findsOneWidget);
    expect(find.text('design memo'), findsOneWidget);
  });

  testWidgets('skill face: showTags:false hides the tags row', (tester) async {
    await tester.pumpWidget(host(const AnDocHeader(
      crumb: 'Skills',
      name: 'code-review',
      showTags: false,
      tags: ['x'], // even with tags present, showTags:false suppresses the row 即便有标签也不渲
    )));
    expect(find.byType(AnTags), findsNothing);
  });

  testWidgets('document face: tags row renders when editable (onMetaChanged given)', (tester) async {
    await tester.pumpWidget(host(AnDocHeader(
      crumb: 'Documents',
      name: 'Doc',
      tags: const ['design'],
      onMetaChanged: (_) {},
    )));
    expect(find.byType(AnTags), findsOneWidget);
  });

  testWidgets('read-only (no onMetaChanged) + no tags → no tags row', (tester) async {
    await tester.pumpWidget(host(const AnDocHeader(crumb: 'Documents', name: 'Doc')));
    // showTags defaults true, but with neither tags nor an edit callback the row is absent (no phantom
    // editor). 默认 showTags 但既无标签又不可编→不渲(无幽灵编辑器)。
    expect(find.byType(AnTags), findsNothing);
  });

  testWidgets('title rename fires onMetaChanged {name: ...}', (tester) async {
    Map<String, dynamic>? got;
    await tester.pumpWidget(host(AnDocHeader(
      crumb: 'Documents',
      name: 'Old',
      onMetaChanged: (m) => got = m,
    )));
    // The title is the first AnInlineEdit — enter its edit mode via its pencil, type, commit. 点标题铅笔改名。
    final titlePencil = find.descendant(of: find.byType(AnInlineEdit).first, matching: find.byType(AnButton));
    await tester.tap(titlePencil.first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'New');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(got, isNotNull);
    expect(got!['name'], 'New');
  });

  testWidgets('nameEditable:false makes the title non-editable', (tester) async {
    await tester.pumpWidget(host(const AnDocHeader(
      crumb: 'Skills',
      name: 'code-review',
      nameEditable: false,
      showTags: false,
    )));
    // A non-editable title still shows its text. 不可改名仍显示文本。
    expect(find.text('code-review'), findsOneWidget);
  });

  // ── B5 空字段引导律(empty-field guides): grey, clickable, wearing the target shape ──
  testWidgets('empty title/description show grey guides; empty tags show the dummy add-tag pill',
      (tester) async {
    await tester.pumpWidget(host(AnDocHeader(
      crumb: 'Documents',
      name: '',
      namePlaceholder: '未命名',
      description: '',
      descriptionPlaceholder: '添加简介…',
      tags: const [],
      addTagLabel: '添加标签',
      onMetaChanged: (_) {},
    )));
    await tester.pump();
    expect(find.text('未命名'), findsOneWidget, reason: '空标题=灰占位');
    expect(find.text('添加简介…'), findsOneWidget, reason: '空简介=灰引导');
    // Empty tags → a grey dummy AnChip wearing the tag shape (穿目标形态). 空标签=灰 dummy 药丸(AnChip)。
    expect(find.widgetWithText(AnChip, '添加标签'), findsOneWidget);
  });

  testWidgets('a non-empty title/description/tags render VALUES, not the guides', (tester) async {
    await tester.pumpWidget(host(AnDocHeader(
      crumb: 'Documents',
      name: 'Real Title',
      namePlaceholder: '未命名',
      description: 'a real summary',
      descriptionPlaceholder: '添加简介…',
      tags: const ['ops'],
      addTagLabel: '添加标签',
      onMetaChanged: (_) {},
    )));
    await tester.pump();
    expect(find.text('Real Title'), findsOneWidget);
    expect(find.text('a real summary'), findsOneWidget);
    expect(find.text('ops'), findsOneWidget);
    expect(find.text('添加简介…'), findsNothing);
    expect(find.widgetWithText(AnChip, '添加标签'), findsNothing);
  });

  testWidgets('tapping the dummy add-tag pill opens the AnTags input field', (tester) async {
    await tester.pumpWidget(host(AnDocHeader(
      crumb: 'Documents',
      name: 'Doc',
      tags: const [],
      addTagLabel: '添加标签',
      onMetaChanged: (_) {},
    )));
    await tester.pump();
    // At rest: the dummy pill, no input. 静息:dummy 药丸,无输入框。
    expect(find.byType(AnTags), findsNothing);
    await tester.tap(find.widgetWithText(AnChip, '添加标签'));
    await tester.pumpAndSettle();
    // Tapped: the dummy pill gives way to the AnTags add field (autofocused). 点开→AnTags 输入框。
    expect(find.byType(AnTags), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);
  });
}
