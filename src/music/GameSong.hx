package music;

import sys.FileSystem;
import sys.io.File;
import haxe.Json;
import blueprint.sound.SoundPlayer;

@:structInit class ChartNote {
	public var time:Float;
	public var lane:Int;
	public var length:Float;
	public var char:Int;
}

@:structInit class Event {
	public var time:Float;
	public var name:String;
	public var params:Array<Dynamic>;

	@:optional public var func:haxe.Constraints.Function;
}

class GameSong extends Song {
	public var path:String;
	public var diff:String = "idk";
	public var chars:Array<String> = ["bf", "dad", "gf"];
	public var stage:String = "stage";
	public var speed:Float = 3.0;
	public var notes:Array<ChartNote> = [];
	public var events:Array<Event> = [];

	public function new(path:String, diff:String) {
		var tmr = Sys.time();
		this.path = path;
		this.diff = diff;

		var name = path;
		var bpms = [[0, 0, 120, 0.5]];
		try {
			final jsonPath = Paths.songFile('diffs/$diff.json', path);
			final json = Json.parse(File.getContent(jsonPath)).song;
			name = json.song;
			chars = [json.player1 != null ? json.player1 : "bf", json.player2 != null ? json.player2 : "dad", json.gfVersion != null ? json.gfVersion : "gf"];
			stage = json.stage;
			bpms = [[0, 0, json.bpm, 60 / json.bpm]];
			speed = json.speed;

			var curBeat:Float = 0;
			var curTime:Float = 0;
			var lastMustHit:Bool = false;
			for (section in cast (json.notes, Array<Dynamic>)) {
				if (lastMustHit != section.mustHitSection) {
					lastMustHit = section.mustHitSection;
					events.push({time: curTime, name: "Retarget Camera", params: [lastMustHit ? 1 : 0]});
				}

				for (note in cast(section.sectionNotes, Array<Dynamic>)) {
					note = cast cast(note, Array<Dynamic>);
					final data:ChartNote = {
						time: note[0] * 0.001,
						lane: Math.floor(note[1] % 4),
						length: Math.max(note[2], 0.0) * 0.001,
						char: (note[1] % 8 < 4 != lastMustHit) ? 0 : 1
					}
					notes.push(data);
				}

				if (section.changeBPM && section.bpm != null)
					bpms.push([curTime, curBeat, section.bpm, 60 / section.bpm]);
				var beatInc = (section.sectionBeats != null) ? section.sectionBeats : (section.lengthInSteps != null) ? section.lengthInSteps * 0.25 : 4;
				curBeat += beatInc;
				curTime += beatInc * bpms[bpms.length - 1][3];
			}
			notes.sort(sortNotes);
		} catch (e) {
			Sys.println('Failed to load JSON for $path: $e');
		}

		Sys.println('Loaded JSON for $path (${Math.round((Sys.time() - tmr) * 1000) * 0.001} s)');
		super(name, bpms);
	}

	function sortNotes(note1:ChartNote, note2:ChartNote) {
		return Math.floor(note1.time - note2.time);
	}

	override function loadAudio(path:String) {
		final folder = Paths.songFile("audio", path);
		if (FileSystem.exists(folder)) {
			for (file in FileSystem.readDirectory(folder)) {
				var tmr = Sys.time();
				var sound = new SoundPlayer(folder + '/$file');
				sound.gain = 0.25;
				sound.keepOnSwitch = true;
				@:privateAccess if (sound.data != null)
					pushSound(sound);
				else
					sound.destroy();

				Sys.println('Loaded $file for $path (${Math.round((Sys.time() - tmr) * 1000) * 0.001} s)');
			}
		}
	}
}