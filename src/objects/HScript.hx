package objects;

import hscript.Parser;
import hscript.Interp;

class HScript {
	static var parser:Parser;
	public var path:String;
	public var interp:Interp;
	public var code:String;

	public function new(?path:String, ?code:String = "", ?fullPath:Bool = false) {
		this.code = code;
		this.path = (path != null && !fullPath) ? Paths.script(path) : path;
		if (this.path != null)
			this.code += sys.io.File.getContent(this.path);

		interp = new Interp();
		initVars();
		try {
			parser.line = 1;
			final expr = parser.parseString(this.code, this.path);
			interp.execute(expr);
		} catch (e) {
			Sys.println('Failed to load ${this.path == null ? this.code : this.path}\n\t- $e');
			interp = null;
		}
	}

	public function exists(name:String) {
		return interp != null && interp.variables.exists(name);
	}

	public function get(name:String) {
		return (interp == null) ? null : interp.variables.get(name);
	}

	public function set(name:String, val:Dynamic) {
		if (interp != null)
			interp.variables.set(name, val);
	}

	public function call(name:String, ?args:Array<Dynamic>) {
		if (interp == null) return;

		final func = interp.variables.get(name);
		if (func == null || !Reflect.isFunction(func)) return;

		Reflect.callMethod(null, func, (args == null ? [] : args));
	}

	public static function initParser() {
		parser = new Parser();
		parser.allowJSON = true;
		parser.allowTypes = true;
		parser.allowMetadata = true;
	}

	function initVars() {
		// doesn't work well on the constructor so i'll just do it in Gameplay
		// set("scene", blueprint.Game.currentScene);

		set("Conductor", music.Conductor);
		set("Character", objects.Character);
		set("Settings", Settings);
		set("Paths", Paths);

		set("Game", blueprint.Game);
		set("InputHandler", blueprint.input.InputHandler);
		set("Shader", blueprint.graphics.Shader);
		set("Texture", blueprint.graphics.Texture);
		set("Group", blueprint.objects.Group);
		set("Sprite", blueprint.objects.Sprite);
		set("AnimatedSprite", blueprint.objects.AnimatedSprite);
		set("Font", blueprint.text.Font);
		set("Text", blueprint.text.Text);
		set("SoundData", blueprint.sound.SoundData);
		set("SoundPlayer", blueprint.sound.SoundPlayer);
		set("PropertyTween", blueprint.tweening.PropertyTween);
		set("EaseList", blueprint.tweening.EaseList);

		set("Std", Std);
	}
}