package flixel.system.frontEnds;

#if FLX_SOUND_SYSTEM
import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.sound.FlxSoundGroup;
import flixel.system.ui.FlxSoundTray;
import openfl.media.Sound;
import flixel.util.FlxSignal;

/**
 * Accessed via FlxG.sound
 */
@:allow(flixel.FlxG)
class SoundFrontEnd {
	public var music:FlxSound;
	public var muted:Bool = false;

	@:deprecated("Use onVolumeChange instead")
	public var volumeHandler:Float->Void;

	// FlxSignal instead of FlxTypedSignal
	public var onVolumeChange(default, null):FlxSignal<Float->Void> = new FlxSignal<Float->Void>();

	#if FLX_KEYBOARD
	public var volumeUpKeys:Array<FlxKey> = [PLUS, NUMPADPLUS];
	public var volumeDownKeys:Array<FlxKey> = [MINUS, NUMPADMINUS];
	public var muteKeys:Array<FlxKey> = [ZERO, NUMPADZERO];
	#end

	public var soundTrayEnabled:Bool = true;

	#if FLX_SOUND_TRAY
	public var soundTray(get, never):FlxSoundTray;

	inline function get_soundTray()
		return FlxG.game.soundTray;
	#end

	public var defaultMusicGroup:FlxSoundGroup = new FlxSoundGroup();
	public var defaultSoundGroup:FlxSoundGroup = new FlxSoundGroup();

	// Replace FlxTypedGroup<FlxSound> with simple array storage
	public var list:Array<FlxSound> = [];

	public var volume(default, set):Float = 1;

	// -------------------------------------------------------
	// MUSIC
	// -------------------------------------------------------

	public function playMusic(asset:Dynamic, vol:Float = 1, loop = true, ?group:FlxSoundGroup):Void {
		if (group == null)
			group = defaultMusicGroup;

		if (music == null)
			music = new FlxSound();
		else if (music.playing)
			music.stop();

		music.loadEmbedded(asset, loop);
		music.volume = vol;
		music.persist = true;
		group.add(music);
		music.play();
	}

	// -------------------------------------------------------
	// SOUND PLAYBACK
	// -------------------------------------------------------

	public function load(?asset:Dynamic, vol:Float = 1, loop = false, ?group:FlxSoundGroup, autoDestroy = false, autoPlay = false, ?url:String,
			?onComplete:Void->Void, ?onLoad:Void->Void):FlxSound {
		var s:FlxSound = new FlxSound();
		list.push(s);

		if (asset != null) {
			s.loadEmbedded(asset, loop, autoDestroy, onComplete);
			loadHelper(s, vol, group, autoPlay);
			if (onLoad != null)
				onLoad();
		} else if (url != null) {
			s.loadStream(url, loop, autoDestroy, onComplete);
			loadHelper(s, vol, group);
		}

		return s;
	}

	function loadHelper(s:FlxSound, vol:Float, group:FlxSoundGroup, autoPlay = false):FlxSound {
		if (group == null)
			group = defaultSoundGroup;

		s.volume = vol;
		group.add(s);

		if (autoPlay)
			s.play();
		return s;
	}

	public inline function play(asset:Dynamic, vol = 1.0, loop = false, ?group:FlxSoundGroup, autoDestroy = true, ?onComplete:Void->Void):FlxSound {
		var s = new FlxSound();
		list.push(s);

		s.loadEmbedded(asset, loop, autoDestroy, onComplete);
		return loadHelper(s, vol, group, true);
	}

	// -------------------------------------------------------
	// PAUSE / RESUME
	// -------------------------------------------------------

	public function pause():Void {
		if (music != null && music.playing)
			music.pause();

		for (s in list)
			if (s != null && s.playing)
				s.pause();
	}

	public function resume():Void {
		if (music != null)
			music.resume();

		for (s in list)
			if (s != null)
				s.resume();
	}

	// -------------------------------------------------------
	// FOCUS EVENTS
	// -------------------------------------------------------

	@:allow(flixel.FlxGame)
	function onFocusLost():Void {
		if (music != null)
			music.onFocusLost();

		for (s in list)
			if (s != null)
				s.onFocusLost();
	}

	@:allow(flixel.FlxGame)
	function onFocus():Void {
		if (music != null)
			music.onFocus();

		for (s in list)
			if (s != null)
				s.onFocus();
	}

	// -------------------------------------------------------
	// VOLUME
	// -------------------------------------------------------

	public function changeVolume(a:Float):Void {
		muted = false;
		volume += a;
		showSoundTray(a > 0);
	}

	public function toggleMuted():Void {
		muted = !muted;

		if (volumeHandler != null)
			volumeHandler(muted ? 0 : volume);

		onVolumeChange.dispatch(muted ? 0 : volume);

		showSoundTray(true);
	}

	public function showSoundTray(up:Bool = false):Void {
		#if FLX_SOUND_TRAY
		if (soundTrayEnabled && FlxG.game.soundTray != null) {
			if (up)
				soundTray.showIncrement();
			else
				soundTray.showDecrement();
		}
		#end
	}

	function set_volume(v:Float):Float {
		volume = FlxMath.bound(v, 0, 1);

		if (volumeHandler != null)
			volumeHandler(muted ? 0 : volume);

		onVolumeChange.dispatch(muted ? 0 : volume);

		return volume;
	}
}
#end
