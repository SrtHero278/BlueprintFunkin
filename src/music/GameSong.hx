package music;

import moonchart.backend.FormatData;
import moonchart.backend.FormatDetector;
import moonchart.backend.Util.resolveEventValues;
import moonchart.formats.BasicFormat;
import moonchart.formats.StepMania;
import moonchart.formats.fnf.legacy.FNFLegacy;
import moonchart.parsers.StepManiaParser;
import sys.FileSystem;
import sys.io.File;
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
				time: (Math.max(bpm.time, 0) - offset) * 0.001, // use max mainly cuz cne.
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
		
		var timingIdx = 0;
		var crotDiv = 1 / timingPoints[timingIdx].crochet;
		inline function getRow(time:Float)
			return Math.round(((time - timingPoints[timingIdx].time) * crotDiv) * 48);

		final invertLanes = resolveInvert(diff);
		notes = [];
		for (note in data.getNotes(diff)) {
			final time = (note.time - offset) * 0.001;
			final lane = Math.floor(note.lane % 4);
			final char = (invertLanes != (note.lane < 4)) ? 0 : 1;
			while (timingIdx < timingPoints.length - 1 && timingPoints[timingIdx + 1].time < time) {
				++timingIdx;
				crotDiv = 1 / timingPoints[timingIdx].crochet;
			}

			final row = getRow(time);
			var i = notes.length - 1;
			var pushData = true;
			while (i >= 0 && getRow(notes[i].time) == row) {
				if (notes[i].char == char && notes[i].lane == lane) {
					// override the stack data instead.
					notes[i].length = Math.max(note.length, 0.0) * 0.001;
					//notes[i].type = 
					pushData = false;
					break;
				}
				--i;
			}
			if (!pushData) continue;

			final data:ChartNote = {
				time: time,
				lane: lane,
				length: Math.max(note.length, 0.0) * 0.001,
				char: char
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
			case FNFLegacy.FNF_LEGACY_MUST_HIT_SECTION_EVENT:
				name = "Retarget Camera";
				params = [event.data.mustHitSection ? 1 : 0];

			case moonchart.formats.fnf.FNFCodename.CODENAME_CAM_MOVEMENT:
				name = "Retarget Camera";
				params = event.data.array;
			case "Camera Modulo Change":
				name = "Bump Interval";
				params = event.data.array;

			case moonchart.formats.fnf.FNFVSlice.VSLICE_FOCUS_EVENT:
				event.data = expectFields(event.data, ["char", "duration", "ease", "x", "y"]);
				params = resolveEventValues(event);
			case "ZoomCamera":
				event.data = expectFields(event.data, ["zoom", "duration", "ease", "mode"]);
				params = resolveEventValues(event);
			case "SetCameraBop":
				event.data = expectFields(event.data, ["intensity", "rate"]);
				name = "Bump Interval";
				params = resolveEventValues(event);
				params = [params[1], params[0]]; // alphabetical ordering sooooo

			default:
				params = resolveEventValues(event);
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

	function resolveInvert(diff:String):Bool {
		return switch (Type.getClass(data)) {
			case moonchart.formats.OsuMania:
				chartMeta.extraData.get(LANES_LENGTH) < 8;
			case StepMania | moonchart.formats.StepManiaShark:
				final sm:StepManiaBasic<StepManiaFormat> = cast data;
				sm.data.NOTES.get(diff).dance == SINGLE;
			case moonchart.formats.Quaver:
				true; // its always gonna be 4-7 so
			default:
				false;
		};
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



	/**
		A variation of FormatDetector.findFormat designed to work better with BlueprintFunkin's multidiff charts.

		Or, at least it was. It got modified heavily.
	**/
	public static function findMultiDiff(inputFile:String, metaPath:String):FormatData {
		var possibleFormats:Array<Format> = multiDiffFormats.filter((format) -> {
			final data = FormatDetector.getFormatData(format);
			final file = inputFile + "." + data.extension;

			return (FileSystem.exists(file) && (data.hasMetaFile != TRUE || FileSystem.exists(metaPath + "." + data.metaFileExtension)));
		});

		// Check if we got the format with the first filter
		if (possibleFormats.length <= 0)
			return null; // dont say anything, we still have single diffs to check!
		else if (possibleFormats.length == 1)
			return FormatDetector.getFormatData(possibleFormats[0]);

		// Not sure how i can make findFromContents work with this so checkContents is off meaning "Fuck it we ball" -Maru
		return FormatDetector.getFormatData(possibleFormats[possibleFormats.length - 1]);
	}

	/**
		A variation of FormatDetector.findFormat designed to work better with BlueprintFunkin's singlediff charts.
	**/
	public static function trySingleDiff(inputFile:String, metaPath:String):FormatData {
		var isFolder:Bool = FileSystem.isDirectory(inputFile);
		var fileExtension:String = (isFolder ? "" : haxe.io.Path.extension(inputFile));

		// Check based on simple data like extensions, folders, needs metadata, etc
		var possibleFormats = singleDiffFormats.filter((format) -> {
			final data = FormatDetector.getFormatData(format);

			// Setting up some format crap
			final forcedMeta:Bool = (data.hasMetaFile == TRUE);
			final possibleMeta:Bool = (data.hasMetaFile == POSSIBLE);
			final needsFolder:Bool = data.extension.startsWith("folder");
			final extension:String = (needsFolder ? data.extension.split("::").pop() : data.extension);

			// Do the checks for matching formats
			final hasMeta:Bool = FileSystem.exists(metaPath + "." + data.metaFileExtension);
			final metaMatch:Bool = ((forcedMeta == hasMeta) || possibleMeta);
			final folderMatch:Bool = (needsFolder == isFolder);
			final extensionMatch:Bool = (isFolder || (extension == fileExtension));

			// Finally, filter in or out matching formats
			return metaMatch && folderMatch && extensionMatch;
		});

		// Check if we got the format with the first filter
		if (possibleFormats.length <= 0)
		{
			Sys.println('Failed to load "$inputFile": Format nonexistant.');
			return null;
		}
		else if (possibleFormats.length == 1)
		{
			return FormatDetector.getFormatData(possibleFormats[0]);
		}

		return FormatDetector.getFormatData(FormatDetector.findFromContents(File.getContent(inputFile), {possibleFormats: possibleFormats}));
	}
}