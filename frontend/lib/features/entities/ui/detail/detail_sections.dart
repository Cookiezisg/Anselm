import 'package:flutter/widgets.dart';

import '../../../../core/contract/entities/values.dart';
import '../../../../core/ui/an_field.dart';
import '../../../../core/ui/an_kv.dart';
import '../../../../core/ui/an_section.dart';
import '../../../../core/ui/an_state.dart';

/// Small shared builders the four per-kind overviews compose, so KV/field/empty rendering is written
/// once. Pure presentation over the verified kit (AnKv / AnField / AnState). 概览共享小构件(KV/字段/空)。

/// The read-only IDENTITY section shared by the agent + handler overviews — an optional wrapped
/// description field ([descLabel]/[desc]) over an id/version/… KV list. i18n-free like its siblings, so
/// the caller passes the localized description label. 只读身份段(agent/handler 概览共用):可选说明字段 + KV 列。
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

/// A typed-field list (fn/hd/ag inputs+outputs) → `name : type · description`. 字段列表。
Widget fieldList(List<Field> fields, {required String emptyTitle}) =>
    fields.isEmpty
    ? insetEmpty(emptyTitle)
    : AnKv(
        rows: [
          for (final f in fields)
            AnKvRow(
              f.name,
              '${f.type}${f.description != null && f.description!.isNotEmpty ? ' · ${f.description}' : ''}',
              wrap: true,
            ),
        ],
      );

/// An inset empty placeholder for an empty section/card (no deps / no tools / no IO …). 段内空占位。
Widget insetEmpty(String title) =>
    AnState(kind: AnStateKind.empty, title: title, size: AnStateSize.inset);
