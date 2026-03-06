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
	public var tick:Signal<Strumline->Note->Void>;
	public var missed:Signal<Strumline->Note->Void>;

	// Visual Stuff
	public var characters:Array<Character> = [];
	public var strums:Group<AnimatedSprite>;
	public var notes:Group<Note>;
	public var speed:Float = 3.2;
	public var scrollMult(default, set):Float = 1;

	public function new(xFactor:Float, speed:Float) {
		super(blueprint.Game.window.width * xFactor, 0);
		this.speed = speed;

		hit = new Signal();
		tick = new Signal();
		missed = new Signal();

		add(strums = new Group(0, -255));
		add(notes = new Group(0, -255));

		final directions = ["left", "down", "up", "right"];
		for (i in 0...4) {
			var strum = new AnimatedSprite(160 * 0.7 * (-1.5 + i), 0, Paths.sparrowXml("game/strums"));
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

		if (Settings.downscroll)
			scrollMult *= -1;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		for (note in notes) {
			final strum:AnimatedSprite = strums.members[note.data.lane];

			if (note.holding) {
				note.position.copyFrom(strum.position);
				
				note.setLength(note.length - elapsed, speed);
				note.untilTick -= elapsed;
	
				if (note.untilTick <= 0.0) {
					note.untilTick = Conductor.stepCrochet;
					strum.playAnim("confirm", true);
					tick.emit(this, note);
					for (char in characters)
						char.playAnim(note.singAnim);
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
				if (!note.wasHit || note.length > hitWindow) {
					missed.emit(this, note);
					for (char in characters)
						char.playAnim(note.missAnim);
				}
				notes.remove(note);
				note.destroy();
			}
	
			final distance = speed * 450 * (note.hitTime - Conductor.position);
			note.position.x = strum.position.x;
			note.position.y = strum.position.y + distance * scrollMult;
		}
	}

	public function keyDown(keyCode:Int) {
		var index = -1;
		for (i in 0...keybinds.length)
			index = (keybinds[i].contains(keyCode)) ? i : index;
		if (index < 0)
			return;

		final strum:AnimatedSprite = strums.members[index];
		for (note in notes) {
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

		strums.members[index].playAnim("static", true);
		for (note in notes) {
			if (note.data.lane == index && note.holding) {
				note.holding = false;
				note.hitTime = Conductor.position;
				if (note.length <= hitWindow) {
					notes.remove(note);
					note.destroy();
				}
			}
		}
	}

	function tryDeleteNote(note:Note) {
		note.wasHit = true;
		note.holding = (note.length > 0.0);
		if (!note.holding) {
			notes.remove(note);
			note.destroy();
		} else {
			note.untilTick = Conductor.stepCrochet - (Conductor.position % Conductor.stepCrochet);
			note.setLength(note.length + note.hitTime - Conductor.position, speed);
		}
	}

	function get_isCpu():Bool {
		return keybinds.length != strums.members.length;
	}

	function set_scrollMult(newMult:Float) {
		strums.position.y = notes.position.y = -255 * newMult;
		for (note in notes.members)
			note.holdScale = newMult;
		return scrollMult = newMult;
	}
}