package;

import bindings.Glfw;
import blueprint.Game;

var Settings:SettingData = new SettingData();

class SettingData {
	public var downscroll:Bool = false;
	public var centerField:Bool = false;
	public var hideHighJudge:Bool = false;

	public var vSync(default, set):Bool = false;

	public var leftBinds:Array<Int> =	[Glfw.KEY_D, Glfw.KEY_LEFT];
	public var downBinds:Array<Int> =	[Glfw.KEY_F, Glfw.KEY_DOWN];
	public var upBinds:Array<Int> =		[Glfw.KEY_J, Glfw.KEY_UP];
	public var rightBinds:Array<Int> =	[Glfw.KEY_K, Glfw.KEY_RIGHT];

	function set_vSync(to:Bool):Bool {
		return Game.window.vSync = (vSync = to);
	}

	public function new() {}
}