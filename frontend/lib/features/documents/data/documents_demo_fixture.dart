import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/skill.dart';
import 'document_fixtures.dart';

/// A realistic zero-backend seed for `make demo` — a small document tree (nested pages) + a couple of
/// skills, so the documents ocean has a live-feeling library the moment demo opens. Not used by the live
/// app (which wires the Live repository). `make demo` 的零后端种子:小文档树 + 两个 skill。
FixtureDocumentsRepository demoDocumentsRepository() {
  final t = DateTime.utc(2026, 7, 1, 10);
  DocumentNode doc(String id, String? parent, String name, int pos, String path,
          {String content = '', String description = '', List<String> tags = const []}) =>
      DocumentNode(
        id: id,
        parentId: parent,
        name: name,
        position: pos,
        path: path,
        content: content,
        description: description,
        tags: tags,
        sizeBytes: content.length,
        createdAt: t,
        updatedAt: t,
      );

  return FixtureDocumentsRepository(
    documents: [
      // Ids are LEGAL <prefix>_<16hex> (the wikilink codec + backend parser are strict about the shape — an
      // illegal id renders as dead double-bracket text). id 须合法 16hex(wikilink 正则严格,非法=死文本)。
      // Content is the BODY only — the title is the document NAME (rendered by the center header), so the
      // body never repeats it. Bodies are REAL-LENGTH documents (h2/h3 sections, lists, fenced code,
      // quotes, wikilinks) so the reading rhythm / outline / floating head are all visible in demo.
      // 正文=纯 body、标题=name。正文写成真实长度(节标题/列表/代码/引用/链接),demo 里节奏/大纲/浮层头全可见。
      doc('doc_00000000000a11ce', null, 'Getting Started', 0, '/Getting Started',
          description: 'Orientation for the Anselm knowledge base.',
          tags: const ['guide'],
          content: 'Welcome to the Anselm knowledge base. This page orients you; the deeper ideas live in '
              '[[doc_00000000000c33ef]] and the operational recipes in [[doc_00000000000e55f1]].\n\n'
              '## What Anselm is\n\n'
              'Anselm is a **local-first agentic workflow platform**. Everything runs on your machine: the '
              'backend is a single Go binary riding next to the app, and the state of record is a SQLite '
              'file you can back up with `cp`.\n\n'
              '- Local-first — your data never leaves the machine\n'
              '- Agentic — four entity kinds cooperate on real work\n'
              '- Durable — a crash never loses a running workflow\n\n'
              '## First steps\n\n'
              '1. Read [[doc_00000000000b22df]] to configure a workspace\n'
              '2. Create a function and run it from its detail page\n'
              '3. Wire a workflow and watch the run board\n\n'
              '> Tip: every page in this library is plain markdown — edit anything, links keep working.\n\n'
              '## Where things live\n\n'
              '### Entities\n\n'
              'Functions, handlers, agents and workflows each get a detail page in the Entities ocean, '
              'with versions, logs and a run terminal.\n\n'
              '### Documents\n\n'
              'This library. Pages nest; drag a row in the rail to restructure the tree.\n\n'
              '### Chat\n\n'
              'Conversations drive entities: mention one with `@` and the model can call it directly.'),
      doc('doc_00000000000b22df', 'doc_00000000000a11ce', 'Setup', 0, '/Getting Started/Setup',
          description: 'Install, configure, verify.',
          tags: const ['guide', 'ops'],
          content: 'A fresh machine reaches a working Anselm in three moves.\n\n'
              '## Install\n\n'
              '1. Download the desktop app for your platform\n'
              '2. Open it — the backend sidecar starts automatically\n'
              '3. Pick a data directory when prompted\n\n'
              '## Configure the workspace\n\n'
              'Workspaces isolate everything (entities, documents, runs). The default one is created on '
              'first launch; add more from the workspace menu in the sidebar footer.\n\n'
              '```bash\n'
              '# where the state of record lives\n'
              'ls ~/Library/Application\\ Support/anselm/\n'
              'anselm.db   sandbox/   logs/\n'
              '```\n\n'
              '## Verify\n\n'
              '- The health dot in the sidebar footer is green\n'
              '- `Entities` lists the seed functions\n'
              '- Running `fetch-weather` returns a payload\n\n'
              '> If the sidecar fails to start, check the logs directory above — the last line names the '
              'port it fought over.'),
      doc('doc_00000000000c33ef', 'doc_00000000000a11ce', 'Concepts', 1, '/Getting Started/Concepts',
          description: 'The Quadrinity model and durable execution.',
          tags: const ['architecture'],
          content: 'Two ideas carry the whole system: the **Quadrinity** entity model and **durable '
              'execution**.\n\n'
              '## The Quadrinity\n\n'
              'Every capability belongs to exactly one of four kinds:\n\n'
              '- **Function** — pure code, versioned, sandboxed\n'
              '- **Handler** — a connection to the outside world (Postgres, Slack, Stripe…)\n'
              '- **Agent** — an LLM with tools and a system prompt\n'
              '- **Workflow** — a graph that composes the other three\n\n'
              '### Why four\n\n'
              'Each kind has a distinct lifecycle and a distinct failure mode. Splitting them keeps every '
              'page, every log and every permission scoped to one shape of thing.\n\n'
              '## Durable execution\n\n'
              'A workflow run memoizes every node result as a row:\n\n'
              '```sql\n'
              'CREATE UNIQUE INDEX idx_frn_once\n'
              '  ON flowrun_nodes (flowrun_id, node_id, iteration);\n'
              '```\n\n'
              'On crash the interpreter simply re-walks the graph: finished nodes return their recorded '
              'rows, unfinished ones run again. No event journal, no replay drift.\n\n'
              '> The row table IS the truth. Streams only exist so the UI feels alive.\n\n'
              'See [[doc_00000000000a11ce]] for orientation and [[doc_00000000000e55f1]] for how releases '
              'ship.'),
      doc('doc_00000000000d44f0', null, 'Playbooks', 1, '/Playbooks',
          description: 'Operational recipes.',
          content: 'Recipes for running Anselm in anger. Start with [[doc_00000000000e55f1]].\n\n'
              '- [ ] Backup & restore\n'
              '- [ ] Upgrade path\n'
              '- [x] Deploy'),
      doc('doc_00000000000e55f1', 'doc_00000000000d44f0', 'Deploy', 0, '/Playbooks/Deploy',
          description: 'Cutting and verifying a release.',
          tags: const ['ops', 'release'],
          content: 'A release is a tag, a build, and a smoke run — in that order.\n\n'
              '## Cut\n\n'
              '```bash\n'
              'git tag v0.4.0\n'
              'make release   # cross-compiles the sidecar for all three platforms\n'
              '```\n\n'
              '## Verify\n\n'
              '1. Install the artifact on a clean machine\n'
              '2. Run the smoke workflow end to end\n'
              '3. Kill the backend mid-run — the run must resume, not restart\n\n'
              '---\n\n'
              'The resume check is the whole point: durability (see [[doc_00000000000c33ef]]) is a release '
              'gate, not a feature flag.'),
    ],
    skills: [
      Skill(
        name: 'commit-helper',
        description: 'Writes conventional commits from a diff.',
        source: 'user',
        context: 'fork',
        body: 'Inspect the staged diff and propose a conventional-commit message (type, scope, subject) '
            'plus a short body.\n\n'
            '## Message shape\n\n'
            '- type: feat / fix / refactor / docs / test\n'
            '- scope: the touched package or feature\n'
            '- subject: imperative, no trailing period\n\n'
            '## Scope rules\n\n'
            'Prefer the DEEPEST directory that contains every change. A diff touching one package names '
            'the package; a cross-cutting diff names the layer.\n\n'
            '```text\n'
            'feat(frontend): documents ocean gets a live outline\n'
            '```\n\n'
            '> Never invent a scope that is not a real directory.',
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
        body: 'Classify the issue (bug / feature / question), assess severity, and suggest the next '
            'action.\n\n'
            '## Severity ladder\n\n'
            '1. **Critical** — data loss, crash on launch, security\n'
            '2. **High** — a main flow is broken with no workaround\n'
            '3. **Normal** — broken but avoidable\n'
            '4. **Low** — cosmetic, docs, polish\n\n'
            '## Output\n\n'
            'One line per field: `kind · severity · owner-suggestion · next-step`.',
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
