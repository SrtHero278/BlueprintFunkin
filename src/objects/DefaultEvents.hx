package objects;

import blueprint.tweening.PropertyTween;
import blueprint.tweening.EaseList;
import blueprint.Game;
import scenes.Gameplay;
import music.GameSong.Event;
import math.Vector2;

@:allow(scenes.Gameplay)
class DefaultEvents {
	static var cacheVec2:Vector2 = new Vector2();
	static var game:Gameplay;

	static function retarget(char:Int) {
		if (game.strumlines[char] == null || game.strumlines[char].characters.length <= 0) return;

		final character = game.strumlines[char].characters[0];
		if (character.memberOf == null) return;
		
		final constOffset = (character.facingLeft) ? -100 : 150;
		final camMult = (character.facingLeft) ? -1 : 1;
		cacheVec2 = character.getGlobalPosition(game.stage, cacheVec2);

		cacheVec2 += game.stage.camOffsets[character.stageCamKey];
		character.camOffset.x *= camMult;
		cacheVec2 += character.camOffset;
		character.camOffset.x *= camMult;

		game.mainCamera.targetPosition.setFull(
			cacheVec2.x + character.danceWidth * 0.5 + constOffset - Game.window.width * 0.5,
			cacheVec2.y + character.danceHeight * 0.5 - 100 - Game.window.height * 0.5
		);
	}

	static function bumpInterval(?interval:Int = 4, ?strength:Float = 1.0) {
		game.bumpInterval = interval;
		game.bumpStrength = strength;
	}

	static function vsliceCamera(?char:Int = 1, ?duration:Float = 4, ?ease:String = "CLASSIC", ?x:Float = 0, ?y:Float = 0) {
		game.mainCamera.targetPosition.setFull(0, 0);

		retarget((char < 2) ? 1 - char : char);
		game.mainCamera.targetPosition.x += x;
		game.mainCamera.targetPosition.y += y;
		
		switch (ease) {
			case "CLASSIC": // jobs already done
			case "INSTANT":
				game.mainCamera.position.copyFrom(game.mainCamera.targetPosition);
			default:
				final easeFunc = Reflect.field(EaseList, ease);
				if (easeFunc == null) return;

				final tarX = game.mainCamera.targetPosition.x;
				final tarY = game.mainCamera.targetPosition.y;
				game.mainCamera.targetPosition.copyFrom(game.mainCamera.position);
				var twn = new PropertyTween(
					game.mainCamera,
					{
						"position.x": tarX,
						"position.y": tarY,
						"targetPosition.x": tarX,
						"targetPosition.y": tarY
					},
					Conductor.stepCrochet * duration,
					easeFunc
				);
		}
	}

	static function vsliceZoom(?duration:Float = 4, ?ease:String = "linear", ?mode:String = "direct", ?z:Float = 1) {
		final zoom = (mode == "direct") ? z : game.stage.jsonData.zoom * z;

		if (ease == "INSTANT") {
			game.stage.defaultZoom = zoom;
			game.mainCamera.zoom.setFull(zoom, zoom);
		} else {
			final easeFunc = Reflect.field(EaseList, ease);
			if (easeFunc == null) return;

			var twn = new PropertyTween(
				game,
				{
					"mainCamera.zoom.x": zoom,
					"mainCamera.zoom.y": zoom,
					"stage.defaultZoom": zoom
				},
				Conductor.stepCrochet * duration,
				easeFunc
			);
		}
	}

	public static function interpetEvents(events:Array<Event>) {
		for (ev in events) {
			switch (ev.name) {
				case "Retarget Camera":
					ev.func = retarget;
				case "Bump Interval":
					ev.func = bumpInterval;
				case "FocusCamera":
					ev.func = vsliceCamera;
				case "ZoomCamera":
					ev.func = vsliceZoom;
			}

			if (game.eventScripts.exists(ev.name) && game.eventScripts[ev.name].exists("trigger"))
				ev.func = game.eventScripts[ev.name].get("trigger");

			game.callScripts("eventRegistered", [ev]);
		}
	}
}