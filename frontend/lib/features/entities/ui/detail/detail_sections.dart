import 'package:flutter/widgets.dart';

import '../../../../core/contract/entities/values.dart';
import '../../../../core/ui/an_field.dart';
import '../../../../core/ui/an_kv.dart';
import '../../../../core/ui/an_section.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../i18n/strings.g.dart';

/// Small shared builders the four per-kind overviews compose, so KV/field/empty rendering is written
/// once. Pure presentation over the verified kit (AnKv / AnField / AnState). 概览共享小构件(KV/字段/空)。

/// The read-only IDENTITY section used by agent and support overviews — an optional wrapped
/// description field ([descLabel]/[desc]) over an id/version/… KV list. Executable entity overviews
/// with a PATCH meta surface use [AnKv] directly. 只读身份段供 agent 与支撑实体概览使用;可 PATCH
/// meta 的可执行实体直接使用 [AnKv]。
Widget identitySection(
  String descLabel,
  String desc,
  List<(String, String?)> rows,
) => AnSection(
  variant: AnSectionVariant.plain,
  children: [
    if (desc.isNotEmpty) AnField(label: descLabel, value: desc, wrap: true),
    // Identity rows (id / vN / updated) are METADATA — the chrome 13 value tier inside the
    // content page (the locked two-tier). 身份行(id/vN/更新时间)=元数据,内容页内守 13 值档。
    kvList(rows, meta: true),
  ],
);

/// A read-only key/value definition list from `(label, value)` tuples — `value: null` rows are dropped.
/// `wrap` is now per-row on AnKvRow (read-only long values); this helper applies it to every row.
/// [meta] marks the whole list as metadata (id/timestamps/counts — 13 value tier inside content);
/// [dense] opts into the chrome tier wholesale (operational panels, the run cockpit).
/// KV 定义列表(label 左 value 右),空值行剔除;wrap 已是行级参数,此处统一施加。meta=整列元数据(13 档);
/// dense=chrome 档(操作面板)。
Widget kvList(
  List<(String, String?)> rows, {
  bool mono = false,
  bool wrap = false,
  bool meta = false,
  bool dense = false,
}) => AnKv(
  mono: mono,
  dense: dense,
  rows: [
    for (final (label, value) in rows)
      if (value != null && value.isNotEmpty)
        AnKvRow(label, value, wrap: wrap, meta: meta),
  ],
);

/// A typed-field list (fn/hd/ag/ctl/apf inputs+outputs) → `name : type · description`. An empty list
/// is ONE row on the SAME [AnKv] grammar as the populated rows — keyed by [emptyLabel] (the caller's
/// own section/card title, e.g. "Inputs") with the value left null so [AnKvRow] renders its own
/// em-dash (WRK-077 ⑫ — retired the inbox-icon tombstone that used to stand in here). 字段列表;空表
/// 降级为同一套 AnKv 文法的一行(标签=调用方自己的段/卡标题,值留空由 AnKvRow 自出 —),不再起大块空态。
Widget fieldList(List<Field> fields, {required String emptyLabel}) => AnKv(
  rows: fields.isEmpty
      ? [AnKvRow(emptyLabel, null)]
      : [
          for (final f in fields)
            AnKvRow(
              f.name,
              '${f.type}${f.description != null && f.description!.isNotEmpty ? ' · ${f.description}' : ''}',
              wrap: true,
            ),
        ],
);

/// The shared guide for "this entity has no active version yet" (WRK-077 ⑫ — ONE generic message
/// for all six rail/support kinds, not per-kind copy — 拍板). No action: creating a version has no
/// reachable entry point from this UI for any of the six kinds today (function/handler/agent version
/// content is AI-only + read-only by decree; control/approval/workflow carry no create-version
/// affordance either) — so this stays text-only guidance rather than a button that goes nowhere.
/// 无活动版本引导(六种实体共用同一套文案);当前无入口可达,故只渲引导文案、不造假按钮。
Widget noVersionGuide(BuildContext context) {
  final d = context.t.entities.detail;
  return AnState(
    kind: AnStateKind.empty,
    size: AnStateSize.inset,
    title: d.state.createFirstVersion,
    hint: d.state.createFirstVersionHint,
  );
}
