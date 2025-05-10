package scenes;

import blueprint.Game;
import blueprint.text.Text;
import blueprint.sound.SoundPlayer;
import sys.FileSystem;

using StringTools;

class ModsList extends BaseMenu {
    public static var mods:Array<String> = [];
    var list:Text;
    var sound:SoundPlayer;

    public static function trySelect() {
        mods = [for (folder in FileSystem.readDirectory("assets"))
            if (FileSystem.isDirectory("assets/" + folder))
                folder
        ];
        return mods.length > 0;
    }

    public function new() {
        super();
        add(list = new Text(10, 10, Paths.font("montserrat"), 32, ">>> " + mods.join("\n")));
        list.anchor.set(0);

        var watermark = new Text(Game.window.width - 10, Game.window.height -10, Paths.font("montserrat"), 24, "TEMPORARY MENU");
        watermark.anchor.set(1);
        add(watermark);

        sound = new SoundPlayer(Paths.audio("menus/scroll"), false, false, 1.0);
    }

    override function changeItem(direction:Int) {
        sound.play(0.0);
        list.text = "";
        for (i => mod in mods)
            list.text += (i == curItem ? ">>> " : "") + mod + "\n";
    }

    override function accept() {
        Paths.foldersToCheck[0] = "assets/" + mods[curItem];
        Game.changeSceneTo(scenes.Title);
    }

    override function cancel() {
        var title:scenes.Title = cast memberOf;
        title.subMenu = null;
        title.acceptTwn.rewind();

        memberOf.remove(this);
        sound.destroy();
        destroy();
    }

    override function getMaxItems():Int {
        return mods.length;
    }
}