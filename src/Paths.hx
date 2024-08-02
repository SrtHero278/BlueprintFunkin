package;

import sys.FileSystem;

class Paths {
    public static var foldersToCheck:Array<String> = ["assets/wiik4", "globalAssets/ESSENTIAL"];

    public static function file(path:String) {
        for (folder in foldersToCheck) {
            final checkPath:String = folder + "/" + path;
            if (FileSystem.exists(checkPath))
                return checkPath;
        }
        return "NONEXISTENT-FILE/" + path;
    }

    public static function folderContents(path:String) {
        var files:Array<String> = [];
        for (folder in foldersToCheck) {
            final checkPath:String = folder + "/" + path;
            if (FileSystem.exists(checkPath) && FileSystem.isDirectory(checkPath))
                files = files.concat(FileSystem.readDirectory(checkPath));
        }
        return files;
    }

    public static function font(path:String, ?ext:String = ".ttf") {return file("fonts/" + path + ext);}
    public static function image(path:String) {return file("images/" + path + ".png");}
    public static function audio(path:String) {return file("audio/" + path + ".ogg");}
    public static function songFile(path:String, song:String) {return file("songs/" + song + "/" + path);}
}