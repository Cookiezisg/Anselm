// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'limits.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LimitField {

 String get key; String get group;@JsonKey(name: 'default') double get defaultValue; double get min; double get max; bool get exclusive; String get unit; String get desc;
/// Create a copy of LimitField
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LimitFieldCopyWith<LimitField> get copyWith => _$LimitFieldCopyWithImpl<LimitField>(this as LimitField, _$identity);

  /// Serializes this LimitField to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LimitField&&(identical(other.key, key) || other.key == key)&&(identical(other.group, group) || other.group == group)&&(identical(other.defaultValue, defaultValue) || other.defaultValue == defaultValue)&&(identical(other.min, min) || other.min == min)&&(identical(other.max, max) || other.max == max)&&(identical(other.exclusive, exclusive) || other.exclusive == exclusive)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.desc, desc) || other.desc == desc));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,group,defaultValue,min,max,exclusive,unit,desc);

@override
String toString() {
  return 'LimitField(key: $key, group: $group, defaultValue: $defaultValue, min: $min, max: $max, exclusive: $exclusive, unit: $unit, desc: $desc)';
}


}

/// @nodoc
abstract mixin class $LimitFieldCopyWith<$Res>  {
  factory $LimitFieldCopyWith(LimitField value, $Res Function(LimitField) _then) = _$LimitFieldCopyWithImpl;
@useResult
$Res call({
 String key, String group,@JsonKey(name: 'default') double defaultValue, double min, double max, bool exclusive, String unit, String desc
});




}
/// @nodoc
class _$LimitFieldCopyWithImpl<$Res>
    implements $LimitFieldCopyWith<$Res> {
  _$LimitFieldCopyWithImpl(this._self, this._then);

  final LimitField _self;
  final $Res Function(LimitField) _then;

/// Create a copy of LimitField
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? group = null,Object? defaultValue = null,Object? min = null,Object? max = null,Object? exclusive = null,Object? unit = null,Object? desc = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,defaultValue: null == defaultValue ? _self.defaultValue : defaultValue // ignore: cast_nullable_to_non_nullable
as double,min: null == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as double,max: null == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as double,exclusive: null == exclusive ? _self.exclusive : exclusive // ignore: cast_nullable_to_non_nullable
as bool,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,desc: null == desc ? _self.desc : desc // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LimitField].
extension LimitFieldPatterns on LimitField {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LimitField value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LimitField() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LimitField value)  $default,){
final _that = this;
switch (_that) {
case _LimitField():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LimitField value)?  $default,){
final _that = this;
switch (_that) {
case _LimitField() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String group, @JsonKey(name: 'default')  double defaultValue,  double min,  double max,  bool exclusive,  String unit,  String desc)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LimitField() when $default != null:
return $default(_that.key,_that.group,_that.defaultValue,_that.min,_that.max,_that.exclusive,_that.unit,_that.desc);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String group, @JsonKey(name: 'default')  double defaultValue,  double min,  double max,  bool exclusive,  String unit,  String desc)  $default,) {final _that = this;
switch (_that) {
case _LimitField():
return $default(_that.key,_that.group,_that.defaultValue,_that.min,_that.max,_that.exclusive,_that.unit,_that.desc);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String group, @JsonKey(name: 'default')  double defaultValue,  double min,  double max,  bool exclusive,  String unit,  String desc)?  $default,) {final _that = this;
switch (_that) {
case _LimitField() when $default != null:
return $default(_that.key,_that.group,_that.defaultValue,_that.min,_that.max,_that.exclusive,_that.unit,_that.desc);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LimitField implements LimitField {
  const _LimitField({required this.key, this.group = '', @JsonKey(name: 'default') this.defaultValue = 0, this.min = 0, this.max = 0, this.exclusive = false, this.unit = '', this.desc = ''});
  factory _LimitField.fromJson(Map<String, dynamic> json) => _$LimitFieldFromJson(json);

@override final  String key;
@override@JsonKey() final  String group;
@override@JsonKey(name: 'default') final  double defaultValue;
@override@JsonKey() final  double min;
@override@JsonKey() final  double max;
@override@JsonKey() final  bool exclusive;
@override@JsonKey() final  String unit;
@override@JsonKey() final  String desc;

/// Create a copy of LimitField
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LimitFieldCopyWith<_LimitField> get copyWith => __$LimitFieldCopyWithImpl<_LimitField>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LimitFieldToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LimitField&&(identical(other.key, key) || other.key == key)&&(identical(other.group, group) || other.group == group)&&(identical(other.defaultValue, defaultValue) || other.defaultValue == defaultValue)&&(identical(other.min, min) || other.min == min)&&(identical(other.max, max) || other.max == max)&&(identical(other.exclusive, exclusive) || other.exclusive == exclusive)&&(identical(other.unit, unit) || other.unit == unit)&&(identical(other.desc, desc) || other.desc == desc));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,group,defaultValue,min,max,exclusive,unit,desc);

@override
String toString() {
  return 'LimitField(key: $key, group: $group, defaultValue: $defaultValue, min: $min, max: $max, exclusive: $exclusive, unit: $unit, desc: $desc)';
}


}

/// @nodoc
abstract mixin class _$LimitFieldCopyWith<$Res> implements $LimitFieldCopyWith<$Res> {
  factory _$LimitFieldCopyWith(_LimitField value, $Res Function(_LimitField) _then) = __$LimitFieldCopyWithImpl;
@override @useResult
$Res call({
 String key, String group,@JsonKey(name: 'default') double defaultValue, double min, double max, bool exclusive, String unit, String desc
});




}
/// @nodoc
class __$LimitFieldCopyWithImpl<$Res>
    implements _$LimitFieldCopyWith<$Res> {
  __$LimitFieldCopyWithImpl(this._self, this._then);

  final _LimitField _self;
  final $Res Function(_LimitField) _then;

/// Create a copy of LimitField
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? group = null,Object? defaultValue = null,Object? min = null,Object? max = null,Object? exclusive = null,Object? unit = null,Object? desc = null,}) {
  return _then(_LimitField(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,defaultValue: null == defaultValue ? _self.defaultValue : defaultValue // ignore: cast_nullable_to_non_nullable
as double,min: null == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as double,max: null == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as double,exclusive: null == exclusive ? _self.exclusive : exclusive // ignore: cast_nullable_to_non_nullable
as bool,unit: null == unit ? _self.unit : unit // ignore: cast_nullable_to_non_nullable
as String,desc: null == desc ? _self.desc : desc // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
