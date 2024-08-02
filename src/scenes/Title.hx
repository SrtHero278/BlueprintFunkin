package scenes;

import blueprint.tweening.BaseTween;
import objects.SparrowText;
import objects.HealthIcon;
import blueprint.sound.formats.OggFormat;
import math.Vector4.Color;
import blueprint.tweening.EaseList;
import blueprint.tweening.PropertyTween;
import blueprint.sound.SoundData;
import blueprint.text.Text;
import blueprint.graphics.Texture;
import math.MathExtras;
import music.Conductor;
import blueprint.sound.SoundPlayer;
import blueprint.objects.Sprite;
import bindings.Glfw;

@:structInit class TitleOpt {
    public var image:Texture;
    public var onSelect:Void->Void;
    public var trySelect:Null<Void->Bool>;
}

class Title extends BaseMenu {
    var options:Array<TitleOpt>;
    var logo:Sprite;
    var music:SoundPlayer;
    var sound:SoundPlayer;
    var leftArrow:Sprite;
    var rightArrow:Sprite;
    var optSprite:Sprite;
    var targetScale:Float = 0.9;

    var debug:Text;
    var countedFrames:Int = 0;
    var tmr:Float = 0;

    public function new() {
        super();
        options = [{
            image: Texture.getCachedTex(Paths.image("menus/play")),
            onSelect: function() {
                subMenu = new SongList();
                add(subMenu);
            },
            trySelect: SongList.trySelect
        }];

        Conductor.reset(102);
        Conductor.beatOffset = -0.05;
        Conductor.onBeat.add(beatHit);
        keybinds = [Glfw.KEY_LEFT, Glfw.KEY_RIGHT];

        add(new Sprite(640, 360, Paths.image("menus/BG")));

        logo = new Sprite(640, 360, Paths.image("menus/logo"));
        logo.scale.set(targetScale);
        add(logo);

        add(optSprite = new Sprite(640, 650));
        optSprite.texture = options[curItem].image;
        add(leftArrow = new Sprite(640 - optSprite.width * 0.5 - 25, 650, Paths.image("menus/arrow")));
        add(rightArrow = new Sprite(640 + optSprite.width * 0.5 + 25, 650, Paths.image("menus/arrow")));
        rightArrow.flipX = true;

        add(debug = new Text(10, 10, Paths.font("montserrat"), 20, "4114\n4114"));
        debug.anchor.set();

        music = new SoundPlayer(Paths.audio("menus/music"), true, true, 0.5);
        sound = new SoundPlayer(Paths.audio("menus/scroll"), false, false, 1.0);

        acceptTwn = new PropertyTween(this, {
            "targetScale": 0.5,
            "logo.position.x": 1050.0,
            "logo.position.y": 125.0,
            "optSprite.position.y": 1000.0,
            "leftArrow.position.y": 1000.0,
            "rightArrow.position.y": 1000.0
        }, 1, EaseList.backIn);
        acceptTwn.deleteWhenDone = false;
        acceptTwn.enabled = false; // save it for later.
    }

    function padDecimal(val:Float) {
        var string = Std.string(val);
        var dotIndex = string.indexOf(".");
        if (dotIndex < 0)
            return string + ".000";
        while (string.substring(dotIndex, string.length).length < 4)
            string += "0";
        return string;
    }

    override function update(elapsed:Float) {
        super.update(elapsed);

        logo.scale.set(MathExtras.lerp(logo.scale.x, targetScale, elapsed * 10));
        Conductor.position = music.time - elapsed;
        Conductor.update(elapsed);

        tmr += elapsed;
        countedFrames++;
        if (tmr >= 1.0) {
            tmr = 0;
            debug.text = Std.string(countedFrames);
            countedFrames = 0;
        }
    }

    override function changeItem() {
        optSprite.texture = options[curItem].image;
        leftArrow.position.x = 640 - optSprite.width * 0.5 - 25;
        rightArrow.position.x = 640 + optSprite.width * 0.5 + 25;
        sound.play(0.0);
    }

    var acceptTwn:PropertyTween;
    function acceptFinish(snd) {
        cancelInput = false;
        sound.finished.remove(acceptFinish);
        acceptTwn.reverse = false;
        acceptTwn.start();
        options[curItem].onSelect();
    }

    override function accept() {
        if (options[curItem].trySelect != null && !options[curItem].trySelect())
            return;

        cancelInput = true;
        sound.data = SoundData.getSoundData(Paths.audio("menus/confirm"));
        sound.play(0.0);
        sound.finished.add(acceptFinish);
        new PropertyTween(this, {tint: new Color(2.0)}, 0.5, EaseList.quadOut).reverse = true;
    }

    override function getMaxItems():Int {
        return options.length;
    }

    function beatHit(beat:Int) {
        logo.scale.set(targetScale * 1.1);
    }
}