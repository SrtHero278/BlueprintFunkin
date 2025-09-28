package scenes;

import blueprint.sound.SoundPlayer;
import bindings.Glfw;
import blueprint.objects.Sprite;

class SoundTray extends blueprint.Scene {
    var shake:Float = 0;
    var timer:Float = 0;
    var lerpVol:Float = 1;
    var lerpYPos:Float = 0;
    var lerpAlpha:Float = 0;

    var bg:Sprite;
    var empty:Sprite;
    var fill:Sprite;

    // blame phantom
    var barPoints:Array<Float> = [0, 21, 38, 55, 73, 92, 113, 137, 158, 180, 203];

    var sndDown:SoundPlayer;
    var sndUp:SoundPlayer;
    var sndMax:SoundPlayer;

    public function new() {
        super();
        position.setFull(640, -146 * 0.7);
        scale.set(0.7);

        add(bg = new Sprite(0, 0, Paths.image("soundtray/volumebox")));
        bg.anchor.y = 0;

        add(empty = new Sprite(0, 16, Paths.image("soundtray/bars")));
        empty.position.x -= empty.width * 0.5;
        empty.anchor.set();
        empty.tint.a = 0.5;

        add(fill = new Sprite(empty.position.x, empty.position.y, Paths.image("soundtray/bars")));
        fill.anchor.set();

        mainCamera.keepOnSwitch = true;
        mainCamera.layer = 99;

        sndDown = new SoundPlayer(Paths.audio("soundtray/down"));
        sndDown.keepOnSwitch = true;
        sndUp = new SoundPlayer(Paths.audio("soundtray/up"));
        sndUp.keepOnSwitch = true;
        sndMax = new SoundPlayer(Paths.audio("soundtray/max"));
        sndMax.keepOnSwitch = true;
    }

    override function update(elapsed:Float) {
        super.update(elapsed);
        lerpVol = MathExtras.lerp(lerpVol, Settings.volume, elapsed * 15);
        final snapVol = Math.round(lerpVol * 50) * 0.02;
        final barIdx = Math.floor(snapVol * 10);
        fill.sourceRect.width = barIdx == 10 ? barPoints[10] : MathExtras.lerp(barPoints[barIdx], barPoints[barIdx + 1], (snapVol * 10) % 1);
        position.y = MathExtras.lerp(position.y, lerpYPos, elapsed * 15);
        tint.a = MathExtras.lerp(tint.a, lerpAlpha, elapsed * 15);

        timer = Math.max(timer - elapsed, 0);
        if (timer <= 0.0) {
            lerpYPos = -146 * 0.7;
            lerpAlpha = 0;
        }

        shake = Math.max(shake - elapsed * 6, 0);
        if (shake <= 0.0) {
            positionOffset.setFull(0, 0);
        } else {
            positionOffset.x = (Math.random() * 2 - 1) * shake;
            positionOffset.y = (Math.random() * 2 - 1) * shake;
        }

        if (tint.a <= 0)
            frozen = true;
    }

    override function keyDown(keyCode:Int, scanCode:Int, mods:Int) {
        switch (keyCode) {
            case Glfw.KEY_0 | Glfw.KEY_KP_0:
                Settings.muted = !Settings.muted;
                fill.visible = !Settings.muted;
                sndUp.play(0.0);
                frozen = false;
                timer = 1.5;
                lerpYPos = 10;
                lerpAlpha = 1;
            case Glfw.KEY_EQUAL | Glfw.KEY_KP_ADD:
                Settings.muted = false;
                fill.visible = true;
                if (Settings.volume >= 1.0) {
                    shake = 3;
                    sndMax.play(0.0);
                } else {
                    Settings.volume += 0.1;
                    sndUp.play(0.0);
                }
                frozen = false;
                timer = 1.5;
                lerpYPos = 10;
                lerpAlpha = 1;
            case Glfw.KEY_MINUS | Glfw.KEY_KP_SUBTRACT:
                Settings.muted = false;
                fill.visible = true;
                Settings.volume -= 0.1;
                sndDown.play(0.0);
                frozen = false;
                timer = 1.5;
                lerpYPos = 10;
                lerpAlpha = 1;
        }
    }
}