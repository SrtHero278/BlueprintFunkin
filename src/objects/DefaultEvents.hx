package objects;

import blueprint.Game;
import scenes.Gameplay;
import music.GameSong.Event;
import math.Vector2;

@:allow(scenes.Gameplay)
class DefaultEvents {
	static var cacheVec2:Vector2 = new Vector2();
	static var game:Gameplay;

	static function retarget(char:Int) {
		if (game.strumlines[char].characters.length <= 0) return;

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

	public static function interpetEvents(events:Array<Event>) {
		for (ev in events) {
			switch (ev.name) {
				case "Retarget Camera":
					ev.func = retarget;
			}
		}
	}
}