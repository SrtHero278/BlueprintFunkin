package scenes;

import blueprint.tweening.EaseList;
import blueprint.Game;
import blueprint.objects.Group;
import bindings.Glfw;
import music.GameSong;
import objects.*;

class Gameplay extends blueprint.Scene {
    // Note Stuff
    public var stats:GameStats;
    public var curSong:GameSong;
    public var queuedNote:Int;
    public var strumlines:Array<Strumline> = [];

    // HUD Stuff
    public var leftIcon:HealthIcon;
    public var rightIcon:HealthIcon;
    public var healthBar:CircleBar;
    public var timeBar:CircleBar;

    // Background Stuff
    public var stage:Group;
    public var player:Character;
    public var opponent:Character;
    public var spectator:Character;

    public function new() {
        super();
        curSong = cast Song.current;
        Conductor.reset(curSong.bpmChanges[0][2]);

        add(stage = new Group(-640, -540));
        stage.add(spectator = new Character(400, 130, curSong.chars[2]));
        stage.add(opponent = new Character(100, 100, curSong.chars[1]));
        stage.add(player = new Character(770, 100, curSong.chars[0], true));

        stats = new GameStats();
		leftIcon = new HealthIcon(85 - 640, 360 - 60, opponent.data.icon);
		add(leftIcon);
		rightIcon = new HealthIcon(640 - 85, 360 - 60, player.data.icon);
		add(rightIcon);

		timeBar = new CircleBar(165 - 640, 360 - 60, Paths.image("game/clock"));
		timeBar.emptyTint.set(0.25, 0.25, 0.25, 1.0);
        timeBar.centerPoint.setFull(0.4875, 0.6625);
        timeBar.angleOffset = 7.5;
		timeBar.percent = 0;
        timeBar.invert = true;
		add(timeBar);

		healthBar = new CircleBar(640 - 165, 360 - 60, Paths.image("game/heart"));
		healthBar.emptyTint.setFull(0.25, 0.25, 0.25, 1.0);
		healthBar.tint.setFull(0.0, 1.0, 0.45, 1.0);
        healthBar.centerPoint.setFull(0.635, 0.4125);
        healthBar.angleOffset = -32.5;
		healthBar.percent = 0;
        healthBar.invert = true;
		add(healthBar);

        strumlines.push(new Strumline(-0.25, curSong.speed));
        strumlines[0].hit.add(noteHit);
        strumlines[0].missed.add(noteMissed);
        strumlines.push(new Strumline(0.25, curSong.speed));
        strumlines[1].hit.add(noteHit);
        strumlines[1].missed.add(noteMissed);
        strumlines[1].keybinds = [[Glfw.KEY_A], [Glfw.KEY_S], [Glfw.KEY_KP_5], [Glfw.KEY_KP_6]];

        for(i in 0...strumlines.length) {
            add(strumlines[i]);
            strumlines[i].characters.push([opponent, player][i]);
        }

        position.setFull(640, 360);
        // scale *= 0.5;

        curSong.time = 0;
        curSong.looping = false;
        curSong.play();
    }

    override function update(elapsed:Float) {
        Conductor.update(elapsed);

        var bumpScale = MathExtras.lerp(0.75 * 1.2, 0.75, EaseList.quadOut(Math.abs(Conductor.floatBeat % 1)));
        leftIcon.scale.setFull(bumpScale * leftIcon.iconScale, bumpScale * leftIcon.iconScale);
        rightIcon.scale.setFull(-bumpScale * rightIcon.iconScale, bumpScale * rightIcon.iconScale);

        for (str in strumlines)
            str.hitWindow = stats.hitWindow;
        // strumlines[0].rotation = 15 * Math.sin(Conductor.floatBeat * Math.PI * 0.25);
        // strumlines[1].rotation = -15 * Math.sin(Conductor.floatBeat * Math.PI * 0.25);
        healthBar.percent = MathExtras.lerp(healthBar.percent, stats.health / stats.maxHealth, elapsed);
		timeBar.percent = Conductor.position / curSong.audio[0].length;

        while (queuedNote < curSong.notes.length && curSong.notes[queuedNote].time - Conductor.position < 2) {
            final data = curSong.notes[queuedNote];
            final note = new Note(data);
            note.setLength(data.length, strumlines[data.char].speed);
            strumlines[data.char].notes.add(note);
            queuedNote++;
        }
        for (object in members)
			object.update(elapsed);
    }

    function noteHit(str:Strumline, note:Note) {
        if (str.isCpu) return;
        var judge = stats.getJudgement(Math.abs(note.hitTime - Conductor.position));
    }
    function noteMissed(str:Strumline, note:Note) {
        if (str.isCpu) return;
        stats.addMiss();
    }

    override function keyDown(keyCode:Int, scanCode:Int, mods:Int) {
        for (lane in strumlines) {
            if (!lane.isCpu)
                lane.keyDown(keyCode);
        }

        switch (keyCode) {
            case Glfw.KEY_ESCAPE:
                Game.changeSceneTo(scenes.Title);
        }
    }

    override function keyUp(keyCode:Int, scanCode:Int, mods:Int) {
        for (lane in strumlines) {
            if (!lane.isCpu)
                lane.keyUp(keyCode);
        }
    }
}