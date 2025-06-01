package scenes;

import sys.FileSystem;
import blueprint.text.Text;
import blueprint.objects.Camera;
import blueprint.graphics.Texture;
import blueprint.objects.Sprite;
import blueprint.objects.AnimatedSprite;
import blueprint.objects.Group;
import blueprint.tweening.EaseList;
import blueprint.Game;
import bindings.Glfw;
import bindings.CppHelpers;
import math.Vector4;
import music.GameSong;
import objects.*;

class Gameplay extends blueprint.Scene {
	// Note and Event Stuff
	public var stats:GameStats;
	public var curSong:GameSong;
	public var queuedNote:Int = 0;
	public var queuedEvent:Int = 0;
	public var strumlines:Array<Strumline> = [];

	// HUD Stuff
	final white:Color = new Color(1.0);
	final red:Color = new Color(1.0, 0.0, 0.0, 1.0);

	public var fps:Text;
	public var countedFrames:Int = 0;
	public var untilFpsRegister:Float = 1;

	public var hud:Group;
	public var hudCamera:Camera;
	public var leftIcon:HealthIcon;
	public var rightIcon:HealthIcon;
	public var healthBar:CircleBar;
	public var timeBar:CircleBar;

	public var scoreNums:Group;
	public var missNums:Group;
	public var accNums:Group;
	public var curAcc:String = "100";
	public var missIcon:Sprite;
	public var rankIcon:Sprite;
	public var accIcon:Sprite;

	public var rating:RatingPopup;

	// Background Stuff
	public var stage:Stage;
	public var player:Character;
	public var opponent:Character;
	public var spectator:Character;
	public var bumpInterval:Int = 4;
	public var bumpStrength:Float = 1.0;

	// Script Stuff
	public var eventScripts:Map<String, HScript> = [];
	public var scripts:Array<HScript> = [];

	public function new() {
		super();
		curSong = cast Song.current;
		curSong.loadEvents();
		Conductor.reset(curSong.timingPoints[0].bpm);
		Conductor.onBeat.add(beatHit);

		stats = new GameStats();

		add(stage = new Stage(curSong.stage));
		mainCamera.targetLerp = 0.05 * 60;
		mainCamera.zoom.set(stage.defaultZoom);
		player = new Character(0, 0, curSong.chars[0]);
		opponent = new Character(0, 0, curSong.chars[1]);
		spectator = new Character(0, 0, curSong.chars[2]);
		stage.addChars(player, opponent, spectator);

		add(hud = new Group(640, 360));
		leftIcon = new HealthIcon(85 - 640, 360 - 60, opponent.data.icon);
		leftIcon.invertHealth = true;
		addToHud(leftIcon);
		rightIcon = new HealthIcon(640 - 85, 360 - 60, player.data.icon);
		addToHud(rightIcon);

		timeBar = new CircleBar(165 - 640, 360 - 60, Paths.image("game/clock"));
		timeBar.emptyTint.set(0.25, 0.25, 0.25, 1.0);
		timeBar.centerPoint.setFull(0.4875, 0.6625);
		timeBar.angleOffset = 7.5;
		timeBar.percent = 0;
		timeBar.invert = true;
		addToHud(timeBar);

		healthBar = new CircleBar(640 - 165, 360 - 60, Paths.image("game/heart"));
		healthBar.emptyTint.setFull(0.25, 0.25, 0.25, 1.0);
		healthBar.tint.setFull(0.0, 1.0, 0.45, 1.0);
		healthBar.centerPoint.setFull(0.635, 0.4125);
		healthBar.angleOffset = -32.5;
		healthBar.percent = 0;
		healthBar.invert = true;
		addToHud(healthBar);

		rankIcon = new Sprite(225 - 640, 300, Paths.image("game/ranks/" + stats.curRank.image));
		rankIcon.anchor.y = 1.0;
		addToHud(rankIcon);
		addToHud(scoreNums = new Group(225 - 640, 345 - 43 * 0.5));
		updateNums("0", scoreNums, 35, white);
		accIcon = new Sprite(640 - 225, 345, Paths.image("game/accIcon"));
		accIcon.anchor.y = 1.0;
		addToHud(accIcon);
		addToHud(accNums = new Group(640 - 225, 345 - 43 * 0.5));
		updateNums("100", accNums, -35, white);
		missIcon = new Sprite(640 - 225 - 35, 300, Paths.image("game/missIcon"));
		missIcon.anchor.y = 1.0;
		addToHud(missIcon);
		addToHud(missNums = new Group(640 - 225 + 35, 300 - 43 * 0.5));
		updateNums("0", missNums, -35, white);

		strumlines.push(new Strumline(-0.25 - (1 / 16) * CppHelpers.boolToInt(Settings.centerField), curSong.speed));
		strumlines[0].scale.set(1.0 - 0.5 * CppHelpers.boolToInt(Settings.centerField));
		strumlines[0].hit.add(noteHit);
		strumlines[0].missed.add(noteMissed);
		strumlines.push(new Strumline(0.25 * CppHelpers.boolToInt(!Settings.centerField), curSong.speed));
		strumlines[1].hit.add(noteHit);
		strumlines[1].missed.add(noteMissed);
		strumlines[1].keybinds = [Settings.leftBinds, Settings.downBinds, Settings.upBinds, Settings.rightBinds];

		for(i in 0...strumlines.length) {
			hud.add(strumlines[i]);
			strumlines[i].characters.push([opponent, player][i]);
		}

		addToHud(rating = new RatingPopup());
		
		hud.add(fps = new Text(0, -150, Paths.font("montserrat"), 24, "? FPS"));
		fps.tint.setFull(0, 0, 0, 1);

		hudCamera = new Camera();
		hud.cameras = [hudCamera];

		loadScripts();
		setOnScripts("scene", this);
		callScripts("create");

		DefaultEvents.game = this;
		DefaultEvents.interpetEvents(curSong.events);
		DefaultEvents.retarget(0);
		mainCamera.position.copyFrom(mainCamera.targetPosition);
		curSong.time = 0;
		curSong.looping = false;
		curSong.play();
		curSong.finished.add(songFinished);
	}

	public function addToHud(obj:Sprite, ?adjustToDownscroll:Bool = true) {
		if (adjustToDownscroll && Settings.downscroll) {
			obj.position.y = -obj.position.y;
			obj.anchor.y = 1.0 - obj.anchor.y;
		}
		hud.add(obj);
	}

	override function update(elapsed:Float) {
		callScripts("preUpdate", [elapsed]);

		++countedFrames;
		untilFpsRegister -= elapsed;
		if (untilFpsRegister <= 0.0) {
			untilFpsRegister = 1.0;
			fps.text = countedFrames + " FPS";
			countedFrames = 0;
		}

		Conductor.update(elapsed);
		mainCamera.zoom.set(MathExtras.lerp(mainCamera.zoom.x, stage.defaultZoom, elapsed * 60 * 0.05));
		hudCamera.zoom.set(MathExtras.lerp(hudCamera.zoom.x, 1, elapsed * 60 * 0.05));

		var bumpScale = MathExtras.lerp(0.75 * 1.2, 0.75, EaseList.quadOut(Math.abs(Conductor.floatBeat % 1)));
		leftIcon.scale.setFull(bumpScale * leftIcon.iconScale, bumpScale * leftIcon.iconScale);
		rightIcon.scale.setFull(-bumpScale * rightIcon.iconScale, bumpScale * rightIcon.iconScale);

		for (str in strumlines)
			str.hitWindow = stats.hitWindow;
		healthBar.percent = MathExtras.lerp(healthBar.percent, stats.health / stats.maxHealth, elapsed * 3);
		timeBar.percent = Conductor.position / curSong.length;

		for (num in scoreNums.members)
			num.position.y = MathExtras.lerp(num.position.y, 43 * 0.5, elapsed * 9);
		scoreNums.tint = MathExtras.lerp(scoreNums.tint, white, elapsed * 5);
		
		for (num in missNums.members)
			num.position.y = MathExtras.lerp(num.position.y, 43 * 0.5, elapsed * 9);
		missNums.tint = MathExtras.lerp(missNums.tint, white, elapsed * 5);

		for (num in accNums.members)
			num.position.y = MathExtras.lerp(num.position.y, 43 * 0.5, elapsed * 9);
		accNums.tint = MathExtras.lerp(accNums.tint, white, elapsed * 5);

		while (queuedNote < curSong.notes.length && curSong.notes[queuedNote].time - Conductor.position < 2) {
			final data = curSong.notes[queuedNote];
			final note = new Note(data);
			note.setLength(data.length, strumlines[data.char].speed);
			note.holdScale = strumlines[data.char].scrollMult;
			strumlines[data.char].notes.add(note);
			queuedNote++;
		}
		while (queuedEvent < curSong.events.length && Conductor.position >= curSong.events[queuedEvent].time) {
			if (curSong.events[queuedEvent].func != null)
				Reflect.callMethod(null, curSong.events[queuedEvent].func, curSong.events[queuedEvent].params);
			queuedEvent++;
		}
		
		for (object in members)
			object.update(elapsed);
		
		callScripts("update", [elapsed]);
	}

	function songFinished(song:Song) {
		Game.changeSceneTo(scenes.Title);
	}

	function beatHit(beat:Int) {
		callScripts("beatHit", [beat]);

		if (bumpInterval > 0 && beat % bumpInterval == 0) {
			hudCamera.zoom += 0.015 * bumpStrength;
			mainCamera.zoom += 0.03 * bumpStrength;
		}
	}

	function noteHit(str:Strumline, note:Note) {
		if (str.isCpu) return;

		++stats.combo;
		var judge = stats.getJudgement(Math.abs(note.hitTime - Conductor.position));
		rating.popup(judge, stats, note.hitTime - Conductor.position);

		updateNums(Std.string(stats.score), scoreNums, 35, stats.curRank.color);

		var newAcc = Std.string(Math.floor(stats.accuracy * 100));
		if (curAcc != newAcc) {
			curAcc = newAcc;
			updateNums(newAcc, accNums, -35, stats.curRank.color);
		}

		var rankPath = Paths.image("game/ranks/" + stats.curRank.image);
		if (rankIcon.texture.path != rankPath)
			rankIcon.texture = Texture.getCachedTex(rankPath);

		leftIcon.health = stats.health / stats.maxHealth;
		rightIcon.health = stats.health / stats.maxHealth;
	}
	function noteMissed(str:Strumline, note:Note) {
		if (str.isCpu) return;

		stats.combo = 0;
		stats.addMiss();
		updateNums(Std.string(stats.score), scoreNums, 35, red);
		updateNums(Std.string(stats.misses), missNums, -35, red);
		missIcon.position.x = missNums.position.x + missNums.members[0].position.x - 35;

		var newAcc = Std.string(Math.floor(stats.accuracy * 100));
		if (curAcc != newAcc) {
			curAcc = newAcc;
			updateNums(newAcc, accNums, -35, red);
		}

		var rankPath = Paths.image("game/ranks/" + stats.curRank.image);
		if (rankIcon.texture.path != rankPath)
			rankIcon.texture = Texture.getCachedTex(rankPath);

		leftIcon.health = stats.health / stats.maxHealth;
		rightIcon.health = stats.health / stats.maxHealth;
	}

	function updateNums(stringNum:String, numbers:Group, intervalX:Float, color:Color) {
		final startX = intervalX * stringNum.length * CppHelpers.boolToInt(intervalX < 0);
		intervalX = Math.abs(intervalX);

		while (numbers.members.length > stringNum.length) {
			var spr = numbers.members[0];
			numbers.remove(spr);
			spr.destroy();
		}
		while (numbers.members.length < stringNum.length) {
			var newNum = new AnimatedSprite(startX, -10 + 43 * 0.5, Paths.sparrowXml("tallieNumber"));
			numbers.insert(0, newNum);
			newNum.anchor.y = 1.0;
			for (i in 0...10)
				newNum.addPrefixAnim(Std.string(i), i + " small");
			newNum.addPrefixAnim("-", "- small");
			newNum.playAnim("0");
		}

		numbers.tint.copyFrom(color);
		for (i in 0...numbers.members.length) {
			final num:AnimatedSprite = cast numbers.members[i];

			var lastAnim = num.curAnim;
			var newAnim = stringNum.charAt(i);
			num.playAnim(newAnim);
			if (lastAnim != newAnim)
				num.position.y = -10 + 43 * 0.5;
			num.position.x = startX + intervalX * i;
		}
	}

	override function keyDown(keyCode:Int, scanCode:Int, mods:Int) {
		for (lane in strumlines) {
			if (!lane.isCpu)
				lane.keyDown(keyCode);
		}

		switch (keyCode) {
			case Glfw.KEY_F5:
				Game.changeSceneTo(scenes.Gameplay);
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


	function loadScripts():Void {
		inline function tryScript(path):HScript {
			if (path == null) return null;

			final script = new HScript(path, "", true);
			if (script.interp != null) {
				scripts.push(script);
				return script;
			}
			return null;
		}

		for (ev in curSong.events) {
			if (!eventScripts.exists(ev.name))
				eventScripts.set(ev.name, tryScript(Paths.script("data/events/" + ev.name)));
		}
		for (ev in eventScripts.keys()) { // clear the broken scripts
			if (eventScripts[ev] == null)
				eventScripts.remove(ev);
		}

		final songScripts:String = Paths.songFile("scripts", curSong.path);
		if (Paths.exists(songScripts, true) && FileSystem.isDirectory(songScripts)) {
			for (script in FileSystem.readDirectory(songScripts)) {
				if (Paths.isScriptPath(script))
					tryScript(songScripts + "/" + script);
			}
		}

		var globalPush = [];
		for (script in Paths.folderContents("data/scripts")) {
			if (Paths.isScriptPath(script) && !globalPush.contains(script)) {
				globalPush.push(script);
				tryScript(Paths.file("data/scripts/" + script));
			}
		}

		tryScript(Paths.script("data/stages/" + stage.name));
	}

	public function getFromScripts(name:String) {
		for (script in scripts) {
			if (script.exists(name))
				return script.get(name);
		}
		return null;
	}
	public function setOnScripts(name:String, val:Dynamic) {
		for (script in scripts)
			script.set(name, val);
	}
	public function callScripts(name:String, ?args:Array<Dynamic>) {
		args = (args == null ? [] : args);
		for (script in scripts)
			script.call(name, args);
	}
}