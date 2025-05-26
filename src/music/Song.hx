package music;

// this is possibly over complicating it........

import moonchart.formats.BasicFormat.DynamicFormat;
import haxe.io.Path;
import sys.FileSystem;
import blueprint.sound.SoundPlayer;

class Song {
	public static var current:Song;

	public var time(get, set):Float;
	public var length(default, null):Float = 0;
	public var looping:Bool = false;
	public var name:String = "idk";
	public var bpmChanges:Array<Array<Float>> = [];
	public var audio:Array<SoundPlayer> = [];
	public var complete(get, never):Bool;
	public var finished:Signal<Song->Void>;

	public function new(name:String, bpms:Array<Array<Float>>) {
		this.name = name;
		this.bpmChanges = bpms;
		this.finished = new Signal();
	}

	function get_time():Float {
		var curTime:Float = 0;
		for (sound in audio)
			curTime = Math.max(curTime, sound.time);
		return curTime;
	}
	function set_time(to:Float):Float {
		for (sound in audio)
			sound.time = to;
		return get_time();
	}

	function get_complete() {
		for (sound in audio) {
			if (!sound.complete)
				return false;
		}
		return true;
	}

	public function play(?atTime:Float) {
		for (sound in audio)
			sound.play(atTime);
	}

	public function pause() {
		for (sound in audio)
			sound.pause();
	}

	public function destroy() {
		for (sound in audio)
			sound.destroy();
	}

	function soundFinished(sound:SoundPlayer) {
		if (!complete) return;

		if (looping)
			play(0.0);
		else
			finished.emit(this);
	}

	// for some setup while pushing
	function pushSound(sound:SoundPlayer) {
		audio.push(sound);
		length = Math.max(length, sound.length);
		sound.finished.add(soundFinished);
	}

	function loadAudio(path:String) {
		if (FileSystem.exists(path)) {
			var tmr = Sys.time();
			var sound = new SoundPlayer(path);
			sound.gain = 0.25;
			sound.keepOnSwitch = true;
			@:privateAccess if (sound.data != null)
				pushSound(sound);
			else
				sound.destroy();

			Sys.println('Loaded $path (${Math.round((Sys.time() - tmr) * 1000) * 0.001} s)');
		}
	}

	public static function setCurrentFromChart(data:DynamicFormat, path:String, diff:String):GameSong {
		final castSong:GameSong = (current != null && current is GameSong) ? cast current : null;

		if (castSong != null && castSong.data == data)
			return castSong.loadDiff(diff);

		final audio = (current != null) ? current.audio : null;
		final reloadAudio = (castSong == null || castSong.path != path);

		if (reloadAudio && current != null)
			current.destroy();
		var gameSong = new GameSong(data, path, diff);
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