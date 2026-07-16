// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduler_stats.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SchedulerTotals {

 int get running; int get completedSince; int get failedSince; int get parkedNodes;
/// Create a copy of SchedulerTotals
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchedulerTotalsCopyWith<SchedulerTotals> get copyWith => _$SchedulerTotalsCopyWithImpl<SchedulerTotals>(this as SchedulerTotals, _$identity);

  /// Serializes this SchedulerTotals to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchedulerTotals&&(identical(other.running, running) || other.running == running)&&(identical(other.completedSince, completedSince) || other.completedSince == completedSince)&&(identical(other.failedSince, failedSince) || other.failedSince == failedSince)&&(identical(other.parkedNodes, parkedNodes) || other.parkedNodes == parkedNodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,running,completedSince,failedSince,parkedNodes);

@override
String toString() {
  return 'SchedulerTotals(running: $running, completedSince: $completedSince, failedSince: $failedSince, parkedNodes: $parkedNodes)';
}


}

/// @nodoc
abstract mixin class $SchedulerTotalsCopyWith<$Res>  {
  factory $SchedulerTotalsCopyWith(SchedulerTotals value, $Res Function(SchedulerTotals) _then) = _$SchedulerTotalsCopyWithImpl;
@useResult
$Res call({
 int running, int completedSince, int failedSince, int parkedNodes
});




}
/// @nodoc
class _$SchedulerTotalsCopyWithImpl<$Res>
    implements $SchedulerTotalsCopyWith<$Res> {
  _$SchedulerTotalsCopyWithImpl(this._self, this._then);

  final SchedulerTotals _self;
  final $Res Function(SchedulerTotals) _then;

/// Create a copy of SchedulerTotals
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? running = null,Object? completedSince = null,Object? failedSince = null,Object? parkedNodes = null,}) {
  return _then(_self.copyWith(
running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as int,completedSince: null == completedSince ? _self.completedSince : completedSince // ignore: cast_nullable_to_non_nullable
as int,failedSince: null == failedSince ? _self.failedSince : failedSince // ignore: cast_nullable_to_non_nullable
as int,parkedNodes: null == parkedNodes ? _self.parkedNodes : parkedNodes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SchedulerTotals].
extension SchedulerTotalsPatterns on SchedulerTotals {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchedulerTotals value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchedulerTotals() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchedulerTotals value)  $default,){
final _that = this;
switch (_that) {
case _SchedulerTotals():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchedulerTotals value)?  $default,){
final _that = this;
switch (_that) {
case _SchedulerTotals() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int running,  int completedSince,  int failedSince,  int parkedNodes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchedulerTotals() when $default != null:
return $default(_that.running,_that.completedSince,_that.failedSince,_that.parkedNodes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int running,  int completedSince,  int failedSince,  int parkedNodes)  $default,) {final _that = this;
switch (_that) {
case _SchedulerTotals():
return $default(_that.running,_that.completedSince,_that.failedSince,_that.parkedNodes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int running,  int completedSince,  int failedSince,  int parkedNodes)?  $default,) {final _that = this;
switch (_that) {
case _SchedulerTotals() when $default != null:
return $default(_that.running,_that.completedSince,_that.failedSince,_that.parkedNodes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SchedulerTotals implements SchedulerTotals {
  const _SchedulerTotals({this.running = 0, this.completedSince = 0, this.failedSince = 0, this.parkedNodes = 0});
  factory _SchedulerTotals.fromJson(Map<String, dynamic> json) => _$SchedulerTotalsFromJson(json);

@override@JsonKey() final  int running;
@override@JsonKey() final  int completedSince;
@override@JsonKey() final  int failedSince;
@override@JsonKey() final  int parkedNodes;

/// Create a copy of SchedulerTotals
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchedulerTotalsCopyWith<_SchedulerTotals> get copyWith => __$SchedulerTotalsCopyWithImpl<_SchedulerTotals>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SchedulerTotalsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchedulerTotals&&(identical(other.running, running) || other.running == running)&&(identical(other.completedSince, completedSince) || other.completedSince == completedSince)&&(identical(other.failedSince, failedSince) || other.failedSince == failedSince)&&(identical(other.parkedNodes, parkedNodes) || other.parkedNodes == parkedNodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,running,completedSince,failedSince,parkedNodes);

@override
String toString() {
  return 'SchedulerTotals(running: $running, completedSince: $completedSince, failedSince: $failedSince, parkedNodes: $parkedNodes)';
}


}

/// @nodoc
abstract mixin class _$SchedulerTotalsCopyWith<$Res> implements $SchedulerTotalsCopyWith<$Res> {
  factory _$SchedulerTotalsCopyWith(_SchedulerTotals value, $Res Function(_SchedulerTotals) _then) = __$SchedulerTotalsCopyWithImpl;
@override @useResult
$Res call({
 int running, int completedSince, int failedSince, int parkedNodes
});




}
/// @nodoc
class __$SchedulerTotalsCopyWithImpl<$Res>
    implements _$SchedulerTotalsCopyWith<$Res> {
  __$SchedulerTotalsCopyWithImpl(this._self, this._then);

  final _SchedulerTotals _self;
  final $Res Function(_SchedulerTotals) _then;

/// Create a copy of SchedulerTotals
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? running = null,Object? completedSince = null,Object? failedSince = null,Object? parkedNodes = null,}) {
  return _then(_SchedulerTotals(
running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as int,completedSince: null == completedSince ? _self.completedSince : completedSince // ignore: cast_nullable_to_non_nullable
as int,failedSince: null == failedSince ? _self.failedSince : failedSince // ignore: cast_nullable_to_non_nullable
as int,parkedNodes: null == parkedNodes ? _self.parkedNodes : parkedNodes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$WorkflowRunStats {

 String get workflowId; int get running; DateTime? get lastRunAt; List<String> get recent; double? get successRate; int? get avgElapsedMs; int get consecutiveFailures; int get parkedNodes;
/// Create a copy of WorkflowRunStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkflowRunStatsCopyWith<WorkflowRunStats> get copyWith => _$WorkflowRunStatsCopyWithImpl<WorkflowRunStats>(this as WorkflowRunStats, _$identity);

  /// Serializes this WorkflowRunStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkflowRunStats&&(identical(other.workflowId, workflowId) || other.workflowId == workflowId)&&(identical(other.running, running) || other.running == running)&&(identical(other.lastRunAt, lastRunAt) || other.lastRunAt == lastRunAt)&&const DeepCollectionEquality().equals(other.recent, recent)&&(identical(other.successRate, successRate) || other.successRate == successRate)&&(identical(other.avgElapsedMs, avgElapsedMs) || other.avgElapsedMs == avgElapsedMs)&&(identical(other.consecutiveFailures, consecutiveFailures) || other.consecutiveFailures == consecutiveFailures)&&(identical(other.parkedNodes, parkedNodes) || other.parkedNodes == parkedNodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workflowId,running,lastRunAt,const DeepCollectionEquality().hash(recent),successRate,avgElapsedMs,consecutiveFailures,parkedNodes);

@override
String toString() {
  return 'WorkflowRunStats(workflowId: $workflowId, running: $running, lastRunAt: $lastRunAt, recent: $recent, successRate: $successRate, avgElapsedMs: $avgElapsedMs, consecutiveFailures: $consecutiveFailures, parkedNodes: $parkedNodes)';
}


}

/// @nodoc
abstract mixin class $WorkflowRunStatsCopyWith<$Res>  {
  factory $WorkflowRunStatsCopyWith(WorkflowRunStats value, $Res Function(WorkflowRunStats) _then) = _$WorkflowRunStatsCopyWithImpl;
@useResult
$Res call({
 String workflowId, int running, DateTime? lastRunAt, List<String> recent, double? successRate, int? avgElapsedMs, int consecutiveFailures, int parkedNodes
});




}
/// @nodoc
class _$WorkflowRunStatsCopyWithImpl<$Res>
    implements $WorkflowRunStatsCopyWith<$Res> {
  _$WorkflowRunStatsCopyWithImpl(this._self, this._then);

  final WorkflowRunStats _self;
  final $Res Function(WorkflowRunStats) _then;

/// Create a copy of WorkflowRunStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? workflowId = null,Object? running = null,Object? lastRunAt = freezed,Object? recent = null,Object? successRate = freezed,Object? avgElapsedMs = freezed,Object? consecutiveFailures = null,Object? parkedNodes = null,}) {
  return _then(_self.copyWith(
workflowId: null == workflowId ? _self.workflowId : workflowId // ignore: cast_nullable_to_non_nullable
as String,running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as int,lastRunAt: freezed == lastRunAt ? _self.lastRunAt : lastRunAt // ignore: cast_nullable_to_non_nullable
as DateTime?,recent: null == recent ? _self.recent : recent // ignore: cast_nullable_to_non_nullable
as List<String>,successRate: freezed == successRate ? _self.successRate : successRate // ignore: cast_nullable_to_non_nullable
as double?,avgElapsedMs: freezed == avgElapsedMs ? _self.avgElapsedMs : avgElapsedMs // ignore: cast_nullable_to_non_nullable
as int?,consecutiveFailures: null == consecutiveFailures ? _self.consecutiveFailures : consecutiveFailures // ignore: cast_nullable_to_non_nullable
as int,parkedNodes: null == parkedNodes ? _self.parkedNodes : parkedNodes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkflowRunStats].
extension WorkflowRunStatsPatterns on WorkflowRunStats {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkflowRunStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkflowRunStats() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkflowRunStats value)  $default,){
final _that = this;
switch (_that) {
case _WorkflowRunStats():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkflowRunStats value)?  $default,){
final _that = this;
switch (_that) {
case _WorkflowRunStats() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String workflowId,  int running,  DateTime? lastRunAt,  List<String> recent,  double? successRate,  int? avgElapsedMs,  int consecutiveFailures,  int parkedNodes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkflowRunStats() when $default != null:
return $default(_that.workflowId,_that.running,_that.lastRunAt,_that.recent,_that.successRate,_that.avgElapsedMs,_that.consecutiveFailures,_that.parkedNodes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String workflowId,  int running,  DateTime? lastRunAt,  List<String> recent,  double? successRate,  int? avgElapsedMs,  int consecutiveFailures,  int parkedNodes)  $default,) {final _that = this;
switch (_that) {
case _WorkflowRunStats():
return $default(_that.workflowId,_that.running,_that.lastRunAt,_that.recent,_that.successRate,_that.avgElapsedMs,_that.consecutiveFailures,_that.parkedNodes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String workflowId,  int running,  DateTime? lastRunAt,  List<String> recent,  double? successRate,  int? avgElapsedMs,  int consecutiveFailures,  int parkedNodes)?  $default,) {final _that = this;
switch (_that) {
case _WorkflowRunStats() when $default != null:
return $default(_that.workflowId,_that.running,_that.lastRunAt,_that.recent,_that.successRate,_that.avgElapsedMs,_that.consecutiveFailures,_that.parkedNodes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorkflowRunStats implements WorkflowRunStats {
  const _WorkflowRunStats({required this.workflowId, this.running = 0, this.lastRunAt, final  List<String> recent = const <String>[], this.successRate, this.avgElapsedMs, this.consecutiveFailures = 0, this.parkedNodes = 0}): _recent = recent;
  factory _WorkflowRunStats.fromJson(Map<String, dynamic> json) => _$WorkflowRunStatsFromJson(json);

@override final  String workflowId;
@override@JsonKey() final  int running;
@override final  DateTime? lastRunAt;
 final  List<String> _recent;
@override@JsonKey() List<String> get recent {
  if (_recent is EqualUnmodifiableListView) return _recent;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recent);
}

@override final  double? successRate;
@override final  int? avgElapsedMs;
@override@JsonKey() final  int consecutiveFailures;
@override@JsonKey() final  int parkedNodes;

/// Create a copy of WorkflowRunStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkflowRunStatsCopyWith<_WorkflowRunStats> get copyWith => __$WorkflowRunStatsCopyWithImpl<_WorkflowRunStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorkflowRunStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkflowRunStats&&(identical(other.workflowId, workflowId) || other.workflowId == workflowId)&&(identical(other.running, running) || other.running == running)&&(identical(other.lastRunAt, lastRunAt) || other.lastRunAt == lastRunAt)&&const DeepCollectionEquality().equals(other._recent, _recent)&&(identical(other.successRate, successRate) || other.successRate == successRate)&&(identical(other.avgElapsedMs, avgElapsedMs) || other.avgElapsedMs == avgElapsedMs)&&(identical(other.consecutiveFailures, consecutiveFailures) || other.consecutiveFailures == consecutiveFailures)&&(identical(other.parkedNodes, parkedNodes) || other.parkedNodes == parkedNodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,workflowId,running,lastRunAt,const DeepCollectionEquality().hash(_recent),successRate,avgElapsedMs,consecutiveFailures,parkedNodes);

@override
String toString() {
  return 'WorkflowRunStats(workflowId: $workflowId, running: $running, lastRunAt: $lastRunAt, recent: $recent, successRate: $successRate, avgElapsedMs: $avgElapsedMs, consecutiveFailures: $consecutiveFailures, parkedNodes: $parkedNodes)';
}


}

/// @nodoc
abstract mixin class _$WorkflowRunStatsCopyWith<$Res> implements $WorkflowRunStatsCopyWith<$Res> {
  factory _$WorkflowRunStatsCopyWith(_WorkflowRunStats value, $Res Function(_WorkflowRunStats) _then) = __$WorkflowRunStatsCopyWithImpl;
@override @useResult
$Res call({
 String workflowId, int running, DateTime? lastRunAt, List<String> recent, double? successRate, int? avgElapsedMs, int consecutiveFailures, int parkedNodes
});




}
/// @nodoc
class __$WorkflowRunStatsCopyWithImpl<$Res>
    implements _$WorkflowRunStatsCopyWith<$Res> {
  __$WorkflowRunStatsCopyWithImpl(this._self, this._then);

  final _WorkflowRunStats _self;
  final $Res Function(_WorkflowRunStats) _then;

/// Create a copy of WorkflowRunStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? workflowId = null,Object? running = null,Object? lastRunAt = freezed,Object? recent = null,Object? successRate = freezed,Object? avgElapsedMs = freezed,Object? consecutiveFailures = null,Object? parkedNodes = null,}) {
  return _then(_WorkflowRunStats(
workflowId: null == workflowId ? _self.workflowId : workflowId // ignore: cast_nullable_to_non_nullable
as String,running: null == running ? _self.running : running // ignore: cast_nullable_to_non_nullable
as int,lastRunAt: freezed == lastRunAt ? _self.lastRunAt : lastRunAt // ignore: cast_nullable_to_non_nullable
as DateTime?,recent: null == recent ? _self._recent : recent // ignore: cast_nullable_to_non_nullable
as List<String>,successRate: freezed == successRate ? _self.successRate : successRate // ignore: cast_nullable_to_non_nullable
as double?,avgElapsedMs: freezed == avgElapsedMs ? _self.avgElapsedMs : avgElapsedMs // ignore: cast_nullable_to_non_nullable
as int?,consecutiveFailures: null == consecutiveFailures ? _self.consecutiveFailures : consecutiveFailures // ignore: cast_nullable_to_non_nullable
as int,parkedNodes: null == parkedNodes ? _self.parkedNodes : parkedNodes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SchedulerStats {

 SchedulerTotals get totals; List<WorkflowRunStats> get byWorkflow;
/// Create a copy of SchedulerStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchedulerStatsCopyWith<SchedulerStats> get copyWith => _$SchedulerStatsCopyWithImpl<SchedulerStats>(this as SchedulerStats, _$identity);

  /// Serializes this SchedulerStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchedulerStats&&(identical(other.totals, totals) || other.totals == totals)&&const DeepCollectionEquality().equals(other.byWorkflow, byWorkflow));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totals,const DeepCollectionEquality().hash(byWorkflow));

@override
String toString() {
  return 'SchedulerStats(totals: $totals, byWorkflow: $byWorkflow)';
}


}

/// @nodoc
abstract mixin class $SchedulerStatsCopyWith<$Res>  {
  factory $SchedulerStatsCopyWith(SchedulerStats value, $Res Function(SchedulerStats) _then) = _$SchedulerStatsCopyWithImpl;
@useResult
$Res call({
 SchedulerTotals totals, List<WorkflowRunStats> byWorkflow
});


$SchedulerTotalsCopyWith<$Res> get totals;

}
/// @nodoc
class _$SchedulerStatsCopyWithImpl<$Res>
    implements $SchedulerStatsCopyWith<$Res> {
  _$SchedulerStatsCopyWithImpl(this._self, this._then);

  final SchedulerStats _self;
  final $Res Function(SchedulerStats) _then;

/// Create a copy of SchedulerStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totals = null,Object? byWorkflow = null,}) {
  return _then(_self.copyWith(
totals: null == totals ? _self.totals : totals // ignore: cast_nullable_to_non_nullable
as SchedulerTotals,byWorkflow: null == byWorkflow ? _self.byWorkflow : byWorkflow // ignore: cast_nullable_to_non_nullable
as List<WorkflowRunStats>,
  ));
}
/// Create a copy of SchedulerStats
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SchedulerTotalsCopyWith<$Res> get totals {
  
  return $SchedulerTotalsCopyWith<$Res>(_self.totals, (value) {
    return _then(_self.copyWith(totals: value));
  });
}
}


/// Adds pattern-matching-related methods to [SchedulerStats].
extension SchedulerStatsPatterns on SchedulerStats {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchedulerStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchedulerStats() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchedulerStats value)  $default,){
final _that = this;
switch (_that) {
case _SchedulerStats():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchedulerStats value)?  $default,){
final _that = this;
switch (_that) {
case _SchedulerStats() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SchedulerTotals totals,  List<WorkflowRunStats> byWorkflow)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchedulerStats() when $default != null:
return $default(_that.totals,_that.byWorkflow);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SchedulerTotals totals,  List<WorkflowRunStats> byWorkflow)  $default,) {final _that = this;
switch (_that) {
case _SchedulerStats():
return $default(_that.totals,_that.byWorkflow);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SchedulerTotals totals,  List<WorkflowRunStats> byWorkflow)?  $default,) {final _that = this;
switch (_that) {
case _SchedulerStats() when $default != null:
return $default(_that.totals,_that.byWorkflow);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SchedulerStats implements SchedulerStats {
  const _SchedulerStats({this.totals = const SchedulerTotals(), final  List<WorkflowRunStats> byWorkflow = const <WorkflowRunStats>[]}): _byWorkflow = byWorkflow;
  factory _SchedulerStats.fromJson(Map<String, dynamic> json) => _$SchedulerStatsFromJson(json);

@override@JsonKey() final  SchedulerTotals totals;
 final  List<WorkflowRunStats> _byWorkflow;
@override@JsonKey() List<WorkflowRunStats> get byWorkflow {
  if (_byWorkflow is EqualUnmodifiableListView) return _byWorkflow;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_byWorkflow);
}


/// Create a copy of SchedulerStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchedulerStatsCopyWith<_SchedulerStats> get copyWith => __$SchedulerStatsCopyWithImpl<_SchedulerStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SchedulerStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchedulerStats&&(identical(other.totals, totals) || other.totals == totals)&&const DeepCollectionEquality().equals(other._byWorkflow, _byWorkflow));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totals,const DeepCollectionEquality().hash(_byWorkflow));

@override
String toString() {
  return 'SchedulerStats(totals: $totals, byWorkflow: $byWorkflow)';
}


}

/// @nodoc
abstract mixin class _$SchedulerStatsCopyWith<$Res> implements $SchedulerStatsCopyWith<$Res> {
  factory _$SchedulerStatsCopyWith(_SchedulerStats value, $Res Function(_SchedulerStats) _then) = __$SchedulerStatsCopyWithImpl;
@override @useResult
$Res call({
 SchedulerTotals totals, List<WorkflowRunStats> byWorkflow
});


@override $SchedulerTotalsCopyWith<$Res> get totals;

}
/// @nodoc
class __$SchedulerStatsCopyWithImpl<$Res>
    implements _$SchedulerStatsCopyWith<$Res> {
  __$SchedulerStatsCopyWithImpl(this._self, this._then);

  final _SchedulerStats _self;
  final $Res Function(_SchedulerStats) _then;

/// Create a copy of SchedulerStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totals = null,Object? byWorkflow = null,}) {
  return _then(_SchedulerStats(
totals: null == totals ? _self.totals : totals // ignore: cast_nullable_to_non_nullable
as SchedulerTotals,byWorkflow: null == byWorkflow ? _self._byWorkflow : byWorkflow // ignore: cast_nullable_to_non_nullable
as List<WorkflowRunStats>,
  ));
}

/// Create a copy of SchedulerStats
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SchedulerTotalsCopyWith<$Res> get totals {
  
  return $SchedulerTotalsCopyWith<$Res>(_self.totals, (value) {
    return _then(_self.copyWith(totals: value));
  });
}
}

// dart format on
