// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'retention.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RetentionConfig {

 int get runRetentionDays;
/// Create a copy of RetentionConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RetentionConfigCopyWith<RetentionConfig> get copyWith => _$RetentionConfigCopyWithImpl<RetentionConfig>(this as RetentionConfig, _$identity);

  /// Serializes this RetentionConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RetentionConfig&&(identical(other.runRetentionDays, runRetentionDays) || other.runRetentionDays == runRetentionDays));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,runRetentionDays);

@override
String toString() {
  return 'RetentionConfig(runRetentionDays: $runRetentionDays)';
}


}

/// @nodoc
abstract mixin class $RetentionConfigCopyWith<$Res>  {
  factory $RetentionConfigCopyWith(RetentionConfig value, $Res Function(RetentionConfig) _then) = _$RetentionConfigCopyWithImpl;
@useResult
$Res call({
 int runRetentionDays
});




}
/// @nodoc
class _$RetentionConfigCopyWithImpl<$Res>
    implements $RetentionConfigCopyWith<$Res> {
  _$RetentionConfigCopyWithImpl(this._self, this._then);

  final RetentionConfig _self;
  final $Res Function(RetentionConfig) _then;

/// Create a copy of RetentionConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? runRetentionDays = null,}) {
  return _then(_self.copyWith(
runRetentionDays: null == runRetentionDays ? _self.runRetentionDays : runRetentionDays // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RetentionConfig].
extension RetentionConfigPatterns on RetentionConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RetentionConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RetentionConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RetentionConfig value)  $default,){
final _that = this;
switch (_that) {
case _RetentionConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RetentionConfig value)?  $default,){
final _that = this;
switch (_that) {
case _RetentionConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int runRetentionDays)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RetentionConfig() when $default != null:
return $default(_that.runRetentionDays);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int runRetentionDays)  $default,) {final _that = this;
switch (_that) {
case _RetentionConfig():
return $default(_that.runRetentionDays);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int runRetentionDays)?  $default,) {final _that = this;
switch (_that) {
case _RetentionConfig() when $default != null:
return $default(_that.runRetentionDays);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RetentionConfig implements RetentionConfig {
  const _RetentionConfig({this.runRetentionDays = 0});
  factory _RetentionConfig.fromJson(Map<String, dynamic> json) => _$RetentionConfigFromJson(json);

@override@JsonKey() final  int runRetentionDays;

/// Create a copy of RetentionConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RetentionConfigCopyWith<_RetentionConfig> get copyWith => __$RetentionConfigCopyWithImpl<_RetentionConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RetentionConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RetentionConfig&&(identical(other.runRetentionDays, runRetentionDays) || other.runRetentionDays == runRetentionDays));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,runRetentionDays);

@override
String toString() {
  return 'RetentionConfig(runRetentionDays: $runRetentionDays)';
}


}

/// @nodoc
abstract mixin class _$RetentionConfigCopyWith<$Res> implements $RetentionConfigCopyWith<$Res> {
  factory _$RetentionConfigCopyWith(_RetentionConfig value, $Res Function(_RetentionConfig) _then) = __$RetentionConfigCopyWithImpl;
@override @useResult
$Res call({
 int runRetentionDays
});




}
/// @nodoc
class __$RetentionConfigCopyWithImpl<$Res>
    implements _$RetentionConfigCopyWith<$Res> {
  __$RetentionConfigCopyWithImpl(this._self, this._then);

  final _RetentionConfig _self;
  final $Res Function(_RetentionConfig) _then;

/// Create a copy of RetentionConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? runRetentionDays = null,}) {
  return _then(_RetentionConfig(
runRetentionDays: null == runRetentionDays ? _self.runRetentionDays : runRetentionDays // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
