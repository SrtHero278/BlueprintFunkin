package objects;

import hscript.Parser;
import hscript.Interp;

class HScript {
	static var parser:Parser;
	public var path:String;
	public var interp:Interp;
	public var code:String;
	public var curFunc:String = null;

	public function new(?path:String, ?code:String = "", ?fullPath:Bool = false) {
		this.code = code;
		this.path = (path != null && !fullPath) ? Paths.script(path) : path;
		if (this.path != null)
			this.code += sys.io.File.getContent(this.path);

		interp = new Interp();
		interp.onError = printErr;
		initVars();
		try {
			parser.line = 1;
			final expr = parser.parseString(this.code, "Line");
			interp.execute(expr);
		} catch (e:hscript.Expr.Error) {
			Sys.println('Failed to load ${this.path == null ? this.code : this.path}\n\t- ${e.toString()}');
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
		
		var lastFunc = curFunc;
		curFunc = name;
		Reflect.callMethod(null, func, (args == null ? [] : args));
		curFunc = lastFunc;
	}

	public function printErr(e:hscript.Expr.Error) {
		final suffix = " on " + this.path == null ? this.code : this.path + "\n  - " + StringTools.replace(e.toString(), "\n", "\n    - "); // would like to use \t but das a lotta spaces
		if (curFunc != null)
			Sys.println('Failed to run "$curFunc"' + suffix);
		else
			Sys.println('Failed to run code' + suffix);
	}

	public static function initParser() {
		parser = new Parser();
		parser.allowJSON = true;
		parser.allowTypes = true;
		parser.allowMetadata = true;
	}

	function initVars() {
		set("scene", blueprint.Game.currentScene);

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
		set("Math", Math);
	}
}