package flixel.sound;

import flixel.sound.FlxSound;

class FlxSoundGroup
{
    public var volume:Float = 1;
    public var sounds:Array<FlxSound> = [];

    public function new() {}

    public function add(s:FlxSound):Void
    {
        if (sounds.indexOf(s) == -1)
            sounds.push(s);
    }

    public function remove(s:FlxSound):Void
    {
        var i = sounds.indexOf(s);
        if (i != -1) sounds.splice(i, 1);
    }

    public function setVolume(v:Float):Void
    {
        volume = v;
        for (s in sounds)
            s.updateTransform(); // our FlxSound supports this
    }
}
