// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'document.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DocumentNode {

 String get id; String? get parentId; String get name; String get description; String get content;// omitted by GET /tree (metadata only) → empty; full node via GET /{id}
 bool get hasContent;// GET /tree only: body non-empty (≡ sizeBytes>0) → drives empty-page vs written-doc icon
 List<String> get tags; int get position; String get path; int get sizeBytes; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of DocumentNode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentNodeCopyWith<DocumentNode> get copyWith => _$DocumentNodeCopyWithImpl<DocumentNode>(this as DocumentNode, _$identity);

  /// Serializes this DocumentNode to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentNode&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.content, content) || other.content == content)&&(identical(other.hasContent, hasContent) || other.hasContent == hasContent)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.position, position) || other.position == position)&&(identical(other.path, path) || other.path == path)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,name,description,content,hasContent,const DeepCollectionEquality().hash(tags),position,path,sizeBytes,createdAt,updatedAt);

@override
String toString() {
  return 'DocumentNode(id: $id, parentId: $parentId, name: $name, description: $description, content: $content, hasContent: $hasContent, tags: $tags, position: $position, path: $path, sizeBytes: $sizeBytes, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $DocumentNodeCopyWith<$Res>  {
  factory $DocumentNodeCopyWith(DocumentNode value, $Res Function(DocumentNode) _then) = _$DocumentNodeCopyWithImpl;
@useResult
$Res call({
 String id, String? parentId, String name, String description, String content, bool hasContent, List<String> tags, int position, String path, int sizeBytes, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$DocumentNodeCopyWithImpl<$Res>
    implements $DocumentNodeCopyWith<$Res> {
  _$DocumentNodeCopyWithImpl(this._self, this._then);

  final DocumentNode _self;
  final $Res Function(DocumentNode) _then;

/// Create a copy of DocumentNode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? parentId = freezed,Object? name = null,Object? description = null,Object? content = null,Object? hasContent = null,Object? tags = null,Object? position = null,Object? path = null,Object? sizeBytes = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,hasContent: null == hasContent ? _self.hasContent : hasContent // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [DocumentNode].
extension DocumentNodePatterns on DocumentNode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentNode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentNode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentNode value)  $default,){
final _that = this;
switch (_that) {
case _DocumentNode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentNode value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentNode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? parentId,  String name,  String description,  String content,  bool hasContent,  List<String> tags,  int position,  String path,  int sizeBytes,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentNode() when $default != null:
return $default(_that.id,_that.parentId,_that.name,_that.description,_that.content,_that.hasContent,_that.tags,_that.position,_that.path,_that.sizeBytes,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? parentId,  String name,  String description,  String content,  bool hasContent,  List<String> tags,  int position,  String path,  int sizeBytes,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _DocumentNode():
return $default(_that.id,_that.parentId,_that.name,_that.description,_that.content,_that.hasContent,_that.tags,_that.position,_that.path,_that.sizeBytes,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? parentId,  String name,  String description,  String content,  bool hasContent,  List<String> tags,  int position,  String path,  int sizeBytes,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _DocumentNode() when $default != null:
return $default(_that.id,_that.parentId,_that.name,_that.description,_that.content,_that.hasContent,_that.tags,_that.position,_that.path,_that.sizeBytes,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DocumentNode implements DocumentNode {
  const _DocumentNode({required this.id, this.parentId, this.name = '', this.description = '', this.content = '', this.hasContent = false, final  List<String> tags = const <String>[], this.position = 0, this.path = '', this.sizeBytes = 0, required this.createdAt, required this.updatedAt}): _tags = tags;
  factory _DocumentNode.fromJson(Map<String, dynamic> json) => _$DocumentNodeFromJson(json);

@override final  String id;
@override final  String? parentId;
@override@JsonKey() final  String name;
@override@JsonKey() final  String description;
@override@JsonKey() final  String content;
// omitted by GET /tree (metadata only) → empty; full node via GET /{id}
@override@JsonKey() final  bool hasContent;
// GET /tree only: body non-empty (≡ sizeBytes>0) → drives empty-page vs written-doc icon
 final  List<String> _tags;
// GET /tree only: body non-empty (≡ sizeBytes>0) → drives empty-page vs written-doc icon
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override@JsonKey() final  int position;
@override@JsonKey() final  String path;
@override@JsonKey() final  int sizeBytes;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of DocumentNode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentNodeCopyWith<_DocumentNode> get copyWith => __$DocumentNodeCopyWithImpl<_DocumentNode>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DocumentNodeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentNode&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.content, content) || other.content == content)&&(identical(other.hasContent, hasContent) || other.hasContent == hasContent)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.position, position) || other.position == position)&&(identical(other.path, path) || other.path == path)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,name,description,content,hasContent,const DeepCollectionEquality().hash(_tags),position,path,sizeBytes,createdAt,updatedAt);

@override
String toString() {
  return 'DocumentNode(id: $id, parentId: $parentId, name: $name, description: $description, content: $content, hasContent: $hasContent, tags: $tags, position: $position, path: $path, sizeBytes: $sizeBytes, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$DocumentNodeCopyWith<$Res> implements $DocumentNodeCopyWith<$Res> {
  factory _$DocumentNodeCopyWith(_DocumentNode value, $Res Function(_DocumentNode) _then) = __$DocumentNodeCopyWithImpl;
@override @useResult
$Res call({
 String id, String? parentId, String name, String description, String content, bool hasContent, List<String> tags, int position, String path, int sizeBytes, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$DocumentNodeCopyWithImpl<$Res>
    implements _$DocumentNodeCopyWith<$Res> {
  __$DocumentNodeCopyWithImpl(this._self, this._then);

  final _DocumentNode _self;
  final $Res Function(_DocumentNode) _then;

/// Create a copy of DocumentNode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parentId = freezed,Object? name = null,Object? description = null,Object? content = null,Object? hasContent = null,Object? tags = null,Object? position = null,Object? path = null,Object? sizeBytes = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_DocumentNode(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,hasContent: null == hasContent ? _self.hasContent : hasContent // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
