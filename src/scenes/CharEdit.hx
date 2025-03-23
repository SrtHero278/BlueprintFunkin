package scenes;

// Behond! (yes behond) The messiest editor code you'll ever see!

import sys.FileSystem;
import blueprint.Game;
import blueprint.input.InputHandler;
import blueprint.objects.Group;
import blueprint.objects.Sprite;
import blueprint.text.Text;
import blueprint.graphics.Texture;
import objects.Character;
import haxe.io.Path;
import math.Vector4;

import bindings.CppHelpers;
import bindings.Glad;
import bindings.Glfw;

using StringTools;

enum TypeEditKind {
	Normal;
	Number(normal:Float);
	Bool;
	List(opts:Array<String>);
}
typedef TypeEditCallback = (data:Array<String>, lines:Array<String>, kinds:Array<TypeEditKind>, index:Int)->Void;

enum CharEditMode {
	Main;
	Global;
	Type(data:Array<String>, lines:Array<String>, index:Int, ?complete:TypeEditCallback, ?update:TypeEditCallback, ?kinds:Array<TypeEditKind>);
	Indices(length:Int, current:Array<Int>, sel:Int, index:Int);
}

final controlList = [

"[W/S] - Change Anim
(Hold [SHIFT] to reorder!)
[+] - New/Edit Anim
[-] - Delete Anim
[.] - Edit Indices
[ARROW-KEYS] - Move Animation Offset
[SPACE] - Replay Animation

[M] - Edit Global Data
[IJKL] - Move Camera
[Q/E] - Zoom Camera
[CTRL+O] - Open Char
[CTRL+S] - Save Char",

"[WASD] - Move Global Offset
[ARROW-KEYS] - Move Camera Offset
[/] - Switch Intended Direction
[,/.] - Change Scale

[1] - Toggle Antialiasing
[0] - Change Textures

[M] - Edit Animations
[IJKL] - Move Camera
[Q/E] - Zoom Camera
[CTRL+O] - Open Char
[CTRL+S] - Save Char",

"Either type or press [</>] on each line

[ENTER/v] - Next Line (finishes if last)
[ESC/^] - Last Line (leaves if first)",

"[^/v] - Switch Lines
[ENTER] - Confirm Action
[ESC] - Cancel"

];

class CharEdit extends blueprint.Scene {
	var lastMode:CharEditMode;
	var curMode(default, set):CharEditMode = Main;
	var cancelInput:Bool = false;

	var dirArrow:Sprite;
	var line:Sprite;
	var char:Character;
	var anims:Array<String> = [];
	var animIndex(default, set):Int = 0;
	var controls:Text;
	var controlData:Text;
	var animList:Text;
	var pixel:Texture;
	var uiGroup:Group;

	public function new() {
		super();
		Game.window.clearColor = Game.window.clearColor.setFull(0.125, 0.125, 0.125, 1.0);
		position.setFull(640, 360);

		// man i really gotta make a color rect
		pixel = new Texture();
		var data:cpp.RawPointer<cpp.UInt8> = CppHelpers.malloc(4, cpp.UInt8);
		data[0] = data[1] = data[2] = 255;
		data[3] = 128;
		Glad.texImage2D(Glad.TEXTURE_2D, 0, Glad.RGBA, 1, 1, 0, Glad.RGBA, Glad.UNSIGNED_BYTE, data);
		CppHelpers.free(data);

		line = new Sprite(0, 767.5 - 360);
		line.parallax.x = 0;
		line.sourceRect.setFull(0, 0, 1280, 5);
		line.texture = pixel;
		add(line);

		char = new Character(0, -360, "", false);
		char.debugMode = true;
		char.data = {
			spritesheet: "",
			icon: "",
		
			faceLeft: false,
			offsets: {x: 0, y: 0, camX: 0, camY: 0},
			animations: [],
		
			scale: 1,
			scaleAffectsOffset: true,
			antialiasing: true,
			singLength: 4
		}
		add(char);

		dirArrow = new Sprite(0, 0, Paths.image("game/popup/arrow"));
		dirArrow.positionOffset = char.positionOffset;
		updateDirArrow();
		add(dirArrow);

		uiGroup = new Group();
		uiGroup.skipProperties = true;
		add(uiGroup);

		controlData = new Text(1270, 710, Paths.font("montserrat"), 16, controlList[0]);
		controlData.parallax.set(0, 0);
		controlData.zoomFactor = 0;
		controlData.anchor.setFull(1, 1);
		controlData.alignment = RIGHT;
		uiGroup.add(controlData);

		controls = new Text(30, 690, Paths.font("montserrat"), 28, "");
		controls.parallax.set(0, 0);
		controls.zoomFactor = 0;
		controls.anchor.setFull(0, 1);
		uiGroup.add(controls);

		animList = new Text(10, 10, Paths.font("montserrat"), 16, "");
		animList.parallax.set(0, 0);
		animList.zoomFactor = 0;
		animList.anchor.setFull(0, 0);
		uiGroup.add(animList);

		InputHandler.charInputted.add(charPress);
		Song.current.time = 0;
        Song.current.looping = true;
        Song.current.play();
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		if (curMode == Main || curMode == Global) {
			var camMult = 150 + 500 * (Glfw.getKey(Game.window.cWindow, Glfw.KEY_LEFT_SHIFT) + Glfw.getKey(Game.window.cWindow, Glfw.KEY_RIGHT_SHIFT));
			mainCamera.position.x += (Glfw.getKey(Game.window.cWindow, Glfw.KEY_J) - Glfw.getKey(Game.window.cWindow, Glfw.KEY_L)) * elapsed * camMult;
			mainCamera.position.y += (Glfw.getKey(Game.window.cWindow, Glfw.KEY_I) - Glfw.getKey(Game.window.cWindow, Glfw.KEY_K)) * elapsed * camMult;
	
			var newScale = mainCamera.zoom.x + (Glfw.getKey(Game.window.cWindow, Glfw.KEY_E) - Glfw.getKey(Game.window.cWindow, Glfw.KEY_Q)) * elapsed;
			mainCamera.zoom.setFull(newScale, newScale);
	
			line.scale.x = 1.0 / newScale;
		}
	}

	final indicesLines:Array<String> = ["Add Indice: ", "Remove Last Indice", "Clear Indices", "Finish"];
	function updateIndices(current:Array<Int>, sel:Int, index:Int) {
		controls.text = "Current: " + current;
		indicesLines[0] = (index == 0) ? 'Add Indice: < $sel >' : "Add Indice";
		for (i in 0...indicesLines.length) {
			controls.text += "\n";
			if (i == index)
				controls.text += ">>> ";
			controls.text += indicesLines[i];
		}
	}

	function updateTypeText(data:Array<String>, lines:Array<String>, kinds:Array<TypeEditKind>, index:Int) {
		controls.text = "";
		for (i in 0...lines.length) {
			if (i == index) {
				controls.text += ">>> " + lines[i];
				var kind = (kinds == null) ? Normal : kinds[i];
				controls.text += switch (kind) {
					case Normal: '"${data[i]}"';
					case Number(_): '#"${data[i]}"';
					case Bool | List(_): '< ${data[i]} > ';
				}
				controls.text += "\n";
			} else
				controls.text += lines[i] + data[i] + "\n";
		}
		controls.text = controls.text.substring(0, controls.text.length - 1);
	}

	function updateAnimText() {
		animList.text = "";
		for (i in 0...anims.length)
			animList.text += (i == animIndex ? ">>> " : "") + anims[i] + ": " + char.data.animations[i].offsets + "\n";
	}

	function charPress(char:String, code:cpp.UInt32, mods:Int) {
		if (cancelInput) {
			cancelInput = false;
			return;
		}

		switch (curMode) {
			case Type(data, lines, index, complete, update, kinds):
				var kind = (kinds == null) ? 0 : kinds[index].getIndex();
				if (kind >= 2) return;
				data[index] += char;
				if (update != null)
					update(data, lines, kinds, index);
				updateTypeText(data, lines, kinds, index);
			default:
				// do nothin
		}
	}

	override function keyDown(keyCode:Int, scanCode:Int, mods:Int) {
		switch (curMode) {
			case Main:
				switch(keyCode) {
					case Glfw.KEY_M:
						curMode = Global;

					case Glfw.KEY_W:
						if (anims.length <= 0) return;
						var newIndex = (animIndex - 1 + anims.length) % anims.length;
						if (mods & Glfw.MOD_SHIFT != 0) {
							var oldAnim = anims[animIndex];
							var oldData = char.data.animations[animIndex];
							anims.splice(animIndex, 1);
							char.data.animations.splice(animIndex, 1);
							anims.insert(newIndex, oldAnim);
							char.data.animations.insert(newIndex, oldData);
						}
						animIndex = newIndex;
					case Glfw.KEY_S | Glfw.KEY_W:
						if (mods & Glfw.MOD_CONTROL != 0) {
							var lines = ["Save as: "];
							curMode = Type([char.curChar], lines, 0, finishSaveChar);
							cancelInput = true;
							return;
						}
						if (anims.length <= 0) return;
						var newIndex = (animIndex + 1 + anims.length) % anims.length;
						if (mods & Glfw.MOD_SHIFT != 0) {
							var oldAnim = anims[animIndex];
							var oldData = char.data.animations[animIndex];
							anims.splice(animIndex, 1);
							char.data.animations.splice(animIndex, 1);
							anims.insert(newIndex, oldAnim);
							char.data.animations.insert(newIndex, oldData);
						}
						animIndex = newIndex;
					case Glfw.KEY_SPACE:
						if (anims.length > 0)
							char.playAnim(anims[animIndex]);

					case Glfw.KEY_LEFT | Glfw.KEY_RIGHT:
						if (anims.length <= 0) return;
						var offsets = char.data.animations[animIndex].offsets;
						var inc:Float = (CppHelpers.boolToInt(keyCode == Glfw.KEY_RIGHT) - CppHelpers.boolToInt(keyCode == Glfw.KEY_LEFT));
						inc *= 1 + 9 * (mods & Glfw.MOD_SHIFT);
						inc /= ((char.data.scaleAffectsOffset) ? char.data.scale : 1);
						offsets[0] += (char.scale.x < 0) ? -inc : inc;
						char.offsets.set(anims[animIndex], (char.data.scaleAffectsOffset) ? [offsets[0] / char.data.scale, offsets[1] / char.data.scale] : offsets.copy());
						char.playAnim(anims[animIndex]);
						updateAnimText();
					case Glfw.KEY_UP | Glfw.KEY_DOWN:
						if (anims.length <= 0) return;
						var offsets = char.data.animations[animIndex].offsets;
						var inc:Float = (CppHelpers.boolToInt(keyCode == Glfw.KEY_DOWN) - CppHelpers.boolToInt(keyCode == Glfw.KEY_UP));
						inc *= 1 + 9 * (mods & Glfw.MOD_SHIFT);
						inc /= ((char.data.scaleAffectsOffset) ? char.data.scale : 1);
						offsets[1] += inc;
						char.offsets.set(anims[animIndex], (char.data.scaleAffectsOffset) ? [offsets[0] / char.data.scale, offsets[1] / char.data.scale] : offsets.copy());
						char.playAnim(anims[animIndex]);
						updateAnimText();

					case Glfw.KEY_PERIOD | Glfw.KEY_KP_DECIMAL:
						if (anims.length <= 0) return;

						var frameCount:Int = 0;
						var animData = char.data.animations[animIndex];
						var indices = (animData.frameIndices == null ? [] : animData.frameIndices.copy());
						@:privateAccess for (frame in char.frames) {
							frameCount += CppHelpers.boolToInt(frame.name.startsWith(animData.prefix));
						}
						curMode = Indices(frameCount, indices, 0, 0);
					case Glfw.KEY_KP_ADD | Glfw.KEY_EQUAL:
						var lines = ["Anim Name: ", "Interal Name: ", "Frame Rate: ", "Looped: ", "Anim Type: "];
						var kinds = [Normal, Normal, Number(24), Bool, List(["DANCE_AFTER", "CAN_DANCE", "DANCING", "SINGING", "CHAIN"])];
						curMode = Type(["", "", "24", "False", "DANCE_AFTER"], lines, 0, finishAnim, updateAnim, kinds);
						cancelInput = true;
					case Glfw.KEY_KP_SUBTRACT | Glfw.KEY_MINUS:
						if (anims.length > 0) {
							var lines = ["Animation to delete: "];
							curMode = Type([anims[0]], lines, 0, finishAnimDelete, null, [List(anims)]);
							cancelInput = true;
						}

					case Glfw.KEY_O:
						if (mods & Glfw.MOD_CONTROL == 0) return;
						var chars = [for (file in Paths.folderContents("data/characters")) if (Path.extension(file) == "json") Path.withoutExtension(file)];
						var lines = ["Character to load: "];
						curMode = Type([chars[0]], lines, 0, finishLoadChar, null, [List(chars)]);
						cancelInput = true;
				}
			case Global:
				switch (keyCode) {
					case Glfw.KEY_M:
						curMode = Main;

					case Glfw.KEY_A | Glfw.KEY_D:
						var inc:Float = (CppHelpers.boolToInt(keyCode == Glfw.KEY_D) - CppHelpers.boolToInt(keyCode == Glfw.KEY_A));
						inc *= 1 + 9 * (mods & Glfw.MOD_SHIFT);
						char.positionOffset.x += inc;
						char.data.offsets.x = char.positionOffset.x;
					case Glfw.KEY_W:
						char.positionOffset.y -= 1 + 9 * (mods & Glfw.MOD_SHIFT);
						char.data.offsets.y = char.positionOffset.y;
					case Glfw.KEY_S:
						if (mods & Glfw.MOD_CONTROL != 0) {
							var lines = ["Save as: "];
							curMode = Type([char.curChar], lines, 0, finishSaveChar);
							cancelInput = true;
							return;
						}
						char.positionOffset.y += 1 + 9 * (mods & Glfw.MOD_SHIFT);
						char.data.offsets.y = char.positionOffset.y;

					case Glfw.KEY_LEFT | Glfw.KEY_RIGHT:
						var inc:Float = (CppHelpers.boolToInt(keyCode == Glfw.KEY_RIGHT) - CppHelpers.boolToInt(keyCode == Glfw.KEY_LEFT));
						inc *= 1 + 9 * (mods & Glfw.MOD_SHIFT);
						char.camOffset.x += inc;
					case Glfw.KEY_UP | Glfw.KEY_DOWN:
						var inc:Float = (CppHelpers.boolToInt(keyCode == Glfw.KEY_DOWN) - CppHelpers.boolToInt(keyCode == Glfw.KEY_UP));
						inc *= 1 + 9 * (mods & Glfw.MOD_SHIFT);
						char.camOffset.y += inc;

					case Glfw.KEY_COMMA | Glfw.KEY_PERIOD:
						char.scale += 0.1 * (CppHelpers.boolToInt(keyCode == Glfw.KEY_PERIOD) - CppHelpers.boolToInt(keyCode == Glfw.KEY_COMMA));

					case Glfw.KEY_SLASH | Glfw.KEY_KP_DIVIDE:
						char.data.faceLeft = char.facingLeft = !char.facingLeft;
						updateDirArrow();
					case Glfw.KEY_1 | Glfw.KEY_KP_1:
						char.antialiasing = char.data.antialiasing = !char.antialiasing;
					case Glfw.KEY_0 | Glfw.KEY_KP_0:
						var lines = ["Spritesheet: ", "Icon: "];
						curMode = Type(["", ""], lines, 0, finishTexture);
						cancelInput = true;

					case Glfw.KEY_O:
						if (mods & Glfw.MOD_CONTROL == 0) return;
						var chars = [for (file in Paths.folderContents("data/characters")) if (Path.extension(file) == "json") Path.withoutExtension(file)];
						var lines = ["Character to load: "];
						curMode = Type([chars[0]], lines, 0, finishLoadChar, null, [List(chars)]);
						cancelInput = true;
				}
			case Type(data, lines, index, complete, update, kinds):
				var kind = (kinds == null) ? 0 : kinds[index].getIndex();
				switch (keyCode) {
					case Glfw.KEY_BACKSPACE | Glfw.KEY_DELETE:
						if (kind >= 2)
							return;
						data[index] = data[index].substring(0, data[index].length - 1);
						if (update != null)
							update(data, lines, kinds, index);
						updateTypeText(data, lines, kinds, index);
					case Glfw.KEY_LEFT:
						if (kind < 2)
							return;
						var opts = (kind == 2) ? ["True", "False"] : kinds[index].getParameters()[0];
						data[index] = (kind == 2) ? (data[index] == "True" ? "False" : "True") : opts[(opts.indexOf(data[index]) - 1 + opts.length) % opts.length];
						if (update != null)
							update(data, lines, kinds, index);
						updateTypeText(data, lines, kinds, index);
					case Glfw.KEY_RIGHT:
						if (kind < 2)
							return;
						var opts = (kind == 2) ? ["True", "False"] : kinds[index].getParameters()[0];
						data[index] = (kind == 2) ? (data[index] == "True" ? "False" : "True") : opts[(opts.indexOf(data[index]) + 1) % opts.length];
						if (update != null)
							update(data, lines, kinds, index);
						updateTypeText(data, lines, kinds, index);
					case Glfw.KEY_ENTER | Glfw.KEY_DOWN:
						if (kind == 1) {
							var val = Std.parseFloat(data[index]);
							if (Math.isNaN(val))
								val = kinds[index].getParameters()[0];
							data[index] = Std.string(val);
						}

						index++;
						if (index >= data.length) {
							if (complete != null)
								complete(data, lines, kinds, index);
							curMode = lastMode;
						} else
							curMode = Type(data, lines, index, complete, update, kinds);

					case Glfw.KEY_ESCAPE | Glfw.KEY_UP:
						if (kind == 1) {
							var val = Std.parseFloat(data[index]);
							if (Math.isNaN(val))
								val = kinds[index].getParameters()[0];
							data[index] = Std.string(val);
						}

						index--;
						if (index < 0) {
							curMode = lastMode;
						} else
							curMode = Type(data, lines, index, complete, update, kinds);

				}
			case Indices(length, current, sel, index):
				switch (keyCode) {
					case Glfw.KEY_LEFT | Glfw.KEY_RIGHT:
						if (index != 0) return;
						sel = (sel + (1 - 2 * CppHelpers.boolToInt(keyCode == Glfw.KEY_LEFT)) + length) % length;
						curMode = Indices(length, current, sel, index);
					case Glfw.KEY_UP | Glfw.KEY_DOWN:
						index = (index + (1 - 2 * CppHelpers.boolToInt(keyCode == Glfw.KEY_UP)) + indicesLines.length) % indicesLines.length;
						curMode = Indices(length, current, sel, index);
					case Glfw.KEY_ENTER:
						switch (index) {
							case 0:
								current.push(sel);
								updateIndices(current, sel, index);
							case 1:
								current.pop();
								updateIndices(current, sel, index);
							case 2:
								current.splice(0, current.length);
								updateIndices(current, sel, index);
							case 3:
								char.data.animations[animIndex].frameIndices = (current.length <= 0) ? null : current;
								char.addAnim(char.data.animations[animIndex]);
								char.playAnim(anims[animIndex]);

								curMode = lastMode;
						}
					case Glfw.KEY_ESCAPE:
						curMode = lastMode;
				}
		}
	}
	
	override function keyRepeat(keyCode:Int, scanCode:Int, mods:Int) {
		switch (curMode) {
			case Type(data, lines, index, complete, update, kinds):
				var kind = (kinds == null) ? 0 : kinds[index].getIndex();
				if (kind < 2 && (keyCode == Glfw.KEY_BACKSPACE || keyCode == Glfw.KEY_DELETE)) {
					data[index] = data[index].substring(0, data[index].length - 1);
					if (update != null)
						update(data, lines, kinds, index);
					updateTypeText(data, lines, kinds, index);
				}
			default:
				// do nothin
		}
	}

	function updateAnim(data:Array<String>, lines:Array<String>, kinds:Array<TypeEditKind>, index:Int) {
		if (index == 4) {
			while (data.length > 5) {
				data.pop();
				lines.pop();
				kinds.pop();
			}
			if (data[index] == "CHAIN") {
				data.push("");
				lines.push("Chain Animation: ");
				kinds.push(Normal);
			}
		}
	}

	function finishAnim(data:Array<String>, lines:Array<String>, kinds:Array<TypeEditKind>, index:Int) {
		if (anims.contains(data[0])) {
			for (anim in char.data.animations) {
				if (anim.name == data[0]) {
					anim.prefix = data[1];
					anim.frameRate = Std.parseFloat(data[2]);
					anim.looped = data[3] == "True";
					anim.animType = data[4];
					anim.chainAnim = (data.length > 5) ? data[5] : null;
					char.addAnim(anim);
				}
			}
		} else {
			var anim = {
				name: data[0],
				prefix: data[1],
				offsets: [0.0, 0.0],

				looped: data[3] == "True",
				frameRate: Std.parseFloat(data[2]),

				animType: data[4],
				chainAnim: ((data.length > 5) ? data[5] : null)
			};
			anims.push(data[0]);
			char.data.animations.push(anim);
			char.addAnim(anim);
		}
		animIndex = anims.indexOf(data[0]);
	}

	function finishAnimDelete(data:Array<String>, lines:Array<String>, kinds:Array<TypeEditKind>, index:Int) {
		var spliceIndex = anims.indexOf(data[0]);
		if (spliceIndex > -1) {
			anims.splice(spliceIndex, 1);
			char.data.animations.splice(spliceIndex, 1);
			@:privateAccess char.animData.remove(data[0]);
			char.offsets.remove(data[0]);
			char.types.remove(data[0]);
			@:privateAccess char.danceAnims.remove(data[0]);
			char.chains.remove(data[0]);
		}
		animIndex = 0;
	}

	function finishLoadChar(data:Array<String>, lines:Array<String>, kinds:Array<TypeEditKind>, index:Int) {
		char.loadCharacter(data[0]);
		char.facingLeft = char.data.faceLeft;
		updateDirArrow();
		anims.splice(0, anims.length);
		for (anim in char.data.animations)
			anims.push(anim.name);
		animIndex = 0;
	}

	function finishSaveChar(data:Array<String>, lines:Array<String>, kinds:Array<TypeEditKind>, index:Int) {
		if (!FileSystem.exists(Paths.foldersToCheck[0] + "/data"))
			FileSystem.createDirectory(Paths.foldersToCheck[0] + "/data");
		if (!FileSystem.exists(Paths.foldersToCheck[0] + "/data/characters"))
			FileSystem.createDirectory(Paths.foldersToCheck[0] + "/data/characters");
		sys.io.File.saveContent(Paths.foldersToCheck[0] + "/data/characters/" + data[0] + ".json", haxe.Json.stringify(char.data, "\t"));
	}

	function finishTexture(data:Array<String>, lines:Array<String>, kinds:Array<TypeEditKind>, index:Int) {
		char.data.spritesheet = data[0];
		char.data.icon = data[1];
		char.loadFrames(Paths.file('images/game/characters/${char.data.spritesheet}.xml'));
		updateDirArrow();
	}

	override function destroy() {
		super.destroy();
		pixel.destroy();
	}

	final faceColors:Array<Vector4> = [
		new Vector4(255 / 255, 163 / 255, 77 / 255, 1.0),
		new Vector4(143 / 255, 206 / 255, 252 / 255, 1.0)
	];

	function updateDirArrow() {
		var leftMult = CppHelpers.boolToInt(char.facingLeft);
		dirArrow.anchor.x = leftMult;
		dirArrow.position.copyFrom(char.position);
		dirArrow.position.x += char.width * (1 - leftMult);
		dirArrow.position.y += char.height * 0.5;
		dirArrow.flipX = !char.facingLeft;
		dirArrow.tint.copyFrom(faceColors[leftMult]);
	}

	function set_animIndex(val:Int):Int {
		animIndex = val;
		char.playAnim(anims[val]);
		updateAnimText();
		return animIndex;
	}

	function set_curMode(to:CharEditMode) {
		var idx = to.getIndex();
		controlData.text = controlList[idx];
		switch (to) {
			case Type(data, lines, index, complete, update, kinds):
				lastMode = (curMode == Main || curMode == Global) ? curMode : lastMode;
				updateTypeText(data, lines, kinds, index);
			case Indices(length, current, sel, index):
				lastMode = (curMode == Main || curMode == Global) ? curMode : lastMode;
				updateIndices(current, sel, index);
			default:
				controls.text = "";
		}
		return curMode = to;
	}
}