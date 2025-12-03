package openfl.media;

#if !flash
import haxe.Int64;
import openfl.events.Event;
import openfl.events.EventDispatcher;

#if lime
import lime.media.AudioSource;
#end

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

    @:noCompletion private var __left:Float = 0;
    @:noCompletion private var __right:Float = 0;

    #if lime
    @:noCompletion private var __source:AudioSource;

    // COMPAT: OpenFL expects __audioSource
    @:noCompletion private var __audioSource(get, never):AudioSource;
    @:noCompletion private function get___audioSource():AudioSource return __source;
    #end

    @:noCompletion private var __valid:Bool = false;
    @:noCompletion private var __loopTime:Int = -1;

    public function new(src:#if lime AudioSource #else Dynamic #end, transform:SoundTransform = null) {
        super(this);

        __soundTransform = (transform != null) ? transform : new SoundTransform();

        #if lime
        __source = src;
        __valid = (__source != null);

        if (__valid) {
            __source.onComplete.add(onDone);
            __source.play();
        }
        #end

        SoundMixer.__registerSoundChannel(this);
    }

    // -----------------------------------------------------
    // STOP / DISPOSE
    // -----------------------------------------------------

    public function stop():Void {
        SoundMixer.__unregisterSoundChannel(this);

        #if lime
        if (__valid) {
            __source.stop();
        }
        #end

        __dispose();
    }

    private function __dispose():Void {
        #if lime
        if (__valid) {
            __source.onComplete.remove(onDone);
            __source = null;
        }
        #end

        __valid = false;
    }

    // -----------------------------------------------------
    // POSITION
    // -----------------------------------------------------

    private function get_position():Float {
        #if lime
        return __valid ? __source.currentTime : 0;
        #else
        return 0;
        #end
    }

    private function set_position(v:Float):Float {
        #if lime
        if (__valid) __source.currentTime = Std.int(v);
        #end
        return v;
    }

    // -----------------------------------------------------
    // TRANSFORM
    // -----------------------------------------------------

    private function get_soundTransform():SoundTransform {
        return __soundTransform.clone();
    }

    private function set_soundTransform(v:SoundTransform):SoundTransform {
        if (v != null) {
            __soundTransform.pan = v.pan;
            __soundTransform.volume = v.volume;

            #if lime
            if (__valid)
                __source.gain = SoundMixer.__soundTransform.volume * __soundTransform.volume;
            #end
        }
        return v;
    }

    // COMPAT: SoundMixer calls this
    private function __updateTransform():Void {
        #if lime
        if (__valid)
            __source.gain = SoundMixer.__soundTransform.volume * __soundTransform.volume;
        #end
    }

    // -----------------------------------------------------
    // PITCH
    // -----------------------------------------------------

    private function get_pitch():Float {
        #if lime
        return __valid ? __source.pitch : 1;
        #else
        return 1;
        #end
    }

    private function set_pitch(v:Float):Float {
        #if lime
        if (__valid) __source.pitch = v;
        #end
        return v;
    }

    // -----------------------------------------------------
    // LOOPS
    // -----------------------------------------------------

    private function get_loops():Int {
        #if lime
        return __valid ? __source.loops : 0;
        #else
        return 0;
        #end
    }

    private function set_loops(v:Int):Int {
        #if lime
        if (__valid) __source.loops = Std.int(v);
        #end
        return v;
    }

    // -----------------------------------------------------
    // END TIME
    // -----------------------------------------------------

    private function get_endTime():Null<Int> {
        #if lime
        return __valid ? __source.length : null;
        #else
        return null;
        #end
    }

    private function set_endTime(v:Null<Int>):Null<Int> {
        #if lime
        if (__valid && v != null)
            __source.length = Std.int(v);
        #end
        return v;
    }

    // -----------------------------------------------------
    // PEAKS (simple fallback)
    // -----------------------------------------------------

    private function get_leftPeak():Float {
        #if lime
        __left = __source.gain;
        return __left * __soundTransform.volume;
        #else
        return 0;
        #end
    }

    private function get_rightPeak():Float {
        #if lime
        __right = __source.gain;
        return __right * __soundTransform.volume;
        #else
        return 0;
        #end
    }

    // -----------------------------------------------------
    // COMPLETE
    // -----------------------------------------------------

    private function onDone():Void {
        SoundMixer.__unregisterSoundChannel(this);
        __dispose();
        dispatchEvent(new Event(Event.SOUND_COMPLETE));
    }
}
#else
typedef SoundChannel = flash.media.SoundChannel;
#end
