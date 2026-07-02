// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_capability.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ModelCapability {

 String get apiKeyId; String get keyName; String get provider; String get modelId; String get displayName;
/// Create a copy of ModelCapability
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelCapabilityCopyWith<ModelCapability> get copyWith => _$ModelCapabilityCopyWithImpl<ModelCapability>(this as ModelCapability, _$identity);

  /// Serializes this ModelCapability to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelCapability&&(identical(other.apiKeyId, apiKeyId) || other.apiKeyId == apiKeyId)&&(identical(other.keyName, keyName) || other.keyName == keyName)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.displayName, displayName) || other.displayName == displayName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apiKeyId,keyName,provider,modelId,displayName);

@override
String toString() {
  return 'ModelCapability(apiKeyId: $apiKeyId, keyName: $keyName, provider: $provider, modelId: $modelId, displayName: $displayName)';
}


}

/// @nodoc
abstract mixin class $ModelCapabilityCopyWith<$Res>  {
  factory $ModelCapabilityCopyWith(ModelCapability value, $Res Function(ModelCapability) _then) = _$ModelCapabilityCopyWithImpl;
@useResult
$Res call({
 String apiKeyId, String keyName, String provider, String modelId, String displayName
});




}
/// @nodoc
class _$ModelCapabilityCopyWithImpl<$Res>
    implements $ModelCapabilityCopyWith<$Res> {
  _$ModelCapabilityCopyWithImpl(this._self, this._then);

  final ModelCapability _self;
  final $Res Function(ModelCapability) _then;

/// Create a copy of ModelCapability
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? apiKeyId = null,Object? keyName = null,Object? provider = null,Object? modelId = null,Object? displayName = null,}) {
  return _then(_self.copyWith(
apiKeyId: null == apiKeyId ? _self.apiKeyId : apiKeyId // ignore: cast_nullable_to_non_nullable
as String,keyName: null == keyName ? _self.keyName : keyName // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ModelCapability].
extension ModelCapabilityPatterns on ModelCapability {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelCapability value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelCapability() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelCapability value)  $default,){
final _that = this;
switch (_that) {
case _ModelCapability():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelCapability value)?  $default,){
final _that = this;
switch (_that) {
case _ModelCapability() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String apiKeyId,  String keyName,  String provider,  String modelId,  String displayName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelCapability() when $default != null:
return $default(_that.apiKeyId,_that.keyName,_that.provider,_that.modelId,_that.displayName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String apiKeyId,  String keyName,  String provider,  String modelId,  String displayName)  $default,) {final _that = this;
switch (_that) {
case _ModelCapability():
return $default(_that.apiKeyId,_that.keyName,_that.provider,_that.modelId,_that.displayName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String apiKeyId,  String keyName,  String provider,  String modelId,  String displayName)?  $default,) {final _that = this;
switch (_that) {
case _ModelCapability() when $default != null:
return $default(_that.apiKeyId,_that.keyName,_that.provider,_that.modelId,_that.displayName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModelCapability implements ModelCapability {
  const _ModelCapability({required this.apiKeyId, this.keyName = '', this.provider = '', required this.modelId, this.displayName = ''});
  factory _ModelCapability.fromJson(Map<String, dynamic> json) => _$ModelCapabilityFromJson(json);

@override final  String apiKeyId;
@override@JsonKey() final  String keyName;
@override@JsonKey() final  String provider;
@override final  String modelId;
@override@JsonKey() final  String displayName;

/// Create a copy of ModelCapability
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelCapabilityCopyWith<_ModelCapability> get copyWith => __$ModelCapabilityCopyWithImpl<_ModelCapability>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModelCapabilityToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelCapability&&(identical(other.apiKeyId, apiKeyId) || other.apiKeyId == apiKeyId)&&(identical(other.keyName, keyName) || other.keyName == keyName)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.modelId, modelId) || other.modelId == modelId)&&(identical(other.displayName, displayName) || other.displayName == displayName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apiKeyId,keyName,provider,modelId,displayName);

@override
String toString() {
  return 'ModelCapability(apiKeyId: $apiKeyId, keyName: $keyName, provider: $provider, modelId: $modelId, displayName: $displayName)';
}


}

/// @nodoc
abstract mixin class _$ModelCapabilityCopyWith<$Res> implements $ModelCapabilityCopyWith<$Res> {
  factory _$ModelCapabilityCopyWith(_ModelCapability value, $Res Function(_ModelCapability) _then) = __$ModelCapabilityCopyWithImpl;
@override @useResult
$Res call({
 String apiKeyId, String keyName, String provider, String modelId, String displayName
});




}
/// @nodoc
class __$ModelCapabilityCopyWithImpl<$Res>
    implements _$ModelCapabilityCopyWith<$Res> {
  __$ModelCapabilityCopyWithImpl(this._self, this._then);

  final _ModelCapability _self;
  final $Res Function(_ModelCapability) _then;

/// Create a copy of ModelCapability
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? apiKeyId = null,Object? keyName = null,Object? provider = null,Object? modelId = null,Object? displayName = null,}) {
  return _then(_ModelCapability(
apiKeyId: null == apiKeyId ? _self.apiKeyId : apiKeyId // ignore: cast_nullable_to_non_nullable
as String,keyName: null == keyName ? _self.keyName : keyName // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,modelId: null == modelId ? _self.modelId : modelId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
