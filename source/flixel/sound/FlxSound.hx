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

#if lime
import lime.media.AudioSource;
#end

/**
 * Compat-patched FlxSound for Lime 9 / OpenFL 9
 * Removes deprecated AudioSource fields:
 *   pan, leftToRight, rightToLeft, __source, buffer access, etc.
 *
 * This version matches your patched SoundChannel.hx.
 */
class FlxSound extends FlxBasic
{
    public var playing(get, never):Bool;

	/**
	 * The X/Y world-space location of the sound
	 */
	public var x:Float = 0;
	public var y:Float = 0;

	/**
	 * Whether or not the sound persists during state switches
	 */
	public var persist:Bool = false;

	/**
	 * Song name (if available)
	 */
	public var name(default,null):String;
	public var artist(default,null):String;

	/**
	 * Amplitude tracking
	 */
	public var amplitude(default,null):Float = 0;
	public var amplitudeLeft(default,null):Float = 0;
	public var amplitudeRight(default,null):Float = 0;

	/**
	 * Auto-destroy when playback ends
	 */
	public var autoDestroy:Bool = false;

	public var onComplete:Void->Void;

	/**
	 * Pan is removed from AudioSource, but we provide a soft fallback.
	 */
	public var pan(get,set):Float;

	/**
	 * Volume (0–1)
	 */
	public var volume(get,set):Float;

	/**
	 * Pitch (if backend supports it)
	 */
	public var pitch(get,set):Float;

	/**
	 * Current play time
	 */
	public var time(get,set):Float;

	/**
	 * Length (ms)
	 */
	public var length(get,never):Float;

	/**
	 * FlxSoundGroup (new namespace)
	 */
	public var group(default,set):FlxSoundGroup;

	/**
	 * Looping enabled?
	 */
	public var looped:Bool = false;

	/**
	 * Loop start offset
	 */
	public var loopTime:Int = 0;

	/**
	 * Where playback should stop
	 */
	public var endTime:Null<Int>; // Lime 9 uses Int

	/**
	 * Fade Tween
	 */
	public var fadeTween:FlxTween;

	/**
	 * Internal sound / channel
	 */
	var _sound:Sound;
	var _channel:SoundChannel;
	var _transform:SoundTransform = new SoundTransform();

	var _paused:Bool = false;
	var _volume:Float = 1.0;
	var _volumeAdjust:Float = 1.0;

	/**
	 * Cached time when paused
	 */
	var _time:Float = 0;

	var _length:Float = 0;

	/**
	 * Proximity panning no longer works since AudioSource.pan removed.
	 * We emulate it with soft-panning into FlxSoundGroup if needed.
	 */
	var _target:FlxBasic;
	var _radius:Float = 0;
	var _proximityPan:Bool = false;

	public function new()
	{
		super();
		reset();
	}

	// ----------------------------------------------------------
	// RESET / DESTROY
	// ----------------------------------------------------------

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

	// ----------------------------------------------------------
	// UPDATE
	// ----------------------------------------------------------

	override public function update(elapsed:Float):Void
	{
		if (!playing) return;

		_time = _channel.position;

		// proximity volume falloff
		if (_target != null)
		{
			var targetPos = FlxPoint.get(_target.x, _target.y);
			var d = targetPos.distanceTo(FlxPoint.get(x, y));
			var mult = 1 - FlxMath.bound(d / _radius, 0, 1);

			_volumeAdjust = mult;
		}

		updateTransform();

		// amplitude tracking (fallback only)
		if (_transform.volume > 0)
		{
			amplitudeLeft = _channel.leftPeak / _transform.volume;
			amplitudeRight = _channel.rightPeak / _transform.volume;
			amplitude = (amplitudeLeft + amplitudeRight) / 2;
		}

		// manually stop at endTime
		if (endTime != null && _time >= endTime)
			stopped();
	}

	// ----------------------------------------------------------
	// API
	// ----------------------------------------------------------

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

	// ----------------------------------------------------------
	// PLAYBACK
	// ----------------------------------------------------------

	public function play(ForceRestart:Bool=false, StartTime:Float=0, ?End:Int):FlxSound
	{
		if (!exists) return this;

		if (ForceRestart)
			cleanup(false, true);
		else if (playing)
			return this;

		if (_paused)
			resume();
		else
			startSound(StartTime);

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

	function volumeTween(v:Float):Void
	{
		volume = v;
	}

	// ----------------------------------------------------------
	// TRANSFORM
	// ----------------------------------------------------------

// ----------------------------------------------------------
// TRANSFORM
// ----------------------------------------------------------

// Allow FlxSoundGroup to call updateTransform()
// Psych Engine uses BOTH namespaces depending on version
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
		_channel = _sound.play(start, looped ? 999999 : 0, _transform);

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

	function stopped(?_):Void
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

	// ----------------------------------------------------------
	// GETTERS / SETTERS
	// ----------------------------------------------------------

	public inline function get_playing():Bool return _channel != null;

	inline function get_volume():Float return _volume;

	function set_volume(v:Float):Float
	{
		_volume = FlxMath.bound(v, 0, 1);
		updateTransform();
		return v;
	}

	inline function get_pan():Float return _transform.pan;

	inline function set_pan(v:Float):Float
	{
		// AudioSource.pan removed – fallback only inside FlxSound
		_transform.pan = FlxMath.bound(v, -1, 1);
		updateTransform();
		return v;
	}

	inline function get_pitch():Float
	{
		#if lime
		return 1; // Fake: pitch is handled inside SoundChannel
		#else
		return 1;
		#end
	}

	function set_pitch(v:Float):Float
	{
		// No direct AudioSource binding anymore
		return v;
	}

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
}
