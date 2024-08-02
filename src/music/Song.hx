package music;

// still gotta update this. this was from Camellia-Blueprint.

import sys.FileSystem;
import sys.io.File;
import haxe.Json;
import blueprint.sound.SoundPlayer;

@:structInit class ChartNote {
	public var time:Float;
	public var lane:Int;
	public var length:Float;
}

class Song {
	public var name:String = "idk";
	public var diff:String = "idk";
	public var chars:Array<String> = ["bf", "camellia", "gf"];
	public var stage:String = "stage";
	public var bpm:Float = 120;
	public var speed:Float = 3.0;
	public var notes:Array<ChartNote> = [];
	public var bpmChanges:Array<Array<Float>> = [];
	public var audio:Array<SoundPlayer> = [];

	public function new(path:String, diff:String) {
		var tmr = Sys.time();
		this.diff = diff;
		final folder = 'assets/songs/$path/';

		try {
			Sys.println(folder + 'diffs/$diff.json');
			final json = Json.parse(File.getContent(folder + 'diffs/$diff.json')).song;
			name = json.song;
			chars = [json.player1, json.player2, "gf"];
			stage = json.stage;
			bpm = json.bpm;
			speed = json.speed;

			var curBeat:Float = 0;
			for (section in cast (json.notes, Array<Dynamic>)) {
				for (note in cast(section.sectionNotes, Array<Dynamic>)) {
					note = cast cast(note, Array<Dynamic>);
					final data:ChartNote = {
						time: note[0] * 0.001,
						lane: Math.floor(note[1] % 8),
						length: Math.max(note[2], 0.0) * 0.001
					}
					if (section.mustHitSection)
						data.lane = (data.lane + 4) % 8;
					notes.push(data);
				}

				if (section.changeBPM && section.bpm != null)
					bpmChanges.push([curBeat, section.bpm]);
				curBeat += (section.sectionBeats != null) ? section.sectionBeats : (section.lengthInSteps != null) ? section.lengthInSteps * 0.25 : 4;
			}
			notes.sort(sortNotes);
		} catch (e) {
			Sys.println('Failed to load JSON for $path: $e');
		}

		Sys.println('Loaded JSON for $path (${Math.round((Sys.time() - tmr) * 1000) * 0.001} s)');
		loadSongs(path);
	}

	public function play() {
		for (sound in audio)
			sound.play();
	}

	public function pause() {
		for (sound in audio)
			sound.pause();
	}
	
	public function resync() {
		for (sound in audio)
			sound.time = Conductor.position;
	}

	public function destroy() {
		for (sound in audio)
			sound.destroy();
	}

	function sortNotes(note1:ChartNote, note2:ChartNote) {
		return Math.floor(note1.time - note2.time);
	}

	function loadSongs(path:String) {
		final folder = 'assets/songs/$path/audio';
		if (FileSystem.exists(folder)) {
			for (file in FileSystem.readDirectory(folder)) {
				var tmr = Sys.time();
				var sound = new SoundPlayer(folder + '/$file');
				sound.gain = 0.25;
				sound.keepOnSwitch = true;
				@:privateAccess if (sound.data != null)
					audio.push(sound);
				else
					sound.destroy();

				Sys.println('Loaded $file for $path (${Math.round((Sys.time() - tmr) * 1000) * 0.001} s)');
			}
		}
	}
}