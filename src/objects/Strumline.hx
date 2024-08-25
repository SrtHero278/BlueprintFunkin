package objects;

import blueprint.objects.AnimatedSprite;
import blueprint.objects.Group;
import objects.Note;

class Strumline extends Group {
	// Input Stuff
	public var hitWindow:Float = 0.16;
	public var keybinds:Array<Array<Int>> = []; // keep empty for cpu.
	public var isCpu(get, never):Bool;
	public var hit:Signal<Strumline->Note->Void>;
	public var missed:Signal<Strumline->Note->Void>;

	// Visual Stuff
	public var characters:Array<Character> = [];
	public var strums:Group;
	public var notes:Group;
	public var speed:Float = 3.2;

	public function new(xFactor:Float, speed:Float) {
		super(blueprint.Game.window.width * xFactor, 0);
		this.speed = speed;

		hit = new Signal();
		missed = new Signal();

		add(strums = new Group(0, -244));
		add(notes = new Group(0, -244));

		final directions = ["left", "down", "up", "right"];
		for (i in 0...4) {
			var strum = new AnimatedSprite(160 * 0.7 * (-1.5 + i), 0, Paths.file("images/game/strums.xml"));
			strum.addPrefixAnim("static", "arrow" + directions[i].toUpperCase());
			strum.addPrefixAnim("press", directions[i] + " press", 24);
			strum.addPrefixAnim("confirm", directions[i] + " confirm", 24);
			strum.playAnim("static");
			strum.scale.set(0.7);
			strum.finished.add(function(name) {
				if (name == "confirm" && isCpu)
					strum.playAnim("static", true);
			});
			strums.add(strum);
		}
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		for (spr in notes.members) {
			final note:Note = cast spr;
			final strum:AnimatedSprite = cast strums.members[note.data.lane];

			if (note.holding) {
				note.position.copyFrom(strum.position);
				
				note.setLength(note.length - elapsed, speed);
				note.untilTick -= elapsed;
	
				if (note.untilTick <= 0.0) {
					note.untilTick = Conductor.stepCrochet;
					for (char in characters)
						char.playAnim(note.singAnim);
					strum.playAnim("confirm", true);
				}
				
				if (note.length <= 0.0) {
					notes.remove(note);
					note.destroy();
				}
				continue;
			}


			if (isCpu && note.hitTime < Conductor.position && !note.wasHit) {
				strum.playAnim("confirm");
				hit.emit(this, note);
				for (char in characters)
					char.playAnim(note.singAnim);
				tryDeleteNote(note);
			} else if (!isCpu && note.hitTime - Conductor.position < -hitWindow) {
				if (!note.wasHit || note.length >= Conductor.stepCrochet * 0.5) {
					missed.emit(this, note);
					for (char in characters)
						char.playAnim(note.missAnim);
				}
				note.memberOf.remove(note);
				note.destroy();
			}
	
			final distance = speed * 450 * (note.hitTime - Conductor.position);
			note.position.x = strum.position.x;
			note.position.y = strum.position.y + distance;
		}
	}

	public function keyDown(keyCode:Int) {
		var index = -1;
		for (i in 0...keybinds.length)
			index = (keybinds[i].contains(keyCode)) ? i : index;
		if (index < 0)
			return;

		final strum:AnimatedSprite = cast strums.members[index];
		for (spr in notes.members) {
			final note:Note = cast spr;

			if (note.data.lane == index && Math.abs(note.hitTime - Conductor.position) <= hitWindow && !note.holding) {
				strum.playAnim("confirm");
				if (!note.wasHit) {
					hit.emit(this, note);
					for (char in characters)
						char.playAnim(note.singAnim);
					tryDeleteNote(note);
					return;
				}
				tryDeleteNote(note);
			}
		}

		strum.playAnim("press");
	}

	public function keyUp(keyCode:Int) {
		var index = -1;
		for (i in 0...keybinds.length)
			index = (keybinds[i].contains(keyCode)) ? i : index;
		if (index < 0)
			return;

		cast(strums.members[index], AnimatedSprite).playAnim("static", true);
		for (spr in notes.members) {
			final note:Note = cast spr;

			if (note.data.lane == index && note.holding) {
				note.holding = false;
				note.hitTime = Conductor.position;
				if (note.length < Conductor.stepCrochet * 0.5) {
					notes.remove(note);
					note.destroy();
				}
			}
		}
	}

	function tryDeleteNote(note:Note) {
		note.wasHit = true;
		note.holding = (note.length > 0.0);
		note.untilTick = Conductor.stepCrochet - (Conductor.position % Conductor.stepCrochet);
		if (!note.holding) {
			notes.remove(note);
			note.destroy();
		} else {
			note.setLength(note.length + note.hitTime - Conductor.position, speed);
		}
	}

	function get_isCpu():Bool {
		return keybinds.length != strums.members.length;
	}
}