package scenes;

import blueprint.Game;
import blueprint.tweening.EaseList;
import blueprint.tweening.PropertyTween;
import blueprint.graphics.SpriteFrames;
import blueprint.objects.Group;
import blueprint.text.Text;
import objects.SparrowText;
import objects.HealthIcon;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import blueprint.sound.SoundPlayer;

using StringTools;

@:structInit class SongMeta {
    public var display:String;
    public var icon:String;
    public var color:Array<Float>;
    @:optional public var internalName:String; // these two get set in code dw.
    @:optional public var diffs:Array<String>;
}

class SongList extends BaseMenu {
    static var songs:Array<SongMeta> = [];
    var openTwn:PropertyTween;
    var listGrp:Group;
    var songData:Text;
    var icons:Array<HealthIcon> = [];
    var text:Array<SparrowText> = [];
    
    var lastItem:Int = 0;
    var curDiff:String;
    var sound:SoundPlayer;

    public static function trySelect() {
        var txtPath = Paths.file("songs/list.txt");
        songs = [];
        SpriteFrameSet.getCachedFrames(Paths.file("images/menus/bold.xml"));
        if (FileSystem.exists(txtPath))
            getSongs(File.getContent(txtPath).split("\n"));
        else 
            getSongs(Paths.folderContents("songs"));

        return songs.length > 0;
    }

    public function new() {
        super();
        add(listGrp = new Group());
        add(songData = new Text(2280, 540, Paths.font("montserrat"), 32, "um"));
        songData.alignment = RIGHT;
        songData.anchor.x = 1;

        subKeybinds = [bindings.Glfw.KEY_LEFT, bindings.Glfw.KEY_RIGHT];
        sound = new SoundPlayer(Paths.audio("menus/scroll"), false, false, 1.0);

        for (i in 0...songs.length) {
            var song = songs[i];

            var icon = new HealthIcon(75 + 20 * i, 360 + 120 * i, song.icon);
            icon.tint.a = 0.5;
            icons.push(icon);
            listGrp.add(icon);

            var txt = new SparrowText(75 + icon.width * 0.5 + 10 + 20 * i, 360 + 120 * i, song.display.toUpperCase());
            txt.tint.a = 0.5;
            txt.anchor.x = 0;
            text.push(txt);
            listGrp.add(txt);
        }
        icons[curItem].tint.a = 1;
        text[curItem].tint.a = 1;

        curSubItem = Math.floor(songs[curItem].diffs.length * 0.5);
        curDiff = songs[curItem].diffs[curSubItem];
        setSong(!Std.isOfType(Song.current, music.GameSong) || cast(Song.current, music.GameSong).path != songs[curItem].internalName);

        listGrp.positionOffset.x = -1000;
        openTwn = new PropertyTween(this, {"listGrp.positionOffset.x": 0, "songData.position.x": 1270}, 0.75, EaseList.backOut);
        openTwn.deleteWhenDone = false;
    }

    override function update(elapsed:Float) {
        super.update(elapsed);
        listGrp.position.x = MathExtras.lerp(listGrp.position.x, -20 * curItem, elapsed * 9);
        listGrp.position.y = MathExtras.lerp(listGrp.position.y, -120 * curItem, elapsed * 9);
    }

    override function changeItem(direction:Int) {
        sound.play(0.0);
        var diffIndex = songs[curItem].diffs.indexOf(curDiff);
        curSubItem = (diffIndex > -1) ? diffIndex : Math.floor(songs[curItem].diffs.length * 0.5);
        curDiff = songs[curItem].diffs[curSubItem];

        setSong(true);

        icons[lastItem].tint.a = 0.5;
        text[lastItem].tint.a = 0.5;
        icons[curItem].tint.a = 1;
        text[curItem].tint.a = 1;

        lastItem = curItem; // keep this line last
    }

    override function changeSubItem(direction:Int) {
        curDiff = songs[curItem].diffs[curSubItem];
        setSong(false); // should already be the same so no need to replay.
    }

    override function accept() {
        Game.changeSceneTo(scenes.Gameplay);
    }

    override function cancel() {
        var title:scenes.Title = cast memberOf;
        title.subMenu = null;
        title.acceptTwn.rewind();
        openTwn.rewind();
        openTwn.deleteWhenDone = true;
        openTwn.finished.add((twn) -> {
            memberOf.remove(this);
            sound.destroy();
            destroy();
        });
    }

    function setSong(play:Bool) {
        var song = Song.setCurrentFromChart(songs[curItem].internalName, curDiff);
        if (play) {
            Song.current.looping = true;
            Song.current.play();
            Conductor.reset(Conductor.bpm, false);
        }

        var notes:Int = 0;
        var lastRowTime:Float = -5000;
        var curRow:Int = 0;
        var jumps:Int = 0;
        var hands:Int = 0;
        var quads:Int = 0;
        for (note in song.notes) {
            if (note.char != 1) continue;
            notes++;
            curRow = (Math.abs(lastRowTime - note.time) > 0.001) ? 1 : curRow + 1;
            switch (curRow) {
                case 2:
                    ++jumps;
                case 3:
                    --jumps;
                    ++hands;
                case 4:
                    --hands;
                    ++quads;
            }
            lastRowTime = note.time;
        }

        var fancyDiff = curDiff.charAt(0).toUpperCase() + curDiff.substring(1, curDiff.length).toLowerCase();
        songData.text = '< $fancyDiff >\n\nBPM: ${song.bpmChanges[0][2]}\n\nNotes: $notes\nJumps: $jumps\nHands: $hands\nQuads: $quads';
    }

    public static function getSongs(folders:Array<String>) {
        for (song in folders) {
            var diffPath = Paths.songFile("diffs", song);
            if (!FileSystem.exists(diffPath)) continue;

            var data:SongMeta = {
                display: song,
                icon: "UNKNOWN-ICON",
                color: [255, 255, 255]
            };
            var metaPath = Paths.songFile("meta.json", song);
            if (FileSystem.exists(metaPath)) {
                var json = Json.parse(File.getContent(metaPath));
                for (field in Reflect.fields(data)) {
                    if (!Reflect.hasField(json, field))
                        continue;
                    
                    var val = Reflect.field(json, field);
                    if (field != "color" || (val is Array && val.length >= 3))
                        Reflect.setField(data, field, val);
                }
            }
            data.internalName = song;
            data.diffs = [for (file in FileSystem.readDirectory(diffPath)) haxe.io.Path.withoutExtension(file)];
            songs.push(data);
        }
    }
    
    override function getMaxItems():Int {
        return songs.length;
    }
    override function getMaxSubItems():Int {
        return songs[curItem].diffs.length;
    }
}