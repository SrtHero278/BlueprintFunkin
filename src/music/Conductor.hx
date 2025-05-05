package music;

class Conductor {
    public static var bpm(get, default):Float = 120;
    public static var crochet(get, never):Float;
    public static var stepCrochet(get, never):Float;
    public static var position:Float = 0.0;
    public static var beatOffset:Float = 0.0;
    public static var floatBeat:Float = 0.0;
    public static var floatStep:Float = 0.0;
    public static var beat:Int = 0;
    public static var step:Int = 0;
    public static var curChange:Int = 0;

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
            if (Song.current.complete) {
                if (Song.current.looping)
                    Song.current.play(0.0);
                else 
                    Song.current.finished.emit();
            }

            var lastTime = position;
            var bpms = Song.current.bpmChanges;
            position = Song.current.time;

            if (position < lastTime) {
                while (curChange > 0 && bpms[curChange][0] > position)
                    --curChange;
            } else if (bpms.length > 1) {
                while (curChange < bpms.length && bpms[curChange][0] < position)
                    ++curChange;
            }

            floatBeat = bpms[curChange][1] + (position - bpms[curChange][0] + beatOffset) / bpms[curChange][3];
        } else {
            position += elapsed;
            floatBeat = (position + beatOffset) * (bpm / 60);
        }
        floatStep = floatBeat * 4.0;

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
        return (Song.current != null) ? Song.current.bpmChanges[curChange][2] : bpm;
    }

    static function get_crochet():Float {
        return (Song.current != null) ? Song.current.bpmChanges[curChange][3] : (60 / bpm);
    }

    static function get_stepCrochet():Float {
        return crochet * 0.25;
    }
}