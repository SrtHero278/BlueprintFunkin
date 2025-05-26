package;

import sys.FileSystem;
import moonchart.backend.FormatDetector;
import scenes.Title;
import scenes.ModsList;
import music.GameSong;
import bindings.CppHelpers;
import blueprint.Game;

class Main {
	public static var game:Game;
	
	static function main() {
		FormatDetector.init();
		GameSong.multiDiffExts = [".json", ".sm", ".ssc", ".chart"];
		GameSong.singleDiffExts = [".json", ".osu", ".qua"];
		GameSong.multiDiffFormats = [
			FNF_VSLICE,
			STEPMANIA,
			STEPMANIA_SHARK,
			GUITAR_HERO
		];
		GameSong.singleDiffFormats = [
			FNF_LEGACY_PSYCH,
			FNF_LEGACY_TROLL,
			FNF_LEGACY_FPS_PLUS,
			FNF_LEGACY,
			FNF_CODENAME,
			FNF_KADE,
			FNF_MARU,
			OSU_MANIA,
			QUAVER
		];

		ModsList.trySelect();
		Paths.foldersToCheck[0] = "assets/" + ModsList.mods[0];

		objects.HScript.initParser();

		game = new Game(1280, 720, "Blueprint Funkin", Title);
	}
}

enum SettingType {
	BOOL;
	FLOAT(inc:Float, min:Float, max:Float, clampValue:Bool);
	INT(inc:Float, min:Int, max:Int, clampValue:Bool);
}
class GameSetting<T> {
	public var name:String;
	public var desc:String;
	public var type:SettingType;
	public var value:T;
	public var onChange:Null<T->Void>;

	public function new(name:String, desc:String, type:SettingType, value:T, ?onChange:T->Void) {
		this.name = name;
		this.desc = desc;
		this.type = type;
		this.value = value;
		this.onChange = onChange;
	}

	public function change(left:Bool) {
		switch (type) {
			case BOOL:
				final val = cast value;
				value = cast !val;
			case FLOAT(inc, min, max, clamp):
				final plus:Float = inc * (CppHelpers.boolToInt(!left) * 2 - 1);
				final val:Float = cast value;
				value = cast (clamp) ? Math.min(Math.max(val + plus, min), max) : ((val + plus - min + max) % max) + min;
			case INT(inc, min, max, clamp):
				final plus:Int = Std.int(inc * (CppHelpers.boolToInt(!left) * 2 - 1));
				final val:Int = cast value;
				value = cast (clamp) ? Math.min(Math.max(val + plus, min), max) : ((val + plus - min + max) % max) + min;
		}

		if (onChange != null)
			onChange(value);
	}
}