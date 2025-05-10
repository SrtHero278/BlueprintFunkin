package scenes;

import blueprint.Game;
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
import blueprint.sound.SoundPlayer;
import blueprint.objects.Sprite;
import bindings.Glfw;

@:structInit class TitleOpt {
    public var image:Texture;
    public var onSelect:Void->Void;
    @:optional public var trySelect:Null<Void->Bool>;
}

class Title extends BaseMenu {
    var options:Array<TitleOpt>;
    var logo:Sprite;
    var sound:SoundPlayer;
    var leftArrow:Sprite;
    var rightArrow:Sprite;
    var optSprite:Sprite;
    var targetScale:Float = 0.9;

    public function new() {
        super();
        Settings.load("tempOptions.json");

        options = [{
            image: Texture.getCachedTex(Paths.image("menus/titleOpts/play")),
            onSelect: function() {
                subMenu = new SongList();
                add(subMenu);
            },
            trySelect: SongList.trySelect
        }, {
            image: Texture.getCachedTex(Paths.image("menus/titleOpts/options")),
            onSelect: function() {
                subMenu = new OptionList();
                add(subMenu);
            }
        }, {
            image: Texture.getCachedTex(Paths.image("menus/titleOpts/mods")),
            onSelect: function() {
                subMenu = new ModsList();
                add(subMenu);
            },
            trySelect: ModsList.trySelect
        }];

        Song.setCurrentAsBasic("menus/music", "Freaky Menu", 102);
        Song.current.looping = true;
        Song.current.play();
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
        Conductor.update(elapsed);
    }

    override function keyDown(keyCode:Int, scanCode:Int, mods:Int) {
        if (keyCode == Glfw.KEY_8) {
            Game.changeSceneTo(scenes.CharEdit);
        }

        if (keyCode == acceptKeybind && cancelInput)
            acceptFinish(sound);
        else
            super.keyDown(keyCode, scanCode, mods);
    }

    override function changeItem(direction:Int) {
        optSprite.texture = options[curItem].image;
        leftArrow.position.x = 640 - optSprite.width * 0.5 - 25;
        rightArrow.position.x = 640 + optSprite.width * 0.5 + 25;
        sound.play(0.0);
    }

    public var acceptTwn:PropertyTween;
    function acceptFinish(snd) {
        cancelInput = false;
        sound.finished.remove(acceptFinish);
        sound.data = SoundData.getSoundData(Paths.audio("menus/scroll"));
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