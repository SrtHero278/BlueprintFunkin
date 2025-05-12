package objects;

import bindings.CppHelpers;
import blueprint.graphics.Texture;

using StringTools;

class HealthIcon extends blueprint.objects.AnimatedSprite {
	public var iconScale:Float = 1.0;
	public var health(default, set):Float = 1.0;
	public var invertHealth:Bool = false;

	public function new(x:Float, y:Float, icon:String) {
		super(x, y);
		loadIcon(icon);
		scale.set(iconScale);
	}

	public function loadIcon(icon:String) {
		var path = Paths.image("game/icons/" + icon);
		if (!sys.FileSystem.exists(path))
			path = Paths.image("game/icons/UNKNOWN-ICON");

		final xmlPath = path.replace(".png", ".xml");
		if (sys.FileSystem.exists(xmlPath)) {
			loadFrames(xmlPath);

			addPrefixAnim("normal", "normal", 24, true);
			addPrefixAnim("losing", "losing", 24, true);
			addPrefixAnim("winning", "winning", 24, true);

			if (animData["losing"].indexes.length <= 0)
				animData.remove("losing");
			if (animData["winning"].indexes.length <= 0)
				animData.remove("winning");
		} else {
			final text = Texture.getCachedTex(path);
			
			var iconSteps = Math.round(text.width / text.height);
			loadTilesFromTex(text, text.width / iconSteps, text.height);
			
			addBasicAnim("normal", [0], 1, false);
			if (iconSteps >= 2)
				addBasicAnim("losing", [1], 1, false);
			if (iconSteps >= 3)
				addBasicAnim("winning", [2], 1, false);
		}
		
		playAnim("normal");
		iconScale = 150.0 / animHeight;
	}

	function set_health(value:Float) {
		var hp = invertHealth ? (1.0 - value) : value;

		var queueAnim = "normal";
		if (hp < 0.2 && animData.exists("losing"))
			queueAnim = "losing";
		else if (hp > 0.8 && animData.exists("winning"))
			queueAnim = "winning";

		if (curAnim != queueAnim)
			playAnim(queueAnim);

		return health = value;
	}
}