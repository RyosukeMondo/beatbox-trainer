// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AudioError {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioError);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AudioError()';
}


}

/// @nodoc
class $AudioErrorCopyWith<$Res>  {
$AudioErrorCopyWith(AudioError _, $Res Function(AudioError) __);
}


/// Adds pattern-matching-related methods to [AudioError].
extension AudioErrorPatterns on AudioError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AudioError_BpmInvalid value)?  bpmInvalid,TResult Function( AudioError_AlreadyRunning value)?  alreadyRunning,TResult Function( AudioError_NotRunning value)?  notRunning,TResult Function( AudioError_HardwareError value)?  hardwareError,TResult Function( AudioError_PermissionDenied value)?  permissionDenied,TResult Function( AudioError_StreamOpenFailed value)?  streamOpenFailed,TResult Function( AudioError_LockPoisoned value)?  lockPoisoned,TResult Function( AudioError_JniInitFailed value)?  jniInitFailed,TResult Function( AudioError_ContextNotInitialized value)?  contextNotInitialized,TResult Function( AudioError_StreamFailure value)?  streamFailure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AudioError_BpmInvalid() when bpmInvalid != null:
return bpmInvalid(_that);case AudioError_AlreadyRunning() when alreadyRunning != null:
return alreadyRunning(_that);case AudioError_NotRunning() when notRunning != null:
return notRunning(_that);case AudioError_HardwareError() when hardwareError != null:
return hardwareError(_that);case AudioError_PermissionDenied() when permissionDenied != null:
return permissionDenied(_that);case AudioError_StreamOpenFailed() when streamOpenFailed != null:
return streamOpenFailed(_that);case AudioError_LockPoisoned() when lockPoisoned != null:
return lockPoisoned(_that);case AudioError_JniInitFailed() when jniInitFailed != null:
return jniInitFailed(_that);case AudioError_ContextNotInitialized() when contextNotInitialized != null:
return contextNotInitialized(_that);case AudioError_StreamFailure() when streamFailure != null:
return streamFailure(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AudioError_BpmInvalid value)  bpmInvalid,required TResult Function( AudioError_AlreadyRunning value)  alreadyRunning,required TResult Function( AudioError_NotRunning value)  notRunning,required TResult Function( AudioError_HardwareError value)  hardwareError,required TResult Function( AudioError_PermissionDenied value)  permissionDenied,required TResult Function( AudioError_StreamOpenFailed value)  streamOpenFailed,required TResult Function( AudioError_LockPoisoned value)  lockPoisoned,required TResult Function( AudioError_JniInitFailed value)  jniInitFailed,required TResult Function( AudioError_ContextNotInitialized value)  contextNotInitialized,required TResult Function( AudioError_StreamFailure value)  streamFailure,}){
final _that = this;
switch (_that) {
case AudioError_BpmInvalid():
return bpmInvalid(_that);case AudioError_AlreadyRunning():
return alreadyRunning(_that);case AudioError_NotRunning():
return notRunning(_that);case AudioError_HardwareError():
return hardwareError(_that);case AudioError_PermissionDenied():
return permissionDenied(_that);case AudioError_StreamOpenFailed():
return streamOpenFailed(_that);case AudioError_LockPoisoned():
return lockPoisoned(_that);case AudioError_JniInitFailed():
return jniInitFailed(_that);case AudioError_ContextNotInitialized():
return contextNotInitialized(_that);case AudioError_StreamFailure():
return streamFailure(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AudioError_BpmInvalid value)?  bpmInvalid,TResult? Function( AudioError_AlreadyRunning value)?  alreadyRunning,TResult? Function( AudioError_NotRunning value)?  notRunning,TResult? Function( AudioError_HardwareError value)?  hardwareError,TResult? Function( AudioError_PermissionDenied value)?  permissionDenied,TResult? Function( AudioError_StreamOpenFailed value)?  streamOpenFailed,TResult? Function( AudioError_LockPoisoned value)?  lockPoisoned,TResult? Function( AudioError_JniInitFailed value)?  jniInitFailed,TResult? Function( AudioError_ContextNotInitialized value)?  contextNotInitialized,TResult? Function( AudioError_StreamFailure value)?  streamFailure,}){
final _that = this;
switch (_that) {
case AudioError_BpmInvalid() when bpmInvalid != null:
return bpmInvalid(_that);case AudioError_AlreadyRunning() when alreadyRunning != null:
return alreadyRunning(_that);case AudioError_NotRunning() when notRunning != null:
return notRunning(_that);case AudioError_HardwareError() when hardwareError != null:
return hardwareError(_that);case AudioError_PermissionDenied() when permissionDenied != null:
return permissionDenied(_that);case AudioError_StreamOpenFailed() when streamOpenFailed != null:
return streamOpenFailed(_that);case AudioError_LockPoisoned() when lockPoisoned != null:
return lockPoisoned(_that);case AudioError_JniInitFailed() when jniInitFailed != null:
return jniInitFailed(_that);case AudioError_ContextNotInitialized() when contextNotInitialized != null:
return contextNotInitialized(_that);case AudioError_StreamFailure() when streamFailure != null:
return streamFailure(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int bpm)?  bpmInvalid,TResult Function()?  alreadyRunning,TResult Function()?  notRunning,TResult Function( String details)?  hardwareError,TResult Function()?  permissionDenied,TResult Function( String reason)?  streamOpenFailed,TResult Function( String component)?  lockPoisoned,TResult Function( String reason)?  jniInitFailed,TResult Function()?  contextNotInitialized,TResult Function( String reason)?  streamFailure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AudioError_BpmInvalid() when bpmInvalid != null:
return bpmInvalid(_that.bpm);case AudioError_AlreadyRunning() when alreadyRunning != null:
return alreadyRunning();case AudioError_NotRunning() when notRunning != null:
return notRunning();case AudioError_HardwareError() when hardwareError != null:
return hardwareError(_that.details);case AudioError_PermissionDenied() when permissionDenied != null:
return permissionDenied();case AudioError_StreamOpenFailed() when streamOpenFailed != null:
return streamOpenFailed(_that.reason);case AudioError_LockPoisoned() when lockPoisoned != null:
return lockPoisoned(_that.component);case AudioError_JniInitFailed() when jniInitFailed != null:
return jniInitFailed(_that.reason);case AudioError_ContextNotInitialized() when contextNotInitialized != null:
return contextNotInitialized();case AudioError_StreamFailure() when streamFailure != null:
return streamFailure(_that.reason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int bpm)  bpmInvalid,required TResult Function()  alreadyRunning,required TResult Function()  notRunning,required TResult Function( String details)  hardwareError,required TResult Function()  permissionDenied,required TResult Function( String reason)  streamOpenFailed,required TResult Function( String component)  lockPoisoned,required TResult Function( String reason)  jniInitFailed,required TResult Function()  contextNotInitialized,required TResult Function( String reason)  streamFailure,}) {final _that = this;
switch (_that) {
case AudioError_BpmInvalid():
return bpmInvalid(_that.bpm);case AudioError_AlreadyRunning():
return alreadyRunning();case AudioError_NotRunning():
return notRunning();case AudioError_HardwareError():
return hardwareError(_that.details);case AudioError_PermissionDenied():
return permissionDenied();case AudioError_StreamOpenFailed():
return streamOpenFailed(_that.reason);case AudioError_LockPoisoned():
return lockPoisoned(_that.component);case AudioError_JniInitFailed():
return jniInitFailed(_that.reason);case AudioError_ContextNotInitialized():
return contextNotInitialized();case AudioError_StreamFailure():
return streamFailure(_that.reason);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int bpm)?  bpmInvalid,TResult? Function()?  alreadyRunning,TResult? Function()?  notRunning,TResult? Function( String details)?  hardwareError,TResult? Function()?  permissionDenied,TResult? Function( String reason)?  streamOpenFailed,TResult? Function( String component)?  lockPoisoned,TResult? Function( String reason)?  jniInitFailed,TResult? Function()?  contextNotInitialized,TResult? Function( String reason)?  streamFailure,}) {final _that = this;
switch (_that) {
case AudioError_BpmInvalid() when bpmInvalid != null:
return bpmInvalid(_that.bpm);case AudioError_AlreadyRunning() when alreadyRunning != null:
return alreadyRunning();case AudioError_NotRunning() when notRunning != null:
return notRunning();case AudioError_HardwareError() when hardwareError != null:
return hardwareError(_that.details);case AudioError_PermissionDenied() when permissionDenied != null:
return permissionDenied();case AudioError_StreamOpenFailed() when streamOpenFailed != null:
return streamOpenFailed(_that.reason);case AudioError_LockPoisoned() when lockPoisoned != null:
return lockPoisoned(_that.component);case AudioError_JniInitFailed() when jniInitFailed != null:
return jniInitFailed(_that.reason);case AudioError_ContextNotInitialized() when contextNotInitialized != null:
return contextNotInitialized();case AudioError_StreamFailure() when streamFailure != null:
return streamFailure(_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class AudioError_BpmInvalid extends AudioError {
  const AudioError_BpmInvalid({required this.bpm}): super._();
  

 final  int bpm;

/// Create a copy of AudioError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioError_BpmInvalidCopyWith<AudioError_BpmInvalid> get copyWith => _$AudioError_BpmInvalidCopyWithImpl<AudioError_BpmInvalid>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioError_BpmInvalid&&(identical(other.bpm, bpm) || other.bpm == bpm));
}


@override
int get hashCode => Object.hash(runtimeType,bpm);

@override
String toString() {
  return 'AudioError.bpmInvalid(bpm: $bpm)';
}


}

/// @nodoc
abstract mixin class $AudioError_BpmInvalidCopyWith<$Res> implements $AudioErrorCopyWith<$Res> {
  factory $AudioError_BpmInvalidCopyWith(AudioError_BpmInvalid value, $Res Function(AudioError_BpmInvalid) _then) = _$AudioError_BpmInvalidCopyWithImpl;
@useResult
$Res call({
 int bpm
});




}
/// @nodoc
class _$AudioError_BpmInvalidCopyWithImpl<$Res>
    implements $AudioError_BpmInvalidCopyWith<$Res> {
  _$AudioError_BpmInvalidCopyWithImpl(this._self, this._then);

  final AudioError_BpmInvalid _self;
  final $Res Function(AudioError_BpmInvalid) _then;

/// Create a copy of AudioError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? bpm = null,}) {
  return _then(AudioError_BpmInvalid(
bpm: null == bpm ? _self.bpm : bpm // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class AudioError_AlreadyRunning extends AudioError {
  const AudioError_AlreadyRunning(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioError_AlreadyRunning);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AudioError.alreadyRunning()';
}


}




/// @nodoc


class AudioError_NotRunning extends AudioError {
  const AudioError_NotRunning(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioError_NotRunning);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AudioError.notRunning()';
}


}




/// @nodoc


class AudioError_HardwareError extends AudioError {
  const AudioError_HardwareError({required this.details}): super._();
  

 final  String details;

/// Create a copy of AudioError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioError_HardwareErrorCopyWith<AudioError_HardwareError> get copyWith => _$AudioError_HardwareErrorCopyWithImpl<AudioError_HardwareError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioError_HardwareError&&(identical(other.details, details) || other.details == details));
}


@override
int get hashCode => Object.hash(runtimeType,details);

@override
String toString() {
  return 'AudioError.hardwareError(details: $details)';
}


}

/// @nodoc
abstract mixin class $AudioError_HardwareErrorCopyWith<$Res> implements $AudioErrorCopyWith<$Res> {
  factory $AudioError_HardwareErrorCopyWith(AudioError_HardwareError value, $Res Function(AudioError_HardwareError) _then) = _$AudioError_HardwareErrorCopyWithImpl;
@useResult
$Res call({
 String details
});




}
/// @nodoc
class _$AudioError_HardwareErrorCopyWithImpl<$Res>
    implements $AudioError_HardwareErrorCopyWith<$Res> {
  _$AudioError_HardwareErrorCopyWithImpl(this._self, this._then);

  final AudioError_HardwareError _self;
  final $Res Function(AudioError_HardwareError) _then;

/// Create a copy of AudioError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? details = null,}) {
  return _then(AudioError_HardwareError(
details: null == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AudioError_PermissionDenied extends AudioError {
  const AudioError_PermissionDenied(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioError_PermissionDenied);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AudioError.permissionDenied()';
}


}




/// @nodoc


class AudioError_StreamOpenFailed extends AudioError {
  const AudioError_StreamOpenFailed({required this.reason}): super._();
  

 final  String reason;

/// Create a copy of AudioError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioError_StreamOpenFailedCopyWith<AudioError_StreamOpenFailed> get copyWith => _$AudioError_StreamOpenFailedCopyWithImpl<AudioError_StreamOpenFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioError_StreamOpenFailed&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'AudioError.streamOpenFailed(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $AudioError_StreamOpenFailedCopyWith<$Res> implements $AudioErrorCopyWith<$Res> {
  factory $AudioError_StreamOpenFailedCopyWith(AudioError_StreamOpenFailed value, $Res Function(AudioError_StreamOpenFailed) _then) = _$AudioError_StreamOpenFailedCopyWithImpl;
@useResult
$Res call({
 String reason
});




}
/// @nodoc
class _$AudioError_StreamOpenFailedCopyWithImpl<$Res>
    implements $AudioError_StreamOpenFailedCopyWith<$Res> {
  _$AudioError_StreamOpenFailedCopyWithImpl(this._self, this._then);

  final AudioError_StreamOpenFailed _self;
  final $Res Function(AudioError_StreamOpenFailed) _then;

/// Create a copy of AudioError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(AudioError_StreamOpenFailed(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AudioError_LockPoisoned extends AudioError {
  const AudioError_LockPoisoned({required this.component}): super._();
  

 final  String component;

/// Create a copy of AudioError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioError_LockPoisonedCopyWith<AudioError_LockPoisoned> get copyWith => _$AudioError_LockPoisonedCopyWithImpl<AudioError_LockPoisoned>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioError_LockPoisoned&&(identical(other.component, component) || other.component == component));
}


@override
int get hashCode => Object.hash(runtimeType,component);

@override
String toString() {
  return 'AudioError.lockPoisoned(component: $component)';
}


}

/// @nodoc
abstract mixin class $AudioError_LockPoisonedCopyWith<$Res> implements $AudioErrorCopyWith<$Res> {
  factory $AudioError_LockPoisonedCopyWith(AudioError_LockPoisoned value, $Res Function(AudioError_LockPoisoned) _then) = _$AudioError_LockPoisonedCopyWithImpl;
@useResult
$Res call({
 String component
});




}
/// @nodoc
class _$AudioError_LockPoisonedCopyWithImpl<$Res>
    implements $AudioError_LockPoisonedCopyWith<$Res> {
  _$AudioError_LockPoisonedCopyWithImpl(this._self, this._then);

  final AudioError_LockPoisoned _self;
  final $Res Function(AudioError_LockPoisoned) _then;

/// Create a copy of AudioError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? component = null,}) {
  return _then(AudioError_LockPoisoned(
component: null == component ? _self.component : component // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AudioError_JniInitFailed extends AudioError {
  const AudioError_JniInitFailed({required this.reason}): super._();
  

 final  String reason;

/// Create a copy of AudioError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioError_JniInitFailedCopyWith<AudioError_JniInitFailed> get copyWith => _$AudioError_JniInitFailedCopyWithImpl<AudioError_JniInitFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioError_JniInitFailed&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'AudioError.jniInitFailed(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $AudioError_JniInitFailedCopyWith<$Res> implements $AudioErrorCopyWith<$Res> {
  factory $AudioError_JniInitFailedCopyWith(AudioError_JniInitFailed value, $Res Function(AudioError_JniInitFailed) _then) = _$AudioError_JniInitFailedCopyWithImpl;
@useResult
$Res call({
 String reason
});




}
/// @nodoc
class _$AudioError_JniInitFailedCopyWithImpl<$Res>
    implements $AudioError_JniInitFailedCopyWith<$Res> {
  _$AudioError_JniInitFailedCopyWithImpl(this._self, this._then);

  final AudioError_JniInitFailed _self;
  final $Res Function(AudioError_JniInitFailed) _then;

/// Create a copy of AudioError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(AudioError_JniInitFailed(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class AudioError_ContextNotInitialized extends AudioError {
  const AudioError_ContextNotInitialized(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioError_ContextNotInitialized);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AudioError.contextNotInitialized()';
}


}




/// @nodoc


class AudioError_StreamFailure extends AudioError {
  const AudioError_StreamFailure({required this.reason}): super._();
  

 final  String reason;

/// Create a copy of AudioError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioError_StreamFailureCopyWith<AudioError_StreamFailure> get copyWith => _$AudioError_StreamFailureCopyWithImpl<AudioError_StreamFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioError_StreamFailure&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,reason);

@override
String toString() {
  return 'AudioError.streamFailure(reason: $reason)';
}


}

/// @nodoc
abstract mixin class $AudioError_StreamFailureCopyWith<$Res> implements $AudioErrorCopyWith<$Res> {
  factory $AudioError_StreamFailureCopyWith(AudioError_StreamFailure value, $Res Function(AudioError_StreamFailure) _then) = _$AudioError_StreamFailureCopyWithImpl;
@useResult
$Res call({
 String reason
});




}
/// @nodoc
class _$AudioError_StreamFailureCopyWithImpl<$Res>
    implements $AudioError_StreamFailureCopyWith<$Res> {
  _$AudioError_StreamFailureCopyWithImpl(this._self, this._then);

  final AudioError_StreamFailure _self;
  final $Res Function(AudioError_StreamFailure) _then;

/// Create a copy of AudioError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = null,}) {
  return _then(AudioError_StreamFailure(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
