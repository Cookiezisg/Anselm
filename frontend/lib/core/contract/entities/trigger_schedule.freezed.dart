// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trigger_schedule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SchedulePoint {

 DateTime get at; String get triggerId; String get triggerName; List<String> get workflowIds;
/// Create a copy of SchedulePoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SchedulePointCopyWith<SchedulePoint> get copyWith => _$SchedulePointCopyWithImpl<SchedulePoint>(this as SchedulePoint, _$identity);

  /// Serializes this SchedulePoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SchedulePoint&&(identical(other.at, at) || other.at == at)&&(identical(other.triggerId, triggerId) || other.triggerId == triggerId)&&(identical(other.triggerName, triggerName) || other.triggerName == triggerName)&&const DeepCollectionEquality().equals(other.workflowIds, workflowIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,at,triggerId,triggerName,const DeepCollectionEquality().hash(workflowIds));

@override
String toString() {
  return 'SchedulePoint(at: $at, triggerId: $triggerId, triggerName: $triggerName, workflowIds: $workflowIds)';
}


}

/// @nodoc
abstract mixin class $SchedulePointCopyWith<$Res>  {
  factory $SchedulePointCopyWith(SchedulePoint value, $Res Function(SchedulePoint) _then) = _$SchedulePointCopyWithImpl;
@useResult
$Res call({
 DateTime at, String triggerId, String triggerName, List<String> workflowIds
});




}
/// @nodoc
class _$SchedulePointCopyWithImpl<$Res>
    implements $SchedulePointCopyWith<$Res> {
  _$SchedulePointCopyWithImpl(this._self, this._then);

  final SchedulePoint _self;
  final $Res Function(SchedulePoint) _then;

/// Create a copy of SchedulePoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? at = null,Object? triggerId = null,Object? triggerName = null,Object? workflowIds = null,}) {
  return _then(_self.copyWith(
at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,triggerId: null == triggerId ? _self.triggerId : triggerId // ignore: cast_nullable_to_non_nullable
as String,triggerName: null == triggerName ? _self.triggerName : triggerName // ignore: cast_nullable_to_non_nullable
as String,workflowIds: null == workflowIds ? _self.workflowIds : workflowIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [SchedulePoint].
extension SchedulePointPatterns on SchedulePoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SchedulePoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SchedulePoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SchedulePoint value)  $default,){
final _that = this;
switch (_that) {
case _SchedulePoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SchedulePoint value)?  $default,){
final _that = this;
switch (_that) {
case _SchedulePoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime at,  String triggerId,  String triggerName,  List<String> workflowIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SchedulePoint() when $default != null:
return $default(_that.at,_that.triggerId,_that.triggerName,_that.workflowIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime at,  String triggerId,  String triggerName,  List<String> workflowIds)  $default,) {final _that = this;
switch (_that) {
case _SchedulePoint():
return $default(_that.at,_that.triggerId,_that.triggerName,_that.workflowIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime at,  String triggerId,  String triggerName,  List<String> workflowIds)?  $default,) {final _that = this;
switch (_that) {
case _SchedulePoint() when $default != null:
return $default(_that.at,_that.triggerId,_that.triggerName,_that.workflowIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SchedulePoint implements SchedulePoint {
  const _SchedulePoint({required this.at, this.triggerId = '', this.triggerName = '', final  List<String> workflowIds = const <String>[]}): _workflowIds = workflowIds;
  factory _SchedulePoint.fromJson(Map<String, dynamic> json) => _$SchedulePointFromJson(json);

@override final  DateTime at;
@override@JsonKey() final  String triggerId;
@override@JsonKey() final  String triggerName;
 final  List<String> _workflowIds;
@override@JsonKey() List<String> get workflowIds {
  if (_workflowIds is EqualUnmodifiableListView) return _workflowIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_workflowIds);
}


/// Create a copy of SchedulePoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SchedulePointCopyWith<_SchedulePoint> get copyWith => __$SchedulePointCopyWithImpl<_SchedulePoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SchedulePointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SchedulePoint&&(identical(other.at, at) || other.at == at)&&(identical(other.triggerId, triggerId) || other.triggerId == triggerId)&&(identical(other.triggerName, triggerName) || other.triggerName == triggerName)&&const DeepCollectionEquality().equals(other._workflowIds, _workflowIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,at,triggerId,triggerName,const DeepCollectionEquality().hash(_workflowIds));

@override
String toString() {
  return 'SchedulePoint(at: $at, triggerId: $triggerId, triggerName: $triggerName, workflowIds: $workflowIds)';
}


}

/// @nodoc
abstract mixin class _$SchedulePointCopyWith<$Res> implements $SchedulePointCopyWith<$Res> {
  factory _$SchedulePointCopyWith(_SchedulePoint value, $Res Function(_SchedulePoint) _then) = __$SchedulePointCopyWithImpl;
@override @useResult
$Res call({
 DateTime at, String triggerId, String triggerName, List<String> workflowIds
});




}
/// @nodoc
class __$SchedulePointCopyWithImpl<$Res>
    implements _$SchedulePointCopyWith<$Res> {
  __$SchedulePointCopyWithImpl(this._self, this._then);

  final _SchedulePoint _self;
  final $Res Function(_SchedulePoint) _then;

/// Create a copy of SchedulePoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? at = null,Object? triggerId = null,Object? triggerName = null,Object? workflowIds = null,}) {
  return _then(_SchedulePoint(
at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,triggerId: null == triggerId ? _self.triggerId : triggerId // ignore: cast_nullable_to_non_nullable
as String,triggerName: null == triggerName ? _self.triggerName : triggerName // ignore: cast_nullable_to_non_nullable
as String,workflowIds: null == workflowIds ? _self._workflowIds : workflowIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$TriggerSchedule {

 List<SchedulePoint> get points; bool get truncated;
/// Create a copy of TriggerSchedule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TriggerScheduleCopyWith<TriggerSchedule> get copyWith => _$TriggerScheduleCopyWithImpl<TriggerSchedule>(this as TriggerSchedule, _$identity);

  /// Serializes this TriggerSchedule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TriggerSchedule&&const DeepCollectionEquality().equals(other.points, points)&&(identical(other.truncated, truncated) || other.truncated == truncated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(points),truncated);

@override
String toString() {
  return 'TriggerSchedule(points: $points, truncated: $truncated)';
}


}

/// @nodoc
abstract mixin class $TriggerScheduleCopyWith<$Res>  {
  factory $TriggerScheduleCopyWith(TriggerSchedule value, $Res Function(TriggerSchedule) _then) = _$TriggerScheduleCopyWithImpl;
@useResult
$Res call({
 List<SchedulePoint> points, bool truncated
});




}
/// @nodoc
class _$TriggerScheduleCopyWithImpl<$Res>
    implements $TriggerScheduleCopyWith<$Res> {
  _$TriggerScheduleCopyWithImpl(this._self, this._then);

  final TriggerSchedule _self;
  final $Res Function(TriggerSchedule) _then;

/// Create a copy of TriggerSchedule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? points = null,Object? truncated = null,}) {
  return _then(_self.copyWith(
points: null == points ? _self.points : points // ignore: cast_nullable_to_non_nullable
as List<SchedulePoint>,truncated: null == truncated ? _self.truncated : truncated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TriggerSchedule].
extension TriggerSchedulePatterns on TriggerSchedule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TriggerSchedule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TriggerSchedule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TriggerSchedule value)  $default,){
final _that = this;
switch (_that) {
case _TriggerSchedule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TriggerSchedule value)?  $default,){
final _that = this;
switch (_that) {
case _TriggerSchedule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<SchedulePoint> points,  bool truncated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TriggerSchedule() when $default != null:
return $default(_that.points,_that.truncated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<SchedulePoint> points,  bool truncated)  $default,) {final _that = this;
switch (_that) {
case _TriggerSchedule():
return $default(_that.points,_that.truncated);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<SchedulePoint> points,  bool truncated)?  $default,) {final _that = this;
switch (_that) {
case _TriggerSchedule() when $default != null:
return $default(_that.points,_that.truncated);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TriggerSchedule implements TriggerSchedule {
  const _TriggerSchedule({final  List<SchedulePoint> points = const <SchedulePoint>[], this.truncated = false}): _points = points;
  factory _TriggerSchedule.fromJson(Map<String, dynamic> json) => _$TriggerScheduleFromJson(json);

 final  List<SchedulePoint> _points;
@override@JsonKey() List<SchedulePoint> get points {
  if (_points is EqualUnmodifiableListView) return _points;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_points);
}

@override@JsonKey() final  bool truncated;

/// Create a copy of TriggerSchedule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TriggerScheduleCopyWith<_TriggerSchedule> get copyWith => __$TriggerScheduleCopyWithImpl<_TriggerSchedule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TriggerScheduleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TriggerSchedule&&const DeepCollectionEquality().equals(other._points, _points)&&(identical(other.truncated, truncated) || other.truncated == truncated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_points),truncated);

@override
String toString() {
  return 'TriggerSchedule(points: $points, truncated: $truncated)';
}


}

/// @nodoc
abstract mixin class _$TriggerScheduleCopyWith<$Res> implements $TriggerScheduleCopyWith<$Res> {
  factory _$TriggerScheduleCopyWith(_TriggerSchedule value, $Res Function(_TriggerSchedule) _then) = __$TriggerScheduleCopyWithImpl;
@override @useResult
$Res call({
 List<SchedulePoint> points, bool truncated
});




}
/// @nodoc
class __$TriggerScheduleCopyWithImpl<$Res>
    implements _$TriggerScheduleCopyWith<$Res> {
  __$TriggerScheduleCopyWithImpl(this._self, this._then);

  final _TriggerSchedule _self;
  final $Res Function(_TriggerSchedule) _then;

/// Create a copy of TriggerSchedule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? points = null,Object? truncated = null,}) {
  return _then(_TriggerSchedule(
points: null == points ? _self._points : points // ignore: cast_nullable_to_non_nullable
as List<SchedulePoint>,truncated: null == truncated ? _self.truncated : truncated // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
