// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fixture_manifest.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FixtureSourceDescriptor {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FixtureSourceDescriptor);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FixtureSourceDescriptor()';
}


}

/// @nodoc
class $FixtureSourceDescriptorCopyWith<$Res>  {
$FixtureSourceDescriptorCopyWith(FixtureSourceDescriptor _, $Res Function(FixtureSourceDescriptor) __);
}


/// Adds pattern-matching-related methods to [FixtureSourceDescriptor].
extension FixtureSourceDescriptorPatterns on FixtureSourceDescriptor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( FixtureSourceDescriptor_WavFile value)?  wavFile,TResult Function( FixtureSourceDescriptor_Synthetic value)?  synthetic,TResult Function( FixtureSourceDescriptor_Loopback value)?  loopback,required TResult orElse(),}){
final _that = this;
switch (_that) {
case FixtureSourceDescriptor_WavFile() when wavFile != null:
return wavFile(_that);case FixtureSourceDescriptor_Synthetic() when synthetic != null:
return synthetic(_that);case FixtureSourceDescriptor_Loopback() when loopback != null:
return loopback(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( FixtureSourceDescriptor_WavFile value)  wavFile,required TResult Function( FixtureSourceDescriptor_Synthetic value)  synthetic,required TResult Function( FixtureSourceDescriptor_Loopback value)  loopback,}){
final _that = this;
switch (_that) {
case FixtureSourceDescriptor_WavFile():
return wavFile(_that);case FixtureSourceDescriptor_Synthetic():
return synthetic(_that);case FixtureSourceDescriptor_Loopback():
return loopback(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( FixtureSourceDescriptor_WavFile value)?  wavFile,TResult? Function( FixtureSourceDescriptor_Synthetic value)?  synthetic,TResult? Function( FixtureSourceDescriptor_Loopback value)?  loopback,}){
final _that = this;
switch (_that) {
case FixtureSourceDescriptor_WavFile() when wavFile != null:
return wavFile(_that);case FixtureSourceDescriptor_Synthetic() when synthetic != null:
return synthetic(_that);case FixtureSourceDescriptor_Loopback() when loopback != null:
return loopback(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String path)?  wavFile,TResult Function( ManifestSyntheticPattern pattern,  double frequencyHz,  double amplitude)?  synthetic,TResult Function( String? device)?  loopback,required TResult orElse(),}) {final _that = this;
switch (_that) {
case FixtureSourceDescriptor_WavFile() when wavFile != null:
return wavFile(_that.path);case FixtureSourceDescriptor_Synthetic() when synthetic != null:
return synthetic(_that.pattern,_that.frequencyHz,_that.amplitude);case FixtureSourceDescriptor_Loopback() when loopback != null:
return loopback(_that.device);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String path)  wavFile,required TResult Function( ManifestSyntheticPattern pattern,  double frequencyHz,  double amplitude)  synthetic,required TResult Function( String? device)  loopback,}) {final _that = this;
switch (_that) {
case FixtureSourceDescriptor_WavFile():
return wavFile(_that.path);case FixtureSourceDescriptor_Synthetic():
return synthetic(_that.pattern,_that.frequencyHz,_that.amplitude);case FixtureSourceDescriptor_Loopback():
return loopback(_that.device);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String path)?  wavFile,TResult? Function( ManifestSyntheticPattern pattern,  double frequencyHz,  double amplitude)?  synthetic,TResult? Function( String? device)?  loopback,}) {final _that = this;
switch (_that) {
case FixtureSourceDescriptor_WavFile() when wavFile != null:
return wavFile(_that.path);case FixtureSourceDescriptor_Synthetic() when synthetic != null:
return synthetic(_that.pattern,_that.frequencyHz,_that.amplitude);case FixtureSourceDescriptor_Loopback() when loopback != null:
return loopback(_that.device);case _:
  return null;

}
}

}

/// @nodoc


class FixtureSourceDescriptor_WavFile extends FixtureSourceDescriptor {
  const FixtureSourceDescriptor_WavFile({required this.path}): super._();
  

 final  String path;

/// Create a copy of FixtureSourceDescriptor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FixtureSourceDescriptor_WavFileCopyWith<FixtureSourceDescriptor_WavFile> get copyWith => _$FixtureSourceDescriptor_WavFileCopyWithImpl<FixtureSourceDescriptor_WavFile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FixtureSourceDescriptor_WavFile&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'FixtureSourceDescriptor.wavFile(path: $path)';
}


}

/// @nodoc
abstract mixin class $FixtureSourceDescriptor_WavFileCopyWith<$Res> implements $FixtureSourceDescriptorCopyWith<$Res> {
  factory $FixtureSourceDescriptor_WavFileCopyWith(FixtureSourceDescriptor_WavFile value, $Res Function(FixtureSourceDescriptor_WavFile) _then) = _$FixtureSourceDescriptor_WavFileCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$FixtureSourceDescriptor_WavFileCopyWithImpl<$Res>
    implements $FixtureSourceDescriptor_WavFileCopyWith<$Res> {
  _$FixtureSourceDescriptor_WavFileCopyWithImpl(this._self, this._then);

  final FixtureSourceDescriptor_WavFile _self;
  final $Res Function(FixtureSourceDescriptor_WavFile) _then;

/// Create a copy of FixtureSourceDescriptor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(FixtureSourceDescriptor_WavFile(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FixtureSourceDescriptor_Synthetic extends FixtureSourceDescriptor {
  const FixtureSourceDescriptor_Synthetic({required this.pattern, required this.frequencyHz, required this.amplitude}): super._();
  

 final  ManifestSyntheticPattern pattern;
 final  double frequencyHz;
 final  double amplitude;

/// Create a copy of FixtureSourceDescriptor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FixtureSourceDescriptor_SyntheticCopyWith<FixtureSourceDescriptor_Synthetic> get copyWith => _$FixtureSourceDescriptor_SyntheticCopyWithImpl<FixtureSourceDescriptor_Synthetic>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FixtureSourceDescriptor_Synthetic&&(identical(other.pattern, pattern) || other.pattern == pattern)&&(identical(other.frequencyHz, frequencyHz) || other.frequencyHz == frequencyHz)&&(identical(other.amplitude, amplitude) || other.amplitude == amplitude));
}


@override
int get hashCode => Object.hash(runtimeType,pattern,frequencyHz,amplitude);

@override
String toString() {
  return 'FixtureSourceDescriptor.synthetic(pattern: $pattern, frequencyHz: $frequencyHz, amplitude: $amplitude)';
}


}

/// @nodoc
abstract mixin class $FixtureSourceDescriptor_SyntheticCopyWith<$Res> implements $FixtureSourceDescriptorCopyWith<$Res> {
  factory $FixtureSourceDescriptor_SyntheticCopyWith(FixtureSourceDescriptor_Synthetic value, $Res Function(FixtureSourceDescriptor_Synthetic) _then) = _$FixtureSourceDescriptor_SyntheticCopyWithImpl;
@useResult
$Res call({
 ManifestSyntheticPattern pattern, double frequencyHz, double amplitude
});




}
/// @nodoc
class _$FixtureSourceDescriptor_SyntheticCopyWithImpl<$Res>
    implements $FixtureSourceDescriptor_SyntheticCopyWith<$Res> {
  _$FixtureSourceDescriptor_SyntheticCopyWithImpl(this._self, this._then);

  final FixtureSourceDescriptor_Synthetic _self;
  final $Res Function(FixtureSourceDescriptor_Synthetic) _then;

/// Create a copy of FixtureSourceDescriptor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? pattern = null,Object? frequencyHz = null,Object? amplitude = null,}) {
  return _then(FixtureSourceDescriptor_Synthetic(
pattern: null == pattern ? _self.pattern : pattern // ignore: cast_nullable_to_non_nullable
as ManifestSyntheticPattern,frequencyHz: null == frequencyHz ? _self.frequencyHz : frequencyHz // ignore: cast_nullable_to_non_nullable
as double,amplitude: null == amplitude ? _self.amplitude : amplitude // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class FixtureSourceDescriptor_Loopback extends FixtureSourceDescriptor {
  const FixtureSourceDescriptor_Loopback({this.device}): super._();
  

 final  String? device;

/// Create a copy of FixtureSourceDescriptor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FixtureSourceDescriptor_LoopbackCopyWith<FixtureSourceDescriptor_Loopback> get copyWith => _$FixtureSourceDescriptor_LoopbackCopyWithImpl<FixtureSourceDescriptor_Loopback>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FixtureSourceDescriptor_Loopback&&(identical(other.device, device) || other.device == device));
}


@override
int get hashCode => Object.hash(runtimeType,device);

@override
String toString() {
  return 'FixtureSourceDescriptor.loopback(device: $device)';
}


}

/// @nodoc
abstract mixin class $FixtureSourceDescriptor_LoopbackCopyWith<$Res> implements $FixtureSourceDescriptorCopyWith<$Res> {
  factory $FixtureSourceDescriptor_LoopbackCopyWith(FixtureSourceDescriptor_Loopback value, $Res Function(FixtureSourceDescriptor_Loopback) _then) = _$FixtureSourceDescriptor_LoopbackCopyWithImpl;
@useResult
$Res call({
 String? device
});




}
/// @nodoc
class _$FixtureSourceDescriptor_LoopbackCopyWithImpl<$Res>
    implements $FixtureSourceDescriptor_LoopbackCopyWith<$Res> {
  _$FixtureSourceDescriptor_LoopbackCopyWithImpl(this._self, this._then);

  final FixtureSourceDescriptor_Loopback _self;
  final $Res Function(FixtureSourceDescriptor_Loopback) _then;

/// Create a copy of FixtureSourceDescriptor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? device = freezed,}) {
  return _then(FixtureSourceDescriptor_Loopback(
device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
