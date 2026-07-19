// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'network.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NetworkConfig {

 String get httpProxy; String get httpsProxy; String get noProxy;
/// Create a copy of NetworkConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NetworkConfigCopyWith<NetworkConfig> get copyWith => _$NetworkConfigCopyWithImpl<NetworkConfig>(this as NetworkConfig, _$identity);

  /// Serializes this NetworkConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NetworkConfig&&(identical(other.httpProxy, httpProxy) || other.httpProxy == httpProxy)&&(identical(other.httpsProxy, httpsProxy) || other.httpsProxy == httpsProxy)&&(identical(other.noProxy, noProxy) || other.noProxy == noProxy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,httpProxy,httpsProxy,noProxy);

@override
String toString() {
  return 'NetworkConfig(httpProxy: $httpProxy, httpsProxy: $httpsProxy, noProxy: $noProxy)';
}


}

/// @nodoc
abstract mixin class $NetworkConfigCopyWith<$Res>  {
  factory $NetworkConfigCopyWith(NetworkConfig value, $Res Function(NetworkConfig) _then) = _$NetworkConfigCopyWithImpl;
@useResult
$Res call({
 String httpProxy, String httpsProxy, String noProxy
});




}
/// @nodoc
class _$NetworkConfigCopyWithImpl<$Res>
    implements $NetworkConfigCopyWith<$Res> {
  _$NetworkConfigCopyWithImpl(this._self, this._then);

  final NetworkConfig _self;
  final $Res Function(NetworkConfig) _then;

/// Create a copy of NetworkConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? httpProxy = null,Object? httpsProxy = null,Object? noProxy = null,}) {
  return _then(_self.copyWith(
httpProxy: null == httpProxy ? _self.httpProxy : httpProxy // ignore: cast_nullable_to_non_nullable
as String,httpsProxy: null == httpsProxy ? _self.httpsProxy : httpsProxy // ignore: cast_nullable_to_non_nullable
as String,noProxy: null == noProxy ? _self.noProxy : noProxy // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [NetworkConfig].
extension NetworkConfigPatterns on NetworkConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NetworkConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NetworkConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NetworkConfig value)  $default,){
final _that = this;
switch (_that) {
case _NetworkConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NetworkConfig value)?  $default,){
final _that = this;
switch (_that) {
case _NetworkConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String httpProxy,  String httpsProxy,  String noProxy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NetworkConfig() when $default != null:
return $default(_that.httpProxy,_that.httpsProxy,_that.noProxy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String httpProxy,  String httpsProxy,  String noProxy)  $default,) {final _that = this;
switch (_that) {
case _NetworkConfig():
return $default(_that.httpProxy,_that.httpsProxy,_that.noProxy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String httpProxy,  String httpsProxy,  String noProxy)?  $default,) {final _that = this;
switch (_that) {
case _NetworkConfig() when $default != null:
return $default(_that.httpProxy,_that.httpsProxy,_that.noProxy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NetworkConfig implements NetworkConfig {
  const _NetworkConfig({this.httpProxy = '', this.httpsProxy = '', this.noProxy = ''});
  factory _NetworkConfig.fromJson(Map<String, dynamic> json) => _$NetworkConfigFromJson(json);

@override@JsonKey() final  String httpProxy;
@override@JsonKey() final  String httpsProxy;
@override@JsonKey() final  String noProxy;

/// Create a copy of NetworkConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NetworkConfigCopyWith<_NetworkConfig> get copyWith => __$NetworkConfigCopyWithImpl<_NetworkConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NetworkConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NetworkConfig&&(identical(other.httpProxy, httpProxy) || other.httpProxy == httpProxy)&&(identical(other.httpsProxy, httpsProxy) || other.httpsProxy == httpsProxy)&&(identical(other.noProxy, noProxy) || other.noProxy == noProxy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,httpProxy,httpsProxy,noProxy);

@override
String toString() {
  return 'NetworkConfig(httpProxy: $httpProxy, httpsProxy: $httpsProxy, noProxy: $noProxy)';
}


}

/// @nodoc
abstract mixin class _$NetworkConfigCopyWith<$Res> implements $NetworkConfigCopyWith<$Res> {
  factory _$NetworkConfigCopyWith(_NetworkConfig value, $Res Function(_NetworkConfig) _then) = __$NetworkConfigCopyWithImpl;
@override @useResult
$Res call({
 String httpProxy, String httpsProxy, String noProxy
});




}
/// @nodoc
class __$NetworkConfigCopyWithImpl<$Res>
    implements _$NetworkConfigCopyWith<$Res> {
  __$NetworkConfigCopyWithImpl(this._self, this._then);

  final _NetworkConfig _self;
  final $Res Function(_NetworkConfig) _then;

/// Create a copy of NetworkConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? httpProxy = null,Object? httpsProxy = null,Object? noProxy = null,}) {
  return _then(_NetworkConfig(
httpProxy: null == httpProxy ? _self.httpProxy : httpProxy // ignore: cast_nullable_to_non_nullable
as String,httpsProxy: null == httpsProxy ? _self.httpsProxy : httpsProxy // ignore: cast_nullable_to_non_nullable
as String,noProxy: null == noProxy ? _self.noProxy : noProxy // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
