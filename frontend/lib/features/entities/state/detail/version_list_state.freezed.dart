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
mixin _$VersionListState {

 List<VersionRow> get versions; String? get nextCursor; bool get hasMore; bool get loadingMore; int get selectedIndex;
/// Create a copy of VersionListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VersionListStateCopyWith<VersionListState> get copyWith => _$VersionListStateCopyWithImpl<VersionListState>(this as VersionListState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VersionListState&&const DeepCollectionEquality().equals(other.versions, versions)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.selectedIndex, selectedIndex) || other.selectedIndex == selectedIndex));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(versions),nextCursor,hasMore,loadingMore,selectedIndex);

@override
String toString() {
  return 'VersionListState(versions: $versions, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore, selectedIndex: $selectedIndex)';
}


}

/// @nodoc
abstract mixin class $VersionListStateCopyWith<$Res>  {
  factory $VersionListStateCopyWith(VersionListState value, $Res Function(VersionListState) _then) = _$VersionListStateCopyWithImpl;
@useResult
$Res call({
 List<VersionRow> versions, String? nextCursor, bool hasMore, bool loadingMore, int selectedIndex
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
@pragma('vm:prefer-inline') @override $Res call({Object? versions = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,Object? selectedIndex = null,}) {
  return _then(_self.copyWith(
versions: null == versions ? _self.versions : versions // ignore: cast_nullable_to_non_nullable
as List<VersionRow>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,selectedIndex: null == selectedIndex ? _self.selectedIndex : selectedIndex // ignore: cast_nullable_to_non_nullable
as int,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VersionRow> versions,  String? nextCursor,  bool hasMore,  bool loadingMore,  int selectedIndex)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VersionListState() when $default != null:
return $default(_that.versions,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.selectedIndex);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VersionRow> versions,  String? nextCursor,  bool hasMore,  bool loadingMore,  int selectedIndex)  $default,) {final _that = this;
switch (_that) {
case _VersionListState():
return $default(_that.versions,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.selectedIndex);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VersionRow> versions,  String? nextCursor,  bool hasMore,  bool loadingMore,  int selectedIndex)?  $default,) {final _that = this;
switch (_that) {
case _VersionListState() when $default != null:
return $default(_that.versions,_that.nextCursor,_that.hasMore,_that.loadingMore,_that.selectedIndex);case _:
  return null;

}
}

}

/// @nodoc


class _VersionListState implements VersionListState {
  const _VersionListState({final  List<VersionRow> versions = const <VersionRow>[], this.nextCursor, this.hasMore = false, this.loadingMore = false, this.selectedIndex = 0}): _versions = versions;
  

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

/// Create a copy of VersionListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VersionListStateCopyWith<_VersionListState> get copyWith => __$VersionListStateCopyWithImpl<_VersionListState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VersionListState&&const DeepCollectionEquality().equals(other._versions, _versions)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.selectedIndex, selectedIndex) || other.selectedIndex == selectedIndex));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_versions),nextCursor,hasMore,loadingMore,selectedIndex);

@override
String toString() {
  return 'VersionListState(versions: $versions, nextCursor: $nextCursor, hasMore: $hasMore, loadingMore: $loadingMore, selectedIndex: $selectedIndex)';
}


}

/// @nodoc
abstract mixin class _$VersionListStateCopyWith<$Res> implements $VersionListStateCopyWith<$Res> {
  factory _$VersionListStateCopyWith(_VersionListState value, $Res Function(_VersionListState) _then) = __$VersionListStateCopyWithImpl;
@override @useResult
$Res call({
 List<VersionRow> versions, String? nextCursor, bool hasMore, bool loadingMore, int selectedIndex
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
@override @pragma('vm:prefer-inline') $Res call({Object? versions = null,Object? nextCursor = freezed,Object? hasMore = null,Object? loadingMore = null,Object? selectedIndex = null,}) {
  return _then(_VersionListState(
versions: null == versions ? _self._versions : versions // ignore: cast_nullable_to_non_nullable
as List<VersionRow>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,selectedIndex: null == selectedIndex ? _self.selectedIndex : selectedIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
