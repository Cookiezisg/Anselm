import 'package:freezed_annotation/freezed_annotation.dart';

import 'values.dart'; // Field

part 'approval.freezed.dart';
part 'approval.g.dart';

/// Approval form entity — a workflow approval node's human-in-the-loop gate. Named + versioned (方案 A,
/// like function/control), no sandbox/env, NOT executable: its runtime is a flowrun's PARKED row (decided
/// via the flowrun-side `:decide`), not a run of its own. Has NO tags. approval.go ApprovalForm。
@freezed
abstract class ApprovalForm with _$ApprovalForm {
  const factory ApprovalForm({
    required String id,
    @Default('') String name,
    @Default('') String description,
    @Default('') String activeVersionId,
    required DateTime createdAt,
    required DateTime updatedAt,
    ApprovalVersion? activeVersion,
  }) = _ApprovalForm;
  factory ApprovalForm.fromJson(Map<String, dynamic> json) => _$ApprovalFormFromJson(json);
}

/// Approval version (append-only): declared [inputs] + the markdown [template] (with `{{ CEL }}`
/// interpolation over `input.*`) + decision rules ([allowReason] — whether the decider may add a note;
/// [timeout] — a coarse duration string, `''` = never; [timeoutBehavior] — reject/approve/fail, required
/// when timeout is non-empty). approval.go Version。
@freezed
abstract class ApprovalVersion with _$ApprovalVersion {
  const factory ApprovalVersion({
    required String id,
    required String approvalId,
    required int version,
    @Default(<Field>[]) List<Field> inputs,
    @Default('') String template,
    @Default(false) bool allowReason,
    @Default('') String timeout,
    @Default('') String timeoutBehavior,
    String? changeReason,
    String? builtInConversationId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ApprovalVersion;
  factory ApprovalVersion.fromJson(Map<String, dynamic> json) => _$ApprovalVersionFromJson(json);
}
