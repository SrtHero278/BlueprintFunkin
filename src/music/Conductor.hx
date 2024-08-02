package music;

class Conductor {
    static final sixtyFract:Float = 1 / 60;

    public static var bpm(default, set):Float = 120;
    public static var crochet:Float = 60.0 / bpm;
    public static var stepCrochet:Float = crochet * 0.25;
    public static var position:Float = 0.0;
    public static var beatOffset:Float = 0.0;
    public static var floatBeat:Float = 0.0;
    public static var floatStep:Float = 0.0;
    public static var beat:Int = 0;
    public static var step:Int = 0;

    public static var onBeat:Signal<Int->Void> = new Signal();
    public static var onStep:Signal<Int->Void> = new Signal();

    public static function reset(bpm:Float) {
        Conductor.position = 0.0;
        Conductor.beatOffset = 0.0;
        Conductor.floatBeat = 0.0;
        Conductor.floatStep = 0.0;
        Conductor.beat = 0;
        Conductor.step = 0;
        Conductor.bpm = bpm;
        for (func in onBeat.funcsToCall)
            onBeat.remove(func);
        for (func in onStep.funcsToCall)
            onBeat.remove(func);
    }

    public static function update(elapsed:Float) {
        position += elapsed;

        floatBeat = (position + beatOffset) / crochet;
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

    static function set_bpm(newBPM:Float):Float {
        crochet = 60.0 / newBPM;
        stepCrochet = crochet * 0.25;
        return bpm = newBPM;
    }
}