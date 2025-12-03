package graphics;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.math.FlxMatrix;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.graphics.frames.FlxFrame;



import graphics.AtlasFrames;
import openfl.utils.Assets;
import openfl.geom.ColorTransform;

/**
 * An FlxSprite rendered through an FlxFrameate.
 * Used to help implement sprites that are texture atlas.
 */
class FlxAtlasSprite extends FlxFrameate
{
    /**
     * The current animation data being played.
     */
    public var curAnim(get, null):FlxSymbol;

    function get_curAnim():FlxSymbol
    {
        return anim.curSymbol;
    }

    /**
     * The name of the current animation.
     */
    public var curAnimName(get, null):String;

    function get_curAnimName():String
    {
        @:privateAccess
        for (name => symbol in anim.animsMap)
        {
            if (symbol.instance.symbol.name == name)
            {
                return name;
            }
        }
        return '';
    }

    /**
     * A list of all of the animations this sprite has.
     */
    public var animations(get, null):Array<String>;

    function get_animations():Array<String>
    {
        var list:Array<String> = [];
        @:privateAccess
        for (i in anim.animsMap.keys())
        {
            list.push(i);
        }
        return list;
    }

    /**
     * Dispatched when an animation is played.
     */
    public var onStart(default, null):FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

    public function new(X:Float = 0, Y:Float = 0, ?directoryPath:String, ?Settings:Settings)
    {
        super(X, Y, directoryPath, Settings);
    }

    /**
     * Loads an atlas file.
     * @param Path The asset path for the atlas.
     */
    public override function loadAtlas(Path:String)
    {
        if (!Assets.exists('$Path/Animation.json') && haxe.io.Path.extension(Path) != "zip")
        {
            FlxG.log.error('Animation file not found in specified path: "$Path", have you written the correct path?');
            return;
        }

        // FIX: loadSeparateAtlas does not exist in older FlxFrameate versions.
        // Use loadAtlas() instead for max compatibility.
        loadAtlasFromData(atlasSetting(Path), AtlasFrames.textureAtlas(Path));
    }

    // Wrapper to normalize API differences
    inline function loadAtlasFromData(settings:Dynamic, frames:FlxAtlasFrames)
    {
        #if (flxanimate >= "1.4.0")
        loadAtlas(settings, frames);
        #else
        // Older flxanimate uses a different signature
        this.load(settings, frames);
        #end
    }

    /**
     * Plays a given animation.
     */
    public function playAnimation(name:String, force:Bool = false, reverse:Bool = false, frame:Int = 0)
    {
        if ([null, ''].contains(name))
            return;

        anim.play(name, force, reverse, frame);
        onStart.dispatch(name);
    }

    /**
     * Adds a new animation by the prefix.
     */
    public inline function addByPrefix(name:String, prefix:String, frameRate:Int, looped:Bool)
    {
        anim.addBySymbol(name, prefix, frameRate, looped);
    }

    /**
     * Adds a new animation based on a given animation's list of frames.
     */
    public inline function addByIndices(name:String, prefix:String, frameRate:Int, looped:Bool = false, Indices:Array<Int>)
    {
        anim.addBySymbolIndices(name, prefix, Indices, frameRate, looped);
    }

    /**
     * Removes a given animation from the sprite.
     */
    public inline function remove(name:String):Bool
    {
        @:privateAccess
        if (animationExists(name))
        {
            var animation = anim.animsMap.get(name);
            anim.animsMap.remove(name);
            animation.instance.destroy();
            return true;
        }
        return false;
    }

    /**
     * Pauses the current animation.
     */
    public function pause()
    {
        anim.pause();
    }

    /**
     * Resumes the current animation.
     */
    public function resume()
    {
        @:privateAccess
        anim.isPlaying = true;
    }

    /**
     * Checks whether the given animation exists within the sprite.
     */
    public inline function animationExists(name:String):Bool
    {
        // FIX: existsByName does not exist in your version of FlxFrameate!
        #if (flxanimate >= "1.4.0")
        return anim.// REMOVED_ANIMATE // existsByName(name);
        #else
        return anim.animsMap.exists(name);
        #end
    }

    /**
     * Gets an animation data symbol from a given name.
     */
    public inline function getByName(name:String):FlxSymbol
    {
        @:privateAccess
        return anim.symbolDictionary[anim.animsMap.get(name).instance.symbol.name];
    }
}
