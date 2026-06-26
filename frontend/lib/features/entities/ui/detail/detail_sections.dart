import 'package:flutter/widgets.dart';

import '../../../../core/contract/entities/values.dart';
import '../../../../core/ui/an_field.dart';
import '../../../../core/ui/an_state.dart';

/// Small shared builders the four per-kind overviews compose, so KV/field/empty rendering is written
/// once. Pure presentation over the verified kit (AnKv / AnField / AnState). 概览共享小构件(KV/字段/空)。

/// A read-only key/value definition list from `(label, value)` tuples — `value: null` rows are dropped.
/// KV 定义列表(label 左 value 右),空值行剔除。
Widget kvList(List<(String, String?)> rows, {bool mono = false, bool wrap = false}) => AnKv(
      mono: mono,
      wrap: wrap,
      rows: [
        for (final (label, value) in rows)
          if (value != null && value.isNotEmpty) AnKvRow(label, value),
      ],
    );

/// A typed-field list (fn/hd/ag inputs+outputs) → `name : type · description`. 字段列表。
Widget fieldList(List<Field> fields, {required String emptyTitle}) => fields.isEmpty
    ? insetEmpty(emptyTitle)
    : AnKv(
        wrap: true,
        rows: [
          for (final f in fields)
            AnKvRow(f.name, '${f.type}${f.description != null && f.description!.isNotEmpty ? ' · ${f.description}' : ''}'),
        ],
      );

/// An inset empty placeholder for an empty section/card (no deps / no tools / no IO …). 段内空占位。
Widget insetEmpty(String title) =>
    AnState(kind: AnStateKind.empty, title: title, size: AnStateSize.inset);
