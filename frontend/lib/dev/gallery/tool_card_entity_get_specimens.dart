import 'package:flutter/widgets.dart';
import 'package:anselm/core/design/tokens.dart';

import '../../core/model/status_state.dart';
import '../../core/ui/an_chip.dart';
import '../../core/ui/an_kv.dart';
import '../../features/chat/ui/tool_card_entity_get.dart';
import 'specimen.dart';

// EntityGetBody four-part skeleton (B3.4, WRK-056 #31) — ① identity row ② KV vitals (row-level mono
// for the signature) ③ code content window (folded) ④ raw-result disclosure. F06 get 卡的四段骨架。

const _code = 'def fetch_with_retry(url, tries=5):\n'
    '    delay = 1\n'
    '    for i in range(tries):\n'
    '        try:\n'
    '            return http_get(url)\n'
    '        except TimeoutError:\n'
    '            time.sleep(delay); delay *= 2\n';

const _raw = '{"id":"fn_1a2b3c4d5e6f7a8b","name":"fetch_with_retry","description":"指数退避重试,最多 5 次",'
    '"tags":["net","io"],"activeVersionId":"fnv_11223344","updatedAt":"2026-07-01T09:00:00Z",'
    '"activeVersion":{"version":3,"envStatus":"ready","pythonVersion":"3.12","dependencies":["requests==2.31"],'
    '"inputs":[{"name":"url","type":"string"}],"outputs":[{"name":"body","type":"string"}]}}';

final toolCardEntityGetGalleryItem = GalleryItem(
  'EntityGetBody 四段骨架(#31)',
  'F06 get 卡四段:① 身份行(可点 pill + mono id + vN·updated 右缘)② KV 命脉(行级 mono——签名/依赖走等宽、'
      'description 换行散文)③ 大内容折叠窗(代码 reading 档,>50 行折叠 + >6000 字截头注记)④ 原始返回披露(未过滤全量 JSON)。',
  [
    GallerySpecimen(
        'get_function · 四段全款(身份/KV 混排 mono/代码窗/原始底账)',
        (c) => EntityGetBody(
              header: const ToolEntityHeader(
                  kind: 'function', name: 'fetch_with_retry', id: 'fn_1a2b3c4d5e6f7a8b', meta: 'v3 · 2026-07-01 09:00'),
              badges: Wrap(spacing: AnGap.inline, children: const [AnChip('env ready', tone: AnTone.ok)]),
              kv: const AnKv(rows: [
                AnKvRow('描述', '指数退避重试,最多 5 次', wrap: true),
                AnKvRow('签名', 'url:string → body:string', mono: true), // row-level mono
                AnKvRow('依赖', 'requests==2.31', mono: true), // row-level mono
                AnKvRow('Python', '3.12'), // prose value in the SAME list
                AnKvRow('更新', '2026-07-01 09:00', meta: true),
              ]),
              content: const [EntityCodeWindow(code: _code, lang: 'python')],
              rawJson: _raw,
            ),
        span: true),
  ],
);
