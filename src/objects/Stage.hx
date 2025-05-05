package objects;

import math.Vector2;
import blueprint.Game;
import blueprint.objects.AnimatedSprite;
import blueprint.objects.Sprite;
import blueprint.objects.Group;

import sys.io.File;
import haxe.Json;

typedef StageObject = {
	var ?name:String;
	var type:String;
	var asset:String;
	var position:Array<Float>;
	var scroll:Array<Float>;
	var scale:Array<Float>;
	var ?anchor:Array<Float>;
	var ?rotation:Float;
	var ?antialiasing:Bool;

	var ?camera:Array<Float>;
	var ?faceLeft:Bool;

	var ?initialAnim:String;
	var ?animations:Array<objects.Character.JsonAnim>;

	var ?objects:Array<StageObject>;
}

typedef StageJSON = {
	var zoom:Float;
	var objects:Array<StageObject>;
}

class Stage extends Group {
	public var defaultZoom:Float = 1.05;
	public var name:String;
	public var charGroups:Map<String, Group> = [];
	public var camOffsets:Map<String, Vector2> = [];
	public var facingLeft:Map<String, Bool> = [];
	public var objects:Map<String, Sprite> = [];
	var jsonData:StageJSON;

	function getDefaultArray<T>(array:Array<T>, idx:Int, def:T) {
		return (array != null && idx < array.length) ? array[idx] : def;
	}

	public function new(name:String) {
		super();
		this.name = name;

		var path = Paths.file("data/stages/" + name + ".json");
		// if (!sys.FileSystem.exists(path)) {
		//     path = Paths.file("data/stages/stage.json");
		//     this.name = "stage";
		// }
		jsonData = cast Json.parse(File.getContent(path));
		defaultZoom = jsonData.zoom;
		Game.currentScene.mainCamera.zoom.set(defaultZoom);
		parseGroup(this, jsonData.objects);
	}

	function setupObject(spr:Sprite, obj:StageObject) {
		if (obj.name != null)
			objects.set(obj.name, spr);

		final scaleX = getDefaultArray(obj.scale, 0, 1);
		spr.scale.set(scaleX, getDefaultArray(obj.scale, 1, scaleX));
		spr.rotation = (obj.rotation != null) ? obj.rotation : 0;
		spr.antialiasing = (obj.antialiasing == null || obj.antialiasing);
		spr.parallax.setFull(getDefaultArray(obj.scroll, 0, 1), getDefaultArray(obj.scroll, 1, 1));
		spr.anchor.set(getDefaultArray(obj.anchor, 0, 0.5), getDefaultArray(obj.anchor, 1, 0.5));
	}

	function parseGroup(group:Group, list:Array<StageObject>) {
		for (obj in list) {
			var type = obj.type.toLowerCase();
			switch (type) {
				case "image":
					var spr = new Sprite(getDefaultArray(obj.position, 0, 0), getDefaultArray(obj.position, 1, 0), Paths.image("game/stages/" + name + "/" + obj.asset));
					setupObject(spr, obj);
					group.add(spr);
				case "sparrow":
					var spr = new AnimatedSprite(getDefaultArray(obj.position, 0, 0), getDefaultArray(obj.position, 1, 0), Paths.file("images/game/stages/" + name + "/" + obj.asset + ".xml"));
					setupObject(spr, obj);
					for (anim in obj.animations)
						spr.addPrefixAnim(anim.name, anim.prefix, anim.frameRate, anim.looped, anim.frameIndices);
					if (obj.initialAnim != null)
						spr.playAnim(obj.initialAnim);
					group.add(spr);
				case "group":
					var grp = new Group(getDefaultArray(obj.position, 0, 0), getDefaultArray(obj.position, 1, 0));
					setupObject(grp, obj);
					parseGroup(grp, obj.objects);
					group.add(grp);
				case "player" | "spectator" | "opponent":
					if (charGroups.exists(type)) {
						charGroups[type].memberOf.remove(charGroups[type]);
						charGroups[type].destroy();
					}

					var grp = new Group(getDefaultArray(obj.position, 0, 0), getDefaultArray(obj.position, 1, 0));
					setupObject(grp, obj);
					group.add(grp);
					charGroups.set(type, grp);
					camOffsets.set(type, new Vector2(getDefaultArray(obj.camera, 0, 0), getDefaultArray(obj.camera, 1, 0)));
					facingLeft.set(type, obj.faceLeft == null ? type == "player" : obj.faceLeft);
			}
		}
	}

	public function addChars(player:Character, opponent:Character, spectator:Character) {
		if (charGroups.exists("player") && player != null) {
			charGroups["player"].add(player);
			player.stageCamKey = "player";
			player.facingLeft = facingLeft["player"];
		}
		if (charGroups.exists("opponent") && opponent != null) {
			charGroups["opponent"].add(opponent);
			opponent.stageCamKey = "opponent";
			opponent.facingLeft = facingLeft["opponent"];
		}
		if (charGroups.exists("spectator") && spectator != null) {
			charGroups["spectator"].add(spectator);
			spectator.stageCamKey = "spectator";
			spectator.facingLeft = facingLeft["spectator"];
		}
	}
}