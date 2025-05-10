package objects;

import haxe.ds.Vector;
import math.Vector2;
import haxe.Json;
import sys.io.File;
import blueprint.objects.Sprite;

using StringTools;

// a replica of a replica in a way lol
// this is a similar format to kade refreshed, which is a similar format to kade 1.8
typedef CharJson = {
	var spritesheet:String;
	var icon:String;

	var faceLeft:Bool;
	var offsets:CharOffsets;
	var animations:Array<JsonAnim>;

	var ?scale:Float;
	var ?scaleAffectsOffset:Bool;
	var ?antialiasing:Bool;
	var ?singLength:Float;
}

typedef JsonAnim = {
	var name:String;
	var prefix:String;
	var offsets:Array<Float>;

	var ?looped:Bool;
	var ?frameRate:Float;
	var ?frameIndices:Array<Int>;

	var ?animType:String; // Either one of the dance types below. (enum abstract AnimType)
	var ?chainAnim:String; // If the type is CHAIN, it will play this anim after it is done.
}

typedef CharOffsets = {
	var x:Float;
	var y:Float;
	var camX:Float;
	var camY:Float;
}

enum abstract AnimType(Int) from Int to Int {
	var DANCE_AFTER = -1; // the default. will keep it's animation until its finished and dance afterwards.
	var CAN_DANCE = 0; // wont be added to the dance list, but can be replaced by dancing or singing.
	var DANCING = 1; // similar to CAN_DANCE, but will be added to the dance list.
	var SINGING = 2;
	var CHAIN = 3;
}

class Character extends blueprint.objects.AnimatedSprite {
	public var offsets:Map<String, Array<Float>> = [];
	public var types:Map<String, AnimType> = [];
	public var chains:Map<String, String> = [];

	public var data:CharJson;
	public var curChar:String = "";

	public var facingLeft:Bool = false;
	public var debugMode:Bool = false;

	public var camOffset:Vector2 = new Vector2(0.0, 0.0);
	public var stageCamKey:String = "none";
	public var danceWidth:Float = 0;
	public var danceHeight:Float = 0;

	var curAnimType:AnimType = CAN_DANCE;
	var holdTimer:Float = 0.0;
	var danceAnims:Array<String> = [];
	var danceStep:Int = -1;

	public function new(x:Float, y:Float, char:String = "bf", facingLeft:Bool = false) {
		var tmr = Sys.time();
		super(x, y);
		this.facingLeft = facingLeft;
		anchor.set();
		loadCharacter(char);
		music.Conductor.onBeat.add(dance);
		Sys.println('Loaded Character for $curChar (${Math.round((Sys.time() - tmr) * 1000) * 0.001} s)');
	}

	override function destroy() {
		music.Conductor.onBeat.remove(dance);
		super.destroy();
	}

	public function loadCharacter(charName:String) {
		if (curChar == charName) return; //No need to load if they're already loaded.

		offsets.clear();
		types.clear();
		animData.clear();
		chains.clear();
		danceAnims.splice(0, danceAnims.length);
		curChar = charName;
		try {
			data = Json.parse(File.getContent(Paths.file('data/characters/$curChar.json')));
		} catch(e) {
			Sys.println('Failed to load "$curChar": $e');
			curChar = "bf";
			data = Json.parse(File.getContent(Paths.file('data/characters/bf.json')));
		}

		if (data.scale == null) data.scale = 1;
		if (data.scaleAffectsOffset == null) data.scaleAffectsOffset = false;
		if (data.antialiasing == null) data.antialiasing = true;
		if (data.singLength == null) data.singLength = 4;

		loadFrames(Paths.sparrowXml('game/characters/' + data.spritesheet));

		for (anim in data.animations)
			addAnim(anim);

		scale.setFull(data.scale, data.scale);
		positionOffset.setFull(data.offsets.x, data.offsets.y);
		camOffset.setFull(data.offsets.camX, data.offsets.camY);
		antialiasing = data.antialiasing;

		danceStep = -1;
		forceDance();
	}

	public function addAnim(anim:JsonAnim) {
		addPrefixAnim(anim.name, anim.prefix, anim.frameRate, anim.looped, anim.frameIndices);

		if (!animData.exists(anim.name))
			Sys.println(curChar + ": COULDN'T ADD ANIMATION: " + anim.name);

		offsets.set(anim.name, (data.scaleAffectsOffset) ? [anim.offsets[0] / data.scale, anim.offsets[1] / data.scale] : anim.offsets.copy());

		var type:AnimType = (anim.name.startsWith("sing") && !anim.name.endsWith("miss")) ? SINGING : DANCE_AFTER;
		if (anim.animType != null)
			type = ["can_dance", "dancing", "singing", "chain"].indexOf(anim.animType.toLowerCase());
		types.set(anim.name, type);

		danceAnims.remove(anim.name);
		chains.remove(anim.name);
		if (type == DANCING) {
			danceAnims.push(anim.name);
			danceWidth = animData[anim.name].width;
			danceHeight = animData[anim.name].height;
		} else if (type == CHAIN)
			chains.set(anim.name, anim.chainAnim);
	}

	override function update(elapsed:Float) {
		if (!animData.exists(curAnim) || debugMode) return;

		if (curAnimType == SINGING)
			holdTimer += elapsed;

		if (curAnimType == CHAIN && animFinished) {
			playAnim(chains[curAnim]);
			if (curAnimType == DANCING)
				danceStep = danceAnims.indexOf(curAnim);
		}

		var singEnded = (curAnimType == SINGING && holdTimer >= music.Conductor.stepCrochet * data.singLength);
		if ((curAnimType == DANCE_AFTER && animFinished) || singEnded) {
			dance(0);
			if (singEnded)
				holdTimer = 0;
		}
	}

	override function queueDraw() {
		var scaleMult = (facingLeft != data.faceLeft) ? -1.0 : 1.0;
		var posOffset = (facingLeft != data.faceLeft) ? (danceWidth * scale.x) * (1.0 - anchor.x) : 0;
		scale.x *= scaleMult;
		positionOffset.x += posOffset;
		super.queueDraw();
		scale.x *= scaleMult;
		positionOffset.x -= posOffset;
	}

	public function dance(beat) {
		// Sys.println(curChar + " | " + curAnim + " | " + curAnimType);
		var stopDance = switch (curAnimType) {
			case DANCE_AFTER: !animFinished;
			case CAN_DANCE | DANCING: false;
			case SINGING: holdTimer < music.Conductor.stepCrochet * data.singLength;
			default: true;
		}
		if (debugMode || stopDance || danceAnims.length <= 0) return;

		danceStep = (danceStep + 1) % danceAnims.length;
		playAnim(danceAnims[danceStep], false);
	}

	public function forceDance() {
		if (danceAnims.length <= 0) return;

		danceStep = (danceStep + 1) % danceAnims.length;
		playAnim(danceAnims[danceStep], false);
	}

	override function playAnim(newAnim:String, ?forceRestart:Bool = true) {
		if (!animData.exists(newAnim)) return;

		animTime = (curAnim != newAnim || animFinished || forceRestart) ? 0.0 : animTime;
		curAnim = newAnim;
		curAnimType = types[curAnim];
		curFrame = animData[curAnim].indexes[0];
		
		animWidth = animData[curAnim].width;
		animHeight = animData[curAnim].height;
		dynamicOffset.setFull(offsets[curAnim][0], offsets[curAnim][1]);

		holdTimer = (curAnimType == SINGING) ? 0.0 : holdTimer;
	}
}