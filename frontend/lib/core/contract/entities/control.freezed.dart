// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'control.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ControlLogic {

 String get id; String get name; String get description; String get activeVersionId; DateTime get createdAt; DateTime get updatedAt; ControlVersion? get activeVersion;
/// Create a copy of ControlLogic
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlLogicCopyWith<ControlLogic> get copyWith => _$ControlLogicCopyWithImpl<ControlLogic>(this as ControlLogic, _$identity);

  /// Serializes this ControlLogic to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlLogic&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.activeVersionId, activeVersionId) || other.activeVersionId == activeVersionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.activeVersion, activeVersion) || other.activeVersion == activeVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,activeVersionId,createdAt,updatedAt,activeVersion);

@override
String toString() {
  return 'ControlLogic(id: $id, name: $name, description: $description, activeVersionId: $activeVersionId, createdAt: $createdAt, updatedAt: $updatedAt, activeVersion: $activeVersion)';
}


}

/// @nodoc
abstract mixin class $ControlLogicCopyWith<$Res>  {
  factory $ControlLogicCopyWith(ControlLogic value, $Res Function(ControlLogic) _then) = _$ControlLogicCopyWithImpl;
@useResult
$Res call({
 String id, String name, String description, String activeVersionId, DateTime createdAt, DateTime updatedAt, ControlVersion? activeVersion
});


$ControlVersionCopyWith<$Res>? get activeVersion;

}
/// @nodoc
class _$ControlLogicCopyWithImpl<$Res>
    implements $ControlLogicCopyWith<$Res> {
  _$ControlLogicCopyWithImpl(this._self, this._then);

  final ControlLogic _self;
  final $Res Function(ControlLogic) _then;

/// Create a copy of ControlLogic
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = null,Object? activeVersionId = null,Object? createdAt = null,Object? updatedAt = null,Object? activeVersion = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,activeVersionId: null == activeVersionId ? _self.activeVersionId : activeVersionId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,activeVersion: freezed == activeVersion ? _self.activeVersion : activeVersion // ignore: cast_nullable_to_non_nullable
as ControlVersion?,
  ));
}
/// Create a copy of ControlLogic
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ControlVersionCopyWith<$Res>? get activeVersion {
    if (_self.activeVersion == null) {
    return null;
  }

  return $ControlVersionCopyWith<$Res>(_self.activeVersion!, (value) {
    return _then(_self.copyWith(activeVersion: value));
  });
}
}


/// Adds pattern-matching-related methods to [ControlLogic].
extension ControlLogicPatterns on ControlLogic {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ControlLogic value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ControlLogic() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ControlLogic value)  $default,){
final _that = this;
switch (_that) {
case _ControlLogic():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ControlLogic value)?  $default,){
final _that = this;
switch (_that) {
case _ControlLogic() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String description,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  ControlVersion? activeVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ControlLogic() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String description,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  ControlVersion? activeVersion)  $default,) {final _that = this;
switch (_that) {
case _ControlLogic():
return $default(_that.id,_that.name,_that.description,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String description,  String activeVersionId,  DateTime createdAt,  DateTime updatedAt,  ControlVersion? activeVersion)?  $default,) {final _that = this;
switch (_that) {
case _ControlLogic() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.activeVersionId,_that.createdAt,_that.updatedAt,_that.activeVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ControlLogic implements ControlLogic {
  const _ControlLogic({required this.id, this.name = '', this.description = '', this.activeVersionId = '', required this.createdAt, required this.updatedAt, this.activeVersion});
  factory _ControlLogic.fromJson(Map<String, dynamic> json) => _$ControlLogicFromJson(json);

@override final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String description;
@override@JsonKey() final  String activeVersionId;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  ControlVersion? activeVersion;

/// Create a copy of ControlLogic
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ControlLogicCopyWith<_ControlLogic> get copyWith => __$ControlLogicCopyWithImpl<_ControlLogic>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlLogicToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ControlLogic&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.activeVersionId, activeVersionId) || other.activeVersionId == activeVersionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.activeVersion, activeVersion) || other.activeVersion == activeVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,activeVersionId,createdAt,updatedAt,activeVersion);

@override
String toString() {
  return 'ControlLogic(id: $id, name: $name, description: $description, activeVersionId: $activeVersionId, createdAt: $createdAt, updatedAt: $updatedAt, activeVersion: $activeVersion)';
}


}

/// @nodoc
abstract mixin class _$ControlLogicCopyWith<$Res> implements $ControlLogicCopyWith<$Res> {
  factory _$ControlLogicCopyWith(_ControlLogic value, $Res Function(_ControlLogic) _then) = __$ControlLogicCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String description, String activeVersionId, DateTime createdAt, DateTime updatedAt, ControlVersion? activeVersion
});


@override $ControlVersionCopyWith<$Res>? get activeVersion;

}
/// @nodoc
class __$ControlLogicCopyWithImpl<$Res>
    implements _$ControlLogicCopyWith<$Res> {
  __$ControlLogicCopyWithImpl(this._self, this._then);

  final _ControlLogic _self;
  final $Res Function(_ControlLogic) _then;

/// Create a copy of ControlLogic
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? activeVersionId = null,Object? createdAt = null,Object? updatedAt = null,Object? activeVersion = freezed,}) {
  return _then(_ControlLogic(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,activeVersionId: null == activeVersionId ? _self.activeVersionId : activeVersionId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,activeVersion: freezed == activeVersion ? _self.activeVersion : activeVersion // ignore: cast_nullable_to_non_nullable
as ControlVersion?,
  ));
}

/// Create a copy of ControlLogic
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ControlVersionCopyWith<$Res>? get activeVersion {
    if (_self.activeVersion == null) {
    return null;
  }

  return $ControlVersionCopyWith<$Res>(_self.activeVersion!, (value) {
    return _then(_self.copyWith(activeVersion: value));
  });
}
}


/// @nodoc
mixin _$ControlVersion {

 String get id; String get controlId; int get version; List<Field> get inputs; List<Branch> get branches; String? get changeReason; String? get builtInConversationId; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of ControlVersion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControlVersionCopyWith<ControlVersion> get copyWith => _$ControlVersionCopyWithImpl<ControlVersion>(this as ControlVersion, _$identity);

  /// Serializes this ControlVersion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ControlVersion&&(identical(other.id, id) || other.id == id)&&(identical(other.controlId, controlId) || other.controlId == controlId)&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other.inputs, inputs)&&const DeepCollectionEquality().equals(other.branches, branches)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&(identical(other.builtInConversationId, builtInConversationId) || other.builtInConversationId == builtInConversationId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,controlId,version,const DeepCollectionEquality().hash(inputs),const DeepCollectionEquality().hash(branches),changeReason,builtInConversationId,createdAt,updatedAt);

@override
String toString() {
  return 'ControlVersion(id: $id, controlId: $controlId, version: $version, inputs: $inputs, branches: $branches, changeReason: $changeReason, builtInConversationId: $builtInConversationId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ControlVersionCopyWith<$Res>  {
  factory $ControlVersionCopyWith(ControlVersion value, $Res Function(ControlVersion) _then) = _$ControlVersionCopyWithImpl;
@useResult
$Res call({
 String id, String controlId, int version, List<Field> inputs, List<Branch> branches, String? changeReason, String? builtInConversationId, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$ControlVersionCopyWithImpl<$Res>
    implements $ControlVersionCopyWith<$Res> {
  _$ControlVersionCopyWithImpl(this._self, this._then);

  final ControlVersion _self;
  final $Res Function(ControlVersion) _then;

/// Create a copy of ControlVersion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? controlId = null,Object? version = null,Object? inputs = null,Object? branches = null,Object? changeReason = freezed,Object? builtInConversationId = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,controlId: null == controlId ? _self.controlId : controlId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,inputs: null == inputs ? _self.inputs : inputs // ignore: cast_nullable_to_non_nullable
as List<Field>,branches: null == branches ? _self.branches : branches // ignore: cast_nullable_to_non_nullable
as List<Branch>,changeReason: freezed == changeReason ? _self.changeReason : changeReason // ignore: cast_nullable_to_non_nullable
as String?,builtInConversationId: freezed == builtInConversationId ? _self.builtInConversationId : builtInConversationId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ControlVersion].
extension ControlVersionPatterns on ControlVersion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ControlVersion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ControlVersion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ControlVersion value)  $default,){
final _that = this;
switch (_that) {
case _ControlVersion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ControlVersion value)?  $default,){
final _that = this;
switch (_that) {
case _ControlVersion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String controlId,  int version,  List<Field> inputs,  List<Branch> branches,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ControlVersion() when $default != null:
return $default(_that.id,_that.controlId,_that.version,_that.inputs,_that.branches,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String controlId,  int version,  List<Field> inputs,  List<Branch> branches,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ControlVersion():
return $default(_that.id,_that.controlId,_that.version,_that.inputs,_that.branches,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String controlId,  int version,  List<Field> inputs,  List<Branch> branches,  String? changeReason,  String? builtInConversationId,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ControlVersion() when $default != null:
return $default(_that.id,_that.controlId,_that.version,_that.inputs,_that.branches,_that.changeReason,_that.builtInConversationId,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ControlVersion implements ControlVersion {
  const _ControlVersion({required this.id, required this.controlId, required this.version, final  List<Field> inputs = const <Field>[], final  List<Branch> branches = const <Branch>[], this.changeReason, this.builtInConversationId, required this.createdAt, required this.updatedAt}): _inputs = inputs,_branches = branches;
  factory _ControlVersion.fromJson(Map<String, dynamic> json) => _$ControlVersionFromJson(json);

@override final  String id;
@override final  String controlId;
@override final  int version;
 final  List<Field> _inputs;
@override@JsonKey() List<Field> get inputs {
  if (_inputs is EqualUnmodifiableListView) return _inputs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_inputs);
}

 final  List<Branch> _branches;
@override@JsonKey() List<Branch> get branches {
  if (_branches is EqualUnmodifiableListView) return _branches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_branches);
}

@override final  String? changeReason;
@override final  String? builtInConversationId;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of ControlVersion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ControlVersionCopyWith<_ControlVersion> get copyWith => __$ControlVersionCopyWithImpl<_ControlVersion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ControlVersionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ControlVersion&&(identical(other.id, id) || other.id == id)&&(identical(other.controlId, controlId) || other.controlId == controlId)&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other._inputs, _inputs)&&const DeepCollectionEquality().equals(other._branches, _branches)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&(identical(other.builtInConversationId, builtInConversationId) || other.builtInConversationId == builtInConversationId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,controlId,version,const DeepCollectionEquality().hash(_inputs),const DeepCollectionEquality().hash(_branches),changeReason,builtInConversationId,createdAt,updatedAt);

@override
String toString() {
  return 'ControlVersion(id: $id, controlId: $controlId, version: $version, inputs: $inputs, branches: $branches, changeReason: $changeReason, builtInConversationId: $builtInConversationId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ControlVersionCopyWith<$Res> implements $ControlVersionCopyWith<$Res> {
  factory _$ControlVersionCopyWith(_ControlVersion value, $Res Function(_ControlVersion) _then) = __$ControlVersionCopyWithImpl;
@override @useResult
$Res call({
 String id, String controlId, int version, List<Field> inputs, List<Branch> branches, String? changeReason, String? builtInConversationId, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$ControlVersionCopyWithImpl<$Res>
    implements _$ControlVersionCopyWith<$Res> {
  __$ControlVersionCopyWithImpl(this._self, this._then);

  final _ControlVersion _self;
  final $Res Function(_ControlVersion) _then;

/// Create a copy of ControlVersion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? controlId = null,Object? version = null,Object? inputs = null,Object? branches = null,Object? changeReason = freezed,Object? builtInConversationId = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_ControlVersion(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,controlId: null == controlId ? _self.controlId : controlId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,inputs: null == inputs ? _self._inputs : inputs // ignore: cast_nullable_to_non_nullable
as List<Field>,branches: null == branches ? _self._branches : branches // ignore: cast_nullable_to_non_nullable
as List<Branch>,changeReason: freezed == changeReason ? _self.changeReason : changeReason // ignore: cast_nullable_to_non_nullable
as String?,builtInConversationId: freezed == builtInConversationId ? _self.builtInConversationId : builtInConversationId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$Branch {

 String get port; String get when; Map<String, String> get emit;
/// Create a copy of Branch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BranchCopyWith<Branch> get copyWith => _$BranchCopyWithImpl<Branch>(this as Branch, _$identity);

  /// Serializes this Branch to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Branch&&(identical(other.port, port) || other.port == port)&&(identical(other.when, when) || other.when == when)&&const DeepCollectionEquality().equals(other.emit, emit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,port,when,const DeepCollectionEquality().hash(emit));

@override
String toString() {
  return 'Branch(port: $port, when: $when, emit: $emit)';
}


}

/// @nodoc
abstract mixin class $BranchCopyWith<$Res>  {
  factory $BranchCopyWith(Branch value, $Res Function(Branch) _then) = _$BranchCopyWithImpl;
@useResult
$Res call({
 String port, String when, Map<String, String> emit
});




}
/// @nodoc
class _$BranchCopyWithImpl<$Res>
    implements $BranchCopyWith<$Res> {
  _$BranchCopyWithImpl(this._self, this._then);

  final Branch _self;
  final $Res Function(Branch) _then;

/// Create a copy of Branch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? port = null,Object? when = null,Object? emit = null,}) {
  return _then(_self.copyWith(
port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as String,when: null == when ? _self.when : when // ignore: cast_nullable_to_non_nullable
as String,emit: null == emit ? _self.emit : emit // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Branch].
extension BranchPatterns on Branch {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Branch value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Branch() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Branch value)  $default,){
final _that = this;
switch (_that) {
case _Branch():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Branch value)?  $default,){
final _that = this;
switch (_that) {
case _Branch() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String port,  String when,  Map<String, String> emit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Branch() when $default != null:
return $default(_that.port,_that.when,_that.emit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String port,  String when,  Map<String, String> emit)  $default,) {final _that = this;
switch (_that) {
case _Branch():
return $default(_that.port,_that.when,_that.emit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String port,  String when,  Map<String, String> emit)?  $default,) {final _that = this;
switch (_that) {
case _Branch() when $default != null:
return $default(_that.port,_that.when,_that.emit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Branch implements Branch {
  const _Branch({this.port = '', this.when = '', final  Map<String, String> emit = const <String, String>{}}): _emit = emit;
  factory _Branch.fromJson(Map<String, dynamic> json) => _$BranchFromJson(json);

@override@JsonKey() final  String port;
@override@JsonKey() final  String when;
 final  Map<String, String> _emit;
@override@JsonKey() Map<String, String> get emit {
  if (_emit is EqualUnmodifiableMapView) return _emit;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_emit);
}


/// Create a copy of Branch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BranchCopyWith<_Branch> get copyWith => __$BranchCopyWithImpl<_Branch>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BranchToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Branch&&(identical(other.port, port) || other.port == port)&&(identical(other.when, when) || other.when == when)&&const DeepCollectionEquality().equals(other._emit, _emit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,port,when,const DeepCollectionEquality().hash(_emit));

@override
String toString() {
  return 'Branch(port: $port, when: $when, emit: $emit)';
}


}

/// @nodoc
abstract mixin class _$BranchCopyWith<$Res> implements $BranchCopyWith<$Res> {
  factory _$BranchCopyWith(_Branch value, $Res Function(_Branch) _then) = __$BranchCopyWithImpl;
@override @useResult
$Res call({
 String port, String when, Map<String, String> emit
});




}
/// @nodoc
class __$BranchCopyWithImpl<$Res>
    implements _$BranchCopyWith<$Res> {
  __$BranchCopyWithImpl(this._self, this._then);

  final _Branch _self;
  final $Res Function(_Branch) _then;

/// Create a copy of Branch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? port = null,Object? when = null,Object? emit = null,}) {
  return _then(_Branch(
port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as String,when: null == when ? _self.when : when // ignore: cast_nullable_to_non_nullable
as String,emit: null == emit ? _self._emit : emit // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

// dart format on
