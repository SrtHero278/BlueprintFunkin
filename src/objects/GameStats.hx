package objects;

import math.Vector4;

@:structInit class Judgement {
	public var image:String;
	public var window:Float;
	public var score:Int;
	public var accuracy:Float;
	public var hpGain:Float;
}
@:structInit class Ranking {
	public var image:String;
	public var window:Float;
	public var color:Vector4;
}

class GameStats {
	public var hitWindow(get, never):Float;
	var ranks:Array<Ranking> = [
		{image: "perfect",	window: 1.0,	color: new Vector4(0.0, 1.0, 1.0, 1.0)},
		{image: "sick",     window: 0.85,   color: new Vector4(1.0, 1.0, 0.85, 1.0)},
		{image: "amazing",	window: 0.7,	color: new Vector4(0.0, 1.0, 0.0, 1.0)},
		{image: "basic",	window: 0.4,	color: new Vector4(1.0, 0.9, 0.0, 1.0)},
		{image: "crap",		window: 0.1,	color: new Vector4(0.8, 0.35, 0.0, 1.0)},
		{image: "fail",		window: 0.0,	color: new Vector4(0.8, 0.0, 0.0, 1.0)}
	];
	var judgements:Array<Judgement> = [
		{image: "sick",	window: 0.045,	score: 350,	accuracy: 1,	hpGain: 0.023},
		{image: "good",	window: 0.090,	score: 250,	accuracy: 0.85,	hpGain: 0.015},
		{image: "bad",	window: 0.135,	score: 50,	accuracy: 0.6,	hpGain: 0.005},
		{image: "shit",	window: 0.160,	score: -15,	accuracy: 0.15,	hpGain: -0.01}
	];

	var curRank:Ranking;
	var score:Int = 0;
	var misses:Int = 0;
	var accuracy:Float = 1;
	var totalNotes:Int = 0;
	var ratingNotes:Float = 0.0;

	public var health:Float = 1.0;
	public var maxHealth:Float = 2.0;

	public function new() {}

	public function updateRanking() {
		accuracy = ratingNotes / totalNotes;
		for (rank in ranks) {
			if (accuracy >= rank.window) {
				curRank = rank;
				break;
			}
		}
	}

	public function getJudgement(noteDiff:Float, ?applyData:Bool = true) {
		for (judge in judgements) {
			if (noteDiff <= judge.window) {
				if (applyData) {
					totalNotes++;
					score += judge.score;
					ratingNotes += judge.accuracy;
					health = Math.min(Math.max(health + judge.hpGain, 0.0), maxHealth);
					updateRanking();
				}
				return judge;
			}
		}
		return judgements[judgements.length - 1];
	}

	public function addMiss() {
		misses++;
		totalNotes++;
		health = Math.max(health - 0.046, 0.0);
		updateRanking();
	}

	function get_hitWindow() {
		return judgements[judgements.length - 1].window;
	}
}