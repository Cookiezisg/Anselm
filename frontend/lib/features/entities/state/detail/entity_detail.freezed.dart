// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entity_detail.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EntityDetail {

 EntityRef get ref; FunctionEntity? get function; HandlerEntity? get handler; AgentEntity? get agent; WorkflowEntity? get workflow; ControlLogic? get control; ApprovalForm? get approval; TriggerEntity? get trigger; MountHealthReport? get mountHealth;
/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EntityDetailCopyWith<EntityDetail> get copyWith => _$EntityDetailCopyWithImpl<EntityDetail>(this as EntityDetail, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EntityDetail&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.function, function) || other.function == function)&&(identical(other.handler, handler) || other.handler == handler)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.workflow, workflow) || other.workflow == workflow)&&(identical(other.control, control) || other.control == control)&&(identical(other.approval, approval) || other.approval == approval)&&(identical(other.trigger, trigger) || other.trigger == trigger)&&(identical(other.mountHealth, mountHealth) || other.mountHealth == mountHealth));
}


@override
int get hashCode => Object.hash(runtimeType,ref,function,handler,agent,workflow,control,approval,trigger,mountHealth);

@override
String toString() {
  return 'EntityDetail(ref: $ref, function: $function, handler: $handler, agent: $agent, workflow: $workflow, control: $control, approval: $approval, trigger: $trigger, mountHealth: $mountHealth)';
}


}

/// @nodoc
abstract mixin class $EntityDetailCopyWith<$Res>  {
  factory $EntityDetailCopyWith(EntityDetail value, $Res Function(EntityDetail) _then) = _$EntityDetailCopyWithImpl;
@useResult
$Res call({
 EntityRef ref, FunctionEntity? function, HandlerEntity? handler, AgentEntity? agent, WorkflowEntity? workflow, ControlLogic? control, ApprovalForm? approval, TriggerEntity? trigger, MountHealthReport? mountHealth
});


$FunctionEntityCopyWith<$Res>? get function;$HandlerEntityCopyWith<$Res>? get handler;$AgentEntityCopyWith<$Res>? get agent;$WorkflowEntityCopyWith<$Res>? get workflow;$ControlLogicCopyWith<$Res>? get control;$ApprovalFormCopyWith<$Res>? get approval;$TriggerEntityCopyWith<$Res>? get trigger;$MountHealthReportCopyWith<$Res>? get mountHealth;

}
/// @nodoc
class _$EntityDetailCopyWithImpl<$Res>
    implements $EntityDetailCopyWith<$Res> {
  _$EntityDetailCopyWithImpl(this._self, this._then);

  final EntityDetail _self;
  final $Res Function(EntityDetail) _then;

/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ref = null,Object? function = freezed,Object? handler = freezed,Object? agent = freezed,Object? workflow = freezed,Object? control = freezed,Object? approval = freezed,Object? trigger = freezed,Object? mountHealth = freezed,}) {
  return _then(_self.copyWith(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as EntityRef,function: freezed == function ? _self.function : function // ignore: cast_nullable_to_non_nullable
as FunctionEntity?,handler: freezed == handler ? _self.handler : handler // ignore: cast_nullable_to_non_nullable
as HandlerEntity?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as AgentEntity?,workflow: freezed == workflow ? _self.workflow : workflow // ignore: cast_nullable_to_non_nullable
as WorkflowEntity?,control: freezed == control ? _self.control : control // ignore: cast_nullable_to_non_nullable
as ControlLogic?,approval: freezed == approval ? _self.approval : approval // ignore: cast_nullable_to_non_nullable
as ApprovalForm?,trigger: freezed == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as TriggerEntity?,mountHealth: freezed == mountHealth ? _self.mountHealth : mountHealth // ignore: cast_nullable_to_non_nullable
as MountHealthReport?,
  ));
}
/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FunctionEntityCopyWith<$Res>? get function {
    if (_self.function == null) {
    return null;
  }

  return $FunctionEntityCopyWith<$Res>(_self.function!, (value) {
    return _then(_self.copyWith(function: value));
  });
}/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HandlerEntityCopyWith<$Res>? get handler {
    if (_self.handler == null) {
    return null;
  }

  return $HandlerEntityCopyWith<$Res>(_self.handler!, (value) {
    return _then(_self.copyWith(handler: value));
  });
}/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentEntityCopyWith<$Res>? get agent {
    if (_self.agent == null) {
    return null;
  }

  return $AgentEntityCopyWith<$Res>(_self.agent!, (value) {
    return _then(_self.copyWith(agent: value));
  });
}/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkflowEntityCopyWith<$Res>? get workflow {
    if (_self.workflow == null) {
    return null;
  }

  return $WorkflowEntityCopyWith<$Res>(_self.workflow!, (value) {
    return _then(_self.copyWith(workflow: value));
  });
}/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ControlLogicCopyWith<$Res>? get control {
    if (_self.control == null) {
    return null;
  }

  return $ControlLogicCopyWith<$Res>(_self.control!, (value) {
    return _then(_self.copyWith(control: value));
  });
}/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApprovalFormCopyWith<$Res>? get approval {
    if (_self.approval == null) {
    return null;
  }

  return $ApprovalFormCopyWith<$Res>(_self.approval!, (value) {
    return _then(_self.copyWith(approval: value));
  });
}/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TriggerEntityCopyWith<$Res>? get trigger {
    if (_self.trigger == null) {
    return null;
  }

  return $TriggerEntityCopyWith<$Res>(_self.trigger!, (value) {
    return _then(_self.copyWith(trigger: value));
  });
}/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountHealthReportCopyWith<$Res>? get mountHealth {
    if (_self.mountHealth == null) {
    return null;
  }

  return $MountHealthReportCopyWith<$Res>(_self.mountHealth!, (value) {
    return _then(_self.copyWith(mountHealth: value));
  });
}
}


/// Adds pattern-matching-related methods to [EntityDetail].
extension EntityDetailPatterns on EntityDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EntityDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EntityDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EntityDetail value)  $default,){
final _that = this;
switch (_that) {
case _EntityDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EntityDetail value)?  $default,){
final _that = this;
switch (_that) {
case _EntityDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( EntityRef ref,  FunctionEntity? function,  HandlerEntity? handler,  AgentEntity? agent,  WorkflowEntity? workflow,  ControlLogic? control,  ApprovalForm? approval,  TriggerEntity? trigger,  MountHealthReport? mountHealth)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EntityDetail() when $default != null:
return $default(_that.ref,_that.function,_that.handler,_that.agent,_that.workflow,_that.control,_that.approval,_that.trigger,_that.mountHealth);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( EntityRef ref,  FunctionEntity? function,  HandlerEntity? handler,  AgentEntity? agent,  WorkflowEntity? workflow,  ControlLogic? control,  ApprovalForm? approval,  TriggerEntity? trigger,  MountHealthReport? mountHealth)  $default,) {final _that = this;
switch (_that) {
case _EntityDetail():
return $default(_that.ref,_that.function,_that.handler,_that.agent,_that.workflow,_that.control,_that.approval,_that.trigger,_that.mountHealth);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( EntityRef ref,  FunctionEntity? function,  HandlerEntity? handler,  AgentEntity? agent,  WorkflowEntity? workflow,  ControlLogic? control,  ApprovalForm? approval,  TriggerEntity? trigger,  MountHealthReport? mountHealth)?  $default,) {final _that = this;
switch (_that) {
case _EntityDetail() when $default != null:
return $default(_that.ref,_that.function,_that.handler,_that.agent,_that.workflow,_that.control,_that.approval,_that.trigger,_that.mountHealth);case _:
  return null;

}
}

}

/// @nodoc


class _EntityDetail implements EntityDetail {
  const _EntityDetail({required this.ref, this.function, this.handler, this.agent, this.workflow, this.control, this.approval, this.trigger, this.mountHealth});
  

@override final  EntityRef ref;
@override final  FunctionEntity? function;
@override final  HandlerEntity? handler;
@override final  AgentEntity? agent;
@override final  WorkflowEntity? workflow;
@override final  ControlLogic? control;
@override final  ApprovalForm? approval;
@override final  TriggerEntity? trigger;
@override final  MountHealthReport? mountHealth;

/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntityDetailCopyWith<_EntityDetail> get copyWith => __$EntityDetailCopyWithImpl<_EntityDetail>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntityDetail&&(identical(other.ref, ref) || other.ref == ref)&&(identical(other.function, function) || other.function == function)&&(identical(other.handler, handler) || other.handler == handler)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.workflow, workflow) || other.workflow == workflow)&&(identical(other.control, control) || other.control == control)&&(identical(other.approval, approval) || other.approval == approval)&&(identical(other.trigger, trigger) || other.trigger == trigger)&&(identical(other.mountHealth, mountHealth) || other.mountHealth == mountHealth));
}


@override
int get hashCode => Object.hash(runtimeType,ref,function,handler,agent,workflow,control,approval,trigger,mountHealth);

@override
String toString() {
  return 'EntityDetail(ref: $ref, function: $function, handler: $handler, agent: $agent, workflow: $workflow, control: $control, approval: $approval, trigger: $trigger, mountHealth: $mountHealth)';
}


}

/// @nodoc
abstract mixin class _$EntityDetailCopyWith<$Res> implements $EntityDetailCopyWith<$Res> {
  factory _$EntityDetailCopyWith(_EntityDetail value, $Res Function(_EntityDetail) _then) = __$EntityDetailCopyWithImpl;
@override @useResult
$Res call({
 EntityRef ref, FunctionEntity? function, HandlerEntity? handler, AgentEntity? agent, WorkflowEntity? workflow, ControlLogic? control, ApprovalForm? approval, TriggerEntity? trigger, MountHealthReport? mountHealth
});


@override $FunctionEntityCopyWith<$Res>? get function;@override $HandlerEntityCopyWith<$Res>? get handler;@override $AgentEntityCopyWith<$Res>? get agent;@override $WorkflowEntityCopyWith<$Res>? get workflow;@override $ControlLogicCopyWith<$Res>? get control;@override $ApprovalFormCopyWith<$Res>? get approval;@override $TriggerEntityCopyWith<$Res>? get trigger;@override $MountHealthReportCopyWith<$Res>? get mountHealth;

}
/// @nodoc
class __$EntityDetailCopyWithImpl<$Res>
    implements _$EntityDetailCopyWith<$Res> {
  __$EntityDetailCopyWithImpl(this._self, this._then);

  final _EntityDetail _self;
  final $Res Function(_EntityDetail) _then;

/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ref = null,Object? function = freezed,Object? handler = freezed,Object? agent = freezed,Object? workflow = freezed,Object? control = freezed,Object? approval = freezed,Object? trigger = freezed,Object? mountHealth = freezed,}) {
  return _then(_EntityDetail(
ref: null == ref ? _self.ref : ref // ignore: cast_nullable_to_non_nullable
as EntityRef,function: freezed == function ? _self.function : function // ignore: cast_nullable_to_non_nullable
as FunctionEntity?,handler: freezed == handler ? _self.handler : handler // ignore: cast_nullable_to_non_nullable
as HandlerEntity?,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as AgentEntity?,workflow: freezed == workflow ? _self.workflow : workflow // ignore: cast_nullable_to_non_nullable
as WorkflowEntity?,control: freezed == control ? _self.control : control // ignore: cast_nullable_to_non_nullable
as ControlLogic?,approval: freezed == approval ? _self.approval : approval // ignore: cast_nullable_to_non_nullable
as ApprovalForm?,trigger: freezed == trigger ? _self.trigger : trigger // ignore: cast_nullable_to_non_nullable
as TriggerEntity?,mountHealth: freezed == mountHealth ? _self.mountHealth : mountHealth // ignore: cast_nullable_to_non_nullable
as MountHealthReport?,
  ));
}

/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FunctionEntityCopyWith<$Res>? get function {
    if (_self.function == null) {
    return null;
  }

  return $FunctionEntityCopyWith<$Res>(_self.function!, (value) {
    return _then(_self.copyWith(function: value));
  });
}/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$HandlerEntityCopyWith<$Res>? get handler {
    if (_self.handler == null) {
    return null;
  }

  return $HandlerEntityCopyWith<$Res>(_self.handler!, (value) {
    return _then(_self.copyWith(handler: value));
  });
}/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentEntityCopyWith<$Res>? get agent {
    if (_self.agent == null) {
    return null;
  }

  return $AgentEntityCopyWith<$Res>(_self.agent!, (value) {
    return _then(_self.copyWith(agent: value));
  });
}/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorkflowEntityCopyWith<$Res>? get workflow {
    if (_self.workflow == null) {
    return null;
  }

  return $WorkflowEntityCopyWith<$Res>(_self.workflow!, (value) {
    return _then(_self.copyWith(workflow: value));
  });
}/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ControlLogicCopyWith<$Res>? get control {
    if (_self.control == null) {
    return null;
  }

  return $ControlLogicCopyWith<$Res>(_self.control!, (value) {
    return _then(_self.copyWith(control: value));
  });
}/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApprovalFormCopyWith<$Res>? get approval {
    if (_self.approval == null) {
    return null;
  }

  return $ApprovalFormCopyWith<$Res>(_self.approval!, (value) {
    return _then(_self.copyWith(approval: value));
  });
}/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TriggerEntityCopyWith<$Res>? get trigger {
    if (_self.trigger == null) {
    return null;
  }

  return $TriggerEntityCopyWith<$Res>(_self.trigger!, (value) {
    return _then(_self.copyWith(trigger: value));
  });
}/// Create a copy of EntityDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MountHealthReportCopyWith<$Res>? get mountHealth {
    if (_self.mountHealth == null) {
    return null;
  }

  return $MountHealthReportCopyWith<$Res>(_self.mountHealth!, (value) {
    return _then(_self.copyWith(mountHealth: value));
  });
}
}

// dart format on
