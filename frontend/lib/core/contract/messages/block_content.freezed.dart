// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'block_content.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TextContent {

 String get content; String? get signature;
/// Create a copy of TextContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextContentCopyWith<TextContent> get copyWith => _$TextContentCopyWithImpl<TextContent>(this as TextContent, _$identity);

  /// Serializes this TextContent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TextContent&&(identical(other.content, content) || other.content == content)&&(identical(other.signature, signature) || other.signature == signature));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,content,signature);

@override
String toString() {
  return 'TextContent(content: $content, signature: $signature)';
}


}

/// @nodoc
abstract mixin class $TextContentCopyWith<$Res>  {
  factory $TextContentCopyWith(TextContent value, $Res Function(TextContent) _then) = _$TextContentCopyWithImpl;
@useResult
$Res call({
 String content, String? signature
});




}
/// @nodoc
class _$TextContentCopyWithImpl<$Res>
    implements $TextContentCopyWith<$Res> {
  _$TextContentCopyWithImpl(this._self, this._then);

  final TextContent _self;
  final $Res Function(TextContent) _then;

/// Create a copy of TextContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? content = null,Object? signature = freezed,}) {
  return _then(_self.copyWith(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,signature: freezed == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TextContent].
extension TextContentPatterns on TextContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TextContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TextContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TextContent value)  $default,){
final _that = this;
switch (_that) {
case _TextContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TextContent value)?  $default,){
final _that = this;
switch (_that) {
case _TextContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String content,  String? signature)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TextContent() when $default != null:
return $default(_that.content,_that.signature);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String content,  String? signature)  $default,) {final _that = this;
switch (_that) {
case _TextContent():
return $default(_that.content,_that.signature);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String content,  String? signature)?  $default,) {final _that = this;
switch (_that) {
case _TextContent() when $default != null:
return $default(_that.content,_that.signature);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TextContent implements TextContent {
  const _TextContent({this.content = '', this.signature});
  factory _TextContent.fromJson(Map<String, dynamic> json) => _$TextContentFromJson(json);

@override@JsonKey() final  String content;
@override final  String? signature;

/// Create a copy of TextContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TextContentCopyWith<_TextContent> get copyWith => __$TextContentCopyWithImpl<_TextContent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TextContentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TextContent&&(identical(other.content, content) || other.content == content)&&(identical(other.signature, signature) || other.signature == signature));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,content,signature);

@override
String toString() {
  return 'TextContent(content: $content, signature: $signature)';
}


}

/// @nodoc
abstract mixin class _$TextContentCopyWith<$Res> implements $TextContentCopyWith<$Res> {
  factory _$TextContentCopyWith(_TextContent value, $Res Function(_TextContent) _then) = __$TextContentCopyWithImpl;
@override @useResult
$Res call({
 String content, String? signature
});




}
/// @nodoc
class __$TextContentCopyWithImpl<$Res>
    implements _$TextContentCopyWith<$Res> {
  __$TextContentCopyWithImpl(this._self, this._then);

  final _TextContent _self;
  final $Res Function(_TextContent) _then;

/// Create a copy of TextContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,Object? signature = freezed,}) {
  return _then(_TextContent(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,signature: freezed == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ToolCallContent {

 String get name; String? get arguments; String? get summary; String? get danger; String? get entityName;
/// Create a copy of ToolCallContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolCallContentCopyWith<ToolCallContent> get copyWith => _$ToolCallContentCopyWithImpl<ToolCallContent>(this as ToolCallContent, _$identity);

  /// Serializes this ToolCallContent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolCallContent&&(identical(other.name, name) || other.name == name)&&(identical(other.arguments, arguments) || other.arguments == arguments)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.danger, danger) || other.danger == danger)&&(identical(other.entityName, entityName) || other.entityName == entityName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,arguments,summary,danger,entityName);

@override
String toString() {
  return 'ToolCallContent(name: $name, arguments: $arguments, summary: $summary, danger: $danger, entityName: $entityName)';
}


}

/// @nodoc
abstract mixin class $ToolCallContentCopyWith<$Res>  {
  factory $ToolCallContentCopyWith(ToolCallContent value, $Res Function(ToolCallContent) _then) = _$ToolCallContentCopyWithImpl;
@useResult
$Res call({
 String name, String? arguments, String? summary, String? danger, String? entityName
});




}
/// @nodoc
class _$ToolCallContentCopyWithImpl<$Res>
    implements $ToolCallContentCopyWith<$Res> {
  _$ToolCallContentCopyWithImpl(this._self, this._then);

  final ToolCallContent _self;
  final $Res Function(ToolCallContent) _then;

/// Create a copy of ToolCallContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? arguments = freezed,Object? summary = freezed,Object? danger = freezed,Object? entityName = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,danger: freezed == danger ? _self.danger : danger // ignore: cast_nullable_to_non_nullable
as String?,entityName: freezed == entityName ? _self.entityName : entityName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ToolCallContent].
extension ToolCallContentPatterns on ToolCallContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolCallContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolCallContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolCallContent value)  $default,){
final _that = this;
switch (_that) {
case _ToolCallContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolCallContent value)?  $default,){
final _that = this;
switch (_that) {
case _ToolCallContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? arguments,  String? summary,  String? danger,  String? entityName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolCallContent() when $default != null:
return $default(_that.name,_that.arguments,_that.summary,_that.danger,_that.entityName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? arguments,  String? summary,  String? danger,  String? entityName)  $default,) {final _that = this;
switch (_that) {
case _ToolCallContent():
return $default(_that.name,_that.arguments,_that.summary,_that.danger,_that.entityName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? arguments,  String? summary,  String? danger,  String? entityName)?  $default,) {final _that = this;
switch (_that) {
case _ToolCallContent() when $default != null:
return $default(_that.name,_that.arguments,_that.summary,_that.danger,_that.entityName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ToolCallContent implements ToolCallContent {
  const _ToolCallContent({this.name = '', this.arguments, this.summary, this.danger, this.entityName});
  factory _ToolCallContent.fromJson(Map<String, dynamic> json) => _$ToolCallContentFromJson(json);

@override@JsonKey() final  String name;
@override final  String? arguments;
@override final  String? summary;
@override final  String? danger;
@override final  String? entityName;

/// Create a copy of ToolCallContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolCallContentCopyWith<_ToolCallContent> get copyWith => __$ToolCallContentCopyWithImpl<_ToolCallContent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolCallContentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolCallContent&&(identical(other.name, name) || other.name == name)&&(identical(other.arguments, arguments) || other.arguments == arguments)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.danger, danger) || other.danger == danger)&&(identical(other.entityName, entityName) || other.entityName == entityName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,arguments,summary,danger,entityName);

@override
String toString() {
  return 'ToolCallContent(name: $name, arguments: $arguments, summary: $summary, danger: $danger, entityName: $entityName)';
}


}

/// @nodoc
abstract mixin class _$ToolCallContentCopyWith<$Res> implements $ToolCallContentCopyWith<$Res> {
  factory _$ToolCallContentCopyWith(_ToolCallContent value, $Res Function(_ToolCallContent) _then) = __$ToolCallContentCopyWithImpl;
@override @useResult
$Res call({
 String name, String? arguments, String? summary, String? danger, String? entityName
});




}
/// @nodoc
class __$ToolCallContentCopyWithImpl<$Res>
    implements _$ToolCallContentCopyWith<$Res> {
  __$ToolCallContentCopyWithImpl(this._self, this._then);

  final _ToolCallContent _self;
  final $Res Function(_ToolCallContent) _then;

/// Create a copy of ToolCallContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? arguments = freezed,Object? summary = freezed,Object? danger = freezed,Object? entityName = freezed,}) {
  return _then(_ToolCallContent(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String?,danger: freezed == danger ? _self.danger : danger // ignore: cast_nullable_to_non_nullable
as String?,entityName: freezed == entityName ? _self.entityName : entityName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ToolResultContent {

 String get content;
/// Create a copy of ToolResultContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolResultContentCopyWith<ToolResultContent> get copyWith => _$ToolResultContentCopyWithImpl<ToolResultContent>(this as ToolResultContent, _$identity);

  /// Serializes this ToolResultContent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolResultContent&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,content);

@override
String toString() {
  return 'ToolResultContent(content: $content)';
}


}

/// @nodoc
abstract mixin class $ToolResultContentCopyWith<$Res>  {
  factory $ToolResultContentCopyWith(ToolResultContent value, $Res Function(ToolResultContent) _then) = _$ToolResultContentCopyWithImpl;
@useResult
$Res call({
 String content
});




}
/// @nodoc
class _$ToolResultContentCopyWithImpl<$Res>
    implements $ToolResultContentCopyWith<$Res> {
  _$ToolResultContentCopyWithImpl(this._self, this._then);

  final ToolResultContent _self;
  final $Res Function(ToolResultContent) _then;

/// Create a copy of ToolResultContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? content = null,}) {
  return _then(_self.copyWith(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ToolResultContent].
extension ToolResultContentPatterns on ToolResultContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolResultContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolResultContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolResultContent value)  $default,){
final _that = this;
switch (_that) {
case _ToolResultContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolResultContent value)?  $default,){
final _that = this;
switch (_that) {
case _ToolResultContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String content)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolResultContent() when $default != null:
return $default(_that.content);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String content)  $default,) {final _that = this;
switch (_that) {
case _ToolResultContent():
return $default(_that.content);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String content)?  $default,) {final _that = this;
switch (_that) {
case _ToolResultContent() when $default != null:
return $default(_that.content);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ToolResultContent implements ToolResultContent {
  const _ToolResultContent({this.content = ''});
  factory _ToolResultContent.fromJson(Map<String, dynamic> json) => _$ToolResultContentFromJson(json);

@override@JsonKey() final  String content;

/// Create a copy of ToolResultContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolResultContentCopyWith<_ToolResultContent> get copyWith => __$ToolResultContentCopyWithImpl<_ToolResultContent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolResultContentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolResultContent&&(identical(other.content, content) || other.content == content));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,content);

@override
String toString() {
  return 'ToolResultContent(content: $content)';
}


}

/// @nodoc
abstract mixin class _$ToolResultContentCopyWith<$Res> implements $ToolResultContentCopyWith<$Res> {
  factory _$ToolResultContentCopyWith(_ToolResultContent value, $Res Function(_ToolResultContent) _then) = __$ToolResultContentCopyWithImpl;
@override @useResult
$Res call({
 String content
});




}
/// @nodoc
class __$ToolResultContentCopyWithImpl<$Res>
    implements _$ToolResultContentCopyWith<$Res> {
  __$ToolResultContentCopyWithImpl(this._self, this._then);

  final _ToolResultContent _self;
  final $Res Function(_ToolResultContent) _then;

/// Create a copy of ToolResultContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,}) {
  return _then(_ToolResultContent(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$MessageContent {

 String get role; bool? get subagent; String? get content;// user-turn close 用户回合
 String? get status;// assistant-turn close 助手回合
 String? get stopReason; int? get inputTokens; int? get outputTokens; String? get errorCode; String? get errorMessage;
/// Create a copy of MessageContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageContentCopyWith<MessageContent> get copyWith => _$MessageContentCopyWithImpl<MessageContent>(this as MessageContent, _$identity);

  /// Serializes this MessageContent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageContent&&(identical(other.role, role) || other.role == role)&&(identical(other.subagent, subagent) || other.subagent == subagent)&&(identical(other.content, content) || other.content == content)&&(identical(other.status, status) || other.status == status)&&(identical(other.stopReason, stopReason) || other.stopReason == stopReason)&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role,subagent,content,status,stopReason,inputTokens,outputTokens,errorCode,errorMessage);

@override
String toString() {
  return 'MessageContent(role: $role, subagent: $subagent, content: $content, status: $status, stopReason: $stopReason, inputTokens: $inputTokens, outputTokens: $outputTokens, errorCode: $errorCode, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $MessageContentCopyWith<$Res>  {
  factory $MessageContentCopyWith(MessageContent value, $Res Function(MessageContent) _then) = _$MessageContentCopyWithImpl;
@useResult
$Res call({
 String role, bool? subagent, String? content, String? status, String? stopReason, int? inputTokens, int? outputTokens, String? errorCode, String? errorMessage
});




}
/// @nodoc
class _$MessageContentCopyWithImpl<$Res>
    implements $MessageContentCopyWith<$Res> {
  _$MessageContentCopyWithImpl(this._self, this._then);

  final MessageContent _self;
  final $Res Function(MessageContent) _then;

/// Create a copy of MessageContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = null,Object? subagent = freezed,Object? content = freezed,Object? status = freezed,Object? stopReason = freezed,Object? inputTokens = freezed,Object? outputTokens = freezed,Object? errorCode = freezed,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,subagent: freezed == subagent ? _self.subagent : subagent // ignore: cast_nullable_to_non_nullable
as bool?,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,stopReason: freezed == stopReason ? _self.stopReason : stopReason // ignore: cast_nullable_to_non_nullable
as String?,inputTokens: freezed == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int?,outputTokens: freezed == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageContent].
extension MessageContentPatterns on MessageContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageContent value)  $default,){
final _that = this;
switch (_that) {
case _MessageContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageContent value)?  $default,){
final _that = this;
switch (_that) {
case _MessageContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String role,  bool? subagent,  String? content,  String? status,  String? stopReason,  int? inputTokens,  int? outputTokens,  String? errorCode,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageContent() when $default != null:
return $default(_that.role,_that.subagent,_that.content,_that.status,_that.stopReason,_that.inputTokens,_that.outputTokens,_that.errorCode,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String role,  bool? subagent,  String? content,  String? status,  String? stopReason,  int? inputTokens,  int? outputTokens,  String? errorCode,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _MessageContent():
return $default(_that.role,_that.subagent,_that.content,_that.status,_that.stopReason,_that.inputTokens,_that.outputTokens,_that.errorCode,_that.errorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String role,  bool? subagent,  String? content,  String? status,  String? stopReason,  int? inputTokens,  int? outputTokens,  String? errorCode,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _MessageContent() when $default != null:
return $default(_that.role,_that.subagent,_that.content,_that.status,_that.stopReason,_that.inputTokens,_that.outputTokens,_that.errorCode,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageContent implements MessageContent {
  const _MessageContent({this.role = '', this.subagent, this.content, this.status, this.stopReason, this.inputTokens, this.outputTokens, this.errorCode, this.errorMessage});
  factory _MessageContent.fromJson(Map<String, dynamic> json) => _$MessageContentFromJson(json);

@override@JsonKey() final  String role;
@override final  bool? subagent;
@override final  String? content;
// user-turn close 用户回合
@override final  String? status;
// assistant-turn close 助手回合
@override final  String? stopReason;
@override final  int? inputTokens;
@override final  int? outputTokens;
@override final  String? errorCode;
@override final  String? errorMessage;

/// Create a copy of MessageContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageContentCopyWith<_MessageContent> get copyWith => __$MessageContentCopyWithImpl<_MessageContent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageContentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageContent&&(identical(other.role, role) || other.role == role)&&(identical(other.subagent, subagent) || other.subagent == subagent)&&(identical(other.content, content) || other.content == content)&&(identical(other.status, status) || other.status == status)&&(identical(other.stopReason, stopReason) || other.stopReason == stopReason)&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role,subagent,content,status,stopReason,inputTokens,outputTokens,errorCode,errorMessage);

@override
String toString() {
  return 'MessageContent(role: $role, subagent: $subagent, content: $content, status: $status, stopReason: $stopReason, inputTokens: $inputTokens, outputTokens: $outputTokens, errorCode: $errorCode, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$MessageContentCopyWith<$Res> implements $MessageContentCopyWith<$Res> {
  factory _$MessageContentCopyWith(_MessageContent value, $Res Function(_MessageContent) _then) = __$MessageContentCopyWithImpl;
@override @useResult
$Res call({
 String role, bool? subagent, String? content, String? status, String? stopReason, int? inputTokens, int? outputTokens, String? errorCode, String? errorMessage
});




}
/// @nodoc
class __$MessageContentCopyWithImpl<$Res>
    implements _$MessageContentCopyWith<$Res> {
  __$MessageContentCopyWithImpl(this._self, this._then);

  final _MessageContent _self;
  final $Res Function(_MessageContent) _then;

/// Create a copy of MessageContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = null,Object? subagent = freezed,Object? content = freezed,Object? status = freezed,Object? stopReason = freezed,Object? inputTokens = freezed,Object? outputTokens = freezed,Object? errorCode = freezed,Object? errorMessage = freezed,}) {
  return _then(_MessageContent(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,subagent: freezed == subagent ? _self.subagent : subagent // ignore: cast_nullable_to_non_nullable
as bool?,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,stopReason: freezed == stopReason ? _self.stopReason : stopReason // ignore: cast_nullable_to_non_nullable
as String?,inputTokens: freezed == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int?,outputTokens: freezed == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
