package openfl.media;

#if !flash
import haxe.Int64;

import openfl.events.Event;
import openfl.events.EventDispatcher;

#if lime
import lime.media.AudioSource;
#end

/**
 * Fully Lime-9-compatible SoundChannel implementation.
 * Removes deprecated AudioSource fields:
 *   time, pan, buffer, leftToRight, rightToLeft, etc.
 *
 * Uses only:
 *   offset (seconds)
 *   length (seconds)
 *   gain
 *   pitch
 *   loops
 */
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end

@:access(openfl.media.Sound)
@:access(openfl.media.SoundMixer)
@:final @:keep class SoundChannel extends EventDispatcher {

    public var leftPeak(get, null):Float;
    public var rightPeak(get, null):Float;

    public var position(get, set):Float;
    public var soundTransform(get, set):SoundTransform;

    public var loopTime(get, set):Int;
    public var endTime(get, set):Null<Int>;
    public var pitch(get, set):Float;
    public var loops(get, set):Int;

    @:noCompletion private var __soundTransform:SoundTransform;

    #if lime
    @:noCompletion private var __source:AudioSource;
    #end

    @:noCompletion private var __isValid:Bool = false;
    @:noCompletion private var __leftPeak:Float = 0;
    @:noCompletion private var __rightPeak:Float = 0;

    // manual loop timing
    @:noCompletion private var __loopTime:Int = -1;

    // -------------------------------------------------------
    // Constructor
    // -------------------------------------------------------
    @:noCompletion private function new(src:#if lime AudioSource #else Dynamic #end,
                                       transform:SoundTransform = null)
    {
        super(this);

        __soundTransform = (transform != null) ? transform : new SoundTransform();

        __initAudioSource(src);
        SoundMixer.__registerSoundChannel(this);
    }

    // -------------------------------------------------------
    // STOP
    // -------------------------------------------------------
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

    // -------------------------------------------------------
    // INIT
    // -------------------------------------------------------
    @:noCompletion private function __initAudioSource(src:#if lime AudioSource #else Dynamic #end):Void {
        #if lime
        __source = src;
        if (__source == null) return;

        __isValid = true;
        __source.onComplete.add(source_onComplete);
        __source.play();
        #end
    }

    // -------------------------------------------------------
    // POSITION (uses offset instead of removed time field)
    // offset = seconds, OpenFL uses ms
    // -------------------------------------------------------
    @:noCompletion private function get_position():Float {
        #if lime
        if (!__isValid || __source == null) return 0;
        return __source.offset * 1000.0;
        #else
        return 0;
        #end
    }

    @:noCompletion private function set_position(v:Float):Float {
        #if lime
        if (__isValid && __source != null) {
            __source.offset = v / 1000.0; // ms → seconds
            __source.play(); // restart at new position
        }
        #end
        return v;
    }

    // -------------------------------------------------------
    // SOUND TRANSFORM
    // -------------------------------------------------------
    @:noCompletion private function get_soundTransform():SoundTransform {
        return __soundTransform.clone();
    }

    @:noCompletion private function set_soundTransform(v:SoundTransform):SoundTransform {
        if (v != null) {
            __soundTransform.pan = v.pan;
            __soundTransform.volume = v.volume;

            var finalVolume = SoundMixer.__soundTransform.volume * __soundTransform.volume;

            #if lime
            if (__isValid) {
                __source.gain = finalVolume;
            }
            #end
        }
        return v;
    }

    // -------------------------------------------------------
    // PITCH
    // -------------------------------------------------------
    @:noCompletion private function get_pitch():Float {
        #if lime
        return __isValid ? __source.pitch : 1;
        #else
        return 1;
        #end
    }

    @:noCompletion private function set_pitch(v:Float):Float {
        #if lime
        if (__isValid) __source.pitch = v;
        #end
        return v;
    }

    // -------------------------------------------------------
    // LOOP TIME (manual storage)
    // -------------------------------------------------------
    @:noCompletion private function get_loopTime():Int {
        return __loopTime;
    }

    @:noCompletion private function set_loopTime(v:Int):Int {
        __loopTime = v;
        return v;
    }

    // -------------------------------------------------------
    // END TIME (seconds → ms)
    // -------------------------------------------------------
    @:noCompletion private function get_endTime():Null<Int> {
        #if lime
        if (!__isValid || __source == null) return null;
        return Std.int(__source.length * 1000);
        #else
        return null;
        #end
    }

    @:noCompletion private function set_endTime(v:Null<Int>):Null<Int> {
        #if lime
        if (__isValid && v != null) {
            __source.length = v / 1000.0;
        }
        #end
        return v;
    }

    // -------------------------------------------------------
    // LOOPS
    // -------------------------------------------------------
    @:noCompletion private function get_loops():Int {
        #if lime
        return __isValid ? __source.loops : 0;
        #else
        return 0;
        #end
    }

    @:noCompletion private function set_loops(v:Int):Int {
        #if lime
        if (__isValid) __source.loops = v;
        #end
        return v;
    }

    // -------------------------------------------------------
    // PEAKS (approx using gain)
    // -------------------------------------------------------
    @:noCompletion private function get_leftPeak():Float {
        #if lime
        __leftPeak = __source.gain;
        return __leftPeak * __soundTransform.volume;
        #else
        return 0;
        #end
    }

    @:noCompletion private function get_rightPeak():Float {
        #if lime
        __rightPeak = __source.gain;
        return __rightPeak * __soundTransform.volume;
        #else
        return 0;
        #end
    }

    // -------------------------------------------------------
    // COMPLETE
    // -------------------------------------------------------
    @:noCompletion private function source_onComplete():Void {
        SoundMixer.__unregisterSoundChannel(this);
        __dispose();
        dispatchEvent(new Event(Event.SOUND_COMPLETE));
    }
}
#else
typedef SoundChannel = flash.media.SoundChannel;
#end
