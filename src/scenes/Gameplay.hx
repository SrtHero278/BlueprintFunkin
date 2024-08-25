package scenes;

import blueprint.Game;
import blueprint.objects.Group;
import bindings.Glfw;
import music.GameSong;
import music.GameSong.ChartNote;
import objects.Note;
import objects.Strumline;
import objects.Character;

class Gameplay extends blueprint.Scene {
    // Note Stuff
    public var curSong:GameSong;
    public var queuedNote:Int;
    public var strumlines:Array<Strumline> = [];

    // HUD Stuff (currently none)

    // Background Stuff
    public var stage:Group;
    public var player:Character;
    public var opponent:Character;
    public var spectator:Character;

    public function new() {
        super();
        curSong = cast Song.current;
        Conductor.reset(curSong.bpmChanges[0][2]);

        strumlines.push(new Strumline(-0.25, curSong.speed));
        strumlines.push(new Strumline(0.25, curSong.speed));
        strumlines[1].keybinds = [[Glfw.KEY_A], [Glfw.KEY_S], [Glfw.KEY_KP_5], [Glfw.KEY_KP_6]];

        add(stage = new Group(-640, -540));
        stage.add(spectator = new Character(400, 130, "gf"));
        stage.add(opponent = new Character(100, 100, "pico"));
        stage.add(player = new Character(770, 100, "bf", true));

        for(i in 0...strumlines.length) {
            add(strumlines[i]);
            strumlines[i].characters.push([opponent, player][i]);
        }

        position.setFull(640, 360);
        scale *= 0.5;

        curSong.time = 0;
        curSong.looping = false;
        curSong.play();
    }

    override function update(elapsed:Float) {
        Conductor.update(elapsed);

        strumlines[0].rotation = 15 * Math.sin(Conductor.floatBeat * Math.PI * 0.25);
        strumlines[1].rotation = -15 * Math.sin(Conductor.floatBeat * Math.PI * 0.25);

        while (queuedNote < curSong.notes.length && curSong.notes[queuedNote].time - Conductor.position < 2) {
            final data = curSong.notes[queuedNote];
            final note = new Note(data);
            note.setLength(data.length, strumlines[data.char].speed);
            strumlines[data.char].notes.add(note);
            queuedNote++;
        }
        for (object in members)
			object.update(elapsed);
    }

    override function keyDown(keyCode:Int, scanCode:Int, mods:Int) {
        for (lane in strumlines) {
            if (!lane.isCpu)
                lane.keyDown(keyCode);
        }

        switch (keyCode) {
            case Glfw.KEY_ESCAPE:
                Game.changeSceneTo(scenes.Title);
        }
    }

    override function keyUp(keyCode:Int, scanCode:Int, mods:Int) {
        for (lane in strumlines) {
            if (!lane.isCpu)
                lane.keyUp(keyCode);
        }
    }
}