package music;

import moonchart.backend.FormatData;
import moonchart.backend.FormatDetector;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.legacy.FNFLegacy;
import sys.FileSystem;
import sys.io.File;
import haxe.Json;
import blueprint.sound.SoundPlayer;

using StringTools;

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

typedef OgChart = {
	var song:String;

	var ?format:String;
	var ?events:Array<Dynamic>;
	var notes:Array<OgSection>;
	var speed:Float;
	var bpm:Float;

	var ?player1:String;
	var ?player2:String;
	var ?gfVersion:String;
	var ?stage:String;
}

typedef OgSection = {
	var sectionNotes:Array<Array<Dynamic>>;
	var mustHitSection:Bool;
	var changeBPM:Bool;
	var ?bpm:Float;
	var ?sectionBeats:Float;
	var ?lengthInSteps:Float;
}

class GameSong extends Song {
	public static var multiDiffExts:Array<String>;
	public static var singleDiffExts:Array<String>;
	public static var multiDiffFormats:Array<Format>;
	public static var singleDiffFormats:Array<Format>;

	public var data:DynamicFormat;
	public var chartMeta:BasicMetaData;
	public var path:String;
	public var diff:String = "idk";
	public var chars:Array<String> = ["bf", "dad", "gf"];
	public var stage:String = "stage";
	public var speed:Float = 3.0;
	public var offset:Float = 0.0;
	public var notes:Array<ChartNote> = [];
	public var events:Array<Event> = [];

	public function new(data:DynamicFormat, path:String, diff:String) {
		this.data = data;
		this.path = path;
		this.chartMeta = data.getChartMeta();
		this.offset = resolveOffset();

		var times:Array<TimingPoint> = [];
		for (bpm in chartMeta.bpmChanges) {
			final data:TimingPoint = {
				time: (Math.min(bpm.time, 0) - offset) * 0.001, // use min mainly cuz cne.
				bpm: bpm.bpm,
				stepsPerBeat: bpm.stepsPerBeat,
				beatsPerMeasure: bpm.beatsPerMeasure
			};

			if (times.length > 0) {
				final lastPoint = times[times.length - 1];
				final measureDist = Math.fround((data.time - lastPoint.time) / (data.crochet * data.beatsPerMeasure) * 192) / 192;
				data.measure = lastPoint.measure + measureDist;
				data.beat = lastPoint.beat + (measureDist * data.beatsPerMeasure);
				data.step = lastPoint.step + (measureDist * data.beatsPerMeasure * data.stepsPerBeat);
			}
			times.push(data);
		}

		super(path, times);
		loadDiff(diff);
	}

	public function loadDiff(diff:String) {
		this.diff = diff;
		chars = [
			((chartMeta.extraData[PLAYER_1] != null) ? chartMeta.extraData[PLAYER_1] : "bf"),
			((chartMeta.extraData[PLAYER_2] != null) ? chartMeta.extraData[PLAYER_2] : "dad"),
			((chartMeta.extraData[PLAYER_3] != null) ? chartMeta.extraData[PLAYER_3] : "gf")
		];
		stage = (chartMeta.extraData.exists(STAGE)) ? chartMeta.extraData[STAGE] : "stage";
		speed = (chartMeta.scrollSpeeds.exists(diff)) ? chartMeta.scrollSpeeds[diff] : 3.0;
		
		notes = [];
		for (note in data.getNotes(diff)) {
			final data:ChartNote = {
				time: (note.time - offset) * 0.001,
				lane: Math.floor(note.lane % 4),
				length: Math.max(note.length, 0.0) * 0.001,
				char: (note.lane < 4) ? 0 : 1
			}
			notes.push(data);
		}

		return this;
	}

	// seperated so it's not doing so in SongList.
	public function loadEvents() {
		events = [];
		for (event in data.getEvents())
			events.push(resolveEvent(event));
	}

	function resolveEvent(event:BasicEvent):Event {
		var name = event.name;
		var params:Array<Dynamic> = [];
		switch (event.name) {
			case moonchart.formats.fnf.legacy.FNFLegacy.FNF_LEGACY_MUST_HIT_SECTION_EVENT:
				name = "Retarget Camera";
				params = [event.data.mustHitSection ? 1 : 0];
			case moonchart.formats.fnf.FNFCodename.CODENAME_CAM_MOVEMENT:
				name = "Retarget Camera";
				params = event.data.array;
			case moonchart.formats.fnf.FNFVSlice.VSLICE_FOCUS_EVENT:
				event.data = expectFields(event.data, ["char", "duration", "ease", "x", "y"]);
				params = moonchart.backend.Util.resolveEventValues(event);
			case "ZoomCamera":
				event.data = expectFields(event.data, ["zoom", "duration", "ease", "mode"]);
				params = moonchart.backend.Util.resolveEventValues(event);
			default:
				params = moonchart.backend.Util.resolveEventValues(event);
		}

		return {
			time: (event.time - offset) * 0.001,
			name: name,
			params: params
		};
	}

	function expectFields(input:Dynamic, fields:Array<String>) {
		var result = {};
		if (Reflect.isObject(input)) {
			for (field in fields)
				Reflect.setField(result, field, Reflect.field(input, field));
		} else if (fields.length > 0) {
			Reflect.setField(result, fields[0], input);
			for (i in 1...fields.length)
				Reflect.setField(result, fields[i], null);
		}
		return result;
	}

	function resolveOffset():Float {
		return switch (Type.getClass(data)) {
			case moonchart.formats.OsuMania: // AudioLeadIn is NOT a song offset.
				0.0;
			default:
				chartMeta.offset;
		};
	}

	/*function loadDefault(json:OgChart) {
		name = json.song;
		chars = [json.player1 != null ? json.player1 : "bf", json.player2 != null ? json.player2 : "dad", json.gfVersion != null ? json.gfVersion : "gf"];
		stage = json.stage != null ? json.stage : "stage";
		bpmChanges = [[0, 0, json.bpm, 60 / json.bpm]];
		speed = json.speed;

		var curBeat:Float = 0;
		var curTime:Float = 0;
		var lastMustHit:Bool = false;
		var isNewPsych:Bool = json.format != null && json.format.startsWith("psych_v1");
		for (section in json.notes) {
			if (lastMustHit != section.mustHitSection) {
				lastMustHit = section.mustHitSection;
				events.push({time: curTime, name: "Retarget Camera", params: [lastMustHit ? 1 : 0]});
			}

			for (note in section.sectionNotes) {
				final data:ChartNote = {
					time: note[0] * 0.001,
					lane: Math.floor(note[1] % 4),
					length: Math.max(note[2], 0.0) * 0.001,
					char: (note[1] % 8 < 4 != lastMustHit) ? 0 : 1
				}
				notes.push(data);
			}

			if (section.changeBPM && section.bpm != null)
				bpmChanges.push([curTime, curBeat, section.bpm, 60 / section.bpm]);
			var beatInc = (section.sectionBeats != null) ? section.sectionBeats : (section.lengthInSteps != null) ? section.lengthInSteps * 0.25 : 4;
			curBeat += beatInc;
			curTime += beatInc * bpmChanges[bpmChanges.length - 1][3];
		}
		notes.sort(sortNotes);
	}*/

	function sortNotes(note1:ChartNote, note2:ChartNote) {
		return Math.floor(note1.time - note2.time);
	}

	override function loadAudio(path:String) {
		final folder = Paths.songFile("audio", path);
		if (Paths.exists(folder, true) && FileSystem.isDirectory(folder)) {
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