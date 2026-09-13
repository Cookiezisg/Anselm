/// The story dataset's entity seed — every Function / Handler / Agent / Workflow, their version trails,
/// execution logs, flowruns (with Gantt-worthy node stamps), controls / approvals / triggers, MCP mounts
/// and the relation graph, ALL keyed by the story bible so the entity rail tells the same story as chat,
/// scheduler, notifications and documents. Identifiers stay English; prose goes through [StoryLocale.t].
///
/// story 数据集的实体种子——四大实体、版本轨迹、执行日志、运行（节点时刻拉开以便甘特有宽度）、控制/审批/
/// 触发器、MCP 挂载与关系图，全部取自故事总纲，实体 rail 与聊天、调度、通知、文档讲同一个故事。
/// 标识符保持英文，文案经 [StoryLocale.t] 出中英两套。
library;

import '../../core/contract/entities/agent.dart';
import '../../core/contract/entities/approval.dart';
import '../../core/contract/entities/control.dart';
import '../../core/contract/entities/function.dart';
import '../../core/contract/entities/handler.dart';
import '../../core/contract/entities/relation.dart';
import '../../core/contract/entities/trigger.dart';
import '../../core/contract/entities/values.dart';
import '../../core/contract/entities/workflow.dart';
import '../../core/contract/workspace.dart';
import '../../features/entities/data/entity_fixtures.dart';
import 'story_bible.dart';
import 'story_locale.dart';

// ───────────────────────── Python sources (English, real-looking) ─────────────────────────

const _fetchGithubV1 = r'''
import os
import httpx
from datetime import datetime, timedelta, timezone

API = "https://api.github.com/repos/Cookiezisg/Anselm"
PATHS = {"commits": "/commits", "pulls": "/pulls", "issues": "/issues"}

def main(kind, days):
    # `days` arrives as a string from the trigger payload — coerce before arithmetic.
    since = datetime.now(timezone.utc) - timedelta(days=int(days))
    headers = {"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}"}
    params = {"since": since.isoformat(), "state": "all", "per_page": 100}
    r = httpx.get(f"{API}{PATHS[kind]}", params=params, headers=headers, timeout=30)
    r.raise_for_status()
    items = r.json()
    return {"kind": kind, "since": since.date().isoformat(), "count": len(items), "items": items}
''';

const _fetchGithubV2 = r'''
import os
import time
import httpx
from datetime import datetime, timedelta, timezone

API = "https://api.github.com/repos/Cookiezisg/Anselm"
PATHS = {"commits": "/commits", "pulls": "/pulls", "issues": "/issues"}

def _get(client, path, params, attempts=4):
    # GitHub answers 5xx / 403-rate-limit for seconds at a time; back off instead of failing the run.
    for attempt in range(attempts):
        r = client.get(path, params=params)
        if r.status_code < 500 and r.status_code != 403:
            r.raise_for_status()
            return r.json()
        time.sleep(float(r.headers.get("Retry-After", 2 ** attempt)))
    r.raise_for_status()

def _slim(kind, item):
    if kind == "commits":
        return {"sha": item["sha"][:7], "message": item["commit"]["message"].splitlines()[0],
                "author": item["commit"]["author"]["name"]}
    return {"number": item["number"], "title": item["title"], "state": item.get("state")}

def main(kind, days):
    since = datetime.now(timezone.utc) - timedelta(days=int(days))
    headers = {"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}"}
    params = {"since": since.isoformat(), "state": "all", "per_page": 100}
    with httpx.Client(base_url=API, headers=headers, timeout=30) as client:
        items = [_slim(kind, i) for i in _get(client, PATHS[kind], params)]
    return {"kind": kind, "since": since.date().isoformat(), "count": len(items), "items": items}
''';

const _prepareDocV1 = r'''
import re
from datetime import date

def main(markdown, period, folder_id):
    title = re.search(r"^#\s+(.+)$", markdown, re.M)
    slug = re.sub(r"[^a-z0-9]+", "-", period.lower()).strip("-")
    return {
        "title": title.group(1) if title else f"Weekly Digest · {period}",
        "parentId": folder_id,
        "slug": f"digest-{slug}",
        "body": markdown,
        "properties": {"period": period, "generatedOn": date.today().isoformat()},
    }
''';

const _parseInvoiceV3 = r'''
import re
import pdfplumber

AMOUNT = re.compile(r"(?:Total|Amount due)\s*[:：]?\s*\$?([\d,]+\.\d{2})", re.I)
INVOICE = re.compile(r"Invoice\s*(?:#|No\.?)\s*([A-Z0-9-]+)", re.I)

def main(path):
    with pdfplumber.open(path) as pdf:
        text = "\n".join(page.extract_text() or "" for page in pdf.pages)
        tables = [t for page in pdf.pages for t in page.extract_tables()]
    amount = AMOUNT.search(text)
    number = INVOICE.search(text)
    return {
        "invoiceNumber": number.group(1) if number else None,
        "total": float(amount.group(1).replace(",", "")) if amount else None,
        "lineItems": [row for table in tables for row in table[1:] if any(row)],
        "pages": len(pdf.pages),
    }
''';

const _resizeImageV1 = r'''
from io import BytesIO
from PIL import Image

def main(image, max_width, quality=82):
    src = Image.open(image.path)
    ratio = min(1.0, max_width / src.width)
    out = src.resize((round(src.width * ratio), round(src.height * ratio)), Image.LANCZOS)
    buf = BytesIO()
    out.convert("RGB").save(buf, format="WEBP", quality=quality)
    return {
        "image": anselm.media.store(buf.getvalue(), mime="image/webp",
                                    filename=image.filename.rsplit(".", 1)[0] + ".webp"),
        "width": out.width,
        "height": out.height,
        "bytes": buf.tell(),
    }
''';

const _fetchGithubTraceback = '''
Traceback (most recent call last):
  File "/sandbox/fn_e70af68c82e57057/main.py", line 15, in main
    r.raise_for_status()
httpx.HTTPStatusError: Server error '502 Bad Gateway' for url 'https://api.github.com/repos/Cookiezisg/Anselm/commits?since=2026-08-24T01%3A00%3A00%2B00%3A00&state=all&per_page=100'
''';

const _parseInvoiceTraceback = '''
Traceback (most recent call last):
  File "/sandbox/fn_7b1e9c2a4d5f8e30/main.py", line 2, in <module>
    import pdfplumber
ModuleNotFoundError: No module named 'pdfplumber'
''';

const _parseInvoiceEnvError = '''
pip install pdfplumber==0.11.4
ERROR: Could not build wheels for cryptography, which is required to install pyproject.toml-based projects
  note: Rust toolchain not found in the sandbox image (set ANSELM_SANDBOX_RUST=1 or pin cryptography<42).
''';

// ───────────────────────── Workflow graphs ─────────────────────────

// Digest v2 — THE canonical graph from the story bible (see `digestNodeIds`): three parallel fetches
// join at the writer, `check_activity` routes empty weeks straight to a Slack notice, and the `yes`
// port of `review` is the only way into prepare_doc → notify_team. Every node carries a `pos` because
// `layoutGraph` uses authored coordinates verbatim only when ALL nodes have one (any gap → auto-layout
// in the caller's `dir`, which defaults to left→right); the coordinates below are a top→bottom grid on
// the layout's own slot maths (nodeW 188 + gapX 84 per column, nodeH 60 + gapY 44 per row).
// 周报 v2:总纲里的规范图——三路并行抓取在写手汇合,`check_activity` 把空周直接送去 Slack 通知,
// `review` 的 yes 端口是进入 prepare_doc → notify_team 的唯一入口。每个节点都带 `pos`,因为
// `layoutGraph` 只在全部节点有坐标时逐字使用(缺一个就整图按调用方 `dir` 自动布局,默认横向);
// 下方坐标是按布局自身槽距(列 188+84、行 60+44)排出的纵向网格。
const _digestGraphV2 =
    '{"nodes":['
    '{"id":"start","kind":"trigger","ref":"$trgMonday","pos":{"x":272,"y":0}},'
    '{"id":"fetch_commits","kind":"action","ref":"$fnFetchGithub","input":{"kind":"\\"commits\\"","days":"trigger.days"},"pos":{"x":0,"y":104}},'
    '{"id":"fetch_pulls","kind":"action","ref":"$fnFetchGithub","input":{"kind":"\\"pulls\\"","days":"trigger.days"},"pos":{"x":272,"y":104}},'
    '{"id":"fetch_issues","kind":"action","ref":"$fnFetchGithub","input":{"kind":"\\"issues\\"","days":"trigger.days"},"pos":{"x":544,"y":104}},'
    '{"id":"write_digest","kind":"agent","ref":"$agDigest","input":{"activity":"{\'commits\': nodes.fetch_commits.items, \'pulls\': nodes.fetch_pulls.items, \'issues\': nodes.fetch_issues.items}","period":"trigger.period"},"pos":{"x":272,"y":208}},'
    '{"id":"check_activity","kind":"control","ref":"$ctlEmptyWeek","input":{"commits":"nodes.fetch_commits.count","pulls":"nodes.fetch_pulls.count","issues":"nodes.fetch_issues.count"},"pos":{"x":272,"y":312}},'
    '{"id":"review","kind":"approval","ref":"$apfDigest","input":{"summary":"nodes.write_digest.summary","commits":"nodes.fetch_commits.count","period":"trigger.period"},"pos":{"x":272,"y":416}},'
    '{"id":"prepare_doc","kind":"action","ref":"$fnPrepareDoc","input":{"markdown":"nodes.write_digest.digest","period":"trigger.period","folder_id":"\\"$docDigestsFolder\\""},"pos":{"x":272,"y":520}},'
    '{"id":"notify_team","kind":"action","ref":"$hdSlack.post_digest","input":{"channel":"\\"#product-team\\"","markdown":"nodes.write_digest.digest"},"pos":{"x":272,"y":624}},'
    '{"id":"skip_notice","kind":"action","ref":"$hdSlack.post_message","input":{"channel":"\\"#product-team\\"","text":"\\"No GitHub activity in the window — weekly digest skipped.\\""},"pos":{"x":544,"y":416}}'
    '],"edges":['
    '{"id":"e1","from":"start","to":"fetch_commits"},'
    '{"id":"e2","from":"start","to":"fetch_pulls"},'
    '{"id":"e3","from":"start","to":"fetch_issues"},'
    '{"id":"e4","from":"fetch_commits","to":"write_digest"},'
    '{"id":"e5","from":"fetch_pulls","to":"write_digest"},'
    '{"id":"e6","from":"fetch_issues","to":"write_digest"},'
    '{"id":"e7","from":"write_digest","to":"check_activity"},'
    '{"id":"e8","from":"check_activity","fromPort":"has_activity","to":"review"},'
    '{"id":"e9","from":"check_activity","fromPort":"empty","to":"skip_notice"},'
    '{"id":"e10","from":"review","fromPort":"yes","to":"prepare_doc"},'
    '{"id":"e11","from":"prepare_doc","to":"notify_team"}'
    ']}';

// Digest v1 — the commits-only straight line (fetch → write → file → post), no review, no fan-out; kept
// simpler on purpose so the version diff against v2 has something to say. Same vertical grid.
// 周报 v1:只抓提交的直线(抓取 → 写作 → 落文档 → 发帖),无审阅无扇出;刻意简单,让版本 diff 有话可说。
const _digestGraphV1 =
    '{"nodes":['
    '{"id":"start","kind":"trigger","ref":"$trgMonday","pos":{"x":0,"y":0}},'
    '{"id":"fetch_activity","kind":"action","ref":"$fnFetchGithub","input":{"kind":"\\"commits\\"","days":"trigger.days"},"pos":{"x":0,"y":104}},'
    '{"id":"write_digest","kind":"agent","ref":"$agDigest","input":{"activity":"nodes.fetch_activity","period":"trigger.period"},"pos":{"x":0,"y":208}},'
    '{"id":"prepare_doc","kind":"action","ref":"$fnPrepareDoc","input":{"markdown":"nodes.write_digest.digest","period":"trigger.period","folder_id":"\\"$docDigestsFolder\\""},"pos":{"x":0,"y":312}},'
    '{"id":"notify_team","kind":"action","ref":"$hdSlack.post_message","input":{"channel":"\\"#product-team\\"","text":"nodes.write_digest.digest"},"pos":{"x":0,"y":416}}'
    '],"edges":['
    '{"id":"e1","from":"start","to":"fetch_activity"},'
    '{"id":"e2","from":"fetch_activity","to":"write_digest"},'
    '{"id":"e3","from":"write_digest","to":"prepare_doc"},'
    '{"id":"e4","from":"prepare_doc","to":"notify_team"}'
    ']}';

// Triage — a three-port control fans out: urgent pages on-call, refund parks on a human gate, normal
// just files the row. 工单分流:三端口控制节点扇出。
const _triageGraph =
    '{"nodes":['
    '{"id":"on_ticket","kind":"trigger","ref":"$trgZendesk","pos":{"x":40,"y":200}},'
    '{"id":"triage","kind":"agent","ref":"$agTriage","input":{"ticket":"input.body"},"pos":{"x":260,"y":200}},'
    '{"id":"route_by_severity","kind":"control","ref":"$ctlSeverity","input":{"severity":"nodes.triage.severity","refundAmount":"nodes.triage.refundAmount"},"pos":{"x":480,"y":200}},'
    '{"id":"notify_oncall","kind":"action","ref":"$hdSlack.post_message","input":{"channel":"\\"#support-urgent\\"","text":"nodes.triage.summary"},"pos":{"x":720,"y":80}},'
    '{"id":"confirm_refund","kind":"approval","ref":"$apfRefund","input":{"ticketId":"input.body.id","amount":"nodes.triage.refundAmount","customer":"input.body.requester.email","summary":"nodes.triage.summary"},"pos":{"x":720,"y":200}},'
    '{"id":"file_ticket","kind":"action","ref":"$hdPostgres.query","input":{"sql":"\\"insert into tickets(id, severity, summary) values (\$1, \$2, \$3)\\"","args":"[input.body.id, nodes.triage.severity, nodes.triage.summary]"},"pos":{"x":720,"y":320}}'
    '],"edges":['
    '{"id":"e1","from":"on_ticket","to":"triage"},'
    '{"id":"e2","from":"triage","to":"route_by_severity"},'
    '{"id":"e3","from":"route_by_severity","fromPort":"urgent","to":"notify_oncall"},'
    '{"id":"e4","from":"route_by_severity","fromPort":"refund","to":"confirm_refund"},'
    '{"id":"e5","from":"route_by_severity","fromPort":"normal","to":"file_ticket"},'
    '{"id":"e6","from":"confirm_refund","fromPort":"yes","to":"file_ticket"}'
    ']}';

const _invoiceGraph =
    '{"nodes":['
    '{"id":"on_invoice","kind":"trigger","ref":"$trgInvoices","pos":{"x":40,"y":160}},'
    '{"id":"parse_invoice","kind":"action","ref":"$fnParseInvoice","input":{"path":"input.path"},"pos":{"x":260,"y":160}},'
    '{"id":"store_invoice","kind":"action","ref":"$hdPostgres.query","input":{"sql":"\\"insert into invoices(number, total, source) values (\$1, \$2, \$3)\\"","args":"[nodes.parse_invoice.invoiceNumber, nodes.parse_invoice.total, input.path]"},"pos":{"x":480,"y":160}},'
    '{"id":"notify_finance","kind":"action","ref":"$hdSlack.post_message","input":{"channel":"\\"#finance\\"","text":"\\"Invoice \\" + nodes.parse_invoice.invoiceNumber + \\" filed\\""},"pos":{"x":700,"y":160}}'
    '],"edges":['
    '{"id":"e1","from":"on_invoice","to":"parse_invoice"},'
    '{"id":"e2","from":"parse_invoice","to":"store_invoice"},'
    '{"id":"e3","from":"store_invoice","to":"notify_finance"}'
    ']}';

// Release — manual pipeline, so no trigger node: the first node is an action fed by `input.*`.
// 发布线:手动触发故无 trigger 节点。
const _releaseGraph =
    '{"nodes":['
    '{"id":"collect_changes","kind":"action","ref":"$fnFetchGithub","input":{"days":"input.days"},"pos":{"x":40,"y":160}},'
    '{"id":"write_notes","kind":"agent","ref":"$agReleaseNotes","input":{"activity":"nodes.collect_changes","version":"input.version"},"pos":{"x":260,"y":160}},'
    '{"id":"prepare_doc","kind":"action","ref":"$fnPrepareDoc","input":{"markdown":"nodes.write_notes.notes","period":"input.version","folder_id":"\\"$docReleaseProcess\\""},"pos":{"x":480,"y":160}},'
    '{"id":"announce","kind":"action","ref":"$hdSlack.post_message","input":{"channel":"\\"#releases\\"","text":"nodes.write_notes.headline"},"pos":{"x":700,"y":160}}'
    '],"edges":['
    '{"id":"e1","from":"collect_changes","to":"write_notes"},'
    '{"id":"e2","from":"write_notes","to":"prepare_doc"},'
    '{"id":"e3","from":"prepare_doc","to":"announce"}'
    ']}';

/// Build the story entity repository for one locale. 构建某语言的 story 实体仓。
FixtureEntityRepository storyEntityRepository(StoryLocale l) {
  // ── shared stamps 共用时刻 ──
  final digestV2At = ago(days: 14, hours: 2);
  final lastWeekMonday = ago(days: 6, hours: 9);
  final twoWeeksMonday = ago(days: 13, hours: 9);

  // The three digest runs, on the same clock the scheduler story uses so the workflow's "Recent" list
  // and the scheduler matrix agree: parked = kicked from chat 12 minutes ago (the writer took 1m20s,
  // the reviewer has sat on it ~10 minutes); rejected = a manual run yesterday; failed = last Monday's
  // cron tick, replayed once (~5 days ago) and fixed by fetch v2 right after.
  // 三次周报 run,与调度故事同一时钟,工作流「最近」列表与调度矩阵才一致:parked 12 分钟前从聊天发起
  // (写手 1 分 20 秒,审阅人已搁置约 10 分钟);rejected 昨天手动跑;failed 上周一 cron,约 5 天前重放
  // 一次,随后由 fetch v2 修好。
  final parkedStart = ago(minutes: 12);
  final rejectedStart = ago(days: 1, hours: 3);
  final failedStart = lastWeekMonday;
  final failedReplayedAt = ago(days: 5, hours: 2);
  final fetchV2At = ago(days: 5, hours: 1);

  // ───────────────────────── Functions ─────────────────────────

  FunctionVersion fetchGithubVer(int v) => FunctionVersion(
    id: '${fnFetchGithub}_v$v',
    functionId: fnFetchGithub,
    version: v,
    code: v == 1 ? _fetchGithubV1 : _fetchGithubV2,
    inputs: [
      Field(
        name: 'kind',
        type: 'string',
        description: l.t(
          'Which collection to pull: commits | pulls | issues.',
          '拉哪一类：commits | pulls | issues。',
        ),
      ),
      Field(
        name: 'days',
        type: 'number',
        description: l.t('How many days back to look.', '回看多少天。'),
      ),
    ],
    outputs: [
      Field(name: 'kind', type: 'string'),
      Field(
        name: 'since',
        type: 'string',
        description: l.t('Window start (ISO date).', '窗口起点（ISO 日期）。'),
      ),
      Field(
        name: 'count',
        type: 'number',
        description: l.t(
          'Items in the window — what check_activity reads.',
          '窗口内条数——check_activity 读的就是它。',
        ),
      ),
      Field(
        name: 'items',
        type: 'array',
        description: l.t(
          'sha / message / author per commit; number / title / state per PR or issue.',
          '每条提交的 sha / 标题 / 作者；每个 PR 或 issue 的编号 / 标题 / 状态。',
        ),
      ),
    ],
    dependencies: const ['httpx==0.27.2'],
    envId: 'env_${fnFetchGithub}_v$v',
    envStatus: 'ready',
    envSyncedAt: v == 1 ? ago(days: 21) : fetchV2At,
    changeReason: v == 1
        ? l.t(
            'Initial version from chat — one GitHub collection per call so the workflow fans the three fetches out in parallel.',
            '聊天里生成的初版——每次只拉一类，工作流才能把三路抓取并行扇出。',
          )
        : l.t(
            'Retry 5xx and rate-limit answers with backoff (the Monday run died on a 502), slim items to what the writer needs.',
            '对 5xx 与限流应答退避重试（周一那次 run 死在 502 上），只保留写手需要的字段。',
          ),
    builtInConversationId: cvDigest,
    createdAt: v == 1 ? ago(days: 21) : fetchV2At,
    updatedAt: v == 1 ? ago(days: 21) : fetchV2At,
  );

  final prepareDocVer = FunctionVersion(
    id: '${fnPrepareDoc}_v1',
    functionId: fnPrepareDoc,
    version: 1,
    code: _prepareDocV1,
    inputs: [
      Field(name: 'markdown', type: 'string'),
      Field(
        name: 'period',
        type: 'string',
        description: l.t('Human-readable date range.', '可读的日期范围。'),
      ),
      Field(name: 'folder_id', type: 'string'),
    ],
    outputs: const [
      Field(name: 'title', type: 'string'),
      Field(name: 'parentId', type: 'string'),
      Field(name: 'slug', type: 'string'),
      Field(name: 'body', type: 'string'),
      Field(name: 'properties', type: 'object'),
    ],
    envId: 'env_${fnPrepareDoc}_v1',
    envStatus: 'ready',
    envSyncedAt: ago(days: 20),
    changeReason: l.t('Initial version.', '初版。'),
    builtInConversationId: cvDigest,
    createdAt: ago(days: 20),
    updatedAt: ago(days: 20),
  );

  FunctionVersion parseInvoiceVer(
    int v,
    String status, {
    String? error,
  }) => FunctionVersion(
    id: '${fnParseInvoice}_v$v',
    functionId: fnParseInvoice,
    version: v,
    code: _parseInvoiceV3,
    inputs: [
      Field(
        name: 'path',
        type: 'string',
        description: l.t('Absolute path of the PDF.', 'PDF 的绝对路径。'),
      ),
    ],
    outputs: const [
      Field(name: 'invoiceNumber', type: 'string'),
      Field(name: 'total', type: 'number'),
      Field(name: 'lineItems', type: 'array'),
      Field(name: 'pages', type: 'number'),
    ],
    dependencies: v == 3
        ? const ['pdfplumber==0.11.4']
        : const ['pypdf==4.3.1'],
    envId: 'env_${fnParseInvoice}_v$v',
    envStatus: status,
    envError: error,
    envSyncedAt: status == 'ready' ? ago(days: 30 - v * 3) : null,
    changeReason: switch (v) {
      1 => l.t('Initial version.', '初版。'),
      2 => l.t('Read line-item tables too.', '也读取明细表格。'),
      _ => l.t(
        'Switch to pdfplumber for table extraction; regex the invoice number and total.',
        '改用 pdfplumber 抽表格；正则抓发票号与合计。',
      ),
    },
    builtInConversationId: v == 3 ? cvFlakyTest : null,
    createdAt: ago(days: 30 - v * 3),
    updatedAt: ago(days: 30 - v * 3),
  );

  final resizeImageVer = FunctionVersion(
    id: '${fnResizeImage}_v1',
    functionId: fnResizeImage,
    version: 1,
    code: _resizeImageV1,
    inputs: [
      Field(
        name: 'image',
        type: 'object',
        description: l.t('An attachment media ref.', '附件媒体引用。'),
      ),
      Field(name: 'max_width', type: 'number'),
      Field(name: 'quality', type: 'number'),
    ],
    outputs: const [
      Field(name: 'image', type: 'object'),
      Field(name: 'width', type: 'number'),
      Field(name: 'height', type: 'number'),
      Field(name: 'bytes', type: 'number'),
    ],
    dependencies: const ['Pillow==10.4.0'],
    envId: 'env_${fnResizeImage}_v1',
    envStatus: 'ready',
    envSyncedAt: ago(days: 2, hours: 3),
    changeReason: l.t('Initial version.', '初版。'),
    builtInConversationId: cvHeroImages,
    createdAt: ago(days: 2, hours: 3),
    updatedAt: ago(days: 2, hours: 3),
  );

  final functions = [
    FunctionEntity(
      id: fnFetchGithub,
      name: fnFetchGithubName,
      description: l.t(
        'Pull commits, merged PRs and issues from the Anselm repo for the last N days.',
        '拉取 Anselm 仓库最近 N 天的提交、合并 PR 与 issue。',
      ),
      tags: const ['github', 'digest'],
      activeVersionId: '${fnFetchGithub}_v2',
      createdAt: ago(days: 21),
      updatedAt: fetchV2At,
      activeVersion: fetchGithubVer(2),
    ),
    FunctionEntity(
      id: fnPrepareDoc,
      name: fnPrepareDocName,
      description: l.t(
        'Shape a markdown digest into the document-create payload (title, slug, folder, properties).',
        '把 markdown 周报整理成建文档的载荷（标题、slug、目录、属性）。',
      ),
      tags: const ['digest', 'documents'],
      activeVersionId: '${fnPrepareDoc}_v1',
      createdAt: ago(days: 20),
      updatedAt: ago(days: 20),
      activeVersion: prepareDocVer,
    ),
    FunctionEntity(
      id: fnParseInvoice,
      name: fnParseInvoiceName,
      description: l.t(
        'Extract invoice number, total and line items from a supplier PDF.',
        '从供应商 PDF 里抽取发票号、合计与明细。',
      ),
      tags: const ['finance', 'pdf'],
      activeVersionId: '${fnParseInvoice}_v3',
      createdAt: ago(days: 27),
      updatedAt: ago(days: 21),
      activeVersion: parseInvoiceVer(3, 'failed', error: _parseInvoiceEnvError),
    ),
    FunctionEntity(
      id: fnResizeImage,
      name: fnResizeImageName,
      description: l.t(
        'Downscale an image to a max width and re-encode it as WebP.',
        '把图片缩到最大宽度并重编码为 WebP。',
      ),
      tags: const ['media', 'launch'],
      activeVersionId: '${fnResizeImage}_v1',
      createdAt: ago(days: 2, hours: 3),
      updatedAt: ago(days: 2, hours: 3),
      activeVersion: resizeImageVer,
    ),
  ];

  // ───────────────────────── Handlers ─────────────────────────

  HandlerVersion slackVer(int v) => HandlerVersion(
    id: '${hdSlack}_v$v',
    handlerId: hdSlack,
    version: v,
    imports: 'import httpx',
    initBody: v == 1
        ? 'self.client = httpx.Client(\n    base_url="https://slack.com/api",\n    headers={"Authorization": f"Bearer {args[\'token\']}"},\n)'
        : 'self.client = httpx.Client(\n    base_url="https://slack.com/api",\n    headers={"Authorization": f"Bearer {args[\'token\']}"},\n    timeout=15,\n)\nself.default_channel = args.get("channel", "#general")',
    shutdownBody: 'self.client.close()',
    methods: [
      MethodSpec(
        name: 'post_message',
        description: l.t('Post one message to a channel.', '往频道发一条消息。'),
        inputs: const [
          Field(name: 'channel', type: 'string'),
          Field(name: 'text', type: 'string'),
        ],
        outputs: const [Field(name: 'ts', type: 'string')],
        body:
            'r = self.client.post("/chat.postMessage", json={"channel": channel or self.default_channel, "text": text})\nr.raise_for_status()\nreturn {"ts": r.json()["ts"]}',
        timeout: 15000,
      ),
      if (v == 2)
        MethodSpec(
          name: 'post_digest',
          description: l.t(
            'Post a markdown digest as Block Kit sections.',
            '把 markdown 周报按 Block Kit 分段发出。',
          ),
          inputs: const [
            Field(name: 'channel', type: 'string'),
            Field(name: 'markdown', type: 'string'),
          ],
          outputs: const [Field(name: 'ts', type: 'string')],
          body:
              'blocks = [{"type": "section", "text": {"type": "mrkdwn", "text": chunk}}\n          for chunk in _split(markdown, 2900)]\nr = self.client.post("/chat.postMessage", json={"channel": channel, "blocks": blocks})\nr.raise_for_status()\nreturn {"ts": r.json()["ts"]}',
          timeout: 15000,
        ),
    ],
    initArgsSchema: [
      InitArgSpec(
        name: 'token',
        type: 'string',
        description: l.t('Bot token (xoxb-…).', 'Bot token（xoxb-…）。'),
        required: true,
        sensitive: true,
      ),
      if (v == 2)
        InitArgSpec(
          name: 'channel',
          type: 'string',
          description: l.t('Fallback channel.', '默认频道。'),
          defaultValue: '#general',
        ),
    ],
    dependencies: const ['httpx==0.27.2'],
    envId: 'env_${hdSlack}_v$v',
    envStatus: 'ready',
    envSyncedAt: v == 1 ? ago(days: 35) : ago(days: 9),
    changeReason: v == 1
        ? l.t('Initial version.', '初版。')
        : l.t(
            'Add post_digest (Block Kit) and a default channel init arg.',
            '新增 post_digest（Block Kit）与默认频道参数。',
          ),
    createdAt: v == 1 ? ago(days: 35) : ago(days: 9),
    updatedAt: v == 1 ? ago(days: 35) : ago(days: 9),
  );

  final postgresVer = HandlerVersion(
    id: '${hdPostgres}_v1',
    handlerId: hdPostgres,
    version: 1,
    imports: 'import psycopg',
    initBody:
        'self.conn = psycopg.connect(args["dsn"], autocommit=True)\nself.schema = args.get("schema", "public")',
    shutdownBody: 'self.conn.close()',
    methods: [
      MethodSpec(
        name: 'query',
        description: l.t(
          'Run one parameterised statement and return rows.',
          '执行一条带参语句并返回行。',
        ),
        inputs: const [
          Field(name: 'sql', type: 'string'),
          Field(name: 'args', type: 'array'),
        ],
        outputs: const [
          Field(name: 'rows', type: 'array'),
          Field(name: 'rowcount', type: 'number'),
        ],
        body:
            'with self.conn.cursor() as cur:\n    cur.execute(f"set search_path to {self.schema}")\n    cur.execute(sql, args or [])\n    rows = cur.fetchall() if cur.description else []\n    return {"rows": rows, "rowcount": cur.rowcount}',
        timeout: 30000,
      ),
      MethodSpec(
        name: 'health',
        description: l.t('Cheap liveness probe.', '轻量存活探测。'),
        outputs: const [
          Field(name: 'ok', type: 'boolean'),
          Field(name: 'latencyMs', type: 'number'),
        ],
        body:
            'import time\nt = time.perf_counter()\nwith self.conn.cursor() as cur:\n    cur.execute("select 1")\nreturn {"ok": True, "latencyMs": round((time.perf_counter() - t) * 1000)}',
        timeout: 5000,
      ),
    ],
    initArgsSchema: [
      InitArgSpec(
        name: 'dsn',
        type: 'string',
        description: l.t('postgres:// connection string.', 'postgres:// 连接串。'),
        required: true,
        sensitive: true,
      ),
      InitArgSpec(name: 'schema', type: 'string', defaultValue: 'public'),
    ],
    dependencies: const ['psycopg[binary]==3.2.1'],
    envId: 'env_${hdPostgres}_v1',
    envStatus: 'ready',
    envSyncedAt: ago(days: 33),
    changeReason: l.t('Initial version.', '初版。'),
    createdAt: ago(days: 33),
    updatedAt: ago(days: 33),
  );

  final handlers = [
    HandlerEntity(
      id: hdSlack,
      name: hdSlackName,
      description: l.t(
        'Resident Slack client — messages and Block Kit digests.',
        '常驻 Slack 客户端——发消息与 Block Kit 周报。',
      ),
      tags: const ['slack', 'notify'],
      activeVersionId: '${hdSlack}_v2',
      createdAt: ago(days: 35),
      updatedAt: ago(days: 9),
      activeVersion: slackVer(2),
      configState: 'ready',
      runtimeState: 'running',
    ),
    HandlerEntity(
      id: hdPostgres,
      name: hdPostgresName,
      description: l.t(
        'Read/write access to the support database.',
        '客服数据库的读写通道。',
      ),
      tags: const ['database'],
      activeVersionId: '${hdPostgres}_v1',
      createdAt: ago(days: 33),
      updatedAt: ago(days: 33),
      activeVersion: postgresVer,
      configState: 'ready',
      runtimeState: 'running',
    ),
  ];

  // ───────────────────────── Agents ─────────────────────────

  final digestPrompt = l.t(
    '''You are the team's weekly digest writer for the Cookiezisg/Anselm repository.

Input: a JSON activity bundle (commits, merged PRs, opened/closed issues) and the reporting period.
Write a markdown digest with these sections, in order: title, Summary, Commits grouped by theme
(cite the short sha and author), Highlights. Use the `fetch-github` tool if the bundle is empty.
Be concrete and terse — no filler, no emoji. Return {"digest": "<markdown>", "summary": "<title, the
Summary paragraph and the four counts — nothing else>"}.''',
    '''你是 Cookiezisg/Anselm 仓库的每周周报写手。

输入：一份 JSON 活动包（提交、合并 PR、新开/关闭 issue）与统计周期。
按顺序写出 markdown 周报：标题、概览、按主题分组的提交（引用短 sha 与作者）、亮点。
活动包为空时调用 `fetch-github` 工具。具体、简洁——不要废话与 emoji。返回 {"digest": "<markdown>", "summary": "<标题、概览段落和四个计数，不含其他>"}。''',
  );

  AgentVersion digestVer(int v) => AgentVersion(
    id: '${agDigest}_v$v',
    agentId: agDigest,
    version: v,
    prompt: v == 2
        ? digestPrompt
        : l.t(
            'Summarize the given GitHub activity as a weekly digest in markdown.',
            '把给定的 GitHub 活动总结成 markdown 周报。',
          ),
    skill: v == 2 ? skillGithubDigest : null,
    knowledge: v == 2 ? const [docDigestPrev, docHandbook] : const [],
    tools: [
      const ToolRef(ref: fnFetchGithub, name: 'fetch-github'),
      if (v == 2) const ToolRef(ref: 'mcp:web/search', name: 'web-search'),
    ],
    inputs: const [
      Field(name: 'activity', type: 'object'),
      Field(name: 'period', type: 'string'),
    ],
    outputs: [
      const Field(name: 'digest', type: 'string'),
      if (v == 2)
        Field(
          name: 'summary',
          type: 'string',
          description: l.t(
            'Title, Summary paragraph and counts — what the approval card renders.',
            '标题、概览段落与计数——审批卡渲染的就是它。',
          ),
        ),
    ],
    modelOverride: v == 2
        ? const ModelRef(apiKeyId: 'key_anthropic', modelId: 'claude-opus-4-8')
        : null,
    changeReason: v == 1
        ? l.t('Initial version.', '初版。')
        : l.t(
            'Structured sections, cite shas, mount the github-digest skill and web search.',
            '固定章节、引用 sha，挂载 github-digest 技能与网页搜索。',
          ),
    builtInConversationId: cvDigest,
    createdAt: v == 1 ? ago(days: 20) : digestV2At,
    updatedAt: v == 1 ? ago(days: 20) : digestV2At,
  );

  final triageVer = AgentVersion(
    id: '${agTriage}_v1',
    agentId: agTriage,
    version: 1,
    prompt: l.t(
      '''You triage inbound support tickets. Read the ticket, look up the customer's recent orders with
`db-query`, and decide a severity: "urgent" (outage, data loss, payment failure), "refund" (a refund is
requested and justified — include refundAmount), or "normal". Post nothing yourself; the workflow routes.
Return {"severity": ..., "refundAmount": <number|null>, "summary": "<one line for Slack>"}.''',
      '''你负责分流客服工单。读工单，用 `db-query` 查客户最近订单，判定严重度："urgent"（故障、数据丢失、
支付失败）、"refund"（申请退款且合理——附 refundAmount）或 "normal"。不要自己发消息，由工作流路由。
返回 {"severity": ..., "refundAmount": <number|null>, "summary": "<给 Slack 的一句话>"}。''',
    ),
    knowledge: const [docSupportPlaybook],
    tools: const [
      ToolRef(ref: '$hdPostgres.query', name: 'db-query'),
      ToolRef(ref: '$hdSlack.post_message', name: 'slack-post'),
    ],
    inputs: const [Field(name: 'ticket', type: 'object')],
    outputs: const [
      Field(name: 'severity', type: 'string'),
      Field(name: 'refundAmount', type: 'number'),
      Field(name: 'summary', type: 'string'),
    ],
    changeReason: l.t('Initial version from chat.', '聊天里生成的初版。'),
    builtInConversationId: cvTriage,
    createdAt: ago(days: 11),
    updatedAt: ago(days: 11),
  );

  final releaseNotesVer = AgentVersion(
    id: '${agReleaseNotes}_v1',
    agentId: agReleaseNotes,
    version: 1,
    prompt: l.t(
      '''Turn a GitHub activity bundle into release notes for the given version. Group by Added / Changed /
Fixed, one line per user-visible change, link PR numbers. Return {"headline": "...", "notes": "<markdown>"}.''',
      '''把 GitHub 活动包整理成指定版本的发布说明。按 新增 / 变更 / 修复 分组，每条用户可见改动一行，链接 PR 号。
返回 {"headline": "...", "notes": "<markdown>"}。''',
    ),
    knowledge: const [docReleaseProcess],
    tools: const [
      ToolRef(ref: fnFetchGithub, name: 'fetch-github'),
      ToolRef(ref: 'mcp:github/list_pull_requests', name: 'list-prs'),
    ],
    inputs: const [
      Field(name: 'activity', type: 'object'),
      Field(name: 'version', type: 'string'),
    ],
    outputs: const [
      Field(name: 'headline', type: 'string'),
      Field(name: 'notes', type: 'string'),
    ],
    changeReason: l.t('Initial version.', '初版。'),
    builtInConversationId: cvReleaseNotes,
    createdAt: ago(days: 3),
    updatedAt: ago(days: 3),
  );

  final agents = [
    AgentEntity(
      id: agDigest,
      name: agDigestName,
      description: l.t(
        'Writes the Monday GitHub digest from the fetched activity.',
        '根据拉取的活动写周一的 GitHub 周报。',
      ),
      tags: const ['digest', 'writer'],
      activeVersionId: '${agDigest}_v2',
      createdAt: ago(days: 20),
      updatedAt: digestV2At,
      activeVersion: digestVer(2),
    ),
    AgentEntity(
      id: agTriage,
      name: agTriageName,
      description: l.t(
        'Reads a Zendesk ticket, checks the customer in Postgres, decides severity.',
        '读 Zendesk 工单，查 Postgres 里的客户，判定严重度。',
      ),
      tags: const ['support'],
      activeVersionId: '${agTriage}_v1',
      createdAt: ago(days: 11),
      updatedAt: ago(days: 11),
      activeVersion: triageVer,
    ),
    AgentEntity(
      id: agReleaseNotes,
      name: agReleaseNotesName,
      description: l.t(
        'Drafts release notes grouped by Added / Changed / Fixed.',
        '起草按新增 / 变更 / 修复分组的发布说明。',
      ),
      tags: const ['release', 'writer'],
      activeVersionId: '${agReleaseNotes}_v1',
      createdAt: ago(days: 3),
      updatedAt: ago(days: 3),
      activeVersion: releaseNotesVer,
    ),
  ];

  // ───────────────────────── Workflows ─────────────────────────

  WorkflowVersion wfVer(
    String wfId,
    int v,
    String graph,
    String reason,
    DateTime at, {
    String? conversationId,
  }) => WorkflowVersion(
    id: '${wfId}_v$v',
    workflowId: wfId,
    version: v,
    graph: graph,
    changeReason: reason,
    builtInConversationId: conversationId,
    createdAt: at,
    updatedAt: at,
  );

  final digestV1 = wfVer(
    wfDigest,
    1,
    _digestGraphV1,
    l.t(
      'Fetch commits → write → file the document → post to Slack.',
      '拉提交 → 写作 → 落文档 → 发 Slack。',
    ),
    ago(days: 20),
    conversationId: cvDigest,
  );
  final digestV2 = wfVer(
    wfDigest,
    2,
    _digestGraphV2,
    l.t(
      'Fan the fetch out into commits / pulls / issues, route empty weeks past the review with check_activity, add a human review before filing, post via post_digest.',
      '把抓取扇出为提交 / PR / issue 三路，用 check_activity 让空周绕过审阅，落文档前加人工审阅，改用 post_digest 发帖。',
    ),
    digestV2At,
    conversationId: cvDigest,
  );
  final triageV1 = wfVer(
    wfTriage,
    1,
    _triageGraph,
    l.t(
      'Webhook → agent → severity control → Slack / refund approval / file.',
      'Webhook → agent → 严重度控制 → Slack / 退款审批 / 入库。',
    ),
    ago(days: 11),
    conversationId: cvTriage,
  );
  final invoiceV1 = wfVer(
    wfInvoice,
    1,
    _invoiceGraph,
    l.t('Folder watch → parse → store → notify.', '目录监听 → 解析 → 入库 → 通知。'),
    ago(days: 24),
  );
  final releaseV1 = wfVer(
    wfRelease,
    1,
    _releaseGraph,
    l.t(
      'Manual: collect changes → draft notes → file doc → announce.',
      '手动：收集改动 → 起草说明 → 落文档 → 公告。',
    ),
    ago(days: 3),
    conversationId: cvReleaseNotes,
  );

  final workflows = [
    WorkflowEntity(
      id: wfDigest,
      name: wfDigestName,
      description: l.t(
        'Every Monday 09:00: fetch two weeks of commits, PRs and issues in parallel, draft the digest, skip empty weeks, get it reviewed, file it under Weekly digests and post it to Slack.',
        '每周一 09:00：并行拉两周的提交、PR 与 issue，起草周报，空周跳过，人工审阅后归档到「每周周报」并发到 Slack。',
      ),
      tags: const ['digest', 'weekly'],
      active: true,
      lifecycleState: 'active',
      concurrency: 'skip',
      lastActionBy: 'user',
      activeVersionId: '${wfDigest}_v2',
      createdAt: ago(days: 20),
      updatedAt: digestV2At,
      activeVersion: digestV2,
    ),
    WorkflowEntity(
      id: wfTriage,
      name: wfTriageName,
      description: l.t(
        'Each Zendesk ticket is triaged by an agent and routed by severity.',
        '每张 Zendesk 工单由 agent 分流并按严重度路由。',
      ),
      tags: const ['support'],
      active: true,
      lifecycleState: 'active',
      concurrency: 'allow_all',
      needsAttention: true,
      attentionReason: l.t(
        'Webhook secret rotated on the Zendesk side — 1 delivery rejected in the last hour.',
        'Zendesk 侧轮换了 webhook 密钥——过去一小时拒绝了 1 次投递。',
      ),
      lastActionBy: 'scheduler',
      activeVersionId: '${wfTriage}_v1',
      createdAt: ago(days: 11),
      updatedAt: ago(hours: 1, minutes: 4),
      activeVersion: triageV1,
    ),
    WorkflowEntity(
      id: wfInvoice,
      name: wfInvoiceName,
      description: l.t(
        'Parse every PDF dropped into the Invoices folder and file it in the ledger.',
        '解析扔进 Invoices 目录的每份 PDF 并记入账本。',
      ),
      tags: const ['finance'],
      active: true,
      lifecycleState: 'active',
      concurrency: 'serial',
      lastActionBy: 'user',
      activeVersionId: '${wfInvoice}_v1',
      createdAt: ago(days: 24),
      updatedAt: ago(days: 24),
      activeVersion: invoiceV1,
    ),
    WorkflowEntity(
      id: wfRelease,
      name: wfReleaseName,
      description: l.t(
        'Manual release pipeline: changes → notes → doc → announcement. Not activated yet.',
        '手动发布线：改动 → 说明 → 文档 → 公告。尚未激活。',
      ),
      tags: const ['release'],
      active: false,
      lifecycleState: 'inactive',
      concurrency: 'serial',
      lastActionBy: 'user',
      activeVersionId: '${wfRelease}_v1',
      createdAt: ago(days: 3),
      updatedAt: ago(days: 3),
      activeVersion: releaseV1,
    ),
  ];

  // ───────────────────────── Executions / calls ─────────────────────────

  final commitItems = <Object?>[
    {
      'sha': '33facdd',
      'message': 'test(acceptance): close remaining autonomous frontier',
      'author': authorName,
    },
    {
      'sha': '06e6dbb',
      'message': 'test(acceptance): close edge296 and batch90 gate',
      'author': authorName,
    },
    {
      'sha': '1e9b4d4',
      'message':
          'test(acceptance): close autonomous frontier and fix duplicate tool terminal',
      'author': authorName,
    },
    {
      'sha': '23a40bf',
      'message': 'chore(acceptance): seal current app and rig work',
      'author': authorName,
    },
    {
      'sha': '63cc92f',
      'message': 'test(acceptance): close batch 89 and seal fork lineage',
      'author': authorName,
    },
    {
      'sha': 'fabce11',
      'message':
          'test(acceptance): close batch 88 and repair demo execution bracket',
      'author': authorName,
    },
    {
      'sha': 'e109a37',
      'message': 'fix(acceptance): reset rail viewport when sort axis changes',
      'author': authorName,
    },
    {
      'sha': 'db98b6f',
      'message': 'fix(acceptance): keep branch recovery notice readable',
      'author': authorName,
    },
    {'sha': '…', 'message': '(24 more commits)', 'author': authorName},
  ];

  // One output per `kind` — the three parallel fetch nodes each return exactly one of these, and
  // `check_activity` reads the `count`s. 每类一份输出:三路并行抓取各返回其一,check_activity 读 count。
  final fetchOutputs = <String, Map<String, Object?>>{
    'commits': {
      'kind': 'commits',
      'since': '2026-08-30',
      'count': 32,
      'items': commitItems,
    },
    'pulls': {
      'kind': 'pulls',
      'since': '2026-08-30',
      'count': 0,
      'items': <Object?>[],
    },
    'issues': {
      'kind': 'issues',
      'since': '2026-08-30',
      'count': 0,
      'items': <Object?>[],
    },
  };

  // The activity bundle the writer receives — the three fetch outputs joined. 写手拿到的活动包。
  final fetchOutput = <String, Object?>{
    'commits': commitItems,
    'pulls': <Object?>[],
    'issues': <Object?>[],
  };

  // Parallel fetch timing shared by the three digest runs: all three start inside the same second
  // and overlap (1.1s / 0.9s / 1.4s), so the Gantt shows three bars side by side, not a staircase.
  // 三次周报 run 共用的并行抓取时序:三路在同一秒内起跑且重叠(1.1s / 0.9s / 1.4s),甘特上并排而非阶梯。
  const fetchWindow = <String, (int startMs, int endMs)>{
    'commits': (200, 1300),
    'pulls': (250, 1150),
    'issues': (300, 1700),
  };

  FunctionExecution fetchExec(
    String id,
    String runId,
    DateTime runStart,
    String kind, {
    int fnVersion = 2,
    bool failed = false,
  }) {
    final (startMs, endMs) = fetchWindow[kind]!;
    final started = runStart.add(Duration(milliseconds: startMs));
    final ended = runStart.add(Duration(milliseconds: endMs));
    return FunctionExecution(
      id: id,
      functionId: fnFetchGithub,
      versionId: '${fnFetchGithub}_v$fnVersion',
      status: failed ? 'failed' : 'ok',
      triggeredBy: 'workflow',
      input: {'kind': kind, 'days': '14'},
      output: failed ? null : fetchOutputs[kind],
      errorMessage: failed
          ? 'HTTPStatusError: 502 Bad Gateway (api.github.com /commits)'
          : null,
      logs: failed
          ? _fetchGithubTraceback
          : 'GET /repos/Cookiezisg/Anselm/$kind 200 (${((endMs - startMs) / 1000).toStringAsFixed(2)}s)\n${fetchOutputs[kind]!['count']} $kind in window',
      elapsedMs: endMs - startMs,
      startedAt: started,
      endedAt: ended,
      flowrunId: runId,
      flowrunNodeId: 'fetch_$kind',
      flowrunIteration: 0,
      createdAt: ended,
    );
  }

  final functionExecutions = <String, List<FunctionExecution>>{
    fnFetchGithub: [
      fetchExec('fne_c1d2e3f4a5b6c7d8', frDigestParked, parkedStart, 'commits'),
      fetchExec('fne_c2d3e4f5a6b7c8d9', frDigestParked, parkedStart, 'pulls'),
      fetchExec('fne_c3d4e5f6a7b8c9da', frDigestParked, parkedStart, 'issues'),
      fetchExec(
        'fne_9a8b7c6d5e4f3a2b',
        frDigestRejected,
        rejectedStart,
        'commits',
      ),
      fetchExec(
        'fne_9b8c7d6e5f4a3b2c',
        frDigestRejected,
        rejectedStart,
        'pulls',
      ),
      fetchExec(
        'fne_9c8d7e6f5a4b3c2d',
        frDigestRejected,
        rejectedStart,
        'issues',
      ),
      // Last Monday on fetch v1 (no retry): /commits answered 502, the two siblings completed.
      // 上周一跑的是 fetch v1(无重试):/commits 应答 502,两个兄弟节点正常完成。
      fetchExec(
        'fne_1f2e3d4c5b6a7980',
        frDigestFailed,
        failedStart,
        'commits',
        fnVersion: 1,
        failed: true,
      ),
      fetchExec(
        'fne_1a2b3c4d5e6f7a8b',
        frDigestFailed,
        failedStart,
        'pulls',
        fnVersion: 1,
      ),
      fetchExec(
        'fne_1b2c3d4e5f6a7b8c',
        frDigestFailed,
        failedStart,
        'issues',
        fnVersion: 1,
      ),
    ],
    fnPrepareDoc: [
      FunctionExecution(
        id: 'fne_2b3c4d5e6f708192',
        functionId: fnPrepareDoc,
        versionId: '${fnPrepareDoc}_v1',
        status: 'ok',
        triggeredBy: 'user',
        input: {
          'markdown': '# Weekly Digest …',
          'period': 'Aug 16 – Aug 29, 2026',
          'folder_id': docDigestsFolder,
        },
        output: {
          'title': docDigestPrevTitle(l),
          'parentId': docDigestsFolder,
          'slug': 'digest-aug-16-aug-29-2026',
          'properties': {'period': 'Aug 16 – Aug 29, 2026'},
        },
        elapsedMs: 41,
        startedAt: ago(days: 20, hours: -1),
        endedAt: ago(days: 20, hours: -1),
        conversationId: cvDigest,
        createdAt: ago(days: 20, hours: -1),
      ),
    ],
    fnParseInvoice: [
      FunctionExecution(
        id: 'fne_3c4d5e6f70819203',
        functionId: fnParseInvoice,
        versionId: '${fnParseInvoice}_v3',
        status: 'failed',
        triggeredBy: 'workflow',
        input: const {
          'path': '/Users/you/Documents/Invoices/acme-2026-0912.pdf',
        },
        errorMessage: "ModuleNotFoundError: No module named 'pdfplumber'",
        logs: _parseInvoiceTraceback,
        elapsedMs: 220,
        startedAt: ago(hours: 5, minutes: 40),
        endedAt: ago(hours: 5, minutes: 40),
        flowrunId: frInvoiceFailed,
        flowrunNodeId: 'parse_invoice',
        flowrunIteration: 0,
        createdAt: ago(hours: 5, minutes: 40),
      ),
      FunctionExecution(
        id: 'fne_4d5e6f7081920314',
        functionId: fnParseInvoice,
        versionId: '${fnParseInvoice}_v2',
        status: 'ok',
        triggeredBy: 'workflow',
        input: const {
          'path': '/Users/you/Documents/Invoices/northwind-2026-0903.pdf',
        },
        output: const {
          'invoiceNumber': 'NW-2026-1187',
          'total': 1284.50,
          'lineItems': [
            ['Design retainer · August', '1', '1,200.00'],
            ['Stock photos', '3', '84.50'],
          ],
          'pages': 2,
        },
        elapsedMs: 1730,
        startedAt: ago(days: 9, hours: 3),
        endedAt: ago(days: 9, hours: 3),
        flowrunId: frInvoiceDone,
        flowrunNodeId: 'parse_invoice',
        flowrunIteration: 0,
        createdAt: ago(days: 9, hours: 3),
      ),
    ],
    fnResizeImage: [
      for (final (i, spec) in const [
        ('att_a1b2c3d4e5f60718', 'hero-desktop.webp', 1600, 900, 148_220),
        ('att_b2c3d4e5f6071829', 'hero-tablet.webp', 1024, 576, 71_804),
        ('att_c3d4e5f60718293a', 'hero-mobile.webp', 640, 360, 31_116),
      ].indexed)
        FunctionExecution(
          id: 'fne_5e6f70819203142$i',
          functionId: fnResizeImage,
          versionId: '${fnResizeImage}_v1',
          status: 'ok',
          triggeredBy: 'chat',
          input: {
            'image': {
              'attachmentId': 'att_d4e5f60718293a4b',
              'filename': 'hero.png',
              'mime': 'image/png',
            },
            'max_width': spec.$3,
            'quality': 82,
          },
          output: {
            'image': {
              'attachmentId': spec.$1,
              'filename': spec.$2,
              'mime': 'image/webp',
              'width': spec.$3,
              'height': spec.$4,
              'sizeBytes': spec.$5,
              'source': 'generated',
            },
            'width': spec.$3,
            'height': spec.$4,
            'bytes': spec.$5,
          },
          elapsedMs: 380 - i * 90,
          startedAt: ago(days: 2, hours: 2, minutes: 50 - i * 2),
          endedAt: ago(days: 2, hours: 2, minutes: 50 - i * 2),
          conversationId: cvHeroImages,
          createdAt: ago(days: 2, hours: 2, minutes: 50 - i * 2),
        ),
    ],
  };

  final handlerCalls = <String, List<HandlerCall>>{
    hdSlack: [
      HandlerCall(
        id: 'hcl_a1b2c3d4e5f60711',
        handlerId: hdSlack,
        versionId: '${hdSlack}_v2',
        method: 'post_message',
        instanceId: 'inst_${hdSlack}_1',
        status: 'ok',
        triggeredBy: 'workflow',
        input: const {
          'channel': '#support-urgent',
          'text':
              'Ticket #4819 — checkout returns 502 for EU customers since 02:10 UTC',
        },
        output: const {'ts': '1789421500.004100'},
        elapsedMs: 312,
        startedAt: ago(hours: 6, minutes: 21),
        endedAt: ago(hours: 6, minutes: 21),
        flowrunId: frTriageDone1,
        flowrunNodeId: 'notify_oncall',
        flowrunIteration: 0,
        createdAt: ago(hours: 6, minutes: 21),
      ),
      HandlerCall(
        id: 'hcl_b2c3d4e5f6071822',
        handlerId: hdSlack,
        versionId: '${hdSlack}_v2',
        method: 'post_message',
        instanceId: 'inst_${hdSlack}_1',
        status: 'ok',
        triggeredBy: 'workflow',
        input: const {
          'channel': '#finance',
          'text': 'Invoice NW-2026-1187 filed',
        },
        output: const {'ts': '1788652800.117300'},
        elapsedMs: 287,
        startedAt: ago(days: 9, hours: 3),
        endedAt: ago(days: 9, hours: 3),
        flowrunId: frInvoiceDone,
        flowrunNodeId: 'notify_finance',
        flowrunIteration: 0,
        createdAt: ago(days: 9, hours: 3),
      ),
      HandlerCall(
        id: 'hcl_c3d4e5f607182933',
        handlerId: hdSlack,
        versionId: '${hdSlack}_v2',
        method: 'post_digest',
        instanceId: 'inst_${hdSlack}_1',
        status: 'ok',
        triggeredBy: 'user',
        input: const {
          'channel': '#product-team',
          'markdown': '# Weekly Digest: Cookiezisg/Anselm …',
        },
        output: const {'ts': '1788336000.220900'},
        elapsedMs: 540,
        startedAt: ago(days: 8, hours: 20),
        endedAt: ago(days: 8, hours: 20),
        conversationId: cvDigest,
        createdAt: ago(days: 8, hours: 20),
      ),
      HandlerCall(
        id: 'hcl_d4e5f60718293a44',
        handlerId: hdSlack,
        versionId: '${hdSlack}_v1',
        method: 'post_message',
        instanceId: 'inst_${hdSlack}_0',
        status: 'failed',
        triggeredBy: 'user',
        input: const {'channel': '#product', 'text': 'ping'},
        errorMessage: 'channel_not_found',
        elapsedMs: 198,
        startedAt: ago(days: 34),
        endedAt: ago(days: 34),
        createdAt: ago(days: 34),
      ),
    ],
    hdPostgres: [
      HandlerCall(
        id: 'hcl_e5f60718293a4b55',
        handlerId: hdPostgres,
        versionId: '${hdPostgres}_v1',
        method: 'query',
        instanceId: 'inst_${hdPostgres}_1',
        status: 'ok',
        triggeredBy: 'agent',
        input: const {
          'sql':
              'select id, total, status from orders where customer_email = \$1 order by created_at desc limit 5',
          'args': ['mara@example.com'],
        },
        output: const {
          'rows': [
            ['ord_88213', 129.00, 'delivered'],
            ['ord_87990', 49.00, 'refund_requested'],
          ],
          'rowcount': 2,
        },
        elapsedMs: 23,
        startedAt: ago(minutes: 3, seconds: 20),
        endedAt: ago(minutes: 3, seconds: 20),
        flowrunId: frTriageRunning,
        flowrunNodeId: 'triage',
        flowrunIteration: 0,
        createdAt: ago(minutes: 3, seconds: 20),
      ),
    ],
  };

  final agentExecutions = <String, List<AgentExecution>>{
    agDigest: [
      AgentExecution(
        id: 'agx_a1b2c3d4e5f60731',
        agentId: agDigest,
        versionId: '${agDigest}_v2',
        status: 'ok',
        triggeredBy: 'workflow',
        input: {'activity': fetchOutput, 'period': 'Aug 30 – Sep 13, 2026'},
        output: {'digest': digestMarkdown(l), 'summary': digestApprovalBody(l)},
        provider: 'anthropic',
        modelId: 'claude-opus-4-8',
        apiKeyId: 'key_anthropic',
        transcript: [
          {'role': 'user', 'content': '[activity bundle · 32 commits]'},
          {
            'role': 'assistant',
            'content': l.t(
              'Grouping commits by theme: acceptance testing (6), fixes (2), tooling (24)…',
              '按主题分组提交：验收测试（6）、修复（2）、工具链（24）…',
            ),
          },
          {
            'role': 'assistant',
            'content':
                '{"digest": "# Weekly Digest …", "summary": "**Weekly Digest Review** …"}',
          },
        ],
        elapsedMs: 80_000,
        startedAt: parkedStart.add(const Duration(milliseconds: 1800)),
        endedAt: parkedStart.add(const Duration(milliseconds: 81_800)),
        flowrunId: frDigestParked,
        flowrunNodeId: 'write_digest',
        flowrunIteration: 0,
        createdAt: parkedStart.add(const Duration(milliseconds: 81_800)),
      ),
      AgentExecution(
        id: 'agx_b2c3d4e5f6071842',
        agentId: agDigest,
        versionId: '${agDigest}_v2',
        status: 'ok',
        triggeredBy: 'workflow',
        input: {'activity': fetchOutput, 'period': 'Aug 30 – Sep 13, 2026'},
        output: {'digest': digestMarkdown(l), 'summary': digestApprovalBody(l)},
        provider: 'anthropic',
        modelId: 'claude-opus-4-8',
        apiKeyId: 'key_anthropic',
        elapsedMs: 80_000,
        startedAt: rejectedStart.add(const Duration(milliseconds: 1800)),
        endedAt: rejectedStart.add(const Duration(milliseconds: 81_800)),
        flowrunId: frDigestRejected,
        flowrunNodeId: 'write_digest',
        flowrunIteration: 0,
        createdAt: rejectedStart.add(const Duration(milliseconds: 81_800)),
      ),
    ],
    agTriage: [
      AgentExecution(
        id: 'agx_c3d4e5f607182953',
        agentId: agTriage,
        versionId: '${agTriage}_v1',
        status: 'running',
        triggeredBy: 'workflow',
        input: const {
          'ticket': {
            'id': 4821,
            'subject': 'Charged twice for order ord_87990',
            'requester': {'email': 'mara@example.com'},
          },
        },
        provider: 'anthropic',
        modelId: 'claude-sonnet-4-6',
        apiKeyId: 'key_anthropic',
        transcript: [
          {'role': 'user', 'content': '[ticket #4821]'},
          {
            'role': 'tool',
            'name': 'db-query',
            'content':
                '{"rows": [["ord_88213", 129.0, "delivered"], ["ord_87990", 49.0, "refund_requested"]]}',
          },
        ],
        startedAt: ago(minutes: 3, seconds: 40),
        flowrunId: frTriageRunning,
        flowrunNodeId: 'triage',
        flowrunIteration: 0,
        createdAt: ago(minutes: 3, seconds: 40),
      ),
      AgentExecution(
        id: 'agx_d4e5f60718293a64',
        agentId: agTriage,
        versionId: '${agTriage}_v1',
        status: 'ok',
        triggeredBy: 'workflow',
        input: const {
          'ticket': {'id': 4819, 'subject': 'Checkout 502 for EU customers'},
        },
        output: const {
          'severity': 'urgent',
          'refundAmount': null,
          'summary':
              'Ticket #4819 — checkout returns 502 for EU customers since 02:10 UTC',
        },
        provider: 'anthropic',
        modelId: 'claude-sonnet-4-6',
        apiKeyId: 'key_anthropic',
        elapsedMs: 18_900,
        startedAt: ago(hours: 6, minutes: 22),
        endedAt: ago(hours: 6, minutes: 21, seconds: 41),
        flowrunId: frTriageDone1,
        flowrunNodeId: 'triage',
        flowrunIteration: 0,
        createdAt: ago(hours: 6, minutes: 21, seconds: 41),
      ),
      AgentExecution(
        id: 'agx_e5f60718293a4b75',
        agentId: agTriage,
        versionId: '${agTriage}_v1',
        status: 'ok',
        triggeredBy: 'workflow',
        input: const {
          'ticket': {'id': 4817, 'subject': 'How do I export my data?'},
        },
        output: const {
          'severity': 'normal',
          'refundAmount': null,
          'summary': 'Ticket #4817 — how-to question about data export',
        },
        provider: 'anthropic',
        modelId: 'claude-sonnet-4-6',
        apiKeyId: 'key_anthropic',
        elapsedMs: 9_300,
        startedAt: ago(hours: 9, minutes: 5),
        endedAt: ago(hours: 9, minutes: 4, seconds: 51),
        flowrunId: frTriageDone2,
        flowrunNodeId: 'triage',
        flowrunIteration: 0,
        createdAt: ago(hours: 9, minutes: 4, seconds: 51),
      ),
    ],
    agReleaseNotes: [
      AgentExecution(
        id: 'agx_f60718293a4b5c86',
        agentId: agReleaseNotes,
        versionId: '${agReleaseNotes}_v1',
        status: 'ok',
        triggeredBy: 'chat',
        input: const {
          'activity': {'commitCount': 32},
          'version': '0.2.0',
        },
        output: {
          'headline': l.t(
            'Anselm 0.2.0 — durable multimodal runs, reviewed digests',
            'Anselm 0.2.0 — 持久多模态运行、可审阅周报',
          ),
          'notes': '## Added\n- …\n## Changed\n- …\n## Fixed\n- …',
        },
        provider: 'anthropic',
        modelId: 'claude-opus-4-8',
        apiKeyId: 'key_anthropic',
        elapsedMs: 42_700,
        startedAt: ago(days: 3, hours: -1),
        endedAt: ago(days: 3, hours: -1, minutes: -1),
        conversationId: cvReleaseNotes,
        createdAt: ago(days: 3, hours: -1, minutes: -1),
      ),
    ],
  };

  // ───────────────────────── Flowruns ─────────────────────────

  FlowrunNode node(
    String runId,
    String nodeId,
    String kind,
    String ref,
    String status, {
    int iteration = 0,
    DateTime? ready,
    DateTime? started,
    DateTime? done,
    required DateTime created,
    Map<String, Object?> result = const {},
    String? error,
  }) => FlowrunNode(
    id: 'frn_${runId.substring(3, 11)}_${nodeId}_$iteration',
    flowrunId: runId,
    nodeId: nodeId,
    iteration: iteration,
    kind: kind,
    ref: ref,
    status: status,
    result: result,
    error: error,
    readyAt: ready,
    startedAt: started,
    createdAt: created,
    completedAt: done,
    updatedAt: done ?? created,
  );

  // The three digest runs share one node-ledger builder driven by `digestRunOutcomes` from the story
  // bible: a node exists in the ledger only when the bible lists it, with the status the bible gives,
  // so "nodes not listed are not run" is enforced structurally rather than by hand-copied rows.
  // Offsets (ms from the run start): trigger 0; fetches per `fetchWindow` (parallel); writer
  // 1.8s → 81.8s; check_activity 40ms; review opens at 81.95s and either parks or completes at
  // [reviewDone]. 三次周报 run 共用一个由总纲 `digestRunOutcomes` 驱动的节点台账构造器:总纲没列的节点
  // 就不出现,状态照总纲——「未列即未跑」由结构保证而非手抄。
  FlowrunComposite digestDetail(
    Flowrun run,
    DateTime start, {
    Map<String, Object?> reviewResult = const {},
    DateTime? reviewDone,
  }) {
    DateTime at(int ms) => start.add(Duration(milliseconds: ms));
    final outcomes = digestRunOutcomes[run.id]!;
    final fetchDone = fetchWindow.values
        .map((w) => w.$2)
        .reduce((a, b) => a > b ? a : b);
    const writerDone = 81_800;
    const checkDone = 81_890;
    final nodes = <FlowrunNode>[];
    for (final id in digestNodeIds) {
      final status = outcomes[id];
      if (status == null) continue;
      switch (id) {
        case 'start':
          nodes.add(
            node(
              run.id,
              id,
              'trigger',
              trgMonday,
              status,
              created: start,
              done: start,
              result: run.origin == 'cron'
                  ? const {
                      'firedAt': '2026-09-07T09:00:00+08:00',
                      'days': '14',
                      'period': 'Aug 24 – Sep 6, 2026',
                    }
                  : const {
                      'days': '14',
                      'period': 'Aug 30 – Sep 13, 2026',
                      'manual': true,
                    },
            ),
          );
        case 'fetch_commits' || 'fetch_pulls' || 'fetch_issues':
          final kind = id.substring('fetch_'.length);
          final (startMs, endMs) = fetchWindow[kind]!;
          final failed = status == 'failed';
          nodes.add(
            node(
              run.id,
              id,
              'action',
              fnFetchGithub,
              status,
              ready: start,
              started: at(startMs),
              created: at(endMs),
              done: at(endMs),
              result: failed
                  ? const {}
                  : {
                      'kind': kind,
                      'count': fetchOutputs[kind]!['count'],
                      'since': fetchOutputs[kind]!['since'],
                    },
              error: failed
                  ? 'HandlerError: $fnFetchGithubName: 502 Bad Gateway (api.github.com)'
                  : null,
            ),
          );
        case 'write_digest':
          nodes.add(
            node(
              run.id,
              id,
              'agent',
              agDigest,
              status,
              ready: at(fetchDone),
              started: at(1800),
              created: at(writerDone),
              done: at(writerDone),
              result: {
                'digest': digestMarkdown(l),
                'summary': digestApprovalBody(l),
              },
            ),
          );
        case 'check_activity':
          nodes.add(
            node(
              run.id,
              id,
              'control',
              ctlEmptyWeek,
              status,
              ready: at(writerDone),
              started: at(81_850),
              created: at(checkDone),
              done: at(checkDone),
              result: const {
                '__port': 'has_activity',
                'commits': 32,
                'pulls': 0,
                'issues': 0,
              },
            ),
          );
        case 'review':
          nodes.add(
            node(
              run.id,
              id,
              'approval',
              apfDigest,
              status,
              ready: at(checkDone),
              started: at(81_950),
              created: at(81_950),
              done: reviewDone,
              result: {
                'rendered': digestApprovalBody(l),
                'allowReason': true,
                'commits': 32,
                'period': 'Aug 30 – Sep 13, 2026',
                ...reviewResult,
              },
            ),
          );
      }
    }
    return FlowrunComposite(
      flowrun: run,
      workflowName: wfDigestName,
      nodes: nodes,
    );
  }

  final digestPinnedRefs = {
    trgMonday: trgMonday,
    fnFetchGithub: '${fnFetchGithub}_v2',
    agDigest: '${agDigest}_v2',
    ctlEmptyWeek: '${ctlEmptyWeek}_v1',
    apfDigest: '${apfDigest}_v1',
    fnPrepareDoc: '${fnPrepareDoc}_v1',
    hdSlack: '${hdSlack}_v2',
  };

  // Digest — last Monday's cron tick: fetch v1 had no retry, /commits answered 502, the two sibling
  // fetches completed and nothing downstream ran. Replayed once (still v1 → failed again), then fetch
  // v2 landed. 周报:上周一 cron——fetch v1 无重试,/commits 应答 502,两个兄弟抓取完成,下游未跑。
  // 重放一次(仍是 v1,再失败),随后 fetch v2 落地。
  final digestFailedRun = Flowrun(
    id: frDigestFailed,
    workflowId: wfDigest,
    versionId: '${wfDigest}_v2',
    pinnedRefs: {...digestPinnedRefs, fnFetchGithub: '${fnFetchGithub}_v1'},
    triggerId: trgMonday,
    firingId: 'trf_b2c3d4e5f6071802',
    origin: 'cron',
    status: 'failed',
    replayCount: 1,
    error:
        'fetch_commits: HandlerError: $fnFetchGithubName: 502 Bad Gateway (api.github.com)',
    startedAt: failedStart,
    completedAt: failedStart.add(const Duration(milliseconds: 1700)),
    updatedAt: failedReplayedAt,
  );
  final digestFailedDetail = digestDetail(digestFailedRun, failedStart);

  // Digest — yesterday's manual run: the reviewer bounced the draft after ~9 minutes.
  // 周报:昨天手动跑,审阅人约 9 分钟后驳回。
  final rejectedDone = rejectedStart.add(
    const Duration(minutes: 9, seconds: 12),
  );
  final digestRejectedRun = Flowrun(
    id: frDigestRejected,
    workflowId: wfDigest,
    versionId: '${wfDigest}_v2',
    pinnedRefs: digestPinnedRefs,
    origin: 'manual',
    status: 'completed',
    startedAt: rejectedStart,
    completedAt: rejectedDone,
    updatedAt: rejectedDone,
  );
  final digestRejectedDetail = digestDetail(
    digestRejectedRun,
    rejectedStart,
    reviewDone: rejectedDone,
    reviewResult: {
      'decision': 'no',
      'reason': l.t(
        'Highlights section repeats the summary — tighten it and rerun.',
        '「亮点」和概览重复了——收紧后重跑。',
      ),
      'decidedBy': authorName,
    },
  );

  // Digest — the live run parked at review, kicked from the build chat with days=14.
  // 周报:停在审阅的在途 run,从主对话以 days=14 发起。
  final digestParkedRun = Flowrun(
    id: frDigestParked,
    workflowId: wfDigest,
    versionId: '${wfDigest}_v2',
    pinnedRefs: digestPinnedRefs,
    origin: 'chat',
    conversationId: cvDigest,
    status: 'running',
    startedAt: parkedStart,
    updatedAt: parkedStart.add(const Duration(milliseconds: 81_950)),
  );
  final digestParkedDetail = digestDetail(digestParkedRun, parkedStart);

  // Triage — running at the agent node (ticket #4821, the refund one). 在途:agent 节点进行中。
  final triageStart = ago(minutes: 3, seconds: 42);
  final triageRunningRun = Flowrun(
    id: frTriageRunning,
    workflowId: wfTriage,
    versionId: '${wfTriage}_v1',
    pinnedRefs: {agTriage: '${agTriage}_v1', ctlSeverity: '${ctlSeverity}_v1'},
    triggerId: trgZendesk,
    firingId: 'trf_c3d4e5f607182903',
    origin: 'webhook',
    status: 'running',
    startedAt: triageStart,
    updatedAt: triageStart.add(const Duration(seconds: 2)),
  );
  final triageRunningDetail = FlowrunComposite(
    flowrun: triageRunningRun,
    workflowName: wfTriageName,
    nodes: [
      node(
        frTriageRunning,
        'on_ticket',
        'trigger',
        trgZendesk,
        'completed',
        created: triageStart,
        done: triageStart,
        result: const {
          'body': {
            'id': 4821,
            'subject': 'Charged twice for order ord_87990',
            'requester': {'email': 'mara@example.com'},
          },
        },
      ),
    ],
  );

  FlowrunComposite triageDone(
    String runId,
    String firingId,
    DateTime start,
    int agentSec,
    String severity,
    String summary,
    String tail,
    String tailRef,
  ) {
    DateTime s(int sec) => start.add(Duration(seconds: sec));
    final run = Flowrun(
      id: runId,
      workflowId: wfTriage,
      versionId: '${wfTriage}_v1',
      pinnedRefs: {
        agTriage: '${agTriage}_v1',
        ctlSeverity: '${ctlSeverity}_v1',
      },
      triggerId: trgZendesk,
      firingId: firingId,
      origin: 'webhook',
      status: 'completed',
      startedAt: start,
      completedAt: s(agentSec + 3),
      updatedAt: s(agentSec + 3),
    );
    return FlowrunComposite(
      flowrun: run,
      workflowName: wfTriageName,
      nodes: [
        node(
          runId,
          'on_ticket',
          'trigger',
          trgZendesk,
          'completed',
          created: start,
          done: start,
        ),
        node(
          runId,
          'triage',
          'agent',
          agTriage,
          'completed',
          ready: start,
          started: s(1),
          created: s(agentSec),
          done: s(agentSec),
          result: {'severity': severity, 'summary': summary},
        ),
        node(
          runId,
          'route_by_severity',
          'control',
          ctlSeverity,
          'completed',
          ready: s(agentSec),
          started: s(agentSec),
          created: s(agentSec),
          done: s(agentSec),
          result: {'__port': severity, 'severity': severity},
        ),
        node(
          runId,
          tail,
          'action',
          tailRef,
          'completed',
          ready: s(agentSec),
          started: s(agentSec + 1),
          created: s(agentSec + 3),
          done: s(agentSec + 3),
          result: tail == 'notify_oncall'
              ? const {'ts': '1789421500.004100'}
              : const {'rowcount': 1},
        ),
      ],
    );
  }

  final triageDone1Detail = triageDone(
    frTriageDone1,
    'trf_d4e5f60718293a04',
    ago(hours: 6, minutes: 22, seconds: 30),
    20,
    'urgent',
    'Ticket #4819 — checkout returns 502 for EU customers since 02:10 UTC',
    'notify_oncall',
    '$hdSlack.post_message',
  );
  final triageDone2Detail = triageDone(
    frTriageDone2,
    'trf_e5f60718293a4b05',
    ago(hours: 9, minutes: 5, seconds: 10),
    10,
    'normal',
    'Ticket #4817 — how-to question about data export',
    'file_ticket',
    '$hdPostgres.query',
  );

  // Invoice — failed this afternoon at parse (env broken); done 9 days ago on v2. 发票:今下午解析失败。
  final invFailStart = ago(hours: 5, minutes: 40, seconds: 12);
  DateTime ifs(int s) => invFailStart.add(Duration(seconds: s));
  final invoiceFailedRun = Flowrun(
    id: frInvoiceFailed,
    workflowId: wfInvoice,
    versionId: '${wfInvoice}_v1',
    pinnedRefs: {fnParseInvoice: '${fnParseInvoice}_v3'},
    triggerId: trgInvoices,
    firingId: 'trf_f60718293a4b5c06',
    origin: 'fsnotify',
    status: 'failed',
    error: "parse_invoice: ModuleNotFoundError: No module named 'pdfplumber'",
    startedAt: invFailStart,
    completedAt: ifs(2),
    updatedAt: ifs(2),
  );
  final invoiceFailedDetail = FlowrunComposite(
    flowrun: invoiceFailedRun,
    workflowName: wfInvoiceName,
    nodes: [
      node(
        frInvoiceFailed,
        'on_invoice',
        'trigger',
        trgInvoices,
        'completed',
        created: invFailStart,
        done: invFailStart,
        result: const {
          'path': '/Users/you/Documents/Invoices/acme-2026-0912.pdf',
          'event': 'create',
        },
      ),
      node(
        frInvoiceFailed,
        'parse_invoice',
        'action',
        fnParseInvoice,
        'failed',
        ready: invFailStart,
        started: ifs(1),
        created: ifs(2),
        done: ifs(2),
        error: _parseInvoiceTraceback.trim(),
      ),
    ],
  );

  final invDoneStart = ago(days: 9, hours: 3, seconds: 8);
  DateTime ids(int s) => invDoneStart.add(Duration(seconds: s));
  final invoiceDoneRun = Flowrun(
    id: frInvoiceDone,
    workflowId: wfInvoice,
    versionId: '${wfInvoice}_v1',
    pinnedRefs: {fnParseInvoice: '${fnParseInvoice}_v2'},
    triggerId: trgInvoices,
    firingId: 'trf_0718293a4b5c6d07',
    origin: 'fsnotify',
    status: 'completed',
    startedAt: invDoneStart,
    completedAt: ids(6),
    updatedAt: ids(6),
  );
  final invoiceDoneDetail = FlowrunComposite(
    flowrun: invoiceDoneRun,
    workflowName: wfInvoiceName,
    nodes: [
      node(
        frInvoiceDone,
        'on_invoice',
        'trigger',
        trgInvoices,
        'completed',
        created: invDoneStart,
        done: invDoneStart,
        result: const {
          'path': '/Users/you/Documents/Invoices/northwind-2026-0903.pdf',
          'event': 'create',
        },
      ),
      node(
        frInvoiceDone,
        'parse_invoice',
        'action',
        fnParseInvoice,
        'completed',
        ready: invDoneStart,
        started: ids(1),
        created: ids(3),
        done: ids(3),
        result: const {'invoiceNumber': 'NW-2026-1187', 'total': 1284.50},
      ),
      node(
        frInvoiceDone,
        'store_invoice',
        'action',
        '$hdPostgres.query',
        'completed',
        ready: ids(3),
        started: ids(3),
        created: ids(4),
        done: ids(4),
        result: const {'rowcount': 1},
      ),
      node(
        frInvoiceDone,
        'notify_finance',
        'action',
        '$hdSlack.post_message',
        'completed',
        ready: ids(4),
        started: ids(5),
        created: ids(6),
        done: ids(6),
        result: const {'ts': '1788652800.117300'},
      ),
    ],
  );

  // Release — one manual dry run from the release-notes chat. 发布线:从聊天手动试跑一次。
  final relStart = ago(days: 3, hours: -1, minutes: -3);
  DateTime rs(int s) => relStart.add(Duration(seconds: s));
  final releaseDoneRun = Flowrun(
    id: frReleaseDone,
    workflowId: wfRelease,
    versionId: '${wfRelease}_v1',
    pinnedRefs: {
      fnFetchGithub: '${fnFetchGithub}_v2',
      agReleaseNotes: '${agReleaseNotes}_v1',
      fnPrepareDoc: '${fnPrepareDoc}_v1',
    },
    origin: 'chat',
    conversationId: cvReleaseNotes,
    status: 'completed',
    startedAt: relStart,
    completedAt: rs(52),
    updatedAt: rs(52),
  );
  final releaseDoneDetail = FlowrunComposite(
    flowrun: releaseDoneRun,
    workflowName: wfReleaseName,
    nodes: [
      node(
        frReleaseDone,
        'collect_changes',
        'action',
        fnFetchGithub,
        'completed',
        ready: relStart,
        started: rs(0),
        created: rs(2),
        done: rs(2),
        result: const {'commitCount': 32},
      ),
      node(
        frReleaseDone,
        'write_notes',
        'agent',
        agReleaseNotes,
        'completed',
        ready: rs(2),
        started: rs(3),
        created: rs(46),
        done: rs(46),
        result: const {'headline': 'Anselm 0.2.0', 'notes': '## Added …'},
      ),
      node(
        frReleaseDone,
        'prepare_doc',
        'action',
        fnPrepareDoc,
        'completed',
        ready: rs(46),
        started: rs(47),
        created: rs(48),
        done: rs(48),
        result: const {'slug': 'release-0-2-0'},
      ),
      node(
        frReleaseDone,
        'announce',
        'action',
        '$hdSlack.post_message',
        'completed',
        ready: rs(48),
        started: rs(49),
        created: rs(52),
        done: rs(52),
        result: const {'ts': '1789000000.310200'},
      ),
    ],
  );

  final flowrunDetail = <String, FlowrunComposite>{
    frDigestParked: digestParkedDetail,
    frDigestRejected: digestRejectedDetail,
    frDigestFailed: digestFailedDetail,
    frTriageRunning: triageRunningDetail,
    frTriageDone1: triageDone1Detail,
    frTriageDone2: triageDone2Detail,
    frInvoiceFailed: invoiceFailedDetail,
    frInvoiceDone: invoiceDoneDetail,
    frReleaseDone: releaseDoneDetail,
  };

  final flowruns = <String, List<Flowrun>>{
    wfDigest: [digestParkedRun, digestRejectedRun, digestFailedRun],
    wfTriage: [
      triageRunningRun,
      triageDone1Detail.flowrun,
      triageDone2Detail.flowrun,
    ],
    wfInvoice: [invoiceFailedRun, invoiceDoneRun],
    wfRelease: [releaseDoneRun],
  };

  // Activity rows = the audit-table union the Gantt draws exec segments from. 甘特执行段来源。
  FlowrunActivityRow fetchRow(
    String id,
    DateTime runStart,
    String kind, {
    bool failed = false,
  }) {
    final (startMs, endMs) = fetchWindow[kind]!;
    return FlowrunActivityRow(
      nodeId: 'fetch_$kind',
      kind: 'function',
      execId: id,
      status: failed ? 'failed' : 'ok',
      readyAt: runStart,
      startedAt: runStart.add(Duration(milliseconds: startMs)),
      endedAt: runStart.add(Duration(milliseconds: endMs)),
      elapsedMs: endMs - startMs,
    );
  }

  FlowrunActivityRow writerRow(String id, DateTime runStart) =>
      FlowrunActivityRow(
        nodeId: 'write_digest',
        kind: 'agent',
        execId: id,
        status: 'ok',
        readyAt: runStart.add(const Duration(milliseconds: 1700)),
        startedAt: runStart.add(const Duration(milliseconds: 1800)),
        endedAt: runStart.add(const Duration(milliseconds: 81_800)),
        elapsedMs: 80_000,
      );

  final flowrunActivity = <String, List<FlowrunActivityRow>>{
    frDigestParked: [
      fetchRow('fne_c1d2e3f4a5b6c7d8', parkedStart, 'commits'),
      fetchRow('fne_c2d3e4f5a6b7c8d9', parkedStart, 'pulls'),
      fetchRow('fne_c3d4e5f6a7b8c9da', parkedStart, 'issues'),
      writerRow('agx_a1b2c3d4e5f60731', parkedStart),
    ],
    frDigestRejected: [
      fetchRow('fne_9a8b7c6d5e4f3a2b', rejectedStart, 'commits'),
      fetchRow('fne_9b8c7d6e5f4a3b2c', rejectedStart, 'pulls'),
      fetchRow('fne_9c8d7e6f5a4b3c2d', rejectedStart, 'issues'),
      writerRow('agx_b2c3d4e5f6071842', rejectedStart),
    ],
    frDigestFailed: [
      fetchRow('fne_1f2e3d4c5b6a7980', failedStart, 'commits', failed: true),
      fetchRow('fne_1a2b3c4d5e6f7a8b', failedStart, 'pulls'),
      fetchRow('fne_1b2c3d4e5f6a7b8c', failedStart, 'issues'),
    ],
  };

  // ───────────────────────── Control / approvals ─────────────────────────

  final severityVersion = ControlVersion(
    id: '${ctlSeverity}_v1',
    controlId: ctlSeverity,
    version: 1,
    inputs: [
      Field(
        name: 'severity',
        type: 'string',
        description: l.t(
          'urgent | refund | normal from the triage agent.',
          '分流 agent 给出的 urgent | refund | normal。',
        ),
      ),
      Field(
        name: 'refundAmount',
        type: 'number',
        description: l.t('Requested refund, null when none.', '申请退款额，无则 null。'),
      ),
    ],
    branches: const [
      Branch(port: 'urgent', when: 'input.severity == "urgent"'),
      Branch(
        port: 'refund',
        when: 'input.severity == "refund" && input.refundAmount > 0',
        emit: {'amount': 'input.refundAmount'},
      ),
      Branch(port: 'normal', when: 'true'),
    ],
    changeReason: l.t('Initial routing.', '初始路由。'),
    builtInConversationId: cvTriage,
    createdAt: ago(days: 11),
    updatedAt: ago(days: 11),
  );

  // check_activity — the empty-week gate: any activity at all goes to review, a dead-quiet window
  // posts a short Slack notice instead of waking the reviewer for a blank digest.
  // check_activity——空周门:有任何活动就送审,窗口一片死寂则只发一条短 Slack 通知,不为空周报叫醒审阅人。
  final emptyWeekVersion = ControlVersion(
    id: '${ctlEmptyWeek}_v1',
    controlId: ctlEmptyWeek,
    version: 1,
    inputs: [
      Field(
        name: 'commits',
        type: 'number',
        description: l.t('Commits in the window.', '窗口内的提交数。'),
      ),
      Field(
        name: 'pulls',
        type: 'number',
        description: l.t('Pull requests in the window.', '窗口内的 PR 数。'),
      ),
      Field(
        name: 'issues',
        type: 'number',
        description: l.t('Issues in the window.', '窗口内的 issue 数。'),
      ),
    ],
    branches: const [
      Branch(
        port: 'has_activity',
        when: 'input.commits > 0 || input.pulls > 0 || input.issues > 0',
        emit: {
          'commits': 'input.commits',
          'pulls': 'input.pulls',
          'issues': 'input.issues',
        },
      ),
      Branch(port: 'empty', when: 'true'),
    ],
    changeReason: l.t('Initial gate.', '初始门控。'),
    builtInConversationId: cvDigest,
    createdAt: digestV2At,
    updatedAt: digestV2At,
  );

  // The card renders the writer's `summary` (title + Summary paragraph + counts), never the whole
  // digest — every approval surface stays one screen. 审批卡只渲染写手的 summary,不放整篇周报,保持一屏。
  final digestApprovalVersion = ApprovalVersion(
    id: '${apfDigest}_v1',
    approvalId: apfDigest,
    version: 1,
    inputs: [
      Field(
        name: 'summary',
        type: 'string',
        description: l.t(
          'Title, Summary paragraph and counts from the writer.',
          '写手给出的标题、概览段落与计数。',
        ),
      ),
      Field(name: 'commits', type: 'number'),
      Field(name: 'period', type: 'string'),
    ],
    template: l.t(
      '{{ input.summary }}\n\nApprove to file it under **Weekly digests** and post it to Slack; reject with a note to send it back to the writer.',
      '{{ input.summary }}\n\n通过则归档到 **每周周报** 并发到 Slack；驳回并留言会退回写手。',
    ),
    allowReason: true,
    timeout: '48h',
    timeoutBehavior: 'reject',
    changeReason: l.t('Initial form.', '初始表单。'),
    builtInConversationId: cvDigest,
    createdAt: digestV2At,
    updatedAt: digestV2At,
  );

  final refundApprovalVersion = ApprovalVersion(
    id: '${apfRefund}_v1',
    approvalId: apfRefund,
    version: 1,
    inputs: [
      Field(name: 'ticketId', type: 'number'),
      Field(name: 'amount', type: 'number'),
      Field(name: 'customer', type: 'string'),
      Field(name: 'summary', type: 'string'),
    ],
    template: l.t(
      '### Refund **\${{ input.amount }}** to {{ input.customer }}?\n\nTicket #{{ input.ticketId }} — {{ input.summary }}\n\nApproving files the ticket as refunded; rejecting sends it back to a human agent.',
      '### 向 {{ input.customer }} 退款 **¥{{ input.amount }}**？\n\n工单 #{{ input.ticketId }} — {{ input.summary }}\n\n通过则记为已退款；驳回则交回人工客服。',
    ),
    allowReason: true,
    timeout: '24h',
    timeoutBehavior: 'reject',
    changeReason: l.t('Initial form.', '初始表单。'),
    builtInConversationId: cvTriage,
    createdAt: ago(days: 11),
    updatedAt: ago(days: 11),
  );

  // ───────────────────────── Triggers ─────────────────────────

  final triggerEntities = [
    TriggerEntity(
      id: trgMonday,
      name: trgMondayName,
      description: l.t('Every Monday at 09:00 local time.', '每周一本地时间 09:00。'),
      kind: TriggerSource.cron,
      config: const {'expression': '0 9 * * 1'},
      outputs: [
        Field(
          name: 'firedAt',
          type: 'string',
          description: l.t(
            'When the tick fired (RFC3339).',
            '刻度触发时刻（RFC3339）。',
          ),
        ),
      ],
      refCount: 1,
      listening: true,
      lastFiredAt: lastWeekMonday,
      nextFireAt: ahead(hours: 11),
      createdAt: ago(days: 20),
      updatedAt: ago(days: 20),
    ),
    TriggerEntity(
      id: trgZendesk,
      name: trgZendeskName,
      description: l.t(
        'Zendesk "ticket created" webhook, HMAC-signed.',
        'Zendesk「工单创建」webhook，HMAC 签名。',
      ),
      kind: TriggerSource.webhook,
      config: const {
        'path': 'zendesk/ticket-created',
        'signatureAlgo': 'hmac-sha256-base64',
        'signatureHeader': 'X-Zendesk-Webhook-Signature',
      },
      outputs: [
        Field(
          name: 'body',
          type: 'object',
          description: l.t(
            'The ticket JSON Zendesk posted.',
            'Zendesk 推送的工单 JSON。',
          ),
        ),
      ],
      refCount: 1,
      listening: true,
      lastFiredAt: ago(minutes: 3, seconds: 42),
      createdAt: ago(days: 11),
      updatedAt: ago(days: 11),
    ),
    TriggerEntity(
      id: trgInvoices,
      name: trgInvoicesName,
      description: l.t(
        'New PDFs in the Invoices folder.',
        'Invoices 目录里的新 PDF。',
      ),
      kind: TriggerSource.fsnotify,
      config: const {
        'path': '/Users/you/Documents/Invoices',
        'events': ['create'],
        'pattern': '*.pdf',
      },
      outputs: const [
        Field(name: 'path', type: 'string'),
        Field(name: 'event', type: 'string'),
      ],
      refCount: 1,
      listening: true,
      lastFiredAt: ago(hours: 5, minutes: 40, seconds: 12),
      createdAt: ago(days: 24),
      updatedAt: ago(days: 24),
    ),
    TriggerEntity(
      id: trgUptime,
      name: trgUptimeName,
      description: l.t(
        'Probe the support database every minute; fire when it stops answering.',
        '每分钟探测客服数据库，失联即触发。',
      ),
      kind: TriggerSource.sensor,
      config: const {
        'targetKind': 'handler',
        'targetId': hdPostgres,
        'method': 'health',
        'intervalSec': 60,
        'condition': '!output.ok || output.latencyMs > 500',
      },
      outputs: const [
        Field(name: 'ok', type: 'boolean'),
        Field(name: 'latencyMs', type: 'number'),
      ],
      refCount: 0,
      listening: true,
      lastFiredAt: ago(days: 4, hours: 2),
      createdAt: ago(days: 30),
      updatedAt: ago(days: 30),
    ),
  ];

  final activations = <String, List<Activation>>{
    trgMonday: [
      Activation(
        id: 'tra_a1b2c3d4e5f60711',
        triggerId: trgMonday,
        kind: TriggerSource.cron,
        fired: true,
        firingCount: 1,
        payload: const {'firedAt': '2026-09-07T09:00:00+08:00'},
        createdAt: lastWeekMonday,
      ),
      Activation(
        id: 'tra_b2c3d4e5f6071822',
        triggerId: trgMonday,
        kind: TriggerSource.cron,
        fired: true,
        firingCount: 1,
        payload: const {'firedAt': '2026-08-31T09:00:00+08:00'},
        createdAt: twoWeeksMonday,
      ),
    ],
    trgZendesk: [
      Activation(
        id: 'tra_d4e5f60718293a44',
        triggerId: trgZendesk,
        kind: TriggerSource.webhook,
        fired: true,
        firingCount: 1,
        payload: const {
          'body': {'id': 4821, 'subject': 'Charged twice for order ord_87990'},
        },
        createdAt: ago(minutes: 3, seconds: 42),
      ),
      Activation(
        id: 'tra_e5f60718293a4b55',
        triggerId: trgZendesk,
        kind: TriggerSource.webhook,
        fired: false,
        error: 'signature mismatch',
        detail: l.t(
          'X-Zendesk-Webhook-Signature did not verify — secret rotated?',
          'X-Zendesk-Webhook-Signature 校验失败——密钥轮换了？',
        ),
        createdAt: ago(hours: 1, minutes: 4),
      ),
      Activation(
        id: 'tra_f60718293a4b5c66',
        triggerId: trgZendesk,
        kind: TriggerSource.webhook,
        fired: true,
        firingCount: 1,
        payload: const {
          'body': {'id': 4819, 'subject': 'Checkout 502 for EU customers'},
        },
        createdAt: ago(hours: 6, minutes: 22, seconds: 30),
      ),
      Activation(
        id: 'tra_0718293a4b5c6d77',
        triggerId: trgZendesk,
        kind: TriggerSource.webhook,
        fired: true,
        firingCount: 1,
        payload: const {
          'body': {'id': 4819, 'subject': 'Checkout 502 for EU customers'},
        },
        detail: l.t('Zendesk retried the delivery.', 'Zendesk 重投了一次。'),
        createdAt: ago(hours: 6, minutes: 21, seconds: 50),
      ),
      Activation(
        id: 'tra_18293a4b5c6d7e88',
        triggerId: trgZendesk,
        kind: TriggerSource.webhook,
        fired: true,
        firingCount: 1,
        payload: const {
          'body': {'id': 4817, 'subject': 'How do I export my data?'},
        },
        createdAt: ago(hours: 9, minutes: 5, seconds: 10),
      ),
    ],
    trgInvoices: [
      Activation(
        id: 'tra_293a4b5c6d7e8f99',
        triggerId: trgInvoices,
        kind: TriggerSource.fsnotify,
        fired: true,
        firingCount: 1,
        payload: const {
          'path': '/Users/you/Documents/Invoices/acme-2026-0912.pdf',
          'event': 'create',
        },
        createdAt: ago(hours: 5, minutes: 40, seconds: 12),
      ),
      Activation(
        id: 'tra_3a4b5c6d7e8f90aa',
        triggerId: trgInvoices,
        kind: TriggerSource.fsnotify,
        fired: true,
        firingCount: 1,
        payload: const {
          'path': '/Users/you/Documents/Invoices/acme-2026-0912.pdf',
          'event': 'create',
        },
        detail: l.t(
          'Finder wrote the file twice (temp rename).',
          'Finder 写了两次（临时重命名）。',
        ),
        createdAt: ago(hours: 5, minutes: 40, seconds: 11),
      ),
      Activation(
        id: 'tra_4b5c6d7e8f90a1bb',
        triggerId: trgInvoices,
        kind: TriggerSource.fsnotify,
        fired: true,
        firingCount: 1,
        payload: const {
          'path': '/Users/you/Documents/Invoices/northwind-2026-0903.pdf',
          'event': 'create',
        },
        createdAt: ago(days: 9, hours: 3, seconds: 8),
      ),
    ],
    trgUptime: [
      Activation(
        id: 'tra_5c6d7e8f90a1b2cc',
        triggerId: trgUptime,
        kind: TriggerSource.sensor,
        fired: false,
        returnValue: const {'ok': true, 'latencyMs': 4},
        detail: l.t('condition evaluated false', '条件为假'),
        createdAt: ago(seconds: 35),
      ),
      Activation(
        id: 'tra_6d7e8f90a1b2c3dd',
        triggerId: trgUptime,
        kind: TriggerSource.sensor,
        fired: false,
        returnValue: const {'ok': true, 'latencyMs': 5},
        detail: l.t('condition evaluated false', '条件为假'),
        createdAt: ago(minutes: 1, seconds: 35),
      ),
      Activation(
        id: 'tra_7e8f90a1b2c3d4ee',
        triggerId: trgUptime,
        kind: TriggerSource.sensor,
        fired: true,
        firingCount: 0,
        returnValue: const {'ok': true, 'latencyMs': 812},
        detail: l.t(
          'condition held — no active workflow listens to this trigger',
          '条件成立——没有活跃工作流监听此触发器',
        ),
        createdAt: ago(days: 4, hours: 2),
      ),
    ],
  };

  final firings = <String, List<Firing>>{
    trgMonday: [
      Firing(
        id: 'trf_b2c3d4e5f6071802',
        triggerId: trgMonday,
        workflowId: wfDigest,
        workflowName: wfDigestName,
        activationId: 'tra_a1b2c3d4e5f60711',
        payload: const {
          'firedAt': '2026-09-07T09:00:00+08:00',
          'days': '14',
          'period': 'Aug 24 – Sep 6, 2026',
        },
        dedupKey: 'cron:2026-09-07T09:00',
        status: FiringStatus.started,
        flowrunId: frDigestFailed,
        createdAt: lastWeekMonday,
        updatedAt: lastWeekMonday,
      ),
      // Skipped by the workflow's `skip` overlap policy — a manual v2 shake-down run was still parked
      // at review when the tick fired. 被 skip 并发策略跳过——刻度触发时,一次手动试跑还停在审阅。
      Firing(
        id: 'trf_a1b2c3d4e5f60701',
        triggerId: trgMonday,
        workflowId: wfDigest,
        workflowName: wfDigestName,
        activationId: 'tra_b2c3d4e5f6071822',
        payload: const {
          'firedAt': '2026-08-31T09:00:00+08:00',
          'days': '14',
          'period': 'Aug 17 – Aug 30, 2026',
        },
        dedupKey: 'cron:2026-08-31T09:00',
        status: FiringStatus.skipped,
        createdAt: twoWeeksMonday,
        updatedAt: twoWeeksMonday,
      ),
    ],
    trgZendesk: [
      Firing(
        id: 'trf_c3d4e5f607182903',
        triggerId: trgZendesk,
        workflowId: wfTriage,
        workflowName: wfTriageName,
        activationId: 'tra_d4e5f60718293a44',
        payload: const {
          'body': {'id': 4821},
        },
        dedupKey: 'zendesk:4821',
        status: FiringStatus.started,
        flowrunId: frTriageRunning,
        createdAt: ago(minutes: 3, seconds: 42),
        updatedAt: ago(minutes: 3, seconds: 42),
      ),
      Firing(
        id: 'trf_d4e5f60718293a04',
        triggerId: trgZendesk,
        workflowId: wfTriage,
        workflowName: wfTriageName,
        activationId: 'tra_f60718293a4b5c66',
        payload: const {
          'body': {'id': 4819},
        },
        dedupKey: 'zendesk:4819',
        status: FiringStatus.started,
        flowrunId: frTriageDone1,
        createdAt: ago(hours: 6, minutes: 22, seconds: 30),
        updatedAt: ago(hours: 6, minutes: 22, seconds: 30),
      ),
      // The Zendesk retry carried the same dedup key → deduped, no second run. 重投同 dedupKey → 去重。
      Firing(
        id: 'trf_e5f60718293a4b00',
        triggerId: trgZendesk,
        workflowId: wfTriage,
        workflowName: wfTriageName,
        activationId: 'tra_0718293a4b5c6d77',
        payload: const {
          'body': {'id': 4819},
        },
        dedupKey: 'zendesk:4819',
        status: FiringStatus.superseded,
        createdAt: ago(hours: 6, minutes: 21, seconds: 50),
        updatedAt: ago(hours: 6, minutes: 21, seconds: 50),
      ),
      Firing(
        id: 'trf_e5f60718293a4b05',
        triggerId: trgZendesk,
        workflowId: wfTriage,
        workflowName: wfTriageName,
        activationId: 'tra_18293a4b5c6d7e88',
        payload: const {
          'body': {'id': 4817},
        },
        dedupKey: 'zendesk:4817',
        status: FiringStatus.started,
        flowrunId: frTriageDone2,
        createdAt: ago(hours: 9, minutes: 5, seconds: 10),
        updatedAt: ago(hours: 9, minutes: 5, seconds: 10),
      ),
    ],
    trgInvoices: [
      Firing(
        id: 'trf_f60718293a4b5c06',
        triggerId: trgInvoices,
        workflowId: wfInvoice,
        workflowName: wfInvoiceName,
        activationId: 'tra_293a4b5c6d7e8f99',
        payload: const {
          'path': '/Users/you/Documents/Invoices/acme-2026-0912.pdf',
        },
        dedupKey: 'fs:acme-2026-0912.pdf',
        status: FiringStatus.started,
        flowrunId: frInvoiceFailed,
        createdAt: ago(hours: 5, minutes: 40, seconds: 12),
        updatedAt: ago(hours: 5, minutes: 40, seconds: 12),
      ),
      Firing(
        id: 'trf_0718293a4b5c6d00',
        triggerId: trgInvoices,
        workflowId: wfInvoice,
        workflowName: wfInvoiceName,
        activationId: 'tra_3a4b5c6d7e8f90aa',
        payload: const {
          'path': '/Users/you/Documents/Invoices/acme-2026-0912.pdf',
        },
        dedupKey: 'fs:acme-2026-0912.pdf',
        status: FiringStatus.skipped,
        createdAt: ago(hours: 5, minutes: 40, seconds: 11),
        updatedAt: ago(hours: 5, minutes: 40, seconds: 11),
      ),
      Firing(
        id: 'trf_0718293a4b5c6d07',
        triggerId: trgInvoices,
        workflowId: wfInvoice,
        workflowName: wfInvoiceName,
        activationId: 'tra_4b5c6d7e8f90a1bb',
        payload: const {
          'path': '/Users/you/Documents/Invoices/northwind-2026-0903.pdf',
        },
        dedupKey: 'fs:northwind-2026-0903.pdf',
        status: FiringStatus.started,
        flowrunId: frInvoiceDone,
        createdAt: ago(days: 9, hours: 3, seconds: 8),
        updatedAt: ago(days: 9, hours: 3, seconds: 8),
      ),
    ],
  };

  // ───────────────────────── Assemble ─────────────────────────

  return FixtureEntityRepository(
    relGraph: storyRelGraph(l),
    functions: functions,
    handlers: handlers,
    agents: agents,
    workflows: workflows,
    functionVersions: {
      fnFetchGithub: [fetchGithubVer(2), fetchGithubVer(1)],
      fnPrepareDoc: [prepareDocVer],
      fnParseInvoice: [
        parseInvoiceVer(3, 'failed', error: _parseInvoiceEnvError),
        parseInvoiceVer(2, 'ready'),
        parseInvoiceVer(1, 'ready'),
      ],
      fnResizeImage: [resizeImageVer],
    },
    handlerVersions: {
      hdSlack: [slackVer(2), slackVer(1)],
      hdPostgres: [postgresVer],
    },
    agentVersions: {
      agDigest: [digestVer(2), digestVer(1)],
      agTriage: [triageVer],
      agReleaseNotes: [releaseNotesVer],
    },
    workflowVersions: {
      wfDigest: [digestV2, digestV1],
      wfTriage: [triageV1],
      wfInvoice: [invoiceV1],
      wfRelease: [releaseV1],
    },
    controlVersions: {
      ctlSeverity: [severityVersion],
      ctlEmptyWeek: [emptyWeekVersion],
    },
    approvalVersions: {
      apfDigest: [digestApprovalVersion],
      apfRefund: [refundApprovalVersion],
    },
    functionExecutions: functionExecutions,
    handlerCalls: handlerCalls,
    agentExecutions: agentExecutions,
    flowruns: flowruns,
    flowrunDetail: flowrunDetail,
    flowrunActivity: flowrunActivity,
    mountHealth: {
      agDigest: MountHealthReport(
        mounts: [
          const MountHealth(
            ref: fnFetchGithub,
            name: 'fetch-github',
            healthy: true,
          ),
          MountHealth(
            ref: 'mcp:web/search',
            name: 'web-search',
            healthy: false,
            error: l.t(
              'MCP server "web" is not configured in this workspace — the agent falls back to the activity bundle.',
              'MCP 服务器「web」未在此 workspace 配置——agent 退回只用活动包。',
            ),
          ),
        ],
        allHealthy: false,
      ),
      agTriage: const MountHealthReport(
        mounts: [
          MountHealth(
            ref: '$hdPostgres.query',
            name: 'db-query',
            healthy: true,
          ),
          MountHealth(
            ref: '$hdSlack.post_message',
            name: 'slack-post',
            healthy: true,
          ),
        ],
        allHealthy: true,
      ),
      agReleaseNotes: const MountHealthReport(
        mounts: [
          MountHealth(ref: fnFetchGithub, name: 'fetch-github', healthy: true),
          MountHealth(
            ref: 'mcp:github/list_pull_requests',
            name: 'list-prs',
            healthy: true,
          ),
        ],
        allHealthy: true,
      ),
    },
    mcpServers: const [
      (id: 'github', name: 'github', meta: 'ready'),
      (id: 'filesystem', name: 'filesystem', meta: 'ready'),
    ],
    mcpTools: const {
      'github': [
        (id: 'list_pull_requests', name: 'list_pull_requests', meta: 'github'),
        (id: 'search_issues', name: 'search_issues', meta: 'github'),
        (id: 'get_file_contents', name: 'get_file_contents', meta: 'github'),
        (id: 'create_issue', name: 'create_issue', meta: 'github'),
      ],
      'filesystem': [
        (id: 'read_file', name: 'read_file', meta: 'filesystem'),
        (id: 'write_file', name: 'write_file', meta: 'filesystem'),
        (id: 'list_directory', name: 'list_directory', meta: 'filesystem'),
      ],
    },
    triggers: const [
      (id: trgMonday, name: trgMondayName, meta: 'cron'),
      (id: trgZendesk, name: trgZendeskName, meta: 'webhook'),
      (id: trgInvoices, name: trgInvoicesName, meta: 'fsnotify'),
      (id: trgUptime, name: trgUptimeName, meta: 'sensor'),
    ],
    controls: const [
      (id: ctlSeverity, name: ctlSeverityName, meta: null),
      (id: ctlEmptyWeek, name: ctlEmptyWeekName, meta: null),
    ],
    approvals: const [
      (id: apfDigest, name: apfDigestName, meta: null),
      (id: apfRefund, name: apfRefundName, meta: null),
    ],
    controlLogics: [
      ControlLogic(
        id: ctlSeverity,
        name: ctlSeverityName,
        description: l.t(
          'Route a triaged ticket: urgent → on-call, refund → approval, else file.',
          '按分流结果路由：urgent → 值班，refund → 审批，其余入库。',
        ),
        activeVersionId: '${ctlSeverity}_v1',
        createdAt: ago(days: 11),
        updatedAt: ago(days: 11),
        activeVersion: severityVersion,
      ),
      ControlLogic(
        id: ctlEmptyWeek,
        name: ctlEmptyWeekName,
        description: l.t(
          'Gate the weekly digest: any commits, PRs or issues → review; nothing at all → a short Slack notice.',
          '周报门控：有任何提交、PR 或 issue → 送审；一片空白 → 只发一条短 Slack 通知。',
        ),
        activeVersionId: '${ctlEmptyWeek}_v1',
        createdAt: digestV2At,
        updatedAt: digestV2At,
        activeVersion: emptyWeekVersion,
      ),
    ],
    approvalForms: [
      ApprovalForm(
        id: apfDigest,
        name: apfDigestName,
        description: l.t(
          'Human sign-off on the Monday digest before it is filed and posted.',
          '周一周报归档并发出前的人工签核。',
        ),
        activeVersionId: '${apfDigest}_v1',
        createdAt: digestV2At,
        updatedAt: digestV2At,
        activeVersion: digestApprovalVersion,
      ),
      ApprovalForm(
        id: apfRefund,
        name: apfRefundName,
        description: l.t(
          'Confirm a refund the triage agent recommends.',
          '确认分流 agent 建议的退款。',
        ),
        activeVersionId: '${apfRefund}_v1',
        createdAt: ago(days: 11),
        updatedAt: ago(days: 11),
        activeVersion: refundApprovalVersion,
      ),
    ],
    triggerEntities: triggerEntities,
    activations: activations,
    firings: firings,
    handlerConfigs: {
      hdSlack: HandlerConfig(
        config: const {'token': '********', 'channel': '#product-team'},
        configState: 'ready',
        schema: slackVer(2).initArgsSchema,
      ),
      hdPostgres: HandlerConfig(
        config: const {'dsn': '********', 'schema': 'support'},
        configState: 'ready',
        schema: postgresVer.initArgsSchema,
      ),
    },
  );
}

/// The story relation snapshot — the Entities overview graph. Two hubs (fetch_github_activity feeds the
/// digest agent, the digest workflow, the release agent and the release workflow; slack_notifier is
/// equipped by all four workflows and one agent), both controls, document/skill/mcp accessory nodes,
/// and conversation provenance so the "show provenance" toggle reveals which chats built what.
///
/// story 关系快照——实体总览图。两个枢纽（fetch_github_activity 与 slack_notifier）、两个控制节点、
/// 文档/技能/MCP 配件节点，以及对话溯源边，打开「显示溯源」能看到哪次聊天造了什么。
EntityRelGraph storyRelGraph(StoryLocale l) {
  var seq = 0;
  final edges = <EntityRelation>[];
  final names = <String, ({String kind, String name})>{};
  void note(String kind, String id, String name) =>
      names[id] = (kind: kind, name: name);
  void edge(String verb, String fromId, String toId) {
    final from = names[fromId]!;
    final to = names[toId]!;
    edges.add(
      EntityRelation(
        id: 'rel_${(seq++).toRadixString(16).padLeft(16, '0')}',
        kind: verb,
        fromKind: from.kind,
        fromId: fromId,
        fromName: from.name,
        toKind: to.kind,
        toId: toId,
        toName: to.name,
      ),
    );
  }

  note('function', fnFetchGithub, fnFetchGithubName);
  note('function', fnPrepareDoc, fnPrepareDocName);
  note('function', fnParseInvoice, fnParseInvoiceName);
  note('handler', hdSlack, hdSlackName);
  note('handler', hdPostgres, hdPostgresName);
  note('agent', agDigest, agDigestName);
  note('agent', agTriage, agTriageName);
  note('agent', agReleaseNotes, agReleaseNotesName);
  note('workflow', wfDigest, wfDigestName);
  note('workflow', wfTriage, wfTriageName);
  note('workflow', wfInvoice, wfInvoiceName);
  note('workflow', wfRelease, wfReleaseName);
  note('control', ctlSeverity, ctlSeverityName);
  note('control', ctlEmptyWeek, ctlEmptyWeekName);
  note('approval', apfDigest, apfDigestName);
  note('approval', apfRefund, apfRefundName);
  note('trigger', trgMonday, trgMondayName);
  note('trigger', trgZendesk, trgZendeskName);
  note('trigger', trgInvoices, trgInvoicesName);
  note('skill', skillGithubDigest, skillGithubDigest);
  note('mcp', 'github', 'github');
  note('document', docDigestLatest, docDigestLatestTitle(l));
  note('document', docDigestPrev, docDigestPrevTitle(l));
  note('conversation', cvDigest, cvDigestTitle(l));
  note('conversation', cvTriage, cvTriageTitle(l));

  // Structural edges (equip / link). 结构边。
  edge('equip', wfDigest, trgMonday);
  edge('equip', wfDigest, fnFetchGithub);
  edge('equip', wfDigest, agDigest);
  edge('equip', wfDigest, ctlEmptyWeek);
  edge('equip', wfDigest, apfDigest);
  edge('equip', wfDigest, fnPrepareDoc);
  edge('equip', wfDigest, hdSlack);
  edge('equip', wfTriage, trgZendesk);
  edge('equip', wfTriage, agTriage);
  edge('equip', wfTriage, ctlSeverity);
  edge('equip', wfTriage, apfRefund);
  edge('equip', wfTriage, hdSlack);
  edge('equip', wfTriage, hdPostgres);
  edge('equip', wfInvoice, trgInvoices);
  edge('equip', wfInvoice, fnParseInvoice);
  edge('equip', wfInvoice, hdPostgres);
  edge('equip', wfInvoice, hdSlack);
  edge('equip', wfRelease, fnFetchGithub);
  edge('equip', wfRelease, agReleaseNotes);
  edge('equip', wfRelease, fnPrepareDoc);
  edge('equip', wfRelease, hdSlack);
  edge('equip', agDigest, fnFetchGithub);
  edge('equip', agDigest, skillGithubDigest);
  edge('equip', agTriage, hdPostgres);
  edge('equip', agTriage, hdSlack);
  edge('equip', agReleaseNotes, fnFetchGithub);
  edge('equip', agReleaseNotes, 'github');
  edge('link', agDigest, docDigestPrev);
  edge(
    'link',
    docDigestLatest,
    wfDigest,
  ); // the digest page's [[wf]] wikilink 周报页的 wikilink
  edge('link', docDigestLatest, docDigestPrev);

  // Provenance edges (create / edit) — behind the "show provenance" toggle. 溯源边。
  edge('create', cvDigest, wfDigest);
  edge('create', cvDigest, fnFetchGithub);
  edge('create', cvDigest, fnPrepareDoc);
  edge('create', cvDigest, agDigest);
  edge('create', cvDigest, ctlEmptyWeek);
  edge('create', cvDigest, apfDigest);
  edge('edit', cvDigest, fnFetchGithub);
  edge('create', cvTriage, wfTriage);
  edge('create', cvTriage, agTriage);
  edge('create', cvTriage, ctlSeverity);
  edge('create', cvTriage, apfRefund);

  return EntityRelGraph(
    nodes: [
      for (final e in names.entries)
        EntityNode(kind: e.value.kind, id: e.key, name: e.value.name),
    ],
    edges: edges,
  );
}
