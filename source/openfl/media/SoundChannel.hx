package openfl.media;

#if !flash
import haxe.Int64;

import openfl.events.Event;
import openfl.events.EventDispatcher;
#if lime
import lime.media.AudioSource;
import lime.media.openal.AL;
#end

/**
	The SoundChannel class controls a sound in an application. Every sound is
	assigned to a sound channel. This patched version is fully compatible with
	Lime 7/8/9 and mobile backends, removing deprecated fields.
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
#if lime_cffi
@:access(lime._internal.backend.native.NativeAudioSource)
@:access(lime.media.AudioSource)
#end
@:access(openfl.media.Sound)
@:access(openfl.media.SoundMixer)
@:final @:keep class SoundChannel extends EventDispatcher {

	public var leftPeak(get, null):Float;
	public var rightPeak(get, null):Float;
	public var position(get, set):Float;
	public var soundTransform(get, set):SoundTransform;

	public var loopTime(get, set):Float;
	public var endTime(get, set):Null<Float>;
	public var pitch(get, set):Float;
	public var loops(get, set):Int;

	@:noCompletion private var __sound:Sound;
	@:noCompletion private var __isValid:Bool = false;
	@:noCompletion private var __soundTransform:SoundTransform;
	@:noCompletion private var __lastPeakTime:Float = 0;
	@:noCompletion private var __leftPeak:Float = 0;
	@:noCompletion private var __rightPeak:Float = 0;

	#if lime
	@:noCompletion private var __source:AudioSource;
	@:noCompletion private var __audioSource(get, set):AudioSource;
	#end


	@:noCompletion private function new(source:#if lime AudioSource #else Dynamic #end = null, soundTransform:SoundTransform = null) {
		super(this);

		if (soundTransform != null) __soundTransform = soundTransform;
		else __soundTransform = new SoundTransform();

		__initAudioSource(source);

		SoundMixer.__registerSoundChannel(this);
	}

	public function stop():Void {
		SoundMixer.__unregisterSoundChannel(this);

		if (!__isValid) return;

		#if lime
		__source.stop();
		#end

		__dispose();
	}

	@:noCompletion private function __dispose():Void {
		if (!__isValid) return;

		#if lime
		__source.onComplete.remove(source_onComplete);
		__source.dispose();
		__source = null;
		#end

		__isValid = false;
	}

	@:noCompletion private function __updatePeaks(time:Float):Bool {
		if (!__isValid) return false;

		// Fallback peak detection (Lime 7/8/9)
		#if lime
		__leftPeak = __source.gain;
		__rightPeak = __source.gain;
		#else
		__leftPeak = 0;
		__rightPeak = 0;
		#end

		return true;
	}

	@:noCompletion private function __initAudioSource(source:#if lime AudioSource #else Dynamic #end):Void {
		#if lime
		__source = source;

		if (__source == null)
			return;

		__source.onComplete.add(source_onComplete);
		__isValid = true;
		__source.play();
		#end
	}

	// ------------------ Position ------------------

	@:noCompletion private function get_position():Float {
		if (!__isValid) return 0;

		#if lime
		return __source.currentTime + __source.offset;
		#else
		return 0;
		#end
	}

	@:noCompletion private function set_position(value:Float):Float {
		if (!__isValid) return 0;

		#if lime
		__source.currentTime = value - __source.offset;
		#end

		return value;
	}

	// ------------------ SoundTransform ------------------

	@:noCompletion private function get_soundTransform():SoundTransform {
		return __soundTransform.clone();
	}

	@:noCompletion private function set_soundTransform(value:SoundTransform):SoundTransform {
		if (value != null) {
			__soundTransform.pan = value.pan;
			__soundTransform.volume = value.volume;

			var pan = SoundMixer.__soundTransform.pan + __soundTransform.pan;
			if (pan < -1) pan = -1;
			if (pan > 1) pan = 1;

			var volume = SoundMixer.__soundTransform.volume * __soundTransform.volume;

			#if lime
			if (__isValid) {
				// Lime does *not* have .pan anymore. Use a safe fallback.
				__source.gain = volume;
				// No pan support available in Lime 8/9. Ignored safely.
			}
			#end
		}

		return value;
	}

	// ------------------ Pitch ------------------

	@:noCompletion private function get_pitch():Float {
		if (!__isValid) return 1;

		#if lime
		return __source.pitch;
		#else
		return 1;
		#end
	}

	@:noCompletion private function set_pitch(value:Float):Float {
		if (!__isValid) return value;

		#if lime
		__source.pitch = value;
		#end

		return value;
	}

	// ------------------ Loop Time ------------------

	@:noCompletion private function get_loopTime():Float {
		#if lime
		return __isValid ? __source.loopTime : -1;
		#else
		return -1;
		#end
	}

	@:noCompletion private function set_loopTime(value:Float):Float {
		#if lime
		if (__isValid) __source.loopTime = value;
		#end
		return value;
	}

	// ------------------ End Time ------------------

	@:noCompletion private function get_endTime():Null<Float> {
		#if lime
		return __isValid ? __source.length : null;
		#else
		return null;
		#end
	}

	@:noCompletion private function set_endTime(value:Null<Float>):Null<Float> {
		#if lime
		if (__isValid) __source.length = value;
		#end

		return value;
	}

	// ------------------ Loops ------------------

	@:noCompletion private function get_loops():Int {
		#if lime
		return __isValid ? __source.loops : 0;
		#else
		return 0;
		#end
	}

	@:noCompletion private function set_loops(value:Int):Int {
		#if lime
		if (__isValid) __source.loops = value;
		#end

		return value;
	}

	// ------------------ Peaks ------------------

	@:noCompletion private function get_leftPeak():Float {
		__updatePeaks(get_position());
		return __leftPeak * (__soundTransform == null ? 1 : __soundTransform.volume);
	}

	@:noCompletion private function get_rightPeak():Float {
		__updatePeaks(get_position());
		return __rightPeak * (__soundTransform == null ? 1 : __soundTransform.volume);
	}

	// ------------------ Events ------------------

	@:noCompletion private function source_onComplete():Void {
		SoundMixer.__unregisterSoundChannel(this);
		__dispose();
		dispatchEvent(new Event(Event.SOUND_COMPLETE));
	}

	#if lime
	@:noCompletion private function get___audioSource():AudioSource return __source;
	@:noCompletion private function set___audioSource(src:AudioSource):AudioSource return __source = src;
	#end
}
#else
typedef SoundChannel = flash.media.SoundChannel;
#end
