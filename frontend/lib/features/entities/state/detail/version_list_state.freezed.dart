// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'version_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VersionRow {

 int get version; bool get active; DateTime get createdAt; String get src; String get lang; String? get changeReason; List<String> get summary; int? get added; int? get removed;
/// Create a copy of VersionRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VersionRowCopyWith<VersionRow> get copyWith => _$VersionRowCopyWithImpl<VersionRow>(this as VersionRow, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VersionRow&&(identical(other.version, version) || other.version == version)&&(identical(other.active, active) || other.active == active)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.src, src) || other.src == src)&&(identical(other.lang, lang) || other.lang == lang)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&const DeepCollectionEquality().equals(other.summary, summary)&&(identical(other.added, added) || other.added == added)&&(identical(other.removed, removed) || other.removed == removed));
}


@override
int get hashCode => Object.hash(runtimeType,version,active,createdAt,src,lang,changeReason,const DeepCollectionEquality().hash(summary),added,removed);

@override
String toString() {
  return 'VersionRow(version: $version, active: $active, createdAt: $createdAt, src: $src, lang: $lang, changeReason: $changeReason, summary: $summary, added: $added, removed: $removed)';
}


}

/// @nodoc
abstract mixin class $VersionRowCopyWith<$Res>  {
  factory $VersionRowCopyWith(VersionRow value, $Res Function(VersionRow) _then) = _$VersionRowCopyWithImpl;
@useResult
$Res call({
 int version, bool active, DateTime createdAt, String src, String lang, String? changeReason, List<String> summary, int? added, int? removed
});




}
/// @nodoc
class _$VersionRowCopyWithImpl<$Res>
    implements $VersionRowCopyWith<$Res> {
  _$VersionRowCopyWithImpl(this._self, this._then);

  final VersionRow _self;
  final $Res Function(VersionRow) _then;

/// Create a copy of VersionRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? active = null,Object? createdAt = null,Object? src = null,Object? lang = null,Object? changeReason = freezed,Object? summary = null,Object? added = freezed,Object? removed = freezed,}) {
  return _then(_self.copyWith(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,src: null == src ? _self.src : src // ignore: cast_nullable_to_non_nullable
as String,lang: null == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String,changeReason: freezed == changeReason ? _self.changeReason : changeReason // ignore: cast_nullable_to_non_nullable
as String?,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as List<String>,added: freezed == added ? _self.added : added // ignore: cast_nullable_to_non_nullable
as int?,removed: freezed == removed ? _self.removed : removed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [VersionRow].
extension VersionRowPatterns on VersionRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VersionRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VersionRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VersionRow value)  $default,){
final _that = this;
switch (_that) {
case _VersionRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VersionRow value)?  $default,){
final _that = this;
switch (_that) {
case _VersionRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int version,  bool active,  DateTime createdAt,  String src,  String lang,  String? changeReason,  List<String> summary,  int? added,  int? removed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VersionRow() when $default != null:
return $default(_that.version,_that.active,_that.createdAt,_that.src,_that.lang,_that.changeReason,_that.summary,_that.added,_that.removed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int version,  bool active,  DateTime createdAt,  String src,  String lang,  String? changeReason,  List<String> summary,  int? added,  int? removed)  $default,) {final _that = this;
switch (_that) {
case _VersionRow():
return $default(_that.version,_that.active,_that.createdAt,_that.src,_that.lang,_that.changeReason,_that.summary,_that.added,_that.removed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int version,  bool active,  DateTime createdAt,  String src,  String lang,  String? changeReason,  List<String> summary,  int? added,  int? removed)?  $default,) {final _that = this;
switch (_that) {
case _VersionRow() when $default != null:
return $default(_that.version,_that.active,_that.createdAt,_that.src,_that.lang,_that.changeReason,_that.summary,_that.added,_that.removed);case _:
  return null;

}
}

}

/// @nodoc


class _VersionRow implements VersionRow {
  const _VersionRow({required this.version, required this.active, required this.createdAt, required this.src, required this.lang, this.changeReason, final  List<String> summary = const <String>[], this.added, this.removed}): _summary = summary;
  

@override final  int version;
@override final  bool active;
@override final  DateTime createdAt;
@override final  String src;
@override final  String lang;
@override final  String? changeReason;
 final  List<String> _summary;
@override@JsonKey() List<String> get summary {
  if (_summary is EqualUnmodifiableListView) return _summary;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_summary);
}

@override final  int? added;
@override final  int? removed;

/// Create a copy of VersionRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VersionRowCopyWith<_VersionRow> get copyWith => __$VersionRowCopyWithImpl<_VersionRow>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VersionRow&&(identical(other.version, version) || other.version == version)&&(identical(other.active, active) || other.active == active)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.src, src) || other.src == src)&&(identical(other.lang, lang) || other.lang == lang)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&const DeepCollectionEquality().equals(other._summary, _summary)&&(identical(other.added, added) || other.added == added)&&(identical(other.removed, removed) || other.removed == removed));
}


@override
int get hashCode => Object.hash(runtimeType,version,active,createdAt,src,lang,changeReason,const DeepCollectionEquality().hash(_summary),added,removed);

@override
String toString() {
  return 'VersionRow(version: $version, active: $active, createdAt: $createdAt, src: $src, lang: $lang, changeReason: $changeReason, summary: $summary, added: $added, removed: $removed)';
}


}

/// @nodoc
abstract mixin class _$VersionRowCopyWith<$Res> implements $VersionRowCopyWith<$Res> {
  factory _$VersionRowCopyWith(_VersionRow value, $Res Function(_VersionRow) _then) = __$VersionRowCopyWithImpl;
@override @useResult
$Res call({
 int version, bool active, DateTime createdAt, String src, String lang, String? changeReason, List<String> summary, int? added, int? removed
});




}
/// @nodoc
class __$VersionRowCopyWithImpl<$Res>
    implements _$VersionRowCopyWith<$Res> {
  __$VersionRowCopyWithImpl(this._self, this._then);

  final _VersionRow _self;
  final $Res Function(_VersionRow) _then;

/// Create a copy of VersionRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? active = null,Object? createdAt = null,Object? src = null,Object? lang = null,Object? changeReason = freezed,Object? summary = null,Object? added = freezed,Object? removed = freezed,}) {
  return _then(_VersionRow(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,src: null == src ? _self.src : src // ignore: cast_nullable_to_non_nullable
as String,lang: null == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String,changeReason: freezed == changeReason ? _self.changeReason : changeReason // ignore: cast_nullable_to_non_nullable
as String?,summary: null == summary ? _self._summary : summary // ignore: cast_nullable_to_non_nullable
as List<String>,added: freezed == added ? _self.added : added // ignore: cast_nullable_to_non_nullable
as int?,removed: freezed == removed ? _self.removed : removed // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$VersionListState {

 List<VersionRow> get versions; String? get nextCursor; bool get hasMore; bool get loadingMore; Set<int> get expanded; Set<int> get fullSource; int? get activatingVersion;
/// Create a copy of VersionListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VersionListStateCopyWith<VersionListState> get copyWith => _$VersionListStateCopyWithImpl<VersionListState>(this as VersionListState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VersionListState&&const DeepCollectionEquality().equals(other.versions, versions)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&const DeepCollectionEquality().equals(other.expanded, expanded)&&const DeepCollectionEquality().equals(other.fullSource, fullSource)&&(identical(other.activatingVersion, activatingVersion) || other.activatingVersion == activatingVersion));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(versions),nextCursor,hasMore,loadingMore,const DeepCollectionEquality().hash(expanded),const DeepCollectionEquality().hash(fullSource),activatingVersion);

@override
String toString() {
  return 'VersionListState(versions: $versions, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore, expanded: $expanded, fullSource: $fullSource, activatingVersion: $activatingVersion)';
}


}

/// @nodoc
abstract mixin class $VersionListStateCopyWith<$Res>  {
  factory $VersionListStateCopyWith(VersionListState value, $Res Function(VersionListState) _then) = _$VersionListStateCopyWithImpl;
@useResult
$Res call({
 List<VersionRow> versions, String? nextCursor, bool hasMore, bool loadingMore, Set<int> expanded, Set<int> fullSource, int? activatingVersion
});




}
/// @nodoc
class _$VersionListStateCopyWithImpl<$Res>
    implements $VersionListStateCopyWith<$Res> {
  _$VersionListStateCopyWithImpl(this._self, this._then);

  final VersionListState _self;
  final $Res Function(VersionListState) _then;

/// Create a copy of VersionListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? versions = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,Object? expanded = null,Object? fullSource = null,Object? activatingVersion = freezed,}) {
  return _then(_self.copyWith(
versions: null == versions ? _self.versions : versions // ignore: cast_nullable_to_non_nullable
as List<VersionRow>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,expanded: null == expanded ? _self.expanded : expanded // ignore: cast_nullable_to_non_nullable
as Set<int>,fullSource: null == fullSource ? _self.fullSource : fullSource // ignore: cast_nullable_to_non_nullable
as Set<int>,activatingVersion: freezed == activatingVersion ? _self.activatingVersion : activatingVersion // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [VersionListState].
extension VersionListStatePatterns on VersionListState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VersionListState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VersionListState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VersionListState value)  $default,){
final _that = this;
switch (_that) {
case _VersionListState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VersionListState value)?  $default,){
final _that = this;
switch (_that) {
case _VersionListState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VersionRow> versions,  String? nextCursor,  bool hasMore,  bool loadingMore,  Set<int> expanded,  Set<int> fullSource,  int? activatingVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VersionListState() when $default != null:
return $default(_that.versions,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.expanded,_that.fullSource,_that.activatingVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VersionRow> versions,  String? nextCursor,  bool hasMore,  bool loadingMore,  Set<int> expanded,  Set<int> fullSource,  int? activatingVersion)  $default,) {final _that = this;
switch (_that) {
case _VersionListState():
return $default(_that.versions,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.expanded,_that.fullSource,_that.activatingVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VersionRow> versions,  String? nextCursor,  bool hasMore,  bool loadingMore,  Set<int> expanded,  Set<int> fullSource,  int? activatingVersion)?  $default,) {final _that = this;
switch (_that) {
case _VersionListState() when $default != null:
return $default(_that.versions,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.expanded,_that.fullSource,_that.activatingVersion);case _:
  return null;

}
}

}

/// @nodoc


class _VersionListState implements VersionListState {
  const _VersionListState({final  List<VersionRow> versions = const <VersionRow>[], this.nextCursor, this.hasMore = false, this.loadingMore = false, final  Set<int> expanded = const <int>{}, final  Set<int> fullSource = const <int>{}, this.activatingVersion}): _versions = versions,_expanded = expanded,_fullSource = fullSource;
  

 final  List<VersionRow> _versions;
@override@JsonKey() List<VersionRow> get versions {
  if (_versions is EqualUnmodifiableListView) return _versions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_versions);
}

@override final  String? nextCursor;
@override@JsonKey() final  bool hasMore;
@override@JsonKey() final  bool loadingMore;
 final  Set<int> _expanded;
@override@JsonKey() Set<int> get expanded {
  if (_expanded is EqualUnmodifiableSetView) return _expanded;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_expanded);
}

 final  Set<int> _fullSource;
@override@JsonKey() Set<int> get fullSource {
  if (_fullSource is EqualUnmodifiableSetView) return _fullSource;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_fullSource);
}

@override final  int? activatingVersion;

/// Create a copy of VersionListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VersionListStateCopyWith<_VersionListState> get copyWith => __$VersionListStateCopyWithImpl<_VersionListState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VersionListState&&const DeepCollectionEquality().equals(other._versions, _versions)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&const DeepCollectionEquality().equals(other._expanded, _expanded)&&const DeepCollectionEquality().equals(other._fullSource, _fullSource)&&(identical(other.activatingVersion, activatingVersion) || other.activatingVersion == activatingVersion));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_versions),nextCursor,hasMore,loadingMore,const DeepCollectionEquality().hash(_expanded),const DeepCollectionEquality().hash(_fullSource),activatingVersion);

@override
String toString() {
  return 'VersionListState(versions: $versions, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore, expanded: $expanded, fullSource: $fullSource, activatingVersion: $activatingVersion)';
}


}

/// @nodoc
abstract mixin class _$VersionListStateCopyWith<$Res> implements $VersionListStateCopyWith<$Res> {
  factory _$VersionListStateCopyWith(_VersionListState value, $Res Function(_VersionListState) _then) = __$VersionListStateCopyWithImpl;
@override @useResult
$Res call({
 List<VersionRow> versions, String? nextCursor, bool hasMore, bool loadingMore, Set<int> expanded, Set<int> fullSource, int? activatingVersion
});




}
/// @nodoc
class __$VersionListStateCopyWithImpl<$Res>
    implements _$VersionListStateCopyWith<$Res> {
  __$VersionListStateCopyWithImpl(this._self, this._then);

  final _VersionListState _self;
  final $Res Function(_VersionListState) _then;

/// Create a copy of VersionListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? versions = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,Object? expanded = null,Object? fullSource = null,Object? activatingVersion = freezed,}) {
  return _then(_VersionListState(
versions: null == versions ? _self._versions : versions // ignore: cast_nullable_to_non_nullable
as List<VersionRow>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,expanded: null == expanded ? _self._expanded : expanded // ignore: cast_nullable_to_non_nullable
as Set<int>,fullSource: null == fullSource ? _self._fullSource : fullSource // ignore: cast_nullable_to_non_nullable
as Set<int>,activatingVersion: freezed == activatingVersion ? _self.activatingVersion : activatingVersion // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
