// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'values.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Field {

 String get name; String get type; String? get description;
/// Create a copy of Field
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FieldCopyWith<Field> get copyWith => _$FieldCopyWithImpl<Field>(this as Field, _$identity);

  /// Serializes this Field to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Field&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,type,description);

@override
String toString() {
  return 'Field(name: $name, type: $type, description: $description)';
}


}

/// @nodoc
abstract mixin class $FieldCopyWith<$Res>  {
  factory $FieldCopyWith(Field value, $Res Function(Field) _then) = _$FieldCopyWithImpl;
@useResult
$Res call({
 String name, String type, String? description
});




}
/// @nodoc
class _$FieldCopyWithImpl<$Res>
    implements $FieldCopyWith<$Res> {
  _$FieldCopyWithImpl(this._self, this._then);

  final Field _self;
  final $Res Function(Field) _then;

/// Create a copy of Field
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? type = null,Object? description = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Field].
extension FieldPatterns on Field {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Field value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Field() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Field value)  $default,){
final _that = this;
switch (_that) {
case _Field():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Field value)?  $default,){
final _that = this;
switch (_that) {
case _Field() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String type,  String? description)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Field() when $default != null:
return $default(_that.name,_that.type,_that.description);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String type,  String? description)  $default,) {final _that = this;
switch (_that) {
case _Field():
return $default(_that.name,_that.type,_that.description);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String type,  String? description)?  $default,) {final _that = this;
switch (_that) {
case _Field() when $default != null:
return $default(_that.name,_that.type,_that.description);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Field implements Field {
  const _Field({required this.name, required this.type, this.description});
  factory _Field.fromJson(Map<String, dynamic> json) => _$FieldFromJson(json);

@override final  String name;
@override final  String type;
@override final  String? description;

/// Create a copy of Field
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FieldCopyWith<_Field> get copyWith => __$FieldCopyWithImpl<_Field>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FieldToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Field&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,type,description);

@override
String toString() {
  return 'Field(name: $name, type: $type, description: $description)';
}


}

/// @nodoc
abstract mixin class _$FieldCopyWith<$Res> implements $FieldCopyWith<$Res> {
  factory _$FieldCopyWith(_Field value, $Res Function(_Field) _then) = __$FieldCopyWithImpl;
@override @useResult
$Res call({
 String name, String type, String? description
});




}
/// @nodoc
class __$FieldCopyWithImpl<$Res>
    implements _$FieldCopyWith<$Res> {
  __$FieldCopyWithImpl(this._self, this._then);

  final _Field _self;
  final $Res Function(_Field) _then;

/// Create a copy of Field
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? type = null,Object? description = freezed,}) {
  return _then(_Field(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ToolRef {

 String get ref; String get name;
/// Create a copy of ToolRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolRefCopyWith<ToolRef> get copyWith => _$ToolRefCopyWithImpl<ToolRef>(this as ToolRef, _$identity);

  /// Serializes this ToolRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolRef&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ref,name);

@override
String toString() {
  return 'ToolRef(ref: $ref, name: $name)';
}


}

/// @nodoc
abstract mixin class $ToolRefCopyWith<$Res>  {
  factory $ToolRefCopyWith(ToolRef value, $Res Function(ToolRef) _then) = _$ToolRefCopyWithImpl;
@useResult
$Res call({
 String ref, String name
});




}
/// @nodoc
class _$ToolRefCopyWithImpl<$Res>
    implements $ToolRefCopyWith<$Res> {
  _$ToolRefCopyWithImpl(this._self, this._then);

  final ToolRef _self;
  final $Res Function(ToolRef) _then;

/// Create a copy of ToolRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ref = null,Object? name = null,}) {
  return _then(_self.copyWith(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ToolRef].
extension ToolRefPatterns on ToolRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolRef value)  $default,){
final _that = this;
switch (_that) {
case _ToolRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolRef value)?  $default,){
final _that = this;
switch (_that) {
case _ToolRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ref,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolRef() when $default != null:
return $default(_that.ref,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ref,  String name)  $default,) {final _that = this;
switch (_that) {
case _ToolRef():
return $default(_that.ref,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ref,  String name)?  $default,) {final _that = this;
switch (_that) {
case _ToolRef() when $default != null:
return $default(_that.ref,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ToolRef implements ToolRef {
  const _ToolRef({required this.ref, required this.name});
  factory _ToolRef.fromJson(Map<String, dynamic> json) => _$ToolRefFromJson(json);

@override final  String ref;
@override final  String name;

/// Create a copy of ToolRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolRefCopyWith<_ToolRef> get copyWith => __$ToolRefCopyWithImpl<_ToolRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolRefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolRef&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ref,name);

@override
String toString() {
  return 'ToolRef(ref: $ref, name: $name)';
}


}

/// @nodoc
abstract mixin class _$ToolRefCopyWith<$Res> implements $ToolRefCopyWith<$Res> {
  factory _$ToolRefCopyWith(_ToolRef value, $Res Function(_ToolRef) _then) = __$ToolRefCopyWithImpl;
@override @useResult
$Res call({
 String ref, String name
});




}
/// @nodoc
class __$ToolRefCopyWithImpl<$Res>
    implements _$ToolRefCopyWith<$Res> {
  __$ToolRefCopyWithImpl(this._self, this._then);

  final _ToolRef _self;
  final $Res Function(_ToolRef) _then;

/// Create a copy of ToolRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ref = null,Object? name = null,}) {
  return _then(_ToolRef(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$MethodSpec {

 String get name; String? get description; List<Field> get inputs; List<Field> get outputs; String get body; bool get streaming; int? get timeout;
/// Create a copy of MethodSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MethodSpecCopyWith<MethodSpec> get copyWith => _$MethodSpecCopyWithImpl<MethodSpec>(this as MethodSpec, _$identity);

  /// Serializes this MethodSpec to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MethodSpec&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.inputs, inputs)&&const DeepCollectionEquality().equals(other.outputs, outputs)&&(identical(other.body, body) || other.body == body)&&(identical(other.streaming, streaming) || other.streaming == streaming)&&(identical(other.timeout, timeout) || other.timeout == timeout));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(inputs),const DeepCollectionEquality().hash(outputs),body,streaming,timeout);

@override
String toString() {
  return 'MethodSpec(name: $name, description: $description, inputs: $inputs, outputs: $outputs, body: $body, streaming: $streaming, timeout: $timeout)';
}


}

/// @nodoc
abstract mixin class $MethodSpecCopyWith<$Res>  {
  factory $MethodSpecCopyWith(MethodSpec value, $Res Function(MethodSpec) _then) = _$MethodSpecCopyWithImpl;
@useResult
$Res call({
 String name, String? description, List<Field> inputs, List<Field> outputs, String body, bool streaming, int? timeout
});




}
/// @nodoc
class _$MethodSpecCopyWithImpl<$Res>
    implements $MethodSpecCopyWith<$Res> {
  _$MethodSpecCopyWithImpl(this._self, this._then);

  final MethodSpec _self;
  final $Res Function(MethodSpec) _then;

/// Create a copy of MethodSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = freezed,Object? inputs = null,Object? outputs = null,Object? body = null,Object? streaming = null,Object? timeout = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,inputs: null == inputs ? _self.inputs : inputs // ignore: cast_nullable_to_non_nullable
as List<Field>,outputs: null == outputs ? _self.outputs : outputs // ignore: cast_nullable_to_non_nullable
as List<Field>,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,streaming: null == streaming ? _self.streaming : streaming // ignore: cast_nullable_to_non_nullable
as bool,timeout: freezed == timeout ? _self.timeout : timeout // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [MethodSpec].
extension MethodSpecPatterns on MethodSpec {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MethodSpec value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MethodSpec() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MethodSpec value)  $default,){
final _that = this;
switch (_that) {
case _MethodSpec():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MethodSpec value)?  $default,){
final _that = this;
switch (_that) {
case _MethodSpec() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? description,  List<Field> inputs,  List<Field> outputs,  String body,  bool streaming,  int? timeout)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MethodSpec() when $default != null:
return $default(_that.name,_that.description,_that.inputs,_that.outputs,_that.body,_that.streaming,_that.timeout);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? description,  List<Field> inputs,  List<Field> outputs,  String body,  bool streaming,  int? timeout)  $default,) {final _that = this;
switch (_that) {
case _MethodSpec():
return $default(_that.name,_that.description,_that.inputs,_that.outputs,_that.body,_that.streaming,_that.timeout);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? description,  List<Field> inputs,  List<Field> outputs,  String body,  bool streaming,  int? timeout)?  $default,) {final _that = this;
switch (_that) {
case _MethodSpec() when $default != null:
return $default(_that.name,_that.description,_that.inputs,_that.outputs,_that.body,_that.streaming,_that.timeout);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MethodSpec implements MethodSpec {
  const _MethodSpec({required this.name, this.description, final  List<Field> inputs = const <Field>[], final  List<Field> outputs = const <Field>[], this.body = '', this.streaming = false, this.timeout}): _inputs = inputs,_outputs = outputs;
  factory _MethodSpec.fromJson(Map<String, dynamic> json) => _$MethodSpecFromJson(json);

@override final  String name;
@override final  String? description;
 final  List<Field> _inputs;
@override@JsonKey() List<Field> get inputs {
  if (_inputs is EqualUnmodifiableListView) return _inputs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_inputs);
}

 final  List<Field> _outputs;
@override@JsonKey() List<Field> get outputs {
  if (_outputs is EqualUnmodifiableListView) return _outputs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_outputs);
}

@override@JsonKey() final  String body;
@override@JsonKey() final  bool streaming;
@override final  int? timeout;

/// Create a copy of MethodSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MethodSpecCopyWith<_MethodSpec> get copyWith => __$MethodSpecCopyWithImpl<_MethodSpec>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MethodSpecToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MethodSpec&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._inputs, _inputs)&&const DeepCollectionEquality().equals(other._outputs, _outputs)&&(identical(other.body, body) || other.body == body)&&(identical(other.streaming, streaming) || other.streaming == streaming)&&(identical(other.timeout, timeout) || other.timeout == timeout));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(_inputs),const DeepCollectionEquality().hash(_outputs),body,streaming,timeout);

@override
String toString() {
  return 'MethodSpec(name: $name, description: $description, inputs: $inputs, outputs: $outputs, body: $body, streaming: $streaming, timeout: $timeout)';
}


}

/// @nodoc
abstract mixin class _$MethodSpecCopyWith<$Res> implements $MethodSpecCopyWith<$Res> {
  factory _$MethodSpecCopyWith(_MethodSpec value, $Res Function(_MethodSpec) _then) = __$MethodSpecCopyWithImpl;
@override @useResult
$Res call({
 String name, String? description, List<Field> inputs, List<Field> outputs, String body, bool streaming, int? timeout
});




}
/// @nodoc
class __$MethodSpecCopyWithImpl<$Res>
    implements _$MethodSpecCopyWith<$Res> {
  __$MethodSpecCopyWithImpl(this._self, this._then);

  final _MethodSpec _self;
  final $Res Function(_MethodSpec) _then;

/// Create a copy of MethodSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = freezed,Object? inputs = null,Object? outputs = null,Object? body = null,Object? streaming = null,Object? timeout = freezed,}) {
  return _then(_MethodSpec(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,inputs: null == inputs ? _self._inputs : inputs // ignore: cast_nullable_to_non_nullable
as List<Field>,outputs: null == outputs ? _self._outputs : outputs // ignore: cast_nullable_to_non_nullable
as List<Field>,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,streaming: null == streaming ? _self.streaming : streaming // ignore: cast_nullable_to_non_nullable
as bool,timeout: freezed == timeout ? _self.timeout : timeout // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$InitArgSpec {

 String get name; String get type; String? get description; bool get required; bool get sensitive;@JsonKey(name: 'default') Object? get defaultValue;
/// Create a copy of InitArgSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InitArgSpecCopyWith<InitArgSpec> get copyWith => _$InitArgSpecCopyWithImpl<InitArgSpec>(this as InitArgSpec, _$identity);

  /// Serializes this InitArgSpec to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InitArgSpec&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.description, description) || other.description == description)&&(identical(other.required, required) || other.required == required)&&(identical(other.sensitive, sensitive) || other.sensitive == sensitive)&&const DeepCollectionEquality().equals(other.defaultValue, defaultValue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,type,description,required,sensitive,const DeepCollectionEquality().hash(defaultValue));

@override
String toString() {
  return 'InitArgSpec(name: $name, type: $type, description: $description, required: $required, sensitive: $sensitive, defaultValue: $defaultValue)';
}


}

/// @nodoc
abstract mixin class $InitArgSpecCopyWith<$Res>  {
  factory $InitArgSpecCopyWith(InitArgSpec value, $Res Function(InitArgSpec) _then) = _$InitArgSpecCopyWithImpl;
@useResult
$Res call({
 String name, String type, String? description, bool required, bool sensitive,@JsonKey(name: 'default') Object? defaultValue
});




}
/// @nodoc
class _$InitArgSpecCopyWithImpl<$Res>
    implements $InitArgSpecCopyWith<$Res> {
  _$InitArgSpecCopyWithImpl(this._self, this._then);

  final InitArgSpec _self;
  final $Res Function(InitArgSpec) _then;

/// Create a copy of InitArgSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? type = null,Object? description = freezed,Object? required = null,Object? sensitive = null,Object? defaultValue = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,sensitive: null == sensitive ? _self.sensitive : sensitive // ignore: cast_nullable_to_non_nullable
as bool,defaultValue: freezed == defaultValue ? _self.defaultValue : defaultValue ,
  ));
}

}


/// Adds pattern-matching-related methods to [InitArgSpec].
extension InitArgSpecPatterns on InitArgSpec {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InitArgSpec value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InitArgSpec() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InitArgSpec value)  $default,){
final _that = this;
switch (_that) {
case _InitArgSpec():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InitArgSpec value)?  $default,){
final _that = this;
switch (_that) {
case _InitArgSpec() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String type,  String? description,  bool required,  bool sensitive, @JsonKey(name: 'default')  Object? defaultValue)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InitArgSpec() when $default != null:
return $default(_that.name,_that.type,_that.description,_that.required,_that.sensitive,_that.defaultValue);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String type,  String? description,  bool required,  bool sensitive, @JsonKey(name: 'default')  Object? defaultValue)  $default,) {final _that = this;
switch (_that) {
case _InitArgSpec():
return $default(_that.name,_that.type,_that.description,_that.required,_that.sensitive,_that.defaultValue);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String type,  String? description,  bool required,  bool sensitive, @JsonKey(name: 'default')  Object? defaultValue)?  $default,) {final _that = this;
switch (_that) {
case _InitArgSpec() when $default != null:
return $default(_that.name,_that.type,_that.description,_that.required,_that.sensitive,_that.defaultValue);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InitArgSpec implements InitArgSpec {
  const _InitArgSpec({required this.name, required this.type, this.description, this.required = false, this.sensitive = false, @JsonKey(name: 'default') this.defaultValue});
  factory _InitArgSpec.fromJson(Map<String, dynamic> json) => _$InitArgSpecFromJson(json);

@override final  String name;
@override final  String type;
@override final  String? description;
@override@JsonKey() final  bool required;
@override@JsonKey() final  bool sensitive;
@override@JsonKey(name: 'default') final  Object? defaultValue;

/// Create a copy of InitArgSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InitArgSpecCopyWith<_InitArgSpec> get copyWith => __$InitArgSpecCopyWithImpl<_InitArgSpec>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InitArgSpecToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InitArgSpec&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.description, description) || other.description == description)&&(identical(other.required, required) || other.required == required)&&(identical(other.sensitive, sensitive) || other.sensitive == sensitive)&&const DeepCollectionEquality().equals(other.defaultValue, defaultValue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,type,description,required,sensitive,const DeepCollectionEquality().hash(defaultValue));

@override
String toString() {
  return 'InitArgSpec(name: $name, type: $type, description: $description, required: $required, sensitive: $sensitive, defaultValue: $defaultValue)';
}


}

/// @nodoc
abstract mixin class _$InitArgSpecCopyWith<$Res> implements $InitArgSpecCopyWith<$Res> {
  factory _$InitArgSpecCopyWith(_InitArgSpec value, $Res Function(_InitArgSpec) _then) = __$InitArgSpecCopyWithImpl;
@override @useResult
$Res call({
 String name, String type, String? description, bool required, bool sensitive,@JsonKey(name: 'default') Object? defaultValue
});




}
/// @nodoc
class __$InitArgSpecCopyWithImpl<$Res>
    implements _$InitArgSpecCopyWith<$Res> {
  __$InitArgSpecCopyWithImpl(this._self, this._then);

  final _InitArgSpec _self;
  final $Res Function(_InitArgSpec) _then;

/// Create a copy of InitArgSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? type = null,Object? description = freezed,Object? required = null,Object? sensitive = null,Object? defaultValue = freezed,}) {
  return _then(_InitArgSpec(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,sensitive: null == sensitive ? _self.sensitive : sensitive // ignore: cast_nullable_to_non_nullable
as bool,defaultValue: freezed == defaultValue ? _self.defaultValue : defaultValue ,
  ));
}


}


/// @nodoc
mixin _$NodePosition {

 int get x; int get y;
/// Create a copy of NodePosition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NodePositionCopyWith<NodePosition> get copyWith => _$NodePositionCopyWithImpl<NodePosition>(this as NodePosition, _$identity);

  /// Serializes this NodePosition to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NodePosition&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,x,y);

@override
String toString() {
  return 'NodePosition(x: $x, y: $y)';
}


}

/// @nodoc
abstract mixin class $NodePositionCopyWith<$Res>  {
  factory $NodePositionCopyWith(NodePosition value, $Res Function(NodePosition) _then) = _$NodePositionCopyWithImpl;
@useResult
$Res call({
 int x, int y
});




}
/// @nodoc
class _$NodePositionCopyWithImpl<$Res>
    implements $NodePositionCopyWith<$Res> {
  _$NodePositionCopyWithImpl(this._self, this._then);

  final NodePosition _self;
  final $Res Function(NodePosition) _then;

/// Create a copy of NodePosition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? x = null,Object? y = null,}) {
  return _then(_self.copyWith(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [NodePosition].
extension NodePositionPatterns on NodePosition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NodePosition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NodePosition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NodePosition value)  $default,){
final _that = this;
switch (_that) {
case _NodePosition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NodePosition value)?  $default,){
final _that = this;
switch (_that) {
case _NodePosition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int x,  int y)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NodePosition() when $default != null:
return $default(_that.x,_that.y);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int x,  int y)  $default,) {final _that = this;
switch (_that) {
case _NodePosition():
return $default(_that.x,_that.y);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int x,  int y)?  $default,) {final _that = this;
switch (_that) {
case _NodePosition() when $default != null:
return $default(_that.x,_that.y);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NodePosition implements NodePosition {
  const _NodePosition({this.x = 0, this.y = 0});
  factory _NodePosition.fromJson(Map<String, dynamic> json) => _$NodePositionFromJson(json);

@override@JsonKey() final  int x;
@override@JsonKey() final  int y;

/// Create a copy of NodePosition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NodePositionCopyWith<_NodePosition> get copyWith => __$NodePositionCopyWithImpl<_NodePosition>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NodePositionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NodePosition&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,x,y);

@override
String toString() {
  return 'NodePosition(x: $x, y: $y)';
}


}

/// @nodoc
abstract mixin class _$NodePositionCopyWith<$Res> implements $NodePositionCopyWith<$Res> {
  factory _$NodePositionCopyWith(_NodePosition value, $Res Function(_NodePosition) _then) = __$NodePositionCopyWithImpl;
@override @useResult
$Res call({
 int x, int y
});




}
/// @nodoc
class __$NodePositionCopyWithImpl<$Res>
    implements _$NodePositionCopyWith<$Res> {
  __$NodePositionCopyWithImpl(this._self, this._then);

  final _NodePosition _self;
  final $Res Function(_NodePosition) _then;

/// Create a copy of NodePosition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? x = null,Object? y = null,}) {
  return _then(_NodePosition(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$RetryConfig {

 int get maxAttempts; String? get backoff; int? get delayMs;
/// Create a copy of RetryConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RetryConfigCopyWith<RetryConfig> get copyWith => _$RetryConfigCopyWithImpl<RetryConfig>(this as RetryConfig, _$identity);

  /// Serializes this RetryConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RetryConfig&&(identical(other.maxAttempts, maxAttempts) || other.maxAttempts == maxAttempts)&&(identical(other.backoff, backoff) || other.backoff == backoff)&&(identical(other.delayMs, delayMs) || other.delayMs == delayMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,maxAttempts,backoff,delayMs);

@override
String toString() {
  return 'RetryConfig(maxAttempts: $maxAttempts, backoff: $backoff, delayMs: $delayMs)';
}


}

/// @nodoc
abstract mixin class $RetryConfigCopyWith<$Res>  {
  factory $RetryConfigCopyWith(RetryConfig value, $Res Function(RetryConfig) _then) = _$RetryConfigCopyWithImpl;
@useResult
$Res call({
 int maxAttempts, String? backoff, int? delayMs
});




}
/// @nodoc
class _$RetryConfigCopyWithImpl<$Res>
    implements $RetryConfigCopyWith<$Res> {
  _$RetryConfigCopyWithImpl(this._self, this._then);

  final RetryConfig _self;
  final $Res Function(RetryConfig) _then;

/// Create a copy of RetryConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? maxAttempts = null,Object? backoff = freezed,Object? delayMs = freezed,}) {
  return _then(_self.copyWith(
maxAttempts: null == maxAttempts ? _self.maxAttempts : maxAttempts // ignore: cast_nullable_to_non_nullable
as int,backoff: freezed == backoff ? _self.backoff : backoff // ignore: cast_nullable_to_non_nullable
as String?,delayMs: freezed == delayMs ? _self.delayMs : delayMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [RetryConfig].
extension RetryConfigPatterns on RetryConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RetryConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RetryConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RetryConfig value)  $default,){
final _that = this;
switch (_that) {
case _RetryConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RetryConfig value)?  $default,){
final _that = this;
switch (_that) {
case _RetryConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int maxAttempts,  String? backoff,  int? delayMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RetryConfig() when $default != null:
return $default(_that.maxAttempts,_that.backoff,_that.delayMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int maxAttempts,  String? backoff,  int? delayMs)  $default,) {final _that = this;
switch (_that) {
case _RetryConfig():
return $default(_that.maxAttempts,_that.backoff,_that.delayMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int maxAttempts,  String? backoff,  int? delayMs)?  $default,) {final _that = this;
switch (_that) {
case _RetryConfig() when $default != null:
return $default(_that.maxAttempts,_that.backoff,_that.delayMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RetryConfig implements RetryConfig {
  const _RetryConfig({this.maxAttempts = 0, this.backoff, this.delayMs});
  factory _RetryConfig.fromJson(Map<String, dynamic> json) => _$RetryConfigFromJson(json);

@override@JsonKey() final  int maxAttempts;
@override final  String? backoff;
@override final  int? delayMs;

/// Create a copy of RetryConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RetryConfigCopyWith<_RetryConfig> get copyWith => __$RetryConfigCopyWithImpl<_RetryConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RetryConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RetryConfig&&(identical(other.maxAttempts, maxAttempts) || other.maxAttempts == maxAttempts)&&(identical(other.backoff, backoff) || other.backoff == backoff)&&(identical(other.delayMs, delayMs) || other.delayMs == delayMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,maxAttempts,backoff,delayMs);

@override
String toString() {
  return 'RetryConfig(maxAttempts: $maxAttempts, backoff: $backoff, delayMs: $delayMs)';
}


}

/// @nodoc
abstract mixin class _$RetryConfigCopyWith<$Res> implements $RetryConfigCopyWith<$Res> {
  factory _$RetryConfigCopyWith(_RetryConfig value, $Res Function(_RetryConfig) _then) = __$RetryConfigCopyWithImpl;
@override @useResult
$Res call({
 int maxAttempts, String? backoff, int? delayMs
});




}
/// @nodoc
class __$RetryConfigCopyWithImpl<$Res>
    implements _$RetryConfigCopyWith<$Res> {
  __$RetryConfigCopyWithImpl(this._self, this._then);

  final _RetryConfig _self;
  final $Res Function(_RetryConfig) _then;

/// Create a copy of RetryConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? maxAttempts = null,Object? backoff = freezed,Object? delayMs = freezed,}) {
  return _then(_RetryConfig(
maxAttempts: null == maxAttempts ? _self.maxAttempts : maxAttempts // ignore: cast_nullable_to_non_nullable
as int,backoff: freezed == backoff ? _self.backoff : backoff // ignore: cast_nullable_to_non_nullable
as String?,delayMs: freezed == delayMs ? _self.delayMs : delayMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$Edge {

 String get id; String get from; String? get fromPort; String get to;
/// Create a copy of Edge
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EdgeCopyWith<Edge> get copyWith => _$EdgeCopyWithImpl<Edge>(this as Edge, _$identity);

  /// Serializes this Edge to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Edge&&(identical(other.id, id) || other.id == id)&&(identical(other.from, from) || other.from == from)&&(identical(other.fromPort, fromPort) || other.fromPort == fromPort)&&(identical(other.to, to) || other.to == to));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,from,fromPort,to);

@override
String toString() {
  return 'Edge(id: $id, from: $from, fromPort: $fromPort, to: $to)';
}


}

/// @nodoc
abstract mixin class $EdgeCopyWith<$Res>  {
  factory $EdgeCopyWith(Edge value, $Res Function(Edge) _then) = _$EdgeCopyWithImpl;
@useResult
$Res call({
 String id, String from, String? fromPort, String to
});




}
/// @nodoc
class _$EdgeCopyWithImpl<$Res>
    implements $EdgeCopyWith<$Res> {
  _$EdgeCopyWithImpl(this._self, this._then);

  final Edge _self;
  final $Res Function(Edge) _then;

/// Create a copy of Edge
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? from = null,Object? fromPort = freezed,Object? to = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as String,fromPort: freezed == fromPort ? _self.fromPort : fromPort // ignore: cast_nullable_to_non_nullable
as String?,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Edge].
extension EdgePatterns on Edge {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Edge value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Edge() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Edge value)  $default,){
final _that = this;
switch (_that) {
case _Edge():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Edge value)?  $default,){
final _that = this;
switch (_that) {
case _Edge() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String from,  String? fromPort,  String to)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Edge() when $default != null:
return $default(_that.id,_that.from,_that.fromPort,_that.to);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String from,  String? fromPort,  String to)  $default,) {final _that = this;
switch (_that) {
case _Edge():
return $default(_that.id,_that.from,_that.fromPort,_that.to);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String from,  String? fromPort,  String to)?  $default,) {final _that = this;
switch (_that) {
case _Edge() when $default != null:
return $default(_that.id,_that.from,_that.fromPort,_that.to);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Edge implements Edge {
  const _Edge({required this.id, required this.from, this.fromPort, required this.to});
  factory _Edge.fromJson(Map<String, dynamic> json) => _$EdgeFromJson(json);

@override final  String id;
@override final  String from;
@override final  String? fromPort;
@override final  String to;

/// Create a copy of Edge
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EdgeCopyWith<_Edge> get copyWith => __$EdgeCopyWithImpl<_Edge>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EdgeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Edge&&(identical(other.id, id) || other.id == id)&&(identical(other.from, from) || other.from == from)&&(identical(other.fromPort, fromPort) || other.fromPort == fromPort)&&(identical(other.to, to) || other.to == to));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,from,fromPort,to);

@override
String toString() {
  return 'Edge(id: $id, from: $from, fromPort: $fromPort, to: $to)';
}


}

/// @nodoc
abstract mixin class _$EdgeCopyWith<$Res> implements $EdgeCopyWith<$Res> {
  factory _$EdgeCopyWith(_Edge value, $Res Function(_Edge) _then) = __$EdgeCopyWithImpl;
@override @useResult
$Res call({
 String id, String from, String? fromPort, String to
});




}
/// @nodoc
class __$EdgeCopyWithImpl<$Res>
    implements _$EdgeCopyWith<$Res> {
  __$EdgeCopyWithImpl(this._self, this._then);

  final _Edge _self;
  final $Res Function(_Edge) _then;

/// Create a copy of Edge
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? from = null,Object? fromPort = freezed,Object? to = null,}) {
  return _then(_Edge(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as String,fromPort: freezed == fromPort ? _self.fromPort : fromPort // ignore: cast_nullable_to_non_nullable
as String?,to: null == to ? _self.to : to // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Node {

 String get id;@JsonKey(unknownEnumValue: NodeKind.unknown) NodeKind get kind; String get ref; Map<String, String> get input; RetryConfig? get retry; NodePosition? get pos; String? get notes;
/// Create a copy of Node
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NodeCopyWith<Node> get copyWith => _$NodeCopyWithImpl<Node>(this as Node, _$identity);

  /// Serializes this Node to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Node&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.ref, ref) || other.ref == ref)&&const DeepCollectionEquality().equals(other.input, input)&&(identical(other.retry, retry) || other.retry == retry)&&(identical(other.pos, pos) || other.pos == pos)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,ref,const DeepCollectionEquality().hash(input),retry,pos,notes);

@override
String toString() {
  return 'Node(id: $id, kind: $kind, ref: $ref, input: $input, retry: $retry, pos: $pos, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $NodeCopyWith<$Res>  {
  factory $NodeCopyWith(Node value, $Res Function(Node) _then) = _$NodeCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: NodeKind.unknown) NodeKind kind, String ref, Map<String, String> input, RetryConfig? retry, NodePosition? pos, String? notes
});


$RetryConfigCopyWith<$Res>? get retry;$NodePositionCopyWith<$Res>? get pos;

}
/// @nodoc
class _$NodeCopyWithImpl<$Res>
    implements $NodeCopyWith<$Res> {
  _$NodeCopyWithImpl(this._self, this._then);

  final Node _self;
  final $Res Function(Node) _then;

/// Create a copy of Node
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? ref = null,Object? input = null,Object? retry = freezed,Object? pos = freezed,Object? notes = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as NodeKind,ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as Map<String, String>,retry: freezed == retry ? _self.retry : retry // ignore: cast_nullable_to_non_nullable
as RetryConfig?,pos: freezed == pos ? _self.pos : pos // ignore: cast_nullable_to_non_nullable
as NodePosition?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Node
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RetryConfigCopyWith<$Res>? get retry {
    if (_self.retry == null) {
    return null;
  }

  return $RetryConfigCopyWith<$Res>(_self.retry!, (value) {
    return _then(_self.copyWith(retry: value));
  });
}/// Create a copy of Node
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NodePositionCopyWith<$Res>? get pos {
    if (_self.pos == null) {
    return null;
  }

  return $NodePositionCopyWith<$Res>(_self.pos!, (value) {
    return _then(_self.copyWith(pos: value));
  });
}
}


/// Adds pattern-matching-related methods to [Node].
extension NodePatterns on Node {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Node value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Node() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Node value)  $default,){
final _that = this;
switch (_that) {
case _Node():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Node value)?  $default,){
final _that = this;
switch (_that) {
case _Node() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(unknownEnumValue: NodeKind.unknown)  NodeKind kind,  String ref,  Map<String, String> input,  RetryConfig? retry,  NodePosition? pos,  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Node() when $default != null:
return $default(_that.id,_that.kind,_that.ref,_that.input,_that.retry,_that.pos,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(unknownEnumValue: NodeKind.unknown)  NodeKind kind,  String ref,  Map<String, String> input,  RetryConfig? retry,  NodePosition? pos,  String? notes)  $default,) {final _that = this;
switch (_that) {
case _Node():
return $default(_that.id,_that.kind,_that.ref,_that.input,_that.retry,_that.pos,_that.notes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(unknownEnumValue: NodeKind.unknown)  NodeKind kind,  String ref,  Map<String, String> input,  RetryConfig? retry,  NodePosition? pos,  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _Node() when $default != null:
return $default(_that.id,_that.kind,_that.ref,_that.input,_that.retry,_that.pos,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Node implements Node {
  const _Node({required this.id, @JsonKey(unknownEnumValue: NodeKind.unknown) required this.kind, this.ref = '', final  Map<String, String> input = const <String, String>{}, this.retry, this.pos, this.notes}): _input = input;
  factory _Node.fromJson(Map<String, dynamic> json) => _$NodeFromJson(json);

@override final  String id;
@override@JsonKey(unknownEnumValue: NodeKind.unknown) final  NodeKind kind;
@override@JsonKey() final  String ref;
 final  Map<String, String> _input;
@override@JsonKey() Map<String, String> get input {
  if (_input is EqualUnmodifiableMapView) return _input;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_input);
}

@override final  RetryConfig? retry;
@override final  NodePosition? pos;
@override final  String? notes;

/// Create a copy of Node
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NodeCopyWith<_Node> get copyWith => __$NodeCopyWithImpl<_Node>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NodeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Node&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.ref, ref) || other.ref == ref)&&const DeepCollectionEquality().equals(other._input, _input)&&(identical(other.retry, retry) || other.retry == retry)&&(identical(other.pos, pos) || other.pos == pos)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,ref,const DeepCollectionEquality().hash(_input),retry,pos,notes);

@override
String toString() {
  return 'Node(id: $id, kind: $kind, ref: $ref, input: $input, retry: $retry, pos: $pos, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$NodeCopyWith<$Res> implements $NodeCopyWith<$Res> {
  factory _$NodeCopyWith(_Node value, $Res Function(_Node) _then) = __$NodeCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(unknownEnumValue: NodeKind.unknown) NodeKind kind, String ref, Map<String, String> input, RetryConfig? retry, NodePosition? pos, String? notes
});


@override $RetryConfigCopyWith<$Res>? get retry;@override $NodePositionCopyWith<$Res>? get pos;

}
/// @nodoc
class __$NodeCopyWithImpl<$Res>
    implements _$NodeCopyWith<$Res> {
  __$NodeCopyWithImpl(this._self, this._then);

  final _Node _self;
  final $Res Function(_Node) _then;

/// Create a copy of Node
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? ref = null,Object? input = null,Object? retry = freezed,Object? pos = freezed,Object? notes = freezed,}) {
  return _then(_Node(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as NodeKind,ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self._input : input // ignore: cast_nullable_to_non_nullable
as Map<String, String>,retry: freezed == retry ? _self.retry : retry // ignore: cast_nullable_to_non_nullable
as RetryConfig?,pos: freezed == pos ? _self.pos : pos // ignore: cast_nullable_to_non_nullable
as NodePosition?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Node
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RetryConfigCopyWith<$Res>? get retry {
    if (_self.retry == null) {
    return null;
  }

  return $RetryConfigCopyWith<$Res>(_self.retry!, (value) {
    return _then(_self.copyWith(retry: value));
  });
}/// Create a copy of Node
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NodePositionCopyWith<$Res>? get pos {
    if (_self.pos == null) {
    return null;
  }

  return $NodePositionCopyWith<$Res>(_self.pos!, (value) {
    return _then(_self.copyWith(pos: value));
  });
}
}


/// @nodoc
mixin _$Graph {

 List<Node> get nodes; List<Edge> get edges;
/// Create a copy of Graph
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GraphCopyWith<Graph> get copyWith => _$GraphCopyWithImpl<Graph>(this as Graph, _$identity);

  /// Serializes this Graph to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Graph&&const DeepCollectionEquality().equals(other.nodes, nodes)&&const DeepCollectionEquality().equals(other.edges, edges));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(nodes),const DeepCollectionEquality().hash(edges));

@override
String toString() {
  return 'Graph(nodes: $nodes, edges: $edges)';
}


}

/// @nodoc
abstract mixin class $GraphCopyWith<$Res>  {
  factory $GraphCopyWith(Graph value, $Res Function(Graph) _then) = _$GraphCopyWithImpl;
@useResult
$Res call({
 List<Node> nodes, List<Edge> edges
});




}
/// @nodoc
class _$GraphCopyWithImpl<$Res>
    implements $GraphCopyWith<$Res> {
  _$GraphCopyWithImpl(this._self, this._then);

  final Graph _self;
  final $Res Function(Graph) _then;

/// Create a copy of Graph
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nodes = null,Object? edges = null,}) {
  return _then(_self.copyWith(
nodes: null == nodes ? _self.nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<Node>,edges: null == edges ? _self.edges : edges // ignore: cast_nullable_to_non_nullable
as List<Edge>,
  ));
}

}


/// Adds pattern-matching-related methods to [Graph].
extension GraphPatterns on Graph {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Graph value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Graph() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Graph value)  $default,){
final _that = this;
switch (_that) {
case _Graph():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Graph value)?  $default,){
final _that = this;
switch (_that) {
case _Graph() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Node> nodes,  List<Edge> edges)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Graph() when $default != null:
return $default(_that.nodes,_that.edges);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Node> nodes,  List<Edge> edges)  $default,) {final _that = this;
switch (_that) {
case _Graph():
return $default(_that.nodes,_that.edges);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Node> nodes,  List<Edge> edges)?  $default,) {final _that = this;
switch (_that) {
case _Graph() when $default != null:
return $default(_that.nodes,_that.edges);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Graph implements Graph {
  const _Graph({final  List<Node> nodes = const <Node>[], final  List<Edge> edges = const <Edge>[]}): _nodes = nodes,_edges = edges;
  factory _Graph.fromJson(Map<String, dynamic> json) => _$GraphFromJson(json);

 final  List<Node> _nodes;
@override@JsonKey() List<Node> get nodes {
  if (_nodes is EqualUnmodifiableListView) return _nodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_nodes);
}

 final  List<Edge> _edges;
@override@JsonKey() List<Edge> get edges {
  if (_edges is EqualUnmodifiableListView) return _edges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_edges);
}


/// Create a copy of Graph
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GraphCopyWith<_Graph> get copyWith => __$GraphCopyWithImpl<_Graph>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GraphToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Graph&&const DeepCollectionEquality().equals(other._nodes, _nodes)&&const DeepCollectionEquality().equals(other._edges, _edges));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_nodes),const DeepCollectionEquality().hash(_edges));

@override
String toString() {
  return 'Graph(nodes: $nodes, edges: $edges)';
}


}

/// @nodoc
abstract mixin class _$GraphCopyWith<$Res> implements $GraphCopyWith<$Res> {
  factory _$GraphCopyWith(_Graph value, $Res Function(_Graph) _then) = __$GraphCopyWithImpl;
@override @useResult
$Res call({
 List<Node> nodes, List<Edge> edges
});




}
/// @nodoc
class __$GraphCopyWithImpl<$Res>
    implements _$GraphCopyWith<$Res> {
  __$GraphCopyWithImpl(this._self, this._then);

  final _Graph _self;
  final $Res Function(_Graph) _then;

/// Create a copy of Graph
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nodes = null,Object? edges = null,}) {
  return _then(_Graph(
nodes: null == nodes ? _self._nodes : nodes // ignore: cast_nullable_to_non_nullable
as List<Node>,edges: null == edges ? _self._edges : edges // ignore: cast_nullable_to_non_nullable
as List<Edge>,
  ));
}


}

// dart format on
