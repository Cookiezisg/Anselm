// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConvAxis {

 List<Conversation> get rows; String? get nextCursor; bool get hasMore; int? get total; bool get loadingMore; bool get loadFailed;/// Whether this axis has EVER resolved a page. A group axis starts unloaded with `hasMore: true` so the
/// rail renders its tail sentinel and fetches page one only when the section is actually expanded and
/// scrolled into view — lazy by construction, not by a special "fetch on expand" callback.
///
/// 本轴是否**曾**解出过一页。组轴以「未加载 + hasMore: true」起步,使 rail 渲出它的尾哨兵、并**仅在**该段真被
/// 展开且滚进视野时才取第一页——惰性是**构造出来的**、不靠一个特设的「展开时取数」回调。
 bool get loaded;
/// Create a copy of ConvAxis
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConvAxisCopyWith<ConvAxis> get copyWith => _$ConvAxisCopyWithImpl<ConvAxis>(this as ConvAxis, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConvAxis&&const DeepCollectionEquality().equals(other.rows, rows)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.total, total) || other.total == total)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.loadFailed, loadFailed) || other.loadFailed == loadFailed)&&(identical(other.loaded, loaded) || other.loaded == loaded));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(rows),nextCursor,hasMore,total,loadingMore,loadFailed,loaded);

@override
String toString() {
  return 'ConvAxis(rows: $rows, nextCursor: $nextCursor, hasMore: $hasMore, total: $total, loadingMore: $loadingMore, loadFailed: $loadFailed, loaded: $loaded)';
}


}

/// @nodoc
abstract mixin class $ConvAxisCopyWith<$Res>  {
  factory $ConvAxisCopyWith(ConvAxis value, $Res Function(ConvAxis) _then) = _$ConvAxisCopyWithImpl;
@useResult
$Res call({
 List<Conversation> rows, String? nextCursor, bool hasMore, int? total, bool loadingMore, bool loadFailed, bool loaded
});




}
/// @nodoc
class _$ConvAxisCopyWithImpl<$Res>
    implements $ConvAxisCopyWith<$Res> {
  _$ConvAxisCopyWithImpl(this._self, this._then);

  final ConvAxis _self;
  final $Res Function(ConvAxis) _then;

/// Create a copy of ConvAxis
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rows = null,Object? nextCursor = freezed,Object? hasMore = null,Object? total = freezed,Object? loadingMore = null,Object? loadFailed = null,Object? loaded = null,}) {
  return _then(_self.copyWith(
rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as List<Conversation>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,total: freezed == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int?,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,loadFailed: null == loadFailed ? _self.loadFailed : loadFailed // ignore: cast_nullable_to_non_nullable
as bool,loaded: null == loaded ? _self.loaded : loaded // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ConvAxis].
extension ConvAxisPatterns on ConvAxis {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConvAxis value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConvAxis() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConvAxis value)  $default,){
final _that = this;
switch (_that) {
case _ConvAxis():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConvAxis value)?  $default,){
final _that = this;
switch (_that) {
case _ConvAxis() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Conversation> rows,  String? nextCursor,  bool hasMore,  int? total,  bool loadingMore,  bool loadFailed,  bool loaded)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConvAxis() when $default != null:
return $default(_that.rows,_that.nextCursor,_that.hasMore,_that.total,_that.loadingMore,_that.loadFailed,_that.loaded);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Conversation> rows,  String? nextCursor,  bool hasMore,  int? total,  bool loadingMore,  bool loadFailed,  bool loaded)  $default,) {final _that = this;
switch (_that) {
case _ConvAxis():
return $default(_that.rows,_that.nextCursor,_that.hasMore,_that.total,_that.loadingMore,_that.loadFailed,_that.loaded);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Conversation> rows,  String? nextCursor,  bool hasMore,  int? total,  bool loadingMore,  bool loadFailed,  bool loaded)?  $default,) {final _that = this;
switch (_that) {
case _ConvAxis() when $default != null:
return $default(_that.rows,_that.nextCursor,_that.hasMore,_that.total,_that.loadingMore,_that.loadFailed,_that.loaded);case _:
  return null;

}
}

}

/// @nodoc


class _ConvAxis implements ConvAxis {
  const _ConvAxis({final  List<Conversation> rows = const <Conversation>[], this.nextCursor, this.hasMore = false, this.total, this.loadingMore = false, this.loadFailed = false, this.loaded = false}): _rows = rows;
  

 final  List<Conversation> _rows;
@override@JsonKey() List<Conversation> get rows {
  if (_rows is EqualUnmodifiableListView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rows);
}

@override final  String? nextCursor;
@override@JsonKey() final  bool hasMore;
@override final  int? total;
@override@JsonKey() final  bool loadingMore;
@override@JsonKey() final  bool loadFailed;
/// Whether this axis has EVER resolved a page. A group axis starts unloaded with `hasMore: true` so the
/// rail renders its tail sentinel and fetches page one only when the section is actually expanded and
/// scrolled into view — lazy by construction, not by a special "fetch on expand" callback.
///
/// 本轴是否**曾**解出过一页。组轴以「未加载 + hasMore: true」起步,使 rail 渲出它的尾哨兵、并**仅在**该段真被
/// 展开且滚进视野时才取第一页——惰性是**构造出来的**、不靠一个特设的「展开时取数」回调。
@override@JsonKey() final  bool loaded;

/// Create a copy of ConvAxis
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConvAxisCopyWith<_ConvAxis> get copyWith => __$ConvAxisCopyWithImpl<_ConvAxis>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConvAxis&&const DeepCollectionEquality().equals(other._rows, _rows)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.total, total) || other.total == total)&&(identical(other.loadingMore, loadingMore) || other.loadingMore == loadingMore)&&(identical(other.loadFailed, loadFailed) || other.loadFailed == loadFailed)&&(identical(other.loaded, loaded) || other.loaded == loaded));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_rows),nextCursor,hasMore,total,loadingMore,loadFailed,loaded);

@override
String toString() {
  return 'ConvAxis(rows: $rows, nextCursor: $nextCursor, hasMore: $hasMore, total: $total, loadingMore: $loadingMore, loadFailed: $loadFailed, loaded: $loaded)';
}


}

/// @nodoc
abstract mixin class _$ConvAxisCopyWith<$Res> implements $ConvAxisCopyWith<$Res> {
  factory _$ConvAxisCopyWith(_ConvAxis value, $Res Function(_ConvAxis) _then) = __$ConvAxisCopyWithImpl;
@override @useResult
$Res call({
 List<Conversation> rows, String? nextCursor, bool hasMore, int? total, bool loadingMore, bool loadFailed, bool loaded
});




}
/// @nodoc
class __$ConvAxisCopyWithImpl<$Res>
    implements _$ConvAxisCopyWith<$Res> {
  __$ConvAxisCopyWithImpl(this._self, this._then);

  final _ConvAxis _self;
  final $Res Function(_ConvAxis) _then;

/// Create a copy of ConvAxis
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rows = null,Object? nextCursor = freezed,Object? hasMore = null,Object? total = freezed,Object? loadingMore = null,Object? loadFailed = null,Object? loaded = null,}) {
  return _then(_ConvAxis(
rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as List<Conversation>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,total: freezed == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int?,loadingMore: null == loadingMore ? _self.loadingMore : loadingMore // ignore: cast_nullable_to_non_nullable
as bool,loadFailed: null == loadFailed ? _self.loadFailed : loadFailed // ignore: cast_nullable_to_non_nullable
as bool,loaded: null == loaded ? _self.loaded : loaded // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ConversationListState {

 ConvAxis get recents; ConvAxis get pinned; List<WorkDirGroup> get groups; Map<String, ConvAxis> get groupAxes;/// A query is active, so this state is NOT the four-section rail: it is ONE flat result list over the
/// whole workspace, carried by [recents], with no pinned section and no groups.
///
/// Searching REPLACES the structure rather than filtering it, because a folded folder fetches nothing —
/// a rail that merely narrowed each section would answer "no matches" for every thread the user had not
/// already scrolled into view. And it is the honest reading of the question: which CONVERSATIONS match,
/// not which folders do.
///
/// 有查询词,故本态**不是**四段 rail:它是对整个 workspace 的**一条平结果列表**、由 [recents] 承载,无置顶段、
/// 无组。
///
/// 搜索是**替换**结构、不是过滤结构,因为收起的文件夹什么都不取——一个只是把各段收窄的 rail 会对每一条用户
/// 尚未滚进视野的线程答「没有匹配」。而这也是这个问题的诚实读法:哪些**对话**匹配、不是哪些文件夹匹配。
 bool get searching;
/// Create a copy of ConversationListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationListStateCopyWith<ConversationListState> get copyWith => _$ConversationListStateCopyWithImpl<ConversationListState>(this as ConversationListState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationListState&&(identical(other.recents, recents) || other.recents == recents)&&(identical(other.pinned, pinned) || other.pinned == pinned)&&const DeepCollectionEquality().equals(other.groups, groups)&&const DeepCollectionEquality().equals(other.groupAxes, groupAxes)&&(identical(other.searching, searching) || other.searching == searching));
}


@override
int get hashCode => Object.hash(runtimeType,recents,pinned,const DeepCollectionEquality().hash(groups),const DeepCollectionEquality().hash(groupAxes),searching);

@override
String toString() {
  return 'ConversationListState(recents: $recents, pinned: $pinned, groups: $groups, groupAxes: $groupAxes, searching: $searching)';
}


}

/// @nodoc
abstract mixin class $ConversationListStateCopyWith<$Res>  {
  factory $ConversationListStateCopyWith(ConversationListState value, $Res Function(ConversationListState) _then) = _$ConversationListStateCopyWithImpl;
@useResult
$Res call({
 ConvAxis recents, ConvAxis pinned, List<WorkDirGroup> groups, Map<String, ConvAxis> groupAxes, bool searching
});


$ConvAxisCopyWith<$Res> get recents;$ConvAxisCopyWith<$Res> get pinned;

}
/// @nodoc
class _$ConversationListStateCopyWithImpl<$Res>
    implements $ConversationListStateCopyWith<$Res> {
  _$ConversationListStateCopyWithImpl(this._self, this._then);

  final ConversationListState _self;
  final $Res Function(ConversationListState) _then;

/// Create a copy of ConversationListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? recents = null,Object? pinned = null,Object? groups = null,Object? groupAxes = null,Object? searching = null,}) {
  return _then(_self.copyWith(
recents: null == recents ? _self.recents : recents // ignore: cast_nullable_to_non_nullable
as ConvAxis,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as ConvAxis,groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<WorkDirGroup>,groupAxes: null == groupAxes ? _self.groupAxes : groupAxes // ignore: cast_nullable_to_non_nullable
as Map<String, ConvAxis>,searching: null == searching ? _self.searching : searching // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ConversationListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConvAxisCopyWith<$Res> get recents {
  
  return $ConvAxisCopyWith<$Res>(_self.recents, (value) {
    return _then(_self.copyWith(recents: value));
  });
}/// Create a copy of ConversationListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConvAxisCopyWith<$Res> get pinned {
  
  return $ConvAxisCopyWith<$Res>(_self.pinned, (value) {
    return _then(_self.copyWith(pinned: value));
  });
}
}


/// Adds pattern-matching-related methods to [ConversationListState].
extension ConversationListStatePatterns on ConversationListState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConversationListState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConversationListState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConversationListState value)  $default,){
final _that = this;
switch (_that) {
case _ConversationListState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConversationListState value)?  $default,){
final _that = this;
switch (_that) {
case _ConversationListState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ConvAxis recents,  ConvAxis pinned,  List<WorkDirGroup> groups,  Map<String, ConvAxis> groupAxes,  bool searching)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConversationListState() when $default != null:
return $default(_that.recents,_that.pinned,_that.groups,_that.groupAxes,_that.searching);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ConvAxis recents,  ConvAxis pinned,  List<WorkDirGroup> groups,  Map<String, ConvAxis> groupAxes,  bool searching)  $default,) {final _that = this;
switch (_that) {
case _ConversationListState():
return $default(_that.recents,_that.pinned,_that.groups,_that.groupAxes,_that.searching);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ConvAxis recents,  ConvAxis pinned,  List<WorkDirGroup> groups,  Map<String, ConvAxis> groupAxes,  bool searching)?  $default,) {final _that = this;
switch (_that) {
case _ConversationListState() when $default != null:
return $default(_that.recents,_that.pinned,_that.groups,_that.groupAxes,_that.searching);case _:
  return null;

}
}

}

/// @nodoc


class _ConversationListState extends ConversationListState {
  const _ConversationListState({this.recents = const ConvAxis(), this.pinned = const ConvAxis(), final  List<WorkDirGroup> groups = const <WorkDirGroup>[], final  Map<String, ConvAxis> groupAxes = const <String, ConvAxis>{}, this.searching = false}): _groups = groups,_groupAxes = groupAxes,super._();
  

@override@JsonKey() final  ConvAxis recents;
@override@JsonKey() final  ConvAxis pinned;
 final  List<WorkDirGroup> _groups;
@override@JsonKey() List<WorkDirGroup> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}

 final  Map<String, ConvAxis> _groupAxes;
@override@JsonKey() Map<String, ConvAxis> get groupAxes {
  if (_groupAxes is EqualUnmodifiableMapView) return _groupAxes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_groupAxes);
}

/// A query is active, so this state is NOT the four-section rail: it is ONE flat result list over the
/// whole workspace, carried by [recents], with no pinned section and no groups.
///
/// Searching REPLACES the structure rather than filtering it, because a folded folder fetches nothing —
/// a rail that merely narrowed each section would answer "no matches" for every thread the user had not
/// already scrolled into view. And it is the honest reading of the question: which CONVERSATIONS match,
/// not which folders do.
///
/// 有查询词,故本态**不是**四段 rail:它是对整个 workspace 的**一条平结果列表**、由 [recents] 承载,无置顶段、
/// 无组。
///
/// 搜索是**替换**结构、不是过滤结构,因为收起的文件夹什么都不取——一个只是把各段收窄的 rail 会对每一条用户
/// 尚未滚进视野的线程答「没有匹配」。而这也是这个问题的诚实读法:哪些**对话**匹配、不是哪些文件夹匹配。
@override@JsonKey() final  bool searching;

/// Create a copy of ConversationListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationListStateCopyWith<_ConversationListState> get copyWith => __$ConversationListStateCopyWithImpl<_ConversationListState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConversationListState&&(identical(other.recents, recents) || other.recents == recents)&&(identical(other.pinned, pinned) || other.pinned == pinned)&&const DeepCollectionEquality().equals(other._groups, _groups)&&const DeepCollectionEquality().equals(other._groupAxes, _groupAxes)&&(identical(other.searching, searching) || other.searching == searching));
}


@override
int get hashCode => Object.hash(runtimeType,recents,pinned,const DeepCollectionEquality().hash(_groups),const DeepCollectionEquality().hash(_groupAxes),searching);

@override
String toString() {
  return 'ConversationListState(recents: $recents, pinned: $pinned, groups: $groups, groupAxes: $groupAxes, searching: $searching)';
}


}

/// @nodoc
abstract mixin class _$ConversationListStateCopyWith<$Res> implements $ConversationListStateCopyWith<$Res> {
  factory _$ConversationListStateCopyWith(_ConversationListState value, $Res Function(_ConversationListState) _then) = __$ConversationListStateCopyWithImpl;
@override @useResult
$Res call({
 ConvAxis recents, ConvAxis pinned, List<WorkDirGroup> groups, Map<String, ConvAxis> groupAxes, bool searching
});


@override $ConvAxisCopyWith<$Res> get recents;@override $ConvAxisCopyWith<$Res> get pinned;

}
/// @nodoc
class __$ConversationListStateCopyWithImpl<$Res>
    implements _$ConversationListStateCopyWith<$Res> {
  __$ConversationListStateCopyWithImpl(this._self, this._then);

  final _ConversationListState _self;
  final $Res Function(_ConversationListState) _then;

/// Create a copy of ConversationListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? recents = null,Object? pinned = null,Object? groups = null,Object? groupAxes = null,Object? searching = null,}) {
  return _then(_ConversationListState(
recents: null == recents ? _self.recents : recents // ignore: cast_nullable_to_non_nullable
as ConvAxis,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as ConvAxis,groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<WorkDirGroup>,groupAxes: null == groupAxes ? _self._groupAxes : groupAxes // ignore: cast_nullable_to_non_nullable
as Map<String, ConvAxis>,searching: null == searching ? _self.searching : searching // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ConversationListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConvAxisCopyWith<$Res> get recents {
  
  return $ConvAxisCopyWith<$Res>(_self.recents, (value) {
    return _then(_self.copyWith(recents: value));
  });
}/// Create a copy of ConversationListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ConvAxisCopyWith<$Res> get pinned {
  
  return $ConvAxisCopyWith<$Res>(_self.pinned, (value) {
    return _then(_self.copyWith(pinned: value));
  });
}
}

// dart format on
