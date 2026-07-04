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
 String get source;// user | ai
 String get context;// inline | fork
 String get body;// only from GET /skills/{name}
 Frontmatter get frontmatter; DateTime get updatedAt;
/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SkillCopyWith<Skill> get copyWith => _$SkillCopyWithImpl<Skill>(this as Skill, _$identity);

  /// Serializes this Skill to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Skill&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.source, source) || other.source == source)&&(identical(other.context, context) || other.context == context)&&(identical(other.body, body) || other.body == body)&&(identical(other.frontmatter, frontmatter) || other.frontmatter == frontmatter)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,source,context,body,frontmatter,updatedAt);

@override
String toString() {
  return 'Skill(name: $name, description: $description, source: $source, context: $context, body: $body, frontmatter: $frontmatter, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SkillCopyWith<$Res>  {
  factory $SkillCopyWith(Skill value, $Res Function(Skill) _then) = _$SkillCopyWithImpl;
@useResult
$Res call({
 String name, String description, String source, String context, String body, Frontmatter frontmatter, DateTime updatedAt
});


$FrontmatterCopyWith<$Res> get frontmatter;

}
/// @nodoc
class _$SkillCopyWithImpl<$Res>
    implements $SkillCopyWith<$Res> {
  _$SkillCopyWithImpl(this._self, this._then);

  final Skill _self;
  final $Res Function(Skill) _then;

/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? source = null,Object? context = null,Object? body = null,Object? frontmatter = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,context: null == context ? _self.context : context // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,frontmatter: null == frontmatter ? _self.frontmatter : frontmatter // ignore: cast_nullable_to_non_nullable
as Frontmatter,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String description,  String source,  String context,  String body,  Frontmatter frontmatter,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Skill() when $default != null:
return $default(_that.name,_that.description,_that.source,_that.context,_that.body,_that.frontmatter,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String description,  String source,  String context,  String body,  Frontmatter frontmatter,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Skill():
return $default(_that.name,_that.description,_that.source,_that.context,_that.body,_that.frontmatter,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String description,  String source,  String context,  String body,  Frontmatter frontmatter,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Skill() when $default != null:
return $default(_that.name,_that.description,_that.source,_that.context,_that.body,_that.frontmatter,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Skill implements Skill {
  const _Skill({required this.name, this.description = '', this.source = '', this.context = '', this.body = '', this.frontmatter = const Frontmatter(), required this.updatedAt});
  factory _Skill.fromJson(Map<String, dynamic> json) => _$SkillFromJson(json);

@override final  String name;
@override@JsonKey() final  String description;
// mirror of frontmatter.description
@override@JsonKey() final  String source;
// user | ai
@override@JsonKey() final  String context;
// inline | fork
@override@JsonKey() final  String body;
// only from GET /skills/{name}
@override@JsonKey() final  Frontmatter frontmatter;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Skill&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.source, source) || other.source == source)&&(identical(other.context, context) || other.context == context)&&(identical(other.body, body) || other.body == body)&&(identical(other.frontmatter, frontmatter) || other.frontmatter == frontmatter)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,source,context,body,frontmatter,updatedAt);

@override
String toString() {
  return 'Skill(name: $name, description: $description, source: $source, context: $context, body: $body, frontmatter: $frontmatter, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SkillCopyWith<$Res> implements $SkillCopyWith<$Res> {
  factory _$SkillCopyWith(_Skill value, $Res Function(_Skill) _then) = __$SkillCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, String source, String context, String body, Frontmatter frontmatter, DateTime updatedAt
});


@override $FrontmatterCopyWith<$Res> get frontmatter;

}
/// @nodoc
class __$SkillCopyWithImpl<$Res>
    implements _$SkillCopyWith<$Res> {
  __$SkillCopyWithImpl(this._self, this._then);

  final _Skill _self;
  final $Res Function(_Skill) _then;

/// Create a copy of Skill
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? source = null,Object? context = null,Object? body = null,Object? frontmatter = null,Object? updatedAt = null,}) {
  return _then(_Skill(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,context: null == context ? _self.context : context // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,frontmatter: null == frontmatter ? _self.frontmatter : frontmatter // ignore: cast_nullable_to_non_nullable
as Frontmatter,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
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
}
}


/// @nodoc
mixin _$Frontmatter {

 String get name; String get description; List<String> get allowedTools;// pre-authorized tools (fn_/hd_ id · Read/Bash · mcp:server/tool)
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Frontmatter&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.allowedTools, allowedTools)&&(identical(other.context, context) || other.context == context)&&(identical(other.agent, agent) || other.agent == agent)&&const DeepCollectionEquality().equals(other.arguments, arguments)&&(identical(other.disableModelInvocation, disableModelInvocation) || other.disableModelInvocation == disableModelInvocation)&&(identical(other.userInvocable, userInvocable) || other.userInvocable == userInvocable)&&(identical(other.whenToUse, whenToUse) || other.whenToUse == whenToUse)&&(identical(other.model, model) || other.model == model)&&(identical(other.effort, effort) || other.effort == effort)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(allowedTools),context,agent,const DeepCollectionEquality().hash(arguments),disableModelInvocation,userInvocable,whenToUse,model,effort,source);

@override
String toString() {
  return 'Frontmatter(name: $name, description: $description, allowedTools: $allowedTools, context: $context, agent: $agent, arguments: $arguments, disableModelInvocation: $disableModelInvocation, userInvocable: $userInvocable, whenToUse: $whenToUse, model: $model, effort: $effort, source: $source)';
}


}

/// @nodoc
abstract mixin class $FrontmatterCopyWith<$Res>  {
  factory $FrontmatterCopyWith(Frontmatter value, $Res Function(Frontmatter) _then) = _$FrontmatterCopyWithImpl;
@useResult
$Res call({
 String name, String description, List<String> allowedTools, String context, String agent, List<String> arguments, bool disableModelInvocation, bool userInvocable, String whenToUse, String model, String effort, String source
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
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? allowedTools = null,Object? context = null,Object? agent = null,Object? arguments = null,Object? disableModelInvocation = null,Object? userInvocable = null,Object? whenToUse = null,Object? model = null,Object? effort = null,Object? source = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,allowedTools: null == allowedTools ? _self.allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String description,  List<String> allowedTools,  String context,  String agent,  List<String> arguments,  bool disableModelInvocation,  bool userInvocable,  String whenToUse,  String model,  String effort,  String source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Frontmatter() when $default != null:
return $default(_that.name,_that.description,_that.allowedTools,_that.context,_that.agent,_that.arguments,_that.disableModelInvocation,_that.userInvocable,_that.whenToUse,_that.model,_that.effort,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String description,  List<String> allowedTools,  String context,  String agent,  List<String> arguments,  bool disableModelInvocation,  bool userInvocable,  String whenToUse,  String model,  String effort,  String source)  $default,) {final _that = this;
switch (_that) {
case _Frontmatter():
return $default(_that.name,_that.description,_that.allowedTools,_that.context,_that.agent,_that.arguments,_that.disableModelInvocation,_that.userInvocable,_that.whenToUse,_that.model,_that.effort,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String description,  List<String> allowedTools,  String context,  String agent,  List<String> arguments,  bool disableModelInvocation,  bool userInvocable,  String whenToUse,  String model,  String effort,  String source)?  $default,) {final _that = this;
switch (_that) {
case _Frontmatter() when $default != null:
return $default(_that.name,_that.description,_that.allowedTools,_that.context,_that.agent,_that.arguments,_that.disableModelInvocation,_that.userInvocable,_that.whenToUse,_that.model,_that.effort,_that.source);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Frontmatter implements Frontmatter {
  const _Frontmatter({this.name = '', this.description = '', final  List<String> allowedTools = const <String>[], this.context = '', this.agent = '', final  List<String> arguments = const <String>[], this.disableModelInvocation = false, this.userInvocable = false, this.whenToUse = '', this.model = '', this.effort = '', this.source = ''}): _allowedTools = allowedTools,_arguments = arguments;
  factory _Frontmatter.fromJson(Map<String, dynamic> json) => _$FrontmatterFromJson(json);

@override@JsonKey() final  String name;
@override@JsonKey() final  String description;
 final  List<String> _allowedTools;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Frontmatter&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._allowedTools, _allowedTools)&&(identical(other.context, context) || other.context == context)&&(identical(other.agent, agent) || other.agent == agent)&&const DeepCollectionEquality().equals(other._arguments, _arguments)&&(identical(other.disableModelInvocation, disableModelInvocation) || other.disableModelInvocation == disableModelInvocation)&&(identical(other.userInvocable, userInvocable) || other.userInvocable == userInvocable)&&(identical(other.whenToUse, whenToUse) || other.whenToUse == whenToUse)&&(identical(other.model, model) || other.model == model)&&(identical(other.effort, effort) || other.effort == effort)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(_allowedTools),context,agent,const DeepCollectionEquality().hash(_arguments),disableModelInvocation,userInvocable,whenToUse,model,effort,source);

@override
String toString() {
  return 'Frontmatter(name: $name, description: $description, allowedTools: $allowedTools, context: $context, agent: $agent, arguments: $arguments, disableModelInvocation: $disableModelInvocation, userInvocable: $userInvocable, whenToUse: $whenToUse, model: $model, effort: $effort, source: $source)';
}


}

/// @nodoc
abstract mixin class _$FrontmatterCopyWith<$Res> implements $FrontmatterCopyWith<$Res> {
  factory _$FrontmatterCopyWith(_Frontmatter value, $Res Function(_Frontmatter) _then) = __$FrontmatterCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, List<String> allowedTools, String context, String agent, List<String> arguments, bool disableModelInvocation, bool userInvocable, String whenToUse, String model, String effort, String source
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
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? allowedTools = null,Object? context = null,Object? agent = null,Object? arguments = null,Object? disableModelInvocation = null,Object? userInvocable = null,Object? whenToUse = null,Object? model = null,Object? effort = null,Object? source = null,}) {
  return _then(_Frontmatter(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,allowedTools: null == allowedTools ? _self._allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
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
