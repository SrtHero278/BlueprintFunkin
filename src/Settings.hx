package;

import sys.io.File;
import sys.FileSystem;
import haxe.Json;
import bindings.Glfw;
import blueprint.Game;

var Settings:SettingData = new SettingData();

class SettingData {
	public var muted(default, set):Bool = false;
	public var volume(default, set):Float = 1;

	public var chartOffset:Float = 0;
	public var downscroll:Bool = false;
	public var centerField:Bool = false;
	public var hideHighJudge:Bool = false;

	public var vSync(default, set):Bool = false;

	public var leftBinds:Array<Int> =	[Glfw.KEY_D, Glfw.KEY_LEFT];
	public var downBinds:Array<Int> =	[Glfw.KEY_F, Glfw.KEY_DOWN];
	public var upBinds:Array<Int> =		[Glfw.KEY_J, Glfw.KEY_UP];
	public var rightBinds:Array<Int> =	[Glfw.KEY_K, Glfw.KEY_RIGHT];

	function set_muted(to:Bool) {
		Game.mixer.gain = to ? 0 : volume;
		return muted = to;
	}

	function set_volume(to:Float) {
		to = Math.min(Math.max(to, 0), 1);
		Game.mixer.gain = muted ? 0 : to;
		return volume = to;
	}

	function set_vSync(to:Bool):Bool {
		return Game.window.vSync = (vSync = to);
	}

	public function new() {}

	public function load(path:String) {
		try {
			if (!FileSystem.exists(path))
				throw "File nonexistant.";
			final json = Json.parse(File.getContent(path));
			
			for (field in Reflect.fields(json)) {
				if (Reflect.field(this, field) != null) 
					Reflect.setProperty(this, field, Reflect.field(json, field));
			}
		} catch (err) {
			Sys.println('Failed to load save "$path": ${err.details()}');
		}
	}

	// honestly dunno why i did this i think it was just to have a save with the load.
	public function save(path:String) {
		File.saveContent(path, Json.stringify(this, null, "\t"));
	}
}