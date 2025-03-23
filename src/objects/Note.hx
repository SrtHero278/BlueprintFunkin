package objects;

import blueprint.objects.AnimatedSprite;
import blueprint.objects.Sprite;
import bindings.Glad;
import scenes.Gameplay;
import music.GameSong.ChartNote;

class Note extends AnimatedSprite {
	public static var swagWidth:Float = 160 * 0.7;
	public var data:ChartNote;
	public var hitTime:Float;
	public var singAnim:String = "singLEFT";
	public var missAnim:String = "singLEFTmiss";

	public var wasHit:Bool = false;
	public var holding:Bool;
	public var untilTick:Float;
	public var length(default, null):Float = 0.0;
	public var sustain:Sprite;
	public var tail:AnimatedSprite;

	public function new(data:ChartNote) {
		this.data = data;
		hitTime = data.time;
		super(-999, -999, Paths.file("images/game/notes.xml"));
		scale.set(0.7);

		final colors = ["purple", "blue", "green", "red"];
		addPrefixAnim("scroll", colors[data.lane] + "0");
		playAnim("scroll");

		singAnim = ["singLEFT", "singDOWN", "singUP", "singRIGHT"][data.lane];
		missAnim = ["singLEFTmiss", "singDOWNmiss", "singUPmiss", "singRIGHTmiss"][data.lane];

		if (data.length > 0.0) {
			sustain = new Sprite(-999, -999, Paths.image("game/sustains"));
			sustain.verticalWrap = Glad.MIRRORED_REPEAT;
			sustain.sourceRect.x = sustain.texture.width * 0.25 * (data.lane);
			sustain.sourceRect.width = sustain.texture.width * 0.25;
			sustain.sourceRect.height = sustain.texture.height;
			sustain.position = position;

			tail = new AnimatedSprite(-999, -999);
			tail.frames = frames;
			tail.addPrefixAnim("tail", colors[data.lane % 4] + " tail");
			tail.playAnim("tail");
			tail.sourceRect.height = tail.sourceHeight;
			tail.position = position;
			tail.scale = sustain.scale;
			tail.tint = sustain.tint;
		}
	}

	override function queueDraw() {
		if (sustain != null) {
			@:bypassAccessor @:bypassAccessor sustain.memberOf = memberOf;
			@:bypassAccessor @:bypassAccessor tail.memberOf = memberOf;

			sustain.tint.setFull(tint.r, tint.g, tint.b, tint.a * 0.6);
			sustain.scale.setFull(scale.x, scale.y);
			sustain.rotation = rotation;
			sustain.queueDraw();

			tail.rotation = rotation;
			tail.queueDraw();
		}
		if (!wasHit)
			super.queueDraw();
	}
	
	override function destroy() {
		super.destroy();
		if (sustain != null) {
			sustain.destroy();
			tail.destroy();
		}
	}

	public function setLength(newLength:Float, speed:Float) {
		if (newLength > 0.0 && sustain != null) {
			final height = 45 * (newLength * speed * 15) - tail.animHeight;
			sustain.sourceRect.top = Math.min(-height + sustain.texture.height, sustain.texture.height);
			sustain.dynamicOffset.y = sustain.sourceHeight * 0.5;
			tail.sourceRect.top = Math.max(-height, 0.0);
			tail.dynamicOffset.y = sustain.sourceHeight + tail.animHeight * 0.5;
		}
		return length = newLength;
	}
}