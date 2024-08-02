package scenes;

import objects.SparrowText;
import objects.HealthIcon;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

using StringTools;

@:structInit class SongMeta {
    public var display:String;
    public var icon:String;
    public var bpm:Float;
    public var color:Array<Float>;
    @:optional public var internalName:String; // this gets set in code dw.
}

class SongList extends BaseMenu {
    static var songs:Array<SongMeta> = [];
    var icons:Array<HealthIcon> = [];
    var text:Array<SparrowText> = [];

    public static function trySelect() {
        var txtPath = Paths.file("songs/list.txt");
        songs = [];
        if (FileSystem.exists(txtPath))
            getSongs(File.getContent(txtPath).split("\n"));
        else 
            getSongs(Paths.folderContents("songs"));

        return songs.length > 0;
    }

    public function new() {
        super();

        for (song in songs) {
            var icon = new HealthIcon(75, 360, song.icon);
            icons.push(icon);
            add(icon);

            var txt = new SparrowText(75 + icon.width * 0.5 + 10, 360, song.display.toUpperCase());
            txt.anchor.x = 0;
            text.push(txt);
            add(txt);
        }
    }

    public static function getSongs(folders:Array<String>) {
        for (song in folders) {
            if (!FileSystem.exists(Paths.songFile("diffs", song))) continue;

            var data:SongMeta = {
                display: song,
                icon: "UNKNOWN-ICON",
                bpm: 120,
                color: [255, 255, 255]
            };
            var metaPath = Paths.songFile("meta.json", song);
            if (FileSystem.exists(metaPath)) {
                var json = Json.parse(File.getContent(metaPath));
                for (field in Reflect.fields(json)) {
                    var val = Reflect.field(json, field);
                    if (field != "color" || (val is Array && val.length >= 3))
                        Reflect.setField(data, field, val);
                }
            }
            data.internalName = song;
            songs.push(data);
        }
    }
    
    override function getMaxItems():Int {
        return songs.length;
    }
}