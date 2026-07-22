// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'skill.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Skill {

 String get name; String get description;// mirror of frontmatter.description
 String get source;// user | ai | installed（installed 由 sidecar 推导）
 String get context;// inline | fork
 String get body;// only from GET /skills/{name}
 Frontmatter get frontmatter; Provenance? get provenance;// only installed + single-Get（List 省略）
 String get dir;// 目录绝对路径,仅 single-Get——系统打开/Finder 显示用
 DateTime get updatedAt;
/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SkillCopyWith<Skill> get copyWith => _$SkillCopyWithImpl<Skill>(this as Skill, _$identity);

  /// Serializes this Skill to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Skill&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.source, source) || other.source == source)&&(identical(other.context, context) || other.context == context)&&(identical(other.body, body) || other.body == body)&&(identical(other.frontmatter, frontmatter) || other.frontmatter == frontmatter)&&(identical(other.provenance, provenance) || other.provenance == provenance)&&(identical(other.dir, dir) || other.dir == dir)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,source,context,body,frontmatter,provenance,dir,updatedAt);

@override
String toString() {
  return 'Skill(name: $name, description: $description, source: $source, context: $context, body: $body, frontmatter: $frontmatter, provenance: $provenance, dir: $dir, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SkillCopyWith<$Res>  {
  factory $SkillCopyWith(Skill value, $Res Function(Skill) _then) = _$SkillCopyWithImpl;
@useResult
$Res call({
 String name, String description, String source, String context, String body, Frontmatter frontmatter, Provenance? provenance, String dir, DateTime updatedAt
});


$FrontmatterCopyWith<$Res> get frontmatter;$ProvenanceCopyWith<$Res>? get provenance;

}
/// @nodoc
class _$SkillCopyWithImpl<$Res>
    implements $SkillCopyWith<$Res> {
  _$SkillCopyWithImpl(this._self, this._then);

  final Skill _self;
  final $Res Function(Skill) _then;

/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? source = null,Object? context = null,Object? body = null,Object? frontmatter = null,Object? provenance = freezed,Object? dir = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,context: null == context ? _self.context : context // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,frontmatter: null == frontmatter ? _self.frontmatter : frontmatter // ignore: cast_nullable_to_non_nullable
as Frontmatter,provenance: freezed == provenance ? _self.provenance : provenance // ignore: cast_nullable_to_non_nullable
as Provenance?,dir: null == dir ? _self.dir : dir // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FrontmatterCopyWith<$Res> get frontmatter {
  
  return $FrontmatterCopyWith<$Res>(_self.frontmatter, (value) {
    return _then(_self.copyWith(frontmatter: value));
  });
}/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProvenanceCopyWith<$Res>? get provenance {
    if (_self.provenance == null) {
    return null;
  }

  return $ProvenanceCopyWith<$Res>(_self.provenance!, (value) {
    return _then(_self.copyWith(provenance: value));
  });
}
}


/// Adds pattern-matching-related methods to [Skill].
extension SkillPatterns on Skill {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Skill value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Skill() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Skill value)  $default,){
final _that = this;
switch (_that) {
case _Skill():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Skill value)?  $default,){
final _that = this;
switch (_that) {
case _Skill() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String description,  String source,  String context,  String body,  Frontmatter frontmatter,  Provenance? provenance,  String dir,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Skill() when $default != null:
return $default(_that.name,_that.description,_that.source,_that.context,_that.body,_that.frontmatter,_that.provenance,_that.dir,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String description,  String source,  String context,  String body,  Frontmatter frontmatter,  Provenance? provenance,  String dir,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Skill():
return $default(_that.name,_that.description,_that.source,_that.context,_that.body,_that.frontmatter,_that.provenance,_that.dir,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String description,  String source,  String context,  String body,  Frontmatter frontmatter,  Provenance? provenance,  String dir,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Skill() when $default != null:
return $default(_that.name,_that.description,_that.source,_that.context,_that.body,_that.frontmatter,_that.provenance,_that.dir,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Skill implements Skill {
  const _Skill({required this.name, this.description = '', this.source = '', this.context = '', this.body = '', this.frontmatter = const Frontmatter(), this.provenance, this.dir = '', required this.updatedAt});
  factory _Skill.fromJson(Map<String, dynamic> json) => _$SkillFromJson(json);

@override final  String name;
@override@JsonKey() final  String description;
// mirror of frontmatter.description
@override@JsonKey() final  String source;
// user | ai | installed（installed 由 sidecar 推导）
@override@JsonKey() final  String context;
// inline | fork
@override@JsonKey() final  String body;
// only from GET /skills/{name}
@override@JsonKey() final  Frontmatter frontmatter;
@override final  Provenance? provenance;
// only installed + single-Get（List 省略）
@override@JsonKey() final  String dir;
// 目录绝对路径,仅 single-Get——系统打开/Finder 显示用
@override final  DateTime updatedAt;

/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SkillCopyWith<_Skill> get copyWith => __$SkillCopyWithImpl<_Skill>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SkillToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Skill&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.source, source) || other.source == source)&&(identical(other.context, context) || other.context == context)&&(identical(other.body, body) || other.body == body)&&(identical(other.frontmatter, frontmatter) || other.frontmatter == frontmatter)&&(identical(other.provenance, provenance) || other.provenance == provenance)&&(identical(other.dir, dir) || other.dir == dir)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,source,context,body,frontmatter,provenance,dir,updatedAt);

@override
String toString() {
  return 'Skill(name: $name, description: $description, source: $source, context: $context, body: $body, frontmatter: $frontmatter, provenance: $provenance, dir: $dir, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SkillCopyWith<$Res> implements $SkillCopyWith<$Res> {
  factory _$SkillCopyWith(_Skill value, $Res Function(_Skill) _then) = __$SkillCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, String source, String context, String body, Frontmatter frontmatter, Provenance? provenance, String dir, DateTime updatedAt
});


@override $FrontmatterCopyWith<$Res> get frontmatter;@override $ProvenanceCopyWith<$Res>? get provenance;

}
/// @nodoc
class __$SkillCopyWithImpl<$Res>
    implements _$SkillCopyWith<$Res> {
  __$SkillCopyWithImpl(this._self, this._then);

  final _Skill _self;
  final $Res Function(_Skill) _then;

/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? source = null,Object? context = null,Object? body = null,Object? frontmatter = null,Object? provenance = freezed,Object? dir = null,Object? updatedAt = null,}) {
  return _then(_Skill(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,context: null == context ? _self.context : context // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,frontmatter: null == frontmatter ? _self.frontmatter : frontmatter // ignore: cast_nullable_to_non_nullable
as Frontmatter,provenance: freezed == provenance ? _self.provenance : provenance // ignore: cast_nullable_to_non_nullable
as Provenance?,dir: null == dir ? _self.dir : dir // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FrontmatterCopyWith<$Res> get frontmatter {
  
  return $FrontmatterCopyWith<$Res>(_self.frontmatter, (value) {
    return _then(_self.copyWith(frontmatter: value));
  });
}/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProvenanceCopyWith<$Res>? get provenance {
    if (_self.provenance == null) {
    return null;
  }

  return $ProvenanceCopyWith<$Res>(_self.provenance!, (value) {
    return _then(_self.copyWith(provenance: value));
  });
}
}


/// @nodoc
mixin _$Provenance {

 String get source;// owner/repo[@ref][#subdir] 或 URL
 String get repo; String get ref; String get subdir; DateTime? get installedAt; bool get toolsApproved;
/// Create a copy of Provenance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProvenanceCopyWith<Provenance> get copyWith => _$ProvenanceCopyWithImpl<Provenance>(this as Provenance, _$identity);

  /// Serializes this Provenance to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Provenance&&(identical(other.source, source) || other.source == source)&&(identical(other.repo, repo) || other.repo == repo)&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.subdir, subdir) || other.subdir == subdir)&&(identical(other.installedAt, installedAt) || other.installedAt == installedAt)&&(identical(other.toolsApproved, toolsApproved) || other.toolsApproved == toolsApproved));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,source,repo,ref,subdir,installedAt,toolsApproved);

@override
String toString() {
  return 'Provenance(source: $source, repo: $repo, ref: $ref, subdir: $subdir, installedAt: $installedAt, toolsApproved: $toolsApproved)';
}


}

/// @nodoc
abstract mixin class $ProvenanceCopyWith<$Res>  {
  factory $ProvenanceCopyWith(Provenance value, $Res Function(Provenance) _then) = _$ProvenanceCopyWithImpl;
@useResult
$Res call({
 String source, String repo, String ref, String subdir, DateTime? installedAt, bool toolsApproved
});




}
/// @nodoc
class _$ProvenanceCopyWithImpl<$Res>
    implements $ProvenanceCopyWith<$Res> {
  _$ProvenanceCopyWithImpl(this._self, this._then);

  final Provenance _self;
  final $Res Function(Provenance) _then;

/// Create a copy of Provenance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? source = null,Object? repo = null,Object? ref = null,Object? subdir = null,Object? installedAt = freezed,Object? toolsApproved = null,}) {
  return _then(_self.copyWith(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,repo: null == repo ? _self.repo : repo // ignore: cast_nullable_to_non_nullable
as String,ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String,subdir: null == subdir ? _self.subdir : subdir // ignore: cast_nullable_to_non_nullable
as String,installedAt: freezed == installedAt ? _self.installedAt : installedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,toolsApproved: null == toolsApproved ? _self.toolsApproved : toolsApproved // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Provenance].
extension ProvenancePatterns on Provenance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Provenance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Provenance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Provenance value)  $default,){
final _that = this;
switch (_that) {
case _Provenance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Provenance value)?  $default,){
final _that = this;
switch (_that) {
case _Provenance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String source,  String repo,  String ref,  String subdir,  DateTime? installedAt,  bool toolsApproved)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Provenance() when $default != null:
return $default(_that.source,_that.repo,_that.ref,_that.subdir,_that.installedAt,_that.toolsApproved);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String source,  String repo,  String ref,  String subdir,  DateTime? installedAt,  bool toolsApproved)  $default,) {final _that = this;
switch (_that) {
case _Provenance():
return $default(_that.source,_that.repo,_that.ref,_that.subdir,_that.installedAt,_that.toolsApproved);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String source,  String repo,  String ref,  String subdir,  DateTime? installedAt,  bool toolsApproved)?  $default,) {final _that = this;
switch (_that) {
case _Provenance() when $default != null:
return $default(_that.source,_that.repo,_that.ref,_that.subdir,_that.installedAt,_that.toolsApproved);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Provenance implements Provenance {
  const _Provenance({this.source = '', this.repo = '', this.ref = '', this.subdir = '', this.installedAt, this.toolsApproved = false});
  factory _Provenance.fromJson(Map<String, dynamic> json) => _$ProvenanceFromJson(json);

@override@JsonKey() final  String source;
// owner/repo[@ref][#subdir] 或 URL
@override@JsonKey() final  String repo;
@override@JsonKey() final  String ref;
@override@JsonKey() final  String subdir;
@override final  DateTime? installedAt;
@override@JsonKey() final  bool toolsApproved;

/// Create a copy of Provenance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProvenanceCopyWith<_Provenance> get copyWith => __$ProvenanceCopyWithImpl<_Provenance>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProvenanceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Provenance&&(identical(other.source, source) || other.source == source)&&(identical(other.repo, repo) || other.repo == repo)&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.subdir, subdir) || other.subdir == subdir)&&(identical(other.installedAt, installedAt) || other.installedAt == installedAt)&&(identical(other.toolsApproved, toolsApproved) || other.toolsApproved == toolsApproved));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,source,repo,ref,subdir,installedAt,toolsApproved);

@override
String toString() {
  return 'Provenance(source: $source, repo: $repo, ref: $ref, subdir: $subdir, installedAt: $installedAt, toolsApproved: $toolsApproved)';
}


}

/// @nodoc
abstract mixin class _$ProvenanceCopyWith<$Res> implements $ProvenanceCopyWith<$Res> {
  factory _$ProvenanceCopyWith(_Provenance value, $Res Function(_Provenance) _then) = __$ProvenanceCopyWithImpl;
@override @useResult
$Res call({
 String source, String repo, String ref, String subdir, DateTime? installedAt, bool toolsApproved
});




}
/// @nodoc
class __$ProvenanceCopyWithImpl<$Res>
    implements _$ProvenanceCopyWith<$Res> {
  __$ProvenanceCopyWithImpl(this._self, this._then);

  final _Provenance _self;
  final $Res Function(_Provenance) _then;

/// Create a copy of Provenance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? source = null,Object? repo = null,Object? ref = null,Object? subdir = null,Object? installedAt = freezed,Object? toolsApproved = null,}) {
  return _then(_Provenance(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,repo: null == repo ? _self.repo : repo // ignore: cast_nullable_to_non_nullable
as String,ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as String,subdir: null == subdir ? _self.subdir : subdir // ignore: cast_nullable_to_non_nullable
as String,installedAt: freezed == installedAt ? _self.installedAt : installedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,toolsApproved: null == toolsApproved ? _self.toolsApproved : toolsApproved // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SkillFile {

 String get path; int get size; DateTime? get updatedAt;
/// Create a copy of SkillFile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SkillFileCopyWith<SkillFile> get copyWith => _$SkillFileCopyWithImpl<SkillFile>(this as SkillFile, _$identity);

  /// Serializes this SkillFile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SkillFile&&(identical(other.path, path) || other.path == path)&&(identical(other.size, size) || other.size == size)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,size,updatedAt);

@override
String toString() {
  return 'SkillFile(path: $path, size: $size, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SkillFileCopyWith<$Res>  {
  factory $SkillFileCopyWith(SkillFile value, $Res Function(SkillFile) _then) = _$SkillFileCopyWithImpl;
@useResult
$Res call({
 String path, int size, DateTime? updatedAt
});




}
/// @nodoc
class _$SkillFileCopyWithImpl<$Res>
    implements $SkillFileCopyWith<$Res> {
  _$SkillFileCopyWithImpl(this._self, this._then);

  final SkillFile _self;
  final $Res Function(SkillFile) _then;

/// Create a copy of SkillFile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? size = null,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SkillFile].
extension SkillFilePatterns on SkillFile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SkillFile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SkillFile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SkillFile value)  $default,){
final _that = this;
switch (_that) {
case _SkillFile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SkillFile value)?  $default,){
final _that = this;
switch (_that) {
case _SkillFile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  int size,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SkillFile() when $default != null:
return $default(_that.path,_that.size,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  int size,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _SkillFile():
return $default(_that.path,_that.size,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  int size,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _SkillFile() when $default != null:
return $default(_that.path,_that.size,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SkillFile implements SkillFile {
  const _SkillFile({required this.path, this.size = 0, this.updatedAt});
  factory _SkillFile.fromJson(Map<String, dynamic> json) => _$SkillFileFromJson(json);

@override final  String path;
@override@JsonKey() final  int size;
@override final  DateTime? updatedAt;

/// Create a copy of SkillFile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SkillFileCopyWith<_SkillFile> get copyWith => __$SkillFileCopyWithImpl<_SkillFile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SkillFileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SkillFile&&(identical(other.path, path) || other.path == path)&&(identical(other.size, size) || other.size == size)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,size,updatedAt);

@override
String toString() {
  return 'SkillFile(path: $path, size: $size, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SkillFileCopyWith<$Res> implements $SkillFileCopyWith<$Res> {
  factory _$SkillFileCopyWith(_SkillFile value, $Res Function(_SkillFile) _then) = __$SkillFileCopyWithImpl;
@override @useResult
$Res call({
 String path, int size, DateTime? updatedAt
});




}
/// @nodoc
class __$SkillFileCopyWithImpl<$Res>
    implements _$SkillFileCopyWith<$Res> {
  __$SkillFileCopyWithImpl(this._self, this._then);

  final _SkillFile _self;
  final $Res Function(_SkillFile) _then;

/// Create a copy of SkillFile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? size = null,Object? updatedAt = freezed,}) {
  return _then(_SkillFile(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$SkillInstallPreview {

 String get name; String get description; List<String> get allowedTools; int get fileCount; int get totalBytes; bool get installable; String get reason; bool get alreadyExists;
/// Create a copy of SkillInstallPreview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SkillInstallPreviewCopyWith<SkillInstallPreview> get copyWith => _$SkillInstallPreviewCopyWithImpl<SkillInstallPreview>(this as SkillInstallPreview, _$identity);

  /// Serializes this SkillInstallPreview to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SkillInstallPreview&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.allowedTools, allowedTools)&&(identical(other.fileCount, fileCount) || other.fileCount == fileCount)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.installable, installable) || other.installable == installable)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.alreadyExists, alreadyExists) || other.alreadyExists == alreadyExists));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(allowedTools),fileCount,totalBytes,installable,reason,alreadyExists);

@override
String toString() {
  return 'SkillInstallPreview(name: $name, description: $description, allowedTools: $allowedTools, fileCount: $fileCount, totalBytes: $totalBytes, installable: $installable, reason: $reason, alreadyExists: $alreadyExists)';
}


}

/// @nodoc
abstract mixin class $SkillInstallPreviewCopyWith<$Res>  {
  factory $SkillInstallPreviewCopyWith(SkillInstallPreview value, $Res Function(SkillInstallPreview) _then) = _$SkillInstallPreviewCopyWithImpl;
@useResult
$Res call({
 String name, String description, List<String> allowedTools, int fileCount, int totalBytes, bool installable, String reason, bool alreadyExists
});




}
/// @nodoc
class _$SkillInstallPreviewCopyWithImpl<$Res>
    implements $SkillInstallPreviewCopyWith<$Res> {
  _$SkillInstallPreviewCopyWithImpl(this._self, this._then);

  final SkillInstallPreview _self;
  final $Res Function(SkillInstallPreview) _then;

/// Create a copy of SkillInstallPreview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? allowedTools = null,Object? fileCount = null,Object? totalBytes = null,Object? installable = null,Object? reason = null,Object? alreadyExists = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,allowedTools: null == allowedTools ? _self.allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>,fileCount: null == fileCount ? _self.fileCount : fileCount // ignore: cast_nullable_to_non_nullable
as int,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int,installable: null == installable ? _self.installable : installable // ignore: cast_nullable_to_non_nullable
as bool,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,alreadyExists: null == alreadyExists ? _self.alreadyExists : alreadyExists // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SkillInstallPreview].
extension SkillInstallPreviewPatterns on SkillInstallPreview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SkillInstallPreview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SkillInstallPreview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SkillInstallPreview value)  $default,){
final _that = this;
switch (_that) {
case _SkillInstallPreview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SkillInstallPreview value)?  $default,){
final _that = this;
switch (_that) {
case _SkillInstallPreview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String description,  List<String> allowedTools,  int fileCount,  int totalBytes,  bool installable,  String reason,  bool alreadyExists)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SkillInstallPreview() when $default != null:
return $default(_that.name,_that.description,_that.allowedTools,_that.fileCount,_that.totalBytes,_that.installable,_that.reason,_that.alreadyExists);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String description,  List<String> allowedTools,  int fileCount,  int totalBytes,  bool installable,  String reason,  bool alreadyExists)  $default,) {final _that = this;
switch (_that) {
case _SkillInstallPreview():
return $default(_that.name,_that.description,_that.allowedTools,_that.fileCount,_that.totalBytes,_that.installable,_that.reason,_that.alreadyExists);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String description,  List<String> allowedTools,  int fileCount,  int totalBytes,  bool installable,  String reason,  bool alreadyExists)?  $default,) {final _that = this;
switch (_that) {
case _SkillInstallPreview() when $default != null:
return $default(_that.name,_that.description,_that.allowedTools,_that.fileCount,_that.totalBytes,_that.installable,_that.reason,_that.alreadyExists);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SkillInstallPreview implements SkillInstallPreview {
  const _SkillInstallPreview({required this.name, this.description = '', final  List<String> allowedTools = const <String>[], this.fileCount = 0, this.totalBytes = 0, this.installable = false, this.reason = '', this.alreadyExists = false}): _allowedTools = allowedTools;
  factory _SkillInstallPreview.fromJson(Map<String, dynamic> json) => _$SkillInstallPreviewFromJson(json);

@override final  String name;
@override@JsonKey() final  String description;
 final  List<String> _allowedTools;
@override@JsonKey() List<String> get allowedTools {
  if (_allowedTools is EqualUnmodifiableListView) return _allowedTools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allowedTools);
}

@override@JsonKey() final  int fileCount;
@override@JsonKey() final  int totalBytes;
@override@JsonKey() final  bool installable;
@override@JsonKey() final  String reason;
@override@JsonKey() final  bool alreadyExists;

/// Create a copy of SkillInstallPreview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SkillInstallPreviewCopyWith<_SkillInstallPreview> get copyWith => __$SkillInstallPreviewCopyWithImpl<_SkillInstallPreview>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SkillInstallPreviewToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SkillInstallPreview&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._allowedTools, _allowedTools)&&(identical(other.fileCount, fileCount) || other.fileCount == fileCount)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.installable, installable) || other.installable == installable)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.alreadyExists, alreadyExists) || other.alreadyExists == alreadyExists));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(_allowedTools),fileCount,totalBytes,installable,reason,alreadyExists);

@override
String toString() {
  return 'SkillInstallPreview(name: $name, description: $description, allowedTools: $allowedTools, fileCount: $fileCount, totalBytes: $totalBytes, installable: $installable, reason: $reason, alreadyExists: $alreadyExists)';
}


}

/// @nodoc
abstract mixin class _$SkillInstallPreviewCopyWith<$Res> implements $SkillInstallPreviewCopyWith<$Res> {
  factory _$SkillInstallPreviewCopyWith(_SkillInstallPreview value, $Res Function(_SkillInstallPreview) _then) = __$SkillInstallPreviewCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, List<String> allowedTools, int fileCount, int totalBytes, bool installable, String reason, bool alreadyExists
});




}
/// @nodoc
class __$SkillInstallPreviewCopyWithImpl<$Res>
    implements _$SkillInstallPreviewCopyWith<$Res> {
  __$SkillInstallPreviewCopyWithImpl(this._self, this._then);

  final _SkillInstallPreview _self;
  final $Res Function(_SkillInstallPreview) _then;

/// Create a copy of SkillInstallPreview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? allowedTools = null,Object? fileCount = null,Object? totalBytes = null,Object? installable = null,Object? reason = null,Object? alreadyExists = null,}) {
  return _then(_SkillInstallPreview(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,allowedTools: null == allowedTools ? _self._allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>,fileCount: null == fileCount ? _self.fileCount : fileCount // ignore: cast_nullable_to_non_nullable
as int,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int,installable: null == installable ? _self.installable : installable // ignore: cast_nullable_to_non_nullable
as bool,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,alreadyExists: null == alreadyExists ? _self.alreadyExists : alreadyExists // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SkillInstallResult {

 List<String> get installed; Map<String, String> get skipped;
/// Create a copy of SkillInstallResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SkillInstallResultCopyWith<SkillInstallResult> get copyWith => _$SkillInstallResultCopyWithImpl<SkillInstallResult>(this as SkillInstallResult, _$identity);

  /// Serializes this SkillInstallResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SkillInstallResult&&const DeepCollectionEquality().equals(other.installed, installed)&&const DeepCollectionEquality().equals(other.skipped, skipped));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(installed),const DeepCollectionEquality().hash(skipped));

@override
String toString() {
  return 'SkillInstallResult(installed: $installed, skipped: $skipped)';
}


}

/// @nodoc
abstract mixin class $SkillInstallResultCopyWith<$Res>  {
  factory $SkillInstallResultCopyWith(SkillInstallResult value, $Res Function(SkillInstallResult) _then) = _$SkillInstallResultCopyWithImpl;
@useResult
$Res call({
 List<String> installed, Map<String, String> skipped
});




}
/// @nodoc
class _$SkillInstallResultCopyWithImpl<$Res>
    implements $SkillInstallResultCopyWith<$Res> {
  _$SkillInstallResultCopyWithImpl(this._self, this._then);

  final SkillInstallResult _self;
  final $Res Function(SkillInstallResult) _then;

/// Create a copy of SkillInstallResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? installed = null,Object? skipped = null,}) {
  return _then(_self.copyWith(
installed: null == installed ? _self.installed : installed // ignore: cast_nullable_to_non_nullable
as List<String>,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [SkillInstallResult].
extension SkillInstallResultPatterns on SkillInstallResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SkillInstallResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SkillInstallResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SkillInstallResult value)  $default,){
final _that = this;
switch (_that) {
case _SkillInstallResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SkillInstallResult value)?  $default,){
final _that = this;
switch (_that) {
case _SkillInstallResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> installed,  Map<String, String> skipped)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SkillInstallResult() when $default != null:
return $default(_that.installed,_that.skipped);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> installed,  Map<String, String> skipped)  $default,) {final _that = this;
switch (_that) {
case _SkillInstallResult():
return $default(_that.installed,_that.skipped);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> installed,  Map<String, String> skipped)?  $default,) {final _that = this;
switch (_that) {
case _SkillInstallResult() when $default != null:
return $default(_that.installed,_that.skipped);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SkillInstallResult implements SkillInstallResult {
  const _SkillInstallResult({final  List<String> installed = const <String>[], final  Map<String, String> skipped = const <String, String>{}}): _installed = installed,_skipped = skipped;
  factory _SkillInstallResult.fromJson(Map<String, dynamic> json) => _$SkillInstallResultFromJson(json);

 final  List<String> _installed;
@override@JsonKey() List<String> get installed {
  if (_installed is EqualUnmodifiableListView) return _installed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_installed);
}

 final  Map<String, String> _skipped;
@override@JsonKey() Map<String, String> get skipped {
  if (_skipped is EqualUnmodifiableMapView) return _skipped;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_skipped);
}


/// Create a copy of SkillInstallResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SkillInstallResultCopyWith<_SkillInstallResult> get copyWith => __$SkillInstallResultCopyWithImpl<_SkillInstallResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SkillInstallResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SkillInstallResult&&const DeepCollectionEquality().equals(other._installed, _installed)&&const DeepCollectionEquality().equals(other._skipped, _skipped));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_installed),const DeepCollectionEquality().hash(_skipped));

@override
String toString() {
  return 'SkillInstallResult(installed: $installed, skipped: $skipped)';
}


}

/// @nodoc
abstract mixin class _$SkillInstallResultCopyWith<$Res> implements $SkillInstallResultCopyWith<$Res> {
  factory _$SkillInstallResultCopyWith(_SkillInstallResult value, $Res Function(_SkillInstallResult) _then) = __$SkillInstallResultCopyWithImpl;
@override @useResult
$Res call({
 List<String> installed, Map<String, String> skipped
});




}
/// @nodoc
class __$SkillInstallResultCopyWithImpl<$Res>
    implements _$SkillInstallResultCopyWith<$Res> {
  __$SkillInstallResultCopyWithImpl(this._self, this._then);

  final _SkillInstallResult _self;
  final $Res Function(_SkillInstallResult) _then;

/// Create a copy of SkillInstallResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? installed = null,Object? skipped = null,}) {
  return _then(_SkillInstallResult(
installed: null == installed ? _self._installed : installed // ignore: cast_nullable_to_non_nullable
as List<String>,skipped: null == skipped ? _self._skipped : skipped // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}


/// @nodoc
mixin _$Frontmatter {

 String get name; String get description; String get license;// 规范核心（B1 保真新暴露）
 String get compatibility;// 规范核心:环境需求声明
 Map<String, String> get metadata;// 规范扩展逃生口
 List<String> get allowedTools;// pre-authorized tools (fn_/hd_ id · Read/Bash · mcp:server/tool)
 String get context;// inline | fork
 String get agent;// required when context == fork
 List<String> get arguments; bool get disableModelInvocation; bool get userInvocable; String get whenToUse; String get model; String get effort; String get source;
/// Create a copy of Frontmatter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrontmatterCopyWith<Frontmatter> get copyWith => _$FrontmatterCopyWithImpl<Frontmatter>(this as Frontmatter, _$identity);

  /// Serializes this Frontmatter to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Frontmatter&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.license, license) || other.license == license)&&(identical(other.compatibility, compatibility) || other.compatibility == compatibility)&&const DeepCollectionEquality().equals(other.metadata, metadata)&&const DeepCollectionEquality().equals(other.allowedTools, allowedTools)&&(identical(other.context, context) || other.context == context)&&(identical(other.agent, agent) || other.agent == agent)&&const DeepCollectionEquality().equals(other.arguments, arguments)&&(identical(other.disableModelInvocation, disableModelInvocation) || other.disableModelInvocation == disableModelInvocation)&&(identical(other.userInvocable, userInvocable) || other.userInvocable == userInvocable)&&(identical(other.whenToUse, whenToUse) || other.whenToUse == whenToUse)&&(identical(other.model, model) || other.model == model)&&(identical(other.effort, effort) || other.effort == effort)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,license,compatibility,const DeepCollectionEquality().hash(metadata),const DeepCollectionEquality().hash(allowedTools),context,agent,const DeepCollectionEquality().hash(arguments),disableModelInvocation,userInvocable,whenToUse,model,effort,source);

@override
String toString() {
  return 'Frontmatter(name: $name, description: $description, license: $license, compatibility: $compatibility, metadata: $metadata, allowedTools: $allowedTools, context: $context, agent: $agent, arguments: $arguments, disableModelInvocation: $disableModelInvocation, userInvocable: $userInvocable, whenToUse: $whenToUse, model: $model, effort: $effort, source: $source)';
}


}

/// @nodoc
abstract mixin class $FrontmatterCopyWith<$Res>  {
  factory $FrontmatterCopyWith(Frontmatter value, $Res Function(Frontmatter) _then) = _$FrontmatterCopyWithImpl;
@useResult
$Res call({
 String name, String description, String license, String compatibility, Map<String, String> metadata, List<String> allowedTools, String context, String agent, List<String> arguments, bool disableModelInvocation, bool userInvocable, String whenToUse, String model, String effort, String source
});




}
/// @nodoc
class _$FrontmatterCopyWithImpl<$Res>
    implements $FrontmatterCopyWith<$Res> {
  _$FrontmatterCopyWithImpl(this._self, this._then);

  final Frontmatter _self;
  final $Res Function(Frontmatter) _then;

/// Create a copy of Frontmatter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? license = null,Object? compatibility = null,Object? metadata = null,Object? allowedTools = null,Object? context = null,Object? agent = null,Object? arguments = null,Object? disableModelInvocation = null,Object? userInvocable = null,Object? whenToUse = null,Object? model = null,Object? effort = null,Object? source = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,license: null == license ? _self.license : license // ignore: cast_nullable_to_non_nullable
as String,compatibility: null == compatibility ? _self.compatibility : compatibility // ignore: cast_nullable_to_non_nullable
as String,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, String>,allowedTools: null == allowedTools ? _self.allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>,context: null == context ? _self.context : context // ignore: cast_nullable_to_non_nullable
as String,agent: null == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String,arguments: null == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as List<String>,disableModelInvocation: null == disableModelInvocation ? _self.disableModelInvocation : disableModelInvocation // ignore: cast_nullable_to_non_nullable
as bool,userInvocable: null == userInvocable ? _self.userInvocable : userInvocable // ignore: cast_nullable_to_non_nullable
as bool,whenToUse: null == whenToUse ? _self.whenToUse : whenToUse // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,effort: null == effort ? _self.effort : effort // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Frontmatter].
extension FrontmatterPatterns on Frontmatter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Frontmatter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Frontmatter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Frontmatter value)  $default,){
final _that = this;
switch (_that) {
case _Frontmatter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Frontmatter value)?  $default,){
final _that = this;
switch (_that) {
case _Frontmatter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String description,  String license,  String compatibility,  Map<String, String> metadata,  List<String> allowedTools,  String context,  String agent,  List<String> arguments,  bool disableModelInvocation,  bool userInvocable,  String whenToUse,  String model,  String effort,  String source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Frontmatter() when $default != null:
return $default(_that.name,_that.description,_that.license,_that.compatibility,_that.metadata,_that.allowedTools,_that.context,_that.agent,_that.arguments,_that.disableModelInvocation,_that.userInvocable,_that.whenToUse,_that.model,_that.effort,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String description,  String license,  String compatibility,  Map<String, String> metadata,  List<String> allowedTools,  String context,  String agent,  List<String> arguments,  bool disableModelInvocation,  bool userInvocable,  String whenToUse,  String model,  String effort,  String source)  $default,) {final _that = this;
switch (_that) {
case _Frontmatter():
return $default(_that.name,_that.description,_that.license,_that.compatibility,_that.metadata,_that.allowedTools,_that.context,_that.agent,_that.arguments,_that.disableModelInvocation,_that.userInvocable,_that.whenToUse,_that.model,_that.effort,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String description,  String license,  String compatibility,  Map<String, String> metadata,  List<String> allowedTools,  String context,  String agent,  List<String> arguments,  bool disableModelInvocation,  bool userInvocable,  String whenToUse,  String model,  String effort,  String source)?  $default,) {final _that = this;
switch (_that) {
case _Frontmatter() when $default != null:
return $default(_that.name,_that.description,_that.license,_that.compatibility,_that.metadata,_that.allowedTools,_that.context,_that.agent,_that.arguments,_that.disableModelInvocation,_that.userInvocable,_that.whenToUse,_that.model,_that.effort,_that.source);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Frontmatter implements Frontmatter {
  const _Frontmatter({this.name = '', this.description = '', this.license = '', this.compatibility = '', final  Map<String, String> metadata = const <String, String>{}, final  List<String> allowedTools = const <String>[], this.context = '', this.agent = '', final  List<String> arguments = const <String>[], this.disableModelInvocation = false, this.userInvocable = false, this.whenToUse = '', this.model = '', this.effort = '', this.source = ''}): _metadata = metadata,_allowedTools = allowedTools,_arguments = arguments;
  factory _Frontmatter.fromJson(Map<String, dynamic> json) => _$FrontmatterFromJson(json);

@override@JsonKey() final  String name;
@override@JsonKey() final  String description;
@override@JsonKey() final  String license;
// 规范核心（B1 保真新暴露）
@override@JsonKey() final  String compatibility;
// 规范核心:环境需求声明
 final  Map<String, String> _metadata;
// 规范核心:环境需求声明
@override@JsonKey() Map<String, String> get metadata {
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_metadata);
}

// 规范扩展逃生口
 final  List<String> _allowedTools;
// 规范扩展逃生口
@override@JsonKey() List<String> get allowedTools {
  if (_allowedTools is EqualUnmodifiableListView) return _allowedTools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allowedTools);
}

// pre-authorized tools (fn_/hd_ id · Read/Bash · mcp:server/tool)
@override@JsonKey() final  String context;
// inline | fork
@override@JsonKey() final  String agent;
// required when context == fork
 final  List<String> _arguments;
// required when context == fork
@override@JsonKey() List<String> get arguments {
  if (_arguments is EqualUnmodifiableListView) return _arguments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_arguments);
}

@override@JsonKey() final  bool disableModelInvocation;
@override@JsonKey() final  bool userInvocable;
@override@JsonKey() final  String whenToUse;
@override@JsonKey() final  String model;
@override@JsonKey() final  String effort;
@override@JsonKey() final  String source;

/// Create a copy of Frontmatter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrontmatterCopyWith<_Frontmatter> get copyWith => __$FrontmatterCopyWithImpl<_Frontmatter>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FrontmatterToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Frontmatter&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.license, license) || other.license == license)&&(identical(other.compatibility, compatibility) || other.compatibility == compatibility)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._allowedTools, _allowedTools)&&(identical(other.context, context) || other.context == context)&&(identical(other.agent, agent) || other.agent == agent)&&const DeepCollectionEquality().equals(other._arguments, _arguments)&&(identical(other.disableModelInvocation, disableModelInvocation) || other.disableModelInvocation == disableModelInvocation)&&(identical(other.userInvocable, userInvocable) || other.userInvocable == userInvocable)&&(identical(other.whenToUse, whenToUse) || other.whenToUse == whenToUse)&&(identical(other.model, model) || other.model == model)&&(identical(other.effort, effort) || other.effort == effort)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,license,compatibility,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_allowedTools),context,agent,const DeepCollectionEquality().hash(_arguments),disableModelInvocation,userInvocable,whenToUse,model,effort,source);

@override
String toString() {
  return 'Frontmatter(name: $name, description: $description, license: $license, compatibility: $compatibility, metadata: $metadata, allowedTools: $allowedTools, context: $context, agent: $agent, arguments: $arguments, disableModelInvocation: $disableModelInvocation, userInvocable: $userInvocable, whenToUse: $whenToUse, model: $model, effort: $effort, source: $source)';
}


}

/// @nodoc
abstract mixin class _$FrontmatterCopyWith<$Res> implements $FrontmatterCopyWith<$Res> {
  factory _$FrontmatterCopyWith(_Frontmatter value, $Res Function(_Frontmatter) _then) = __$FrontmatterCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, String license, String compatibility, Map<String, String> metadata, List<String> allowedTools, String context, String agent, List<String> arguments, bool disableModelInvocation, bool userInvocable, String whenToUse, String model, String effort, String source
});




}
/// @nodoc
class __$FrontmatterCopyWithImpl<$Res>
    implements _$FrontmatterCopyWith<$Res> {
  __$FrontmatterCopyWithImpl(this._self, this._then);

  final _Frontmatter _self;
  final $Res Function(_Frontmatter) _then;

/// Create a copy of Frontmatter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? license = null,Object? compatibility = null,Object? metadata = null,Object? allowedTools = null,Object? context = null,Object? agent = null,Object? arguments = null,Object? disableModelInvocation = null,Object? userInvocable = null,Object? whenToUse = null,Object? model = null,Object? effort = null,Object? source = null,}) {
  return _then(_Frontmatter(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,license: null == license ? _self.license : license // ignore: cast_nullable_to_non_nullable
as String,compatibility: null == compatibility ? _self.compatibility : compatibility // ignore: cast_nullable_to_non_nullable
as String,metadata: null == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, String>,allowedTools: null == allowedTools ? _self._allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>,context: null == context ? _self.context : context // ignore: cast_nullable_to_non_nullable
as String,agent: null == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String,arguments: null == arguments ? _self._arguments : arguments // ignore: cast_nullable_to_non_nullable
as List<String>,disableModelInvocation: null == disableModelInvocation ? _self.disableModelInvocation : disableModelInvocation // ignore: cast_nullable_to_non_nullable
as bool,userInvocable: null == userInvocable ? _self.userInvocable : userInvocable // ignore: cast_nullable_to_non_nullable
as bool,whenToUse: null == whenToUse ? _self.whenToUse : whenToUse // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,effort: null == effort ? _self.effort : effort // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
