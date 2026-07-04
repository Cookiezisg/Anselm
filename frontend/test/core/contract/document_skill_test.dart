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

    test('tree-meta node (GET /tree, no content) → content defaults empty; root has null parentId', () {
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
    });
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
      expect(s.frontmatter.allowedTools, ['Read', 'Bash(git:*)', 'fn_normalize']);
      expect(s.frontmatter.agent, 'coder');
      expect(s.frontmatter.userInvocable, isTrue);
      expect(s.toJson()['frontmatter']['allowedTools'], contains('fn_normalize'));
    });

    test('list item (no body, minimal frontmatter) → body + omitempty fields default', () {
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
    });

    test('guardrail constants + name regex mirror the backend', () {
      expect(kSkillMaxBodyBytes, 32 * 1024);
      expect(kSkillMaxDescriptionChars, 1024);
      expect(kSkillNameRegex.hasMatch('commit-helper'), isTrue);
      expect(kSkillNameRegex.hasMatch('Commit_Helper'), isFalse); // uppercase rejected
      expect(kSkillNameRegex.hasMatch('9lead'), isFalse); // must start with a-z
      expect(kDocumentMaxContentBytes, 1 << 20);
    });
  });
}
