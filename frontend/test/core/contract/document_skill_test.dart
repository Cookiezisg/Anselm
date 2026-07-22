import 'package:anselm/core/contract/entities/document.dart';
import 'package:anselm/core/contract/entities/skill.dart';
import 'package:flutter_test/flutter_test.dart';

// Contract fidelity: the document + skill DTOs must round-trip the backend wire shapes exactly
// (document.go:21 / skill.go:26+42). File-like knowledge — user-editable content/body, not versioned.

void main() {
  group('DocumentNode', () {
    test('full node (GET /{id}) round-trips every field', () {
      final json = {
        'id': 'doc_9f2c41aa77b0e310',
        'parentId': 'doc_parent00000000',
        'name': 'design-notes',
        'description': 'The documents ocean design.',
        'content': '# Notes\n\nSee [[doc_other0000000000]] for context.',
        'tags': ['design', 'wip'],
        'position': 2,
        'path': '/root/design-notes',
        'sizeBytes': 4096,
        'createdAt': '2026-06-01T00:00:00.000Z',
        'updatedAt': '2026-07-04T09:00:00.000Z',
      };
      final d = DocumentNode.fromJson(json);
      expect(d.parentId, 'doc_parent00000000');
      expect(d.content, contains('[[doc_other0000000000]]'));
      expect(d.tags, ['design', 'wip']);
      expect(d.sizeBytes, 4096);
      expect(d.toJson()['path'], '/root/design-notes');
    });

    test(
      'tree-meta node (GET /tree, no content) → content defaults empty; root has null parentId',
      () {
        final json = {
          'id': 'doc_root0000000000',
          'name': 'root',
          'tags': <String>[],
          'position': 0,
          'path': '/root',
          'sizeBytes': 0,
          'createdAt': '2026-06-01T00:00:00.000Z',
          'updatedAt': '2026-06-01T00:00:00.000Z',
        };
        final d = DocumentNode.fromJson(json);
        expect(d.parentId, isNull); // root-level
        expect(d.content, ''); // omitted by /tree
      },
    );
  });

  group('Skill + Frontmatter', () {
    test('single-Get round-trips body + full frontmatter', () {
      final json = {
        'name': 'commit-helper',
        'description': 'Writes conventional commits.',
        'source': 'user',
        'context': 'fork',
        'body': '# Commit helper\n\nInspect the diff and…',
        'frontmatter': {
          'name': 'commit-helper',
          'description': 'Writes conventional commits.',
          'allowedTools': ['Read', 'Bash(git:*)', 'fn_normalize'],
          'context': 'fork',
          'agent': 'coder',
          'arguments': ['scope'],
          'disableModelInvocation': false,
          'userInvocable': true,
          'whenToUse': 'when committing',
          'model': 'claude-sonnet-5',
          'effort': 'medium',
          'source': 'user',
        },
        'updatedAt': '2026-07-04T09:00:00.000Z',
      };
      final s = Skill.fromJson(json);
      expect(s.name, 'commit-helper');
      expect(s.context, 'fork');
      expect(s.frontmatter.allowedTools, [
        'Read',
        'Bash(git:*)',
        'fn_normalize',
      ]);
      expect(s.frontmatter.agent, 'coder');
      expect(s.frontmatter.userInvocable, isTrue);
      expect(
        s.toJson()['frontmatter']['allowedTools'],
        contains('fn_normalize'),
      );
    });

    test(
      'list item (no body, minimal frontmatter) → body + omitempty fields default',
      () {
        final json = {
          'name': 'lean-skill',
          'description': 'x',
          'source': 'ai',
          'context': 'inline',
          'frontmatter': {'name': 'lean-skill', 'description': 'x'},
          'updatedAt': '2026-07-04T09:00:00.000Z',
        };
        final s = Skill.fromJson(json);
        expect(s.body, ''); // omitted by list
        expect(s.frontmatter.allowedTools, isEmpty);
        expect(s.frontmatter.disableModelInvocation, isFalse);
      },
    );

    test('installed skill round-trips provenance + spec-core frontmatter', () {
      final json = {
        'name': 'pdf',
        'description': 'd',
        'source': 'installed',
        'context': 'inline',
        'frontmatter': {
          'name': 'pdf',
          'description': 'd',
          'license': 'MIT',
          'compatibility': 'needs network',
          'metadata': {'author': 'upstream', 'version': '1.0'},
          'allowedTools': ['run_function'],
        },
        'provenance': {
          'source': 'owner/repo@main#skills/pdf',
          'repo': 'owner/repo',
          'installedAt': '2026-07-22T00:00:00.000Z',
          'toolsApproved': false,
        },
        'updatedAt': '2026-07-22T09:00:00.000Z',
      };
      final s = Skill.fromJson(json);
      expect(s.source, kSkillSourceInstalled);
      expect(s.frontmatter.license, 'MIT');
      expect(s.frontmatter.metadata['author'], 'upstream');
      expect(s.provenance?.toolsApproved, isFalse);
      expect(s.provenance?.repo, 'owner/repo');
      // 本地件无 provenance → null,解码不炸。
      final local = Skill.fromJson({
        'name': 'mine',
        'description': 'd',
        'source': 'user',
        'context': 'inline',
        'frontmatter': {'name': 'mine', 'description': 'd'},
        'updatedAt': '2026-07-22T09:00:00.000Z',
      });
      expect(local.provenance, isNull);
      expect(local.frontmatter.license, '');
    });

    test('SkillFile + install preview/result wire shapes decode', () {
      final f = SkillFile.fromJson({
        'path': 'references/deep/a.md',
        'size': 42,
        'updatedAt': '2026-07-22T09:00:00.000Z',
      });
      expect(f.path, 'references/deep/a.md');
      expect(f.size, 42);
      final p = SkillInstallPreview.fromJson({
        'name': 'pdf',
        'description': 'd',
        'allowedTools': ['bash'],
        'fileCount': 3,
        'totalBytes': 2048,
        'installable': true,
        'alreadyExists': false,
      });
      expect(p.installable, isTrue);
      expect(p.allowedTools, ['bash']);
      final r = SkillInstallResult.fromJson({
        'installed': ['pdf'],
        'skipped': {'broken': 'no manifest'},
      });
      expect(r.installed, ['pdf']);
      expect(r.skipped['broken'], 'no manifest');
    });

    test('guardrail constants + dual name regexes mirror the backend', () {
      expect(kSkillMaxBodyBytes, 32 * 1024);
      expect(kSkillMaxFileBytes, 1024 * 1024);
      expect(kSkillMaxDescriptionChars, 1024);
      // 守卫形态（WRK-076 D3，盘上可存在）：从宽——数字开头与存量下划线都收，大写拒。
      expect(kSkillNameRegex.hasMatch('commit-helper'), isTrue);
      expect(
        kSkillNameRegex.hasMatch('3d-print'),
        isTrue,
      ); // digit start accepted
      expect(
        kSkillNameRegex.hasMatch('legacy_name'),
        isTrue,
      ); // legacy underscore readable
      expect(
        kSkillNameRegex.hasMatch('Commit_Helper'),
        isFalse,
      ); // uppercase rejected
      // 规范形态（新建从严）：无下划线、无首尾/连续连字符，数字开头合法。
      expect(kSkillSpecNameRegex.hasMatch('commit-helper'), isTrue);
      expect(kSkillSpecNameRegex.hasMatch('3d-print'), isTrue);
      expect(kSkillSpecNameRegex.hasMatch('has_underscore'), isFalse);
      expect(kSkillSpecNameRegex.hasMatch('-lead'), isFalse);
      expect(kSkillSpecNameRegex.hasMatch('trail-'), isFalse);
      expect(kSkillSpecNameRegex.hasMatch('double--hyphen'), isFalse);
      expect(kDocumentMaxContentBytes, 1 << 20);
    });
  });
}
