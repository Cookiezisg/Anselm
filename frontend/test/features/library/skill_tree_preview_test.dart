import 'package:anselm/features/library/ui/library_inspector.dart';
import 'package:anselm/features/library/ui/skill_file_preview.dart';
import 'package:anselm/core/contract/entities/skill.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
