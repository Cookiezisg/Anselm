import 'package:freezed_annotation/freezed_annotation.dart';

import 'values.dart'; // Field

part 'control.freezed.dart';
part 'control.g.dart';

/// Control logic entity — a workflow control node's routing gate. Named + versioned (方案 A, like
/// function), but no sandbox/env/executions: pure control flow the interpreter evaluates inline. Has NO
/// tags (unlike workflow/function). control.go ControlLogic。
@freezed
abstract class ControlLogic with _$ControlLogic {
  const factory ControlLogic({
    required String id,
    @Default('') String name,
    @Default('') String description,
    @Default('') String activeVersionId,
    required DateTime createdAt,
    required DateTime updatedAt,
    ControlVersion? activeVersion,
  }) = _ControlLogic;
  factory ControlLogic.fromJson(Map<String, dynamic> json) =>
      _$ControlLogicFromJson(json);
}

/// Control version (append-only): declared [inputs] the node feeds + ordered [branches]. control.go Version。
@freezed
abstract class ControlVersion with _$ControlVersion {
  const factory ControlVersion({
    required String id,
    required String controlId,
    required int version,
    @Default(<Field>[]) List<Field> inputs,
    @Default(<Branch>[]) List<Branch> branches,
    String? changeReason,
    String? builtInConversationId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ControlVersion;
  factory ControlVersion.fromJson(Map<String, dynamic> json) =>
      _$ControlVersionFromJson(json);
}

/// One routing branch: [when] (boolean CEL over `input.*`, first-true-wins top-down) → [port] (the named
/// exit the workflow graph routes on; the edge's `fromPort` matches it) + optional [emit] (field→CEL
/// reshaping the downstream payload; empty = passthrough). The last branch's [when] is always `"true"`
/// (catch-all). control.go Branch。
@freezed
abstract class Branch with _$Branch {
  const factory Branch({
    @Default('') String port,
    @Default('') String when,
    @Default(<String, String>{}) Map<String, String> emit,
  }) = _Branch;
  factory Branch.fromJson(Map<String, dynamic> json) => _$BranchFromJson(json);
}
