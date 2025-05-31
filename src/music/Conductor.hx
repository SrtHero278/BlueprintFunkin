package music;

@:structInit class TimingPoint {
    public var bpm(default, set):Float = 120;
    public var crochet:Float = 0.5;

    public var time:Float = 0;
    public var step:Float = 0;
    public var beat:Float = 0;
    public var measure:Float = 0;

    public var stepsPerBeat:Float = 4;
    public var beatsPerMeasure:Float = 4;

    function set_bpm(to:Float) {
        crochet = 60.0 / to;
        return bpm = to;
    }

    public function new(?bpm:Float = 120, ?time:Float = 0, ?step:Float = 0, ?beat:Float = 0, ?measure:Float = 0, ?stepsPerBeat:Float = 4, ?beatsPerMeasure:Float = 4) {
        this.bpm = bpm;

        this.time = time;
        this.step = step;
        this.beat = beat;
        this.measure = measure;
        
        this.stepsPerBeat = stepsPerBeat;
        this.beatsPerMeasure = beatsPerMeasure;
    }
}

class Conductor {
    public static var bpm(get, default):Float = 120;
    public static var crochet(get, never):Float;
    public static var stepCrochet(get, never):Float;

    public static var position:Float = 0.0;
    public static var beatOffset:Float = 0.0;

    public static var floatMeasure:Float = 0.0;
    public static var floatBeat:Float = 0.0;
    public static var floatStep:Float = 0.0;

    public static var measure:Int = 0;
    public static var beat:Int = 0;
    public static var step:Int = 0;
    public static var curChange:Int = 0;

    public static var onMeasure:Signal<Int->Void> = new Signal();
    public static var onBeat:Signal<Int->Void> = new Signal();
    public static var onStep:Signal<Int->Void> = new Signal();

    public static function reset(bpm:Float, ?removeSignals:Bool = true) {
        Conductor.position = 0.0;
        Conductor.beatOffset = 0.0;
        Conductor.floatBeat = 0.0;
        Conductor.floatStep = 0.0;
        Conductor.beat = 0;
        Conductor.step = 0;
        Conductor.bpm = bpm;
        Conductor.curChange = 0;

        if (removeSignals) {
            for (func in onBeat.funcsToCall)
                onBeat.remove(func);
            for (func in onStep.funcsToCall)
                onStep.remove(func);
        }
    }

    public static function update(elapsed:Float) {
        if (Song.current != null && Song.current.audio.length > 0) {
            var lastTime = position;
            var points = Song.current.timingPoints;
            position = Song.current.time;

            if (position < lastTime) {
                while (curChange > 0 && points[curChange].time > position)
                    --curChange;
            } else if (points.length > 1) {
                while (curChange < points.length && points[curChange].time < position)
                    ++curChange;
            }

            final curPoint = points[curChange];
            final measureDist = (position - curPoint.time + beatOffset) / (curPoint.crochet * curPoint.beatsPerMeasure);
            floatMeasure = curPoint.measure + measureDist;
            floatBeat = curPoint.beat + (measureDist * curPoint.beatsPerMeasure);
            floatStep = curPoint.step + (measureDist * curPoint.beatsPerMeasure * curPoint.stepsPerBeat);
        } else {
            position += elapsed;
            floatBeat = (position + beatOffset) * (bpm / 60);
            floatStep = floatBeat * 4.0;
            floatMeasure = floatBeat * 0.25;
        }

        final floorBeat = Math.floor(floatBeat);
        final floorStep = Math.floor(floatStep);

        if (beat != floorBeat) {
            beat = floorBeat;
            onBeat.emit(beat);
        }

        if (step != floorStep) {
            step = floorStep;
            onStep.emit(step);
        }
    }

    static function get_bpm():Float {
        return (Song.current != null) ? Song.current.timingPoints[curChange].bpm : bpm;
    }

    static function get_crochet():Float {
        return (Song.current != null) ? Song.current.timingPoints[curChange].crochet : (60 / bpm);
    }

    static function get_stepCrochet():Float {
        return (Song.current != null) ? Song.current.timingPoints[curChange].crochet / Song.current.timingPoints[curChange].stepsPerBeat : (15 / bpm);
    }
}