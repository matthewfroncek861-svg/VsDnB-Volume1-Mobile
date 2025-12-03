package flixel.sound;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxStringUtil;
import flixel.tweens.FlxTween;

import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.media.SoundTransform;

class FlxSound extends FlxBasic
{
    public var playing(get, never):Bool;

    public var x:Float = 0;
    public var y:Float = 0;

    public var persist:Bool = false;

    public var name(default, null):String;
    public var artist(default, null):String;

    public var amplitude(default,null):Float = 0;
    public var amplitudeLeft(default,null):Float = 0;
    public var amplitudeRight(default,null):Float = 0;

    public var autoDestroy:Bool = false;

    public var onComplete:Void->Void;

    public var pan(get,set):Float;

    public var volume(get,set):Float;

    public var pitch(get,set):Float;

    public var time(get,set):Float;

    public var length(get,never):Float;

    public var group(default,set):FlxSoundGroup;

    public var looped:Bool = false;
    public var loopTime:Int = 0;

    public var endTime:Null<Int>;

    public var fadeTween:FlxTween;

    var _sound:Sound;
    var _channel:SoundChannel;
    var _transform:SoundTransform = new SoundTransform();

    var _paused:Bool = false;
    var _volume:Float = 1.0;
    var _volumeAdjust:Float = 1.0;

    var _time:Float = 0;
    var _length:Float = 0;

    var _target:FlxBasic;
    var _radius:Float = 0;
    var _proximityPan:Bool = false;

    public function new()
    {
        super();
        reset();
    }

    // -------------------------------------------------------
    // RESET + DESTROY
    // -------------------------------------------------------

    function reset():Void
    {
        destroy();

        _time = 0;
        _paused = false;
        _volume = 1.0;
        _volumeAdjust = 1.0;

        looped = false;
        loopTime = 0;
        endTime = null;

        _target = null;
        _radius = 0;
        _proximityPan = false;

        amplitude = 0;
        amplitudeLeft = 0;
        amplitudeRight = 0;

        autoDestroy = false;

        if (_transform == null)
            _transform = new SoundTransform();
        _transform.pan = 0;
    }

    override public function destroy():Void
    {
        if (_channel != null)
        {
            _channel.removeEventListener(openfl.events.Event.SOUND_COMPLETE, stopped);
            _channel.stop();
            _channel = null;
        }

        _sound = null;
        onComplete = null;
        super.destroy();
    }

    // -------------------------------------------------------
    // UPDATE
    // -------------------------------------------------------

    override public function update(elapsed:Float):Void
    {
        if (!playing) return;

        _time = _channel.position;

        // Safe proximity code
        if (_target != null)
        {
            if (Reflect.hasField(_target, "x") && Reflect.hasField(_target, "y"))
            {
                var dx = _target.x - x;
                var dy = _target.y - y;
                var dist = Math.sqrt(dx * dx + dy * dy);

                _volumeAdjust = 1 - FlxMath.bound(dist / _radius, 0, 1);
            }
        }

        updateTransform();

        amplitudeLeft = _channel.leftPeak;
        amplitudeRight = _channel.rightPeak;
        amplitude = (amplitudeLeft + amplitudeRight) / 2;

        if (endTime != null && _time >= endTime)
            stopped();
    }

    // -------------------------------------------------------
    // API
    // -------------------------------------------------------

    public function loadEmbedded(Snd:Dynamic, Looped:Bool=false, AutoDestroy:Bool=false, ?OnComplete:Void->Void):FlxSound
    {
        cleanup(true);

        if (Std.isOfType(Snd, Sound))
            _sound = cast Snd;
        else if (Std.isOfType(Snd, Class))
            _sound = Type.createInstance(Snd, []);
        else if (Std.isOfType(Snd, String))
            _sound = openfl.utils.Assets.getSound(Snd);

        return init(Looped, AutoDestroy, OnComplete);
    }

    public function loadStream(URL:String, Looped:Bool=false, AutoDestroy:Bool=false, ?OnComplete:Void->Void):FlxSound
    {
        cleanup(true);

        _sound = new Sound();
        _sound.load(new openfl.net.URLRequest(URL));

        return init(Looped, AutoDestroy, OnComplete);
    }

    function init(loop:Bool, auto:Bool, ?cb:Void->Void):FlxSound
    {
        looped = loop;
        autoDestroy = auto;
        onComplete = cb;

        _length = (_sound != null) ? _sound.length : 0;
        endTime = Std.int(_length);

        updateTransform();
        exists = true;

        return this;
    }

    // -------------------------------------------------------
    // PLAYBACK
    // -------------------------------------------------------

    public function play(ForceRestart:Bool=false, Start:Float=0, ?End:Int):FlxSound
    {
        if (!exists) return this;

        if (ForceRestart)
            cleanup(false, true);
        else if (playing)
            return this;

        if (_paused)
            resume();
        else
            startSound(Start);

        endTime = End;
        return this;
    }

    public function resume():FlxSound
    {
        if (_paused)
            startSound(_time);
        return this;
    }

    public function pause():FlxSound
    {
        if (!playing) return this;

        _time = _channel.position;
        _paused = true;
        cleanup(false, false);

        return this;
    }

    public function stop():FlxSound
    {
        cleanup(autoDestroy, true);
        return this;
    }

    // -------------------------------------------------------
    // FADING
    // -------------------------------------------------------

    public inline function fadeOut(dur:Float=1, To:Float=0, ?cb:FlxTween->Void)
    {
        if (fadeTween != null) fadeTween.cancel();
        fadeTween = FlxTween.num(volume, To, dur, {onComplete:cb}, volumeTween);
        return this;
    }

    public inline function fadeIn(dur:Float=1, From:Float=0, To:Float=1, ?cb:FlxTween->Void)
    {
        if (!playing) play();

        if (fadeTween != null) fadeTween.cancel();

        fadeTween = FlxTween.num(From, To, dur, {onComplete:cb}, volumeTween);

        return this;
    }

    function volumeTween(v:Float):Void volume = v;

    // -------------------------------------------------------
    // TRANSFORM
    // -------------------------------------------------------

    @:allow(flixel.sound.FlxSoundGroup)
    @:allow(flixel.system.FlxSoundGroup)
    function updateTransform():Void
    {
        _transform.volume =
            (FlxG.sound.muted ? 0 : 1) *
            FlxG.sound.volume *
            (group != null ? group.volume : 1) *
            _volume * _volumeAdjust;

        if (_channel != null)
            _channel.soundTransform = _transform;
    }

    function startSound(start:Float):Void
    {
        if (_sound == null) return;

        _paused = false;
        _channel = _sound.play(Std.int(start), looped ? 999999 : 0, _transform);

        if (_channel != null)
        {
            _channel.addEventListener(openfl.events.Event.SOUND_COMPLETE, stopped);
            active = true;
        }
        else
        {
            active = false;
            exists = false;
        }
    }

    function stopped(?e:Dynamic):Void
    {
        if (onComplete != null)
            onComplete();

        if (looped)
        {
            cleanup(false);
            play(false, loopTime, endTime);
        }
        else
            cleanup(autoDestroy);
    }

    function cleanup(destroySound:Bool, resetPos:Bool=true):Void
    {
        if (destroySound)
        {
            reset();
            return;
        }

        if (_channel != null)
        {
            _channel.removeEventListener(openfl.events.Event.SOUND_COMPLETE, stopped);
            _channel.stop();
            _channel = null;
        }

        active = false;

        if (resetPos)
        {
            _time = 0;
            _paused = false;
        }
    }

    // -------------------------------------------------------
    // GETTERS / SETTERS
    // -------------------------------------------------------

    public inline function get_playing():Bool return _channel != null;

    inline function get_volume():Float return _volume;

    function set_volume(v:Float):Float
    {
        _volume = FlxMath.bound(v, 0, 1);
        updateTransform();
        return v;
    }

    inline function get_pan():Float return _transform.pan;

    function set_pan(v:Float):Float
    {
        _transform.pan = FlxMath.bound(v, -1, 1);
        updateTransform();
        return v;
    }

    inline function get_pitch():Float return 1;
    function set_pitch(v:Float):Float return v;

    inline function get_time():Float return _time;

    function set_time(v:Float):Float
    {
        if (playing)
        {
            cleanup(false, true);
            startSound(v);
        }
        return _time = v;
    }

    inline function get_length():Float return _length;

    function set_group(g:FlxSoundGroup):FlxSoundGroup
    {
        if (this.group != g)
        {
            if (this.group != null) this.group.remove(this);
            this.group = g;
            if (g != null) g.add(this);
            updateTransform();
        }
        return g;
    }

    override public function toString():String
    {
        return FlxStringUtil.getDebugString([
            LabelValuePair.weak("playing", playing),
            LabelValuePair.weak("time", time),
            LabelValuePair.weak("length", length),
            LabelValuePair.weak("volume", volume)
        ]);
    }

    // -------------------------------------------------------
    // REQUIRED BY SoundFrontEnd
    // -------------------------------------------------------

    public function onFocusLost():Void {}
    public function onFocus():Void {}
}
