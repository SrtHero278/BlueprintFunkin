package scenes;

import blueprint.input.InputHandler;
import bindings.Glfw;
import blueprint.Game;
import blueprint.text.Text;
import blueprint.sound.SoundPlayer;
import sys.FileSystem;

using StringTools;

class OptionList extends BaseMenu {
	public static var self:OptionList;

	public final options:Array<MenuOption> = [
		new MenuOption("Downscroll", "If the notes will fall down instead of move up.", "downscroll", Bool),
		new MenuOption("Centererd Field", "If the player's notes will be in the center.", "centerField", Bool),
		new MenuOption("Hide Highest Judge", "If the highest judgement will be hidden when hit.", "hideHighJudge", Bool),
		new MenuOption("VSync", "If the framerate will depend on your monitor's refresh rate.", "vSync", Bool),
		new MenuOption("Left Binds", "What keys to press for the left note.", "leftBinds", Keybind),
		new MenuOption("Down Binds", "What keys to press for the down note.", "downBinds", Keybind),
		new MenuOption("Up Binds", "What keys to press for the up note.", "upBinds", Keybind),
		new MenuOption("Right Binds", "What keys to press for the right note.", "rightBinds", Keybind),
	];
	public var getKey:Bool = false;
	var list:Text;
	var sound:SoundPlayer;

	var curOpt(get, never):MenuOption;
	function get_curOpt() {
		return options[curItem];
	}

	public function new() {
		super();
		self = this;
		subKeybinds = [bindings.Glfw.KEY_LEFT, bindings.Glfw.KEY_RIGHT];

		add(list = new Text(10, 10, Paths.font("montserrat"), 32, ""));
		updateList();
		list.anchor.set(0);

		var watermark = new Text(Game.window.width - 10, Game.window.height -10, Paths.font("montserrat"), 24, "TEMPORARY MENU");
		watermark.anchor.set(1);
		add(watermark);

		sound = new SoundPlayer(Paths.audio("menus/scroll"), false, false, 1.0);
	}

	function updateList() {
		list.text = "";
		for (i => opt in options)
			list.text += (i == curItem ? ">>> " : "") + opt.text + "\n";
	}

	override function keyDown(keyCode:Int, scanCode:Int, mods:Int) {
		if (getKey) {
			if (keyCode == Glfw.KEY_DELETE && curOpt.curKey < curOpt.keys.length) {
				curOpt.keys.splice(curOpt.curKey, 1);
			} else if (keyCode != Glfw.KEY_ESCAPE) {
				if (curOpt.curKey == curOpt.keys.length)
					curOpt.keys.push(keyCode);
				else
					curOpt.keys[curOpt.curKey] = keyCode;
			}

			getKey = false;
			curOpt.move(0);
			updateList();
		} else
			super.keyDown(keyCode, scanCode, mods);
	}

	override function changeItem(direction:Int) {
		sound.play(0.0);
		updateList();
	}

	override function changeSubItem(direction:Int) {
		if (curOpt.hasMovement)
			curOpt.move(direction);

		updateList();
	}

	override function accept() {
		if (curOpt.hasEnter)
			curOpt.enter();

		updateList();
	}

	override function cancel() {
		self = null;
		Settings.save("tempOptions.json");

		var title:scenes.Title = cast memberOf;
		title.subMenu = null;
		title.acceptTwn.rewind();

		memberOf.remove(this);
		sound.destroy();
		destroy();
	}

	override function getMaxItems():Int {
		return options.length;
	}

	override function getMaxSubItems():Int {
		return 1;
	}
}

enum OptionType {
	Bool;
	Int(min:Int, max:Int, inc:Int);
	Float(min:Float, max:Float, inc:Float);
	List(opts:Array<String>);
	Keybind;
}

class MenuOption {
	var name:String;
	var desc:String;
	var internal:String;
	var type:OptionType;

	public var hasMovement:Bool = true;
	public var hasEnter:Bool = false;
	public var text:String = "";

	public var keys:Array<Int>;
	public var curKey:Int = 0;

	var roundMult:Float;

	public function new(name:String, desc:String, internal:String, type:OptionType) {
		this.name = name;
		this.desc = desc;
		this.internal = internal;
		this.type = type;

		switch (type) {
			case Bool:
				hasEnter = true;

				final bool:Bool = Reflect.field(Settings, internal);
				text = name + ": < " + (bool ? "ON" : "OFF") + " >";
			case Float(min, max, inc):
				roundMult = Math.pow(10, Math.floor(Math.log(inc) / Math.log(10)));

				final float:Float = Reflect.field(Settings, internal);
				text = name + ": < " + float + " >";
			case Keybind:
				hasEnter = true;
				keys = Reflect.field(Settings, internal);
				text = name + ": < " + (curKey == keys.length ? "New Key" : 'Change Key #${curKey + 1} (${InputHandler.keyNames[keys[curKey]]})') + " >";
			default:
				text = name + ": < " + Reflect.field(Settings, internal) + " >";
		}
	}

	public function move(incMult:Int) {
		switch (type) {
			case Bool:
				final bool:Bool = Reflect.field(Settings, internal);
				Reflect.setProperty(Settings, internal, !bool);
				text = name + ": < " + (!bool ? "ON" : "OFF") + " >";
			case Int(min, max, inc):
				var int:Int = Reflect.field(Settings, internal);
				int = Std.int(Math.min(Math.max(int + inc * incMult, min), max));
				Reflect.setProperty(Settings, internal, int);
				text = name + ": < " + int + " >";
			case Float(min, max, inc):
				var float:Float = Reflect.field(Settings, internal);
				float = Math.min(Math.max(float + inc * incMult, min), max);
				float = Math.round(float * roundMult) / roundMult;
				Reflect.setProperty(Settings, internal, float);
				text = name + ": < " + float + " >";
			case List(opts):
				final cur:String = Reflect.field(Settings, internal);
				var idx:Int = opts.indexOf(cur);
				idx = (idx + incMult + opts.length) % opts.length;
				Reflect.setProperty(Settings, internal, opts[idx]);
				text = name + ": < " + opts[idx] + " >";
			case Keybind:
				final len:Int = keys.length + 1;
				curKey = (curKey + incMult + len) % len;
				text = name + ": < " + (curKey == keys.length ? "New Key" : 'Change Key #${curKey + 1} (${InputHandler.keyNames[keys[curKey]]})') + " >";
		}
	}
	
	public function enter() {
		switch (type) {
			case Bool:
				final bool:Bool = Reflect.field(Settings, internal);
				Reflect.setProperty(Settings, internal, !bool);
				text = name + ": < " + (!bool ? "ON" : "OFF") + " >";
			case Keybind:
				if (OptionList.self != null) {
					OptionList.self.getKey = true;
					text = name + ": < Pick a key. (ESC: Cancel, DEL: Remove) >";
				}
			default: // nothin
		}
	}
}