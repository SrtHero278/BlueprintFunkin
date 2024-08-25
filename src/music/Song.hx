package music;

// this is possibly over complicating it........

import haxe.io.Path;
import sys.FileSystem;
import blueprint.sound.SoundPlayer;

class Song {
	public static var current:Song;

	public var time(get, set):Float;
	public var looping(get, set):Bool;
	public var name:String = "idk";
	public var bpmChanges:Array<Array<Float>> = [];
	public var audio:Array<SoundPlayer> = [];

	public function new(name:String, bpms:Array<Array<Float>>) {
		this.name = name;
		this.bpmChanges = bpms;
	}

	function get_time():Float {
		return (audio.length > 0) ? audio[0].time : 0;
	}
	function set_time(to:Float):Float {
		for (sound in audio)
			sound.time = to;
		return get_time();
	}

	function get_looping():Bool {
		return (audio.length > 0) ? audio[0].looping : false;
	}
	function set_looping(to:Bool):Bool {
		for (sound in audio)
			sound.looping = to;
		return get_looping();
	}

	public function play() {
		for (sound in audio)
			sound.play();
	}

	public function pause() {
		for (sound in audio)
			sound.pause();
	}

	public function destroy() {
		for (sound in audio)
			sound.destroy();
	}

	function loadAudio(path:String) {
		if (FileSystem.exists(path)) {
			var tmr = Sys.time();
			var sound = new SoundPlayer(path);
			sound.gain = 0.25;
			sound.keepOnSwitch = true;
			@:privateAccess if (sound.data != null)
				audio.push(sound);
			else
				sound.destroy();

			Sys.println('Loaded $path (${Math.round((Sys.time() - tmr) * 1000) * 0.001} s)');
		}
	}

	public static function setCurrentFromChart(path:String, diff:String):GameSong {
		var audio = (current != null) ? current.audio : null;
		var reloadAudio = (current == null || !Std.isOfType(current, GameSong) || cast(current, GameSong).path != path);

		if (reloadAudio && current != null)
			current.destroy();
		var gameSong = new GameSong(path, diff);
		current = gameSong;

		if (reloadAudio)
			current.loadAudio(path);
		else
			current.audio = audio;
		return gameSong;
	}

	public static function setCurrentAsBasic(path:String, name:String, bpm:Float, ?bpms:Array<Array<Float>>):Song {
		if (current != null)
			current.destroy();
		bpms = (bpms != null) ? bpms : [[0, 0, bpm, 60 / bpm]];
		current = new Song(name, bpms);
		current.loadAudio(Paths.audio(path));
		return current;
	}
}