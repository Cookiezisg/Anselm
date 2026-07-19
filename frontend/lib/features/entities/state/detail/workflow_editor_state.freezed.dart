// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workflow_editor_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WorkflowEditorState {

 Graph get original; Graph get working; GraphDirection get dir; String? get selectedNodeId; String? get selectedEdgeId; bool get saving; String? get saveError;
/// Create a copy of WorkflowEditorState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkflowEditorStateCopyWith<WorkflowEditorState> get copyWith => _$WorkflowEditorStateCopyWithImpl<WorkflowEditorState>(this as WorkflowEditorState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkflowEditorState&&(identical(other.original, original) || other.original == original)&&(identical(other.working, working) || other.working == working)&&(identical(other.dir, dir) || other.dir == dir)&&(identical(other.selectedNodeId, selectedNodeId) || other.selectedNodeId == selectedNodeId)&&(identical(other.selectedEdgeId, selectedEdgeId) || other.selectedEdgeId == selectedEdgeId)&&(identical(other.saving, saving) || other.saving == saving)&&(identical(other.saveError, saveError) || other.saveError == saveError));
}


@override
int get hashCode => Object.hash(runtimeType,original,working,dir,selectedNodeId,selectedEdgeId,saving,saveError);

@override
String toString() {
  return 'WorkflowEditorState(original: $original, working: $working, dir: $dir, selectedNodeId: $selectedNodeId, selectedEdgeId: $selectedEdgeId, saving: $saving, saveError: $saveError)';
}


}

/// @nodoc
abstract mixin class $WorkflowEditorStateCopyWith<$Res>  {
  factory $WorkflowEditorStateCopyWith(WorkflowEditorState value, $Res Function(WorkflowEditorState) _then) = _$WorkflowEditorStateCopyWithImpl;
@useResult
$Res call({
 Graph original, Graph working, GraphDirection dir, String? selectedNodeId, String? selectedEdgeId, bool saving, String? saveError
});


$GraphCopyWith<$Res> get original;$GraphCopyWith<$Res> get working;

}
/// @nodoc
class _$WorkflowEditorStateCopyWithImpl<$Res>
    implements $WorkflowEditorStateCopyWith<$Res> {
  _$WorkflowEditorStateCopyWithImpl(this._self, this._then);

  final WorkflowEditorState _self;
  final $Res Function(WorkflowEditorState) _then;

/// Create a copy of WorkflowEditorState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? original = null,Object? working = null,Object? dir = null,Object? selectedNodeId = freezed,Object? selectedEdgeId = freezed,Object? saving = null,Object? saveError = freezed,}) {
  return _then(_self.copyWith(
original: null == original ? _self.original : original // ignore: cast_nullable_to_non_nullable
as Graph,working: null == working ? _self.working : working // ignore: cast_nullable_to_non_nullable
as Graph,dir: null == dir ? _self.dir : dir // ignore: cast_nullable_to_non_nullable
as GraphDirection,selectedNodeId: freezed == selectedNodeId ? _self.selectedNodeId : selectedNodeId // ignore: cast_nullable_to_non_nullable
as String?,selectedEdgeId: freezed == selectedEdgeId ? _self.selectedEdgeId : selectedEdgeId // ignore: cast_nullable_to_non_nullable
as String?,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,saveError: freezed == saveError ? _self.saveError : saveError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of WorkflowEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GraphCopyWith<$Res> get original {
  
  return $GraphCopyWith<$Res>(_self.original, (value) {
    return _then(_self.copyWith(original: value));
  });
}/// Create a copy of WorkflowEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GraphCopyWith<$Res> get working {
  
  return $GraphCopyWith<$Res>(_self.working, (value) {
    return _then(_self.copyWith(working: value));
  });
}
}


/// Adds pattern-matching-related methods to [WorkflowEditorState].
extension WorkflowEditorStatePatterns on WorkflowEditorState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkflowEditorState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkflowEditorState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkflowEditorState value)  $default,){
final _that = this;
switch (_that) {
case _WorkflowEditorState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkflowEditorState value)?  $default,){
final _that = this;
switch (_that) {
case _WorkflowEditorState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Graph original,  Graph working,  GraphDirection dir,  String? selectedNodeId,  String? selectedEdgeId,  bool saving,  String? saveError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkflowEditorState() when $default != null:
return $default(_that.original,_that.working,_that.dir,_that.selectedNodeId,_that.selectedEdgeId,_that.saving,_that.saveError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Graph original,  Graph working,  GraphDirection dir,  String? selectedNodeId,  String? selectedEdgeId,  bool saving,  String? saveError)  $default,) {final _that = this;
switch (_that) {
case _WorkflowEditorState():
return $default(_that.original,_that.working,_that.dir,_that.selectedNodeId,_that.selectedEdgeId,_that.saving,_that.saveError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Graph original,  Graph working,  GraphDirection dir,  String? selectedNodeId,  String? selectedEdgeId,  bool saving,  String? saveError)?  $default,) {final _that = this;
switch (_that) {
case _WorkflowEditorState() when $default != null:
return $default(_that.original,_that.working,_that.dir,_that.selectedNodeId,_that.selectedEdgeId,_that.saving,_that.saveError);case _:
  return null;

}
}

}

/// @nodoc


class _WorkflowEditorState extends WorkflowEditorState {
  const _WorkflowEditorState({required this.original, required this.working, this.dir = GraphDirection.lr, this.selectedNodeId, this.selectedEdgeId, this.saving = false, this.saveError}): super._();
  

@override final  Graph original;
@override final  Graph working;
@override@JsonKey() final  GraphDirection dir;
@override final  String? selectedNodeId;
@override final  String? selectedEdgeId;
@override@JsonKey() final  bool saving;
@override final  String? saveError;

/// Create a copy of WorkflowEditorState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkflowEditorStateCopyWith<_WorkflowEditorState> get copyWith => __$WorkflowEditorStateCopyWithImpl<_WorkflowEditorState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkflowEditorState&&(identical(other.original, original) || other.original == original)&&(identical(other.working, working) || other.working == working)&&(identical(other.dir, dir) || other.dir == dir)&&(identical(other.selectedNodeId, selectedNodeId) || other.selectedNodeId == selectedNodeId)&&(identical(other.selectedEdgeId, selectedEdgeId) || other.selectedEdgeId == selectedEdgeId)&&(identical(other.saving, saving) || other.saving == saving)&&(identical(other.saveError, saveError) || other.saveError == saveError));
}


@override
int get hashCode => Object.hash(runtimeType,original,working,dir,selectedNodeId,selectedEdgeId,saving,saveError);

@override
String toString() {
  return 'WorkflowEditorState(original: $original, working: $working, dir: $dir, selectedNodeId: $selectedNodeId, selectedEdgeId: $selectedEdgeId, saving: $saving, saveError: $saveError)';
}


}

/// @nodoc
abstract mixin class _$WorkflowEditorStateCopyWith<$Res> implements $WorkflowEditorStateCopyWith<$Res> {
  factory _$WorkflowEditorStateCopyWith(_WorkflowEditorState value, $Res Function(_WorkflowEditorState) _then) = __$WorkflowEditorStateCopyWithImpl;
@override @useResult
$Res call({
 Graph original, Graph working, GraphDirection dir, String? selectedNodeId, String? selectedEdgeId, bool saving, String? saveError
});


@override $GraphCopyWith<$Res> get original;@override $GraphCopyWith<$Res> get working;

}
/// @nodoc
class __$WorkflowEditorStateCopyWithImpl<$Res>
    implements _$WorkflowEditorStateCopyWith<$Res> {
  __$WorkflowEditorStateCopyWithImpl(this._self, this._then);

  final _WorkflowEditorState _self;
  final $Res Function(_WorkflowEditorState) _then;

/// Create a copy of WorkflowEditorState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? original = null,Object? working = null,Object? dir = null,Object? selectedNodeId = freezed,Object? selectedEdgeId = freezed,Object? saving = null,Object? saveError = freezed,}) {
  return _then(_WorkflowEditorState(
original: null == original ? _self.original : original // ignore: cast_nullable_to_non_nullable
as Graph,working: null == working ? _self.working : working // ignore: cast_nullable_to_non_nullable
as Graph,dir: null == dir ? _self.dir : dir // ignore: cast_nullable_to_non_nullable
as GraphDirection,selectedNodeId: freezed == selectedNodeId ? _self.selectedNodeId : selectedNodeId // ignore: cast_nullable_to_non_nullable
as String?,selectedEdgeId: freezed == selectedEdgeId ? _self.selectedEdgeId : selectedEdgeId // ignore: cast_nullable_to_non_nullable
as String?,saving: null == saving ? _self.saving : saving // ignore: cast_nullable_to_non_nullable
as bool,saveError: freezed == saveError ? _self.saveError : saveError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of WorkflowEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GraphCopyWith<$Res> get original {
  
  return $GraphCopyWith<$Res>(_self.original, (value) {
    return _then(_self.copyWith(original: value));
  });
}/// Create a copy of WorkflowEditorState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GraphCopyWith<$Res> get working {
  
  return $GraphCopyWith<$Res>(_self.working, (value) {
    return _then(_self.copyWith(working: value));
  });
}
}

// dart format on
