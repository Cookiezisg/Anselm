// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'common.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ExecutionAggregates {

 int get okCount; int get failedCount;
/// Create a copy of ExecutionAggregates
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExecutionAggregatesCopyWith<ExecutionAggregates> get copyWith => _$ExecutionAggregatesCopyWithImpl<ExecutionAggregates>(this as ExecutionAggregates, _$identity);

  /// Serializes this ExecutionAggregates to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExecutionAggregates&&(identical(other.okCount, okCount) || other.okCount == okCount)&&(identical(other.failedCount, failedCount) || other.failedCount == failedCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,okCount,failedCount);

@override
String toString() {
  return 'ExecutionAggregates(okCount: $okCount, failedCount: $failedCount)';
}


}

/// @nodoc
abstract mixin class $ExecutionAggregatesCopyWith<$Res>  {
  factory $ExecutionAggregatesCopyWith(ExecutionAggregates value, $Res Function(ExecutionAggregates) _then) = _$ExecutionAggregatesCopyWithImpl;
@useResult
$Res call({
 int okCount, int failedCount
});




}
/// @nodoc
class _$ExecutionAggregatesCopyWithImpl<$Res>
    implements $ExecutionAggregatesCopyWith<$Res> {
  _$ExecutionAggregatesCopyWithImpl(this._self, this._then);

  final ExecutionAggregates _self;
  final $Res Function(ExecutionAggregates) _then;

/// Create a copy of ExecutionAggregates
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? okCount = null,Object? failedCount = null,}) {
  return _then(_self.copyWith(
okCount: null == okCount ? _self.okCount : okCount // ignore: cast_nullable_to_non_nullable
as int,failedCount: null == failedCount ? _self.failedCount : failedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ExecutionAggregates].
extension ExecutionAggregatesPatterns on ExecutionAggregates {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExecutionAggregates value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExecutionAggregates() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExecutionAggregates value)  $default,){
final _that = this;
switch (_that) {
case _ExecutionAggregates():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExecutionAggregates value)?  $default,){
final _that = this;
switch (_that) {
case _ExecutionAggregates() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int okCount,  int failedCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExecutionAggregates() when $default != null:
return $default(_that.okCount,_that.failedCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int okCount,  int failedCount)  $default,) {final _that = this;
switch (_that) {
case _ExecutionAggregates():
return $default(_that.okCount,_that.failedCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int okCount,  int failedCount)?  $default,) {final _that = this;
switch (_that) {
case _ExecutionAggregates() when $default != null:
return $default(_that.okCount,_that.failedCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExecutionAggregates implements ExecutionAggregates {
  const _ExecutionAggregates({this.okCount = 0, this.failedCount = 0});
  factory _ExecutionAggregates.fromJson(Map<String, dynamic> json) => _$ExecutionAggregatesFromJson(json);

@override@JsonKey() final  int okCount;
@override@JsonKey() final  int failedCount;

/// Create a copy of ExecutionAggregates
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExecutionAggregatesCopyWith<_ExecutionAggregates> get copyWith => __$ExecutionAggregatesCopyWithImpl<_ExecutionAggregates>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExecutionAggregatesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExecutionAggregates&&(identical(other.okCount, okCount) || other.okCount == okCount)&&(identical(other.failedCount, failedCount) || other.failedCount == failedCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,okCount,failedCount);

@override
String toString() {
  return 'ExecutionAggregates(okCount: $okCount, failedCount: $failedCount)';
}


}

/// @nodoc
abstract mixin class _$ExecutionAggregatesCopyWith<$Res> implements $ExecutionAggregatesCopyWith<$Res> {
  factory _$ExecutionAggregatesCopyWith(_ExecutionAggregates value, $Res Function(_ExecutionAggregates) _then) = __$ExecutionAggregatesCopyWithImpl;
@override @useResult
$Res call({
 int okCount, int failedCount
});




}
/// @nodoc
class __$ExecutionAggregatesCopyWithImpl<$Res>
    implements _$ExecutionAggregatesCopyWith<$Res> {
  __$ExecutionAggregatesCopyWithImpl(this._self, this._then);

  final _ExecutionAggregates _self;
  final $Res Function(_ExecutionAggregates) _then;

/// Create a copy of ExecutionAggregates
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? okCount = null,Object? failedCount = null,}) {
  return _then(_ExecutionAggregates(
okCount: null == okCount ? _self.okCount : okCount // ignore: cast_nullable_to_non_nullable
as int,failedCount: null == failedCount ? _self.failedCount : failedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CapabilityReport {

 bool get structurallyValid; bool get resolved; List<String> get problems; List<String> get warnings;
/// Create a copy of CapabilityReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CapabilityReportCopyWith<CapabilityReport> get copyWith => _$CapabilityReportCopyWithImpl<CapabilityReport>(this as CapabilityReport, _$identity);

  /// Serializes this CapabilityReport to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CapabilityReport&&(identical(other.structurallyValid, structurallyValid) || other.structurallyValid == structurallyValid)&&(identical(other.resolved, resolved) || other.resolved == resolved)&&const DeepCollectionEquality().equals(other.problems, problems)&&const DeepCollectionEquality().equals(other.warnings, warnings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,structurallyValid,resolved,const DeepCollectionEquality().hash(problems),const DeepCollectionEquality().hash(warnings));

@override
String toString() {
  return 'CapabilityReport(structurallyValid: $structurallyValid, resolved: $resolved, problems: $problems, warnings: $warnings)';
}


}

/// @nodoc
abstract mixin class $CapabilityReportCopyWith<$Res>  {
  factory $CapabilityReportCopyWith(CapabilityReport value, $Res Function(CapabilityReport) _then) = _$CapabilityReportCopyWithImpl;
@useResult
$Res call({
 bool structurallyValid, bool resolved, List<String> problems, List<String> warnings
});




}
/// @nodoc
class _$CapabilityReportCopyWithImpl<$Res>
    implements $CapabilityReportCopyWith<$Res> {
  _$CapabilityReportCopyWithImpl(this._self, this._then);

  final CapabilityReport _self;
  final $Res Function(CapabilityReport) _then;

/// Create a copy of CapabilityReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? structurallyValid = null,Object? resolved = null,Object? problems = null,Object? warnings = null,}) {
  return _then(_self.copyWith(
structurallyValid: null == structurallyValid ? _self.structurallyValid : structurallyValid // ignore: cast_nullable_to_non_nullable
as bool,resolved: null == resolved ? _self.resolved : resolved // ignore: cast_nullable_to_non_nullable
as bool,problems: null == problems ? _self.problems : problems // ignore: cast_nullable_to_non_nullable
as List<String>,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [CapabilityReport].
extension CapabilityReportPatterns on CapabilityReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CapabilityReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CapabilityReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CapabilityReport value)  $default,){
final _that = this;
switch (_that) {
case _CapabilityReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CapabilityReport value)?  $default,){
final _that = this;
switch (_that) {
case _CapabilityReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool structurallyValid,  bool resolved,  List<String> problems,  List<String> warnings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CapabilityReport() when $default != null:
return $default(_that.structurallyValid,_that.resolved,_that.problems,_that.warnings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool structurallyValid,  bool resolved,  List<String> problems,  List<String> warnings)  $default,) {final _that = this;
switch (_that) {
case _CapabilityReport():
return $default(_that.structurallyValid,_that.resolved,_that.problems,_that.warnings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool structurallyValid,  bool resolved,  List<String> problems,  List<String> warnings)?  $default,) {final _that = this;
switch (_that) {
case _CapabilityReport() when $default != null:
return $default(_that.structurallyValid,_that.resolved,_that.problems,_that.warnings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CapabilityReport implements CapabilityReport {
  const _CapabilityReport({this.structurallyValid = false, this.resolved = false, final  List<String> problems = const <String>[], final  List<String> warnings = const <String>[]}): _problems = problems,_warnings = warnings;
  factory _CapabilityReport.fromJson(Map<String, dynamic> json) => _$CapabilityReportFromJson(json);

@override@JsonKey() final  bool structurallyValid;
@override@JsonKey() final  bool resolved;
 final  List<String> _problems;
@override@JsonKey() List<String> get problems {
  if (_problems is EqualUnmodifiableListView) return _problems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_problems);
}

 final  List<String> _warnings;
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}


/// Create a copy of CapabilityReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CapabilityReportCopyWith<_CapabilityReport> get copyWith => __$CapabilityReportCopyWithImpl<_CapabilityReport>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CapabilityReportToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CapabilityReport&&(identical(other.structurallyValid, structurallyValid) || other.structurallyValid == structurallyValid)&&(identical(other.resolved, resolved) || other.resolved == resolved)&&const DeepCollectionEquality().equals(other._problems, _problems)&&const DeepCollectionEquality().equals(other._warnings, _warnings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,structurallyValid,resolved,const DeepCollectionEquality().hash(_problems),const DeepCollectionEquality().hash(_warnings));

@override
String toString() {
  return 'CapabilityReport(structurallyValid: $structurallyValid, resolved: $resolved, problems: $problems, warnings: $warnings)';
}


}

/// @nodoc
abstract mixin class _$CapabilityReportCopyWith<$Res> implements $CapabilityReportCopyWith<$Res> {
  factory _$CapabilityReportCopyWith(_CapabilityReport value, $Res Function(_CapabilityReport) _then) = __$CapabilityReportCopyWithImpl;
@override @useResult
$Res call({
 bool structurallyValid, bool resolved, List<String> problems, List<String> warnings
});




}
/// @nodoc
class __$CapabilityReportCopyWithImpl<$Res>
    implements _$CapabilityReportCopyWith<$Res> {
  __$CapabilityReportCopyWithImpl(this._self, this._then);

  final _CapabilityReport _self;
  final $Res Function(_CapabilityReport) _then;

/// Create a copy of CapabilityReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? structurallyValid = null,Object? resolved = null,Object? problems = null,Object? warnings = null,}) {
  return _then(_CapabilityReport(
structurallyValid: null == structurallyValid ? _self.structurallyValid : structurallyValid // ignore: cast_nullable_to_non_nullable
as bool,resolved: null == resolved ? _self.resolved : resolved // ignore: cast_nullable_to_non_nullable
as bool,problems: null == problems ? _self._problems : problems // ignore: cast_nullable_to_non_nullable
as List<String>,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
