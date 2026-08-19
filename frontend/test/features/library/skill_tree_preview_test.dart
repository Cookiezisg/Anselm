import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/library/ui/library_inspector.dart';
import 'package:anselm/features/library/ui/skill_file_preview.dart';
import 'package:anselm/features/library/state/library_state.dart';
import 'package:anselm/core/contract/entities/skill.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

// WRK-076 F3:skill 文件树投影 + 预览分派的纯函数电池(脱 UI)。

void main() {
  group('buildSkillTreeRows', () {
    test('manifest pins first; dirs inserted once; depth = segment depth', () {
      final rows = buildSkillTreeRows(const [
        SkillFile(path: 'references/deep/notes.md', size: 1),
        SkillFile(path: 'SKILL.md', size: 1),
        SkillFile(path: 'references/forms.md', size: 1),
        SkillFile(path: 'scripts/fill.py', size: 1),
      ]);
      final labels = rows.map((r) => '${r.depth}:${r.label}').toList();
      expect(labels, [
        '0:SKILL.md',
        '0:references/',
        '1:deep/',
        '2:notes.md',
        '1:forms.md',
        '0:scripts/',
        '1:fill.py',
      ]);
      expect(rows.where((r) => r.isDir).length, 3);
      // 文件行 path 保全路径(导航用),目录行不可导航。
      expect(
        rows.firstWhere((r) => r.label == 'notes.md').path,
        'references/deep/notes.md',
      );
    });

    test('flat single file yields one row, no dirs', () {
      final rows = buildSkillTreeRows(const [
        SkillFile(path: 'SKILL.md', size: 1),
      ]);
      expect(rows.length, 1);
      expect(rows.single.isDir, isFalse);
    });
  });

  group('skillFileKindOf', () {
    test('dispatches every preview family member', () {
      expect(skillFileKindOf('a/b.md'), SkillFileKind.markdown);
      expect(skillFileKindOf('x.PY'.toLowerCase()), SkillFileKind.code);
      expect(skillFileKindOf('s/run.py'), SkillFileKind.code);
      expect(skillFileKindOf('i.png'), SkillFileKind.image);
      expect(skillFileKindOf('i.webp'), SkillFileKind.image);
      expect(skillFileKindOf('v.svg'), SkillFileKind.svg);
      expect(skillFileKindOf('d.csv'), SkillFileKind.csv);
      expect(skillFileKindOf('f.ttf'), SkillFileKind.font);
      expect(skillFileKindOf('f.otf'), SkillFileKind.font);
      expect(skillFileKindOf('doc.pdf'), SkillFileKind.other);
      expect(skillFileKindOf('noext'), SkillFileKind.other);
    });
  });

  testWidgets(
    'image and SVG previews stay laid out inside the page scroll view',
    (tester) async {
      const pixel = <int>[
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ];
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="40">'
          '<rect width="80" height="40" fill="#17324d"/></svg>';

      Future<void> pumpPreview(String path, List<int> bytes) async {
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(path),
            overrides: [
              skillFileBytesProvider((
                name: 'skill_a',
                path: path,
              )).overrideWith((ref) async => bytes),
            ],
            child: TranslationProvider(
              child: MaterialApp(
                theme: AnTheme.light(),
                home: Scaffold(
                  body: SkillFilePreview(
                    name: 'skill_a',
                    path: path,
                    skillDir: '/tmp/skill_a',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await pumpPreview('assets/mark.png', pixel);
      expect(find.byType(Image), findsOneWidget);
      await pumpPreview('assets/mark.svg', svg.codeUnits);
      expect(find.byType(SvgPicture), findsOneWidget);
    },
  );

  test(
    'skill file location stays on the skill route and preserves nested path',
    () {
      final uri = Uri.parse(
        skillFileLocation('ep108-installed', 'references/guide.md'),
      );
      expect(uri.path, '/library/skill/ep108-installed');
      expect(uri.queryParameters['file'], 'references/guide.md');
    },
  );
}
