import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/skill.dart';
import 'document_fixtures.dart';

/// A realistic zero-backend seed for `make demo` — a small document tree (nested pages) + a couple of
/// skills, so the documents ocean has a live-feeling library the moment demo opens. Not used by the live
/// app (which wires the Live repository). `make demo` 的零后端种子:小文档树 + 两个 skill。
FixtureDocumentsRepository demoDocumentsRepository() {
  final t = DateTime.utc(2026, 7, 1, 10);
  DocumentNode doc(String id, String? parent, String name, int pos, String path, {String content = ''}) =>
      DocumentNode(
        id: id,
        parentId: parent,
        name: name,
        position: pos,
        path: path,
        content: content,
        sizeBytes: content.length,
        createdAt: t,
        updatedAt: t,
      );

  return FixtureDocumentsRepository(
    documents: [
      // Content is the BODY only — the title is the document NAME (rendered by the center header), so the
      // body never repeats it (the real editor separates title field + body). 正文=纯 body,标题=name,不重复。
      doc('doc_start00000000', null, 'Getting Started', 0, '/Getting Started',
          content: 'Welcome to the Anselm knowledge base. See [[doc_concepts00000]] for the core ideas.\n\n'
              '- Local-first\n- Agentic\n- Durable execution'),
      doc('doc_setup000000000', 'doc_start00000000', 'Setup', 0, '/Getting Started/Setup',
          content: '1. Install the app\n2. Configure your workspace\n3. Start building'),
      doc('doc_concepts00000', 'doc_start00000000', 'Concepts', 1, '/Getting Started/Concepts',
          content: '**Quadrinity** entities (Function / Handler / Agent / Workflow) plus durable execution.'),
      doc('doc_playbooks0000', null, 'Playbooks', 1, '/Playbooks'),
      doc('doc_deploy0000000', 'doc_playbooks0000', 'Deploy', 0, '/Playbooks/Deploy',
          content: 'Run `make release` and confirm the smoke tests pass.'),
    ],
    skills: [
      Skill(
        name: 'commit-helper',
        description: 'Writes conventional commits from a diff.',
        source: 'user',
        context: 'fork',
        body: '# Commit helper\n\nInspect the staged diff and propose a conventional-commit message '
            '(type, scope, subject) plus a short body.',
        frontmatter: const Frontmatter(
          name: 'commit-helper',
          description: 'Writes conventional commits from a diff.',
          allowedTools: ['Read', 'Bash(git:*)'],
          context: 'fork',
          agent: 'coder',
          source: 'user',
        ),
        updatedAt: t,
      ),
      Skill(
        name: 'triage',
        description: 'Triages an inbound issue and suggests next steps.',
        source: 'user',
        context: 'inline',
        body: '# Triage\n\nClassify the issue (bug / feature / question), assess severity, and suggest '
            'the next action.',
        frontmatter: const Frontmatter(
          name: 'triage',
          description: 'Triages an inbound issue and suggests next steps.',
          context: 'inline',
          source: 'user',
        ),
        updatedAt: t,
      ),
    ],
  );
}
