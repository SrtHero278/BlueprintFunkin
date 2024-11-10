package scenes;

import blueprint.graphics.Texture;
import blueprint.objects.Sprite;
import math.Vector4;
import blueprint.objects.AnimatedSprite;
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
    public var hud:Group;
    public var leftIcon:HealthIcon;
    public var rightIcon:HealthIcon;
    public var healthBar:CircleBar;
    public var timeBar:CircleBar;
    public var scoreNums:Array<AnimatedSprite> = [];
    public var missNums:Array<AnimatedSprite> = [];
    public var accNums:Array<AnimatedSprite> = [];
    public var curAcc:String = "100";
    public var missIcon:Sprite;
    public var rankIcon:Sprite;
    public var accIcon:Sprite;

    // Background Stuff
    public var stage:Group;
    public var player:Character;
    public var opponent:Character;
    public var spectator:Character;

    final white:Color = new Color(1.0);
    final red:Color = new Color(1.0, 0.0, 0.0, 1.0);

    public function new() {
        super();
        curSong = cast Song.current;
        Conductor.reset(curSong.bpmChanges[0][2]);

        stats = new GameStats();

        add(stage = new Group(0, -200));
        stage.add(spectator = new Character(400, 130, curSong.chars[2]));
        stage.add(opponent = new Character(100, 100, curSong.chars[1]));
        stage.add(player = new Character(770, 100, curSong.chars[0], true));

        add(hud = new Group(640, 360));
		leftIcon = new HealthIcon(85 - 640, 360 - 60, opponent.data.icon);
        leftIcon.invertHealth = true;
		hud.add(leftIcon);
		rightIcon = new HealthIcon(640 - 85, 360 - 60, player.data.icon);
		hud.add(rightIcon);

		timeBar = new CircleBar(165 - 640, 360 - 60, Paths.image("game/clock"));
		timeBar.emptyTint.set(0.25, 0.25, 0.25, 1.0);
        timeBar.centerPoint.setFull(0.4875, 0.6625);
        timeBar.angleOffset = 7.5;
		timeBar.percent = 0;
        timeBar.invert = true;
		hud.add(timeBar);

		healthBar = new CircleBar(640 - 165, 360 - 60, Paths.image("game/heart"));
		healthBar.emptyTint.setFull(0.25, 0.25, 0.25, 1.0);
		healthBar.tint.setFull(0.0, 1.0, 0.45, 1.0);
        healthBar.centerPoint.setFull(0.635, 0.4125);
        healthBar.angleOffset = -32.5;
		healthBar.percent = 0;
        healthBar.invert = true;
		hud.add(healthBar);

        rankIcon = new Sprite(225 - 640, 300, Paths.image("game/ranks/" + stats.curRank.image));
        rankIcon.anchor.y = 1.0;
        hud.add(rankIcon);
        updateNums("0", scoreNums, 225 - 640, 35, 345, white);
        accIcon = new Sprite(640 - 225, 345, Paths.image("game/accIcon"));
        accIcon.anchor.y = 1.0;
        hud.add(accIcon);
        updateNums("100", accNums, 640 - 225, -35, 345, white);
        missIcon = new Sprite(640 - 225 - 35, 300, Paths.image("game/missIcon"));
        missIcon.anchor.y = 1.0;
        hud.add(missIcon);
        updateNums("0", missNums, 640 - 225 + 35, -35, 300, white);

        strumlines.push(new Strumline(-0.25, curSong.speed));
        strumlines[0].hit.add(noteHit);
        strumlines[0].missed.add(noteMissed);
        strumlines.push(new Strumline(0.25, curSong.speed));
        strumlines[1].hit.add(noteHit);
        strumlines[1].missed.add(noteMissed);
        strumlines[1].keybinds = [[Glfw.KEY_A], [Glfw.KEY_S], [Glfw.KEY_KP_5], [Glfw.KEY_KP_6]];

        for(i in 0...strumlines.length) {
            hud.add(strumlines[i]);
            strumlines[i].characters.push([opponent, player][i]);
        }

        curSong.time = 0;
        curSong.looping = false;
        curSong.play();
    }

    override function update(elapsed:Float) {
        Conductor.update(elapsed);
        // strumlines[0].rotation = 15 * Math.sin(Conductor.floatBeat * Math.PI * 0.25);
        // strumlines[1].rotation = -15 * Math.sin(Conductor.floatBeat * Math.PI * 0.25);

        var bumpScale = MathExtras.lerp(0.75 * 1.2, 0.75, EaseList.quadOut(Math.abs(Conductor.floatBeat % 1)));
        leftIcon.scale.setFull(bumpScale * leftIcon.iconScale, bumpScale * leftIcon.iconScale);
        rightIcon.scale.setFull(-bumpScale * rightIcon.iconScale, bumpScale * rightIcon.iconScale);

        for (str in strumlines)
            str.hitWindow = stats.hitWindow;
        healthBar.percent = MathExtras.lerp(healthBar.percent, stats.health / stats.maxHealth, elapsed * 3);
		timeBar.percent = Conductor.position / curSong.audio[0].length;

        for (num in scoreNums) {
            num.position.y = MathExtras.lerp(num.position.y, 345, elapsed * 9);
            num.tint = MathExtras.lerp(num.tint, white, elapsed * 5);
        }
        for (num in missNums) {
            num.position.y = MathExtras.lerp(num.position.y, 300, elapsed * 9);
            num.tint = MathExtras.lerp(num.tint, white, elapsed * 5);
        }
        for (num in accNums) {
            num.position.y = MathExtras.lerp(num.position.y, 345, elapsed * 9);
            num.tint = MathExtras.lerp(num.tint, white, elapsed * 5);
        }

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
        updateNums(Std.string(stats.score), scoreNums, 225 - 640, 35, 335, stats.curRank.color);

        var newAcc = Std.string(Math.floor(stats.accuracy * 100));
        if (curAcc != newAcc) {
            curAcc = newAcc;
            updateNums(newAcc, accNums, 640 - 225, -35, 335, stats.curRank.color);
        }

        var rankPath = Paths.image("game/ranks/" + stats.curRank.image);
        if (rankIcon.texture.path != rankPath)
            rankIcon.texture = Texture.getCachedTex(rankPath);

        leftIcon.health = stats.health / stats.maxHealth;
        rightIcon.health = stats.health / stats.maxHealth;
    }
    function noteMissed(str:Strumline, note:Note) {
        if (str.isCpu) return;

        stats.addMiss();
        updateNums(Std.string(stats.score), scoreNums, 225 - 640, 35, 335, red);
        updateNums(Std.string(stats.misses), missNums, 640 - 225 + 35, -35, 290, red);
        missIcon.position.x = missNums[0].position.x - 35;

        var newAcc = Std.string(Math.floor(stats.accuracy * 100));
        if (curAcc != newAcc) {
            curAcc = newAcc;
            updateNums(newAcc, accNums, 640 - 225, -35, 335, red);
        }

        var rankPath = Paths.image("game/ranks/" + stats.curRank.image);
        if (rankIcon.texture.path != rankPath)
            rankIcon.texture = Texture.getCachedTex(rankPath);

        leftIcon.health = stats.health / stats.maxHealth;
        rightIcon.health = stats.health / stats.maxHealth;
    }

	function updateNums(stringNum:String, numArray:Array<AnimatedSprite>, startX:Float, intervalX:Float, bounceY:Float, color:Color) {
		if (intervalX < 0) {
			startX += intervalX * stringNum.length;
			intervalX *= -1;
		}

		while (numArray.length > stringNum.length) {
			var spr = numArray.shift();
			hud.remove(spr);
			spr.destroy();
		}
		while (numArray.length < stringNum.length) {
            var newNum = new AnimatedSprite(startX, bounceY, Paths.sparrowXml("tallieNumber"));
			numArray.insert(0, newNum);
            newNum.anchor.y = 1.0;
			for (i in 0...10)
				newNum.addPrefixAnim(Std.string(i), i + " small");
			newNum.addPrefixAnim("-", "- small");
			newNum.playAnim("0");
			hud.add(newNum);
		}

		for (i in 0...numArray.length) {
			var lastAnim = numArray[i].curAnim;
            var newAnim = stringNum.charAt(i);
			numArray[i].playAnim(newAnim);
			if (lastAnim != newAnim)
				numArray[i].position.y = bounceY;
			numArray[i].position.x = startX + intervalX * i;
            numArray[i].tint.copyFrom(color);
		}
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