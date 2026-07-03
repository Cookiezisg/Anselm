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

 int get version; bool get active; DateTime get createdAt; String get src; String get lang; String? get changeReason; List<String> get summary;
/// Create a copy of VersionRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VersionRowCopyWith<VersionRow> get copyWith => _$VersionRowCopyWithImpl<VersionRow>(this as VersionRow, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VersionRow&&(identical(other.version, version) || other.version == version)&&(identical(other.active, active) || other.active == active)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.src, src) || other.src == src)&&(identical(other.lang, lang) || other.lang == lang)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&const DeepCollectionEquality().equals(other.summary, summary));
}


@override
int get hashCode => Object.hash(runtimeType,version,active,createdAt,src,lang,changeReason,const DeepCollectionEquality().hash(summary));

@override
String toString() {
  return 'VersionRow(version: $version, active: $active, createdAt: $createdAt, src: $src, lang: $lang, changeReason: $changeReason, summary: $summary)';
}


}

/// @nodoc
abstract mixin class $VersionRowCopyWith<$Res>  {
  factory $VersionRowCopyWith(VersionRow value, $Res Function(VersionRow) _then) = _$VersionRowCopyWithImpl;
@useResult
$Res call({
 int version, bool active, DateTime createdAt, String src, String lang, String? changeReason, List<String> summary
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
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? active = null,Object? createdAt = null,Object? src = null,Object? lang = null,Object? changeReason = freezed,Object? summary = null,}) {
  return _then(_self.copyWith(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,src: null == src ? _self.src : src // ignore: cast_nullable_to_non_nullable
as String,lang: null == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String,changeReason: freezed == changeReason ? _self.changeReason : changeReason // ignore: cast_nullable_to_non_nullable
as String?,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as List<String>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int version,  bool active,  DateTime createdAt,  String src,  String lang,  String? changeReason,  List<String> summary)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VersionRow() when $default != null:
return $default(_that.version,_that.active,_that.createdAt,_that.src,_that.lang,_that.changeReason,_that.summary);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int version,  bool active,  DateTime createdAt,  String src,  String lang,  String? changeReason,  List<String> summary)  $default,) {final _that = this;
switch (_that) {
case _VersionRow():
return $default(_that.version,_that.active,_that.createdAt,_that.src,_that.lang,_that.changeReason,_that.summary);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int version,  bool active,  DateTime createdAt,  String src,  String lang,  String? changeReason,  List<String> summary)?  $default,) {final _that = this;
switch (_that) {
case _VersionRow() when $default != null:
return $default(_that.version,_that.active,_that.createdAt,_that.src,_that.lang,_that.changeReason,_that.summary);case _:
  return null;

}
}

}

/// @nodoc


class _VersionRow implements VersionRow {
  const _VersionRow({required this.version, required this.active, required this.createdAt, required this.src, required this.lang, this.changeReason, final  List<String> summary = const <String>[]}): _summary = summary;
  

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


/// Create a copy of VersionRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VersionRowCopyWith<_VersionRow> get copyWith => __$VersionRowCopyWithImpl<_VersionRow>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VersionRow&&(identical(other.version, version) || other.version == version)&&(identical(other.active, active) || other.active == active)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.src, src) || other.src == src)&&(identical(other.lang, lang) || other.lang == lang)&&(identical(other.changeReason, changeReason) || other.changeReason == changeReason)&&const DeepCollectionEquality().equals(other._summary, _summary));
}


@override
int get hashCode => Object.hash(runtimeType,version,active,createdAt,src,lang,changeReason,const DeepCollectionEquality().hash(_summary));

@override
String toString() {
  return 'VersionRow(version: $version, active: $active, createdAt: $createdAt, src: $src, lang: $lang, changeReason: $changeReason, summary: $summary)';
}


}

/// @nodoc
abstract mixin class _$VersionRowCopyWith<$Res> implements $VersionRowCopyWith<$Res> {
  factory _$VersionRowCopyWith(_VersionRow value, $Res Function(_VersionRow) _then) = __$VersionRowCopyWithImpl;
@override @useResult
$Res call({
 int version, bool active, DateTime createdAt, String src, String lang, String? changeReason, List<String> summary
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
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? active = null,Object? createdAt = null,Object? src = null,Object? lang = null,Object? changeReason = freezed,Object? summary = null,}) {
  return _then(_VersionRow(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,src: null == src ? _self.src : src // ignore: cast_nullable_to_non_nullable
as String,lang: null == lang ? _self.lang : lang // ignore: cast_nullable_to_non_nullable
as String,changeReason: freezed == changeReason ? _self.changeReason : changeReason // ignore: cast_nullable_to_non_nullable
as String?,summary: null == summary ? _self._summary : summary // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$VersionListState {

 List<VersionRow> get versions; String? get nextCursor; bool get hasMore; bool get loadingMore; int get selectedIndex; int? get activatingVersion;
/// Create a copy of VersionListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VersionListStateCopyWith<VersionListState> get copyWith => _$VersionListStateCopyWithImpl<VersionListState>(this as VersionListState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VersionListState&&const DeepCollectionEquality().equals(other.versions, versions)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.selectedIndex, selectedIndex) || other.selectedIndex == selectedIndex)&&(identical(other.activatingVersion, activatingVersion) || other.activatingVersion == activatingVersion));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(versions),nextCursor,hasMore,loadingMore,selectedIndex,activatingVersion);

@override
String toString() {
  return 'VersionListState(versions: $versions, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore, selectedIndex: $selectedIndex, activatingVersion: $activatingVersion)';
}


}

/// @nodoc
abstract mixin class $VersionListStateCopyWith<$Res>  {
  factory $VersionListStateCopyWith(VersionListState value, $Res Function(VersionListState) _then) = _$VersionListStateCopyWithImpl;
@useResult
$Res call({
 List<VersionRow> versions, String? nextCursor, bool hasMore, bool loadingMore, int selectedIndex, int? activatingVersion
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
@pragma('vm:prefer-inline') @override $Res call({Object? versions = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,Object? selectedIndex = null,Object? activatingVersion = freezed,}) {
  return _then(_self.copyWith(
versions: null == versions ? _self.versions : versions // ignore: cast_nullable_to_non_nullable
as List<VersionRow>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,selectedIndex: null == selectedIndex ? _self.selectedIndex : selectedIndex // ignore: cast_nullable_to_non_nullable
as int,activatingVersion: freezed == activatingVersion ? _self.activatingVersion : activatingVersion // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VersionRow> versions,  String? nextCursor,  bool hasMore,  bool loadingMore,  int selectedIndex,  int? activatingVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VersionListState() when $default != null:
return $default(_that.versions,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.selectedIndex,_that.activatingVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VersionRow> versions,  String? nextCursor,  bool hasMore,  bool loadingMore,  int selectedIndex,  int? activatingVersion)  $default,) {final _that = this;
switch (_that) {
case _VersionListState():
return $default(_that.versions,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.selectedIndex,_that.activatingVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VersionRow> versions,  String? nextCursor,  bool hasMore,  bool loadingMore,  int selectedIndex,  int? activatingVersion)?  $default,) {final _that = this;
switch (_that) {
case _VersionListState() when $default != null:
return $default(_that.versions,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.selectedIndex,_that.activatingVersion);case _:
  return null;

}
}

}

/// @nodoc


class _VersionListState implements VersionListState {
  const _VersionListState({final  List<VersionRow> versions = const <VersionRow>[], this.nextCursor, this.hasMore = false, this.loadingMore = false, this.selectedIndex = 0, this.activatingVersion}): _versions = versions;
  

 final  List<VersionRow> _versions;
@override@JsonKey() List<VersionRow> get versions {
  if (_versions is EqualUnmodifiableListView) return _versions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_versions);
}

@override final  String? nextCursor;
@override@JsonKey() final  bool hasMore;
@override@JsonKey() final  bool loadingMore;
@override@JsonKey() final  int selectedIndex;
@override final  int? activatingVersion;

/// Create a copy of VersionListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VersionListStateCopyWith<_VersionListState> get copyWith => __$VersionListStateCopyWithImpl<_VersionListState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VersionListState&&const DeepCollectionEquality().equals(other._versions, _versions)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.selectedIndex, selectedIndex) || other.selectedIndex == selectedIndex)&&(identical(other.activatingVersion, activatingVersion) || other.activatingVersion == activatingVersion));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_versions),nextCursor,hasMore,loadingMore,selectedIndex,activatingVersion);

@override
String toString() {
  return 'VersionListState(versions: $versions, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore, selectedIndex: $selectedIndex, activatingVersion: $activatingVersion)';
}


}

/// @nodoc
abstract mixin class _$VersionListStateCopyWith<$Res> implements $VersionListStateCopyWith<$Res> {
  factory _$VersionListStateCopyWith(_VersionListState value, $Res Function(_VersionListState) _then) = __$VersionListStateCopyWithImpl;
@override @useResult
$Res call({
 List<VersionRow> versions, String? nextCursor, bool hasMore, bool loadingMore, int selectedIndex, int? activatingVersion
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
@override @pragma('vm:prefer-inline') $Res call({Object? versions = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,Object? selectedIndex = null,Object? activatingVersion = freezed,}) {
  return _then(_VersionListState(
versions: null == versions ? _self._versions : versions // ignore: cast_nullable_to_non_nullable
as List<VersionRow>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,selectedIndex: null == selectedIndex ? _self.selectedIndex : selectedIndex // ignore: cast_nullable_to_non_nullable
as int,activatingVersion: freezed == activatingVersion ? _self.activatingVersion : activatingVersion // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
