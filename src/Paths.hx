package;

import sys.FileSystem;

using StringTools;

class Paths {
    public static var foldersToCheck:Array<String> = ["assets/wiik4", "globalAssets/ESSENTIAL"];
    public static var scriptExtensions:Array<String> = [".hx", ".hxs", ".hscript"];

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

    public static function exists(path:String, ?alreadyConverted:Bool = false) {
        final fullPath = alreadyConverted ? path : file(path);
        return FileSystem.exists(fullPath);
    }

    public static function font(path:String, ?ext:String = ".ttf") {return file("fonts/" + path + ext);}
    public static function image(path:String) {return file("images/" + path + ".png");}
    public static function sparrowXml(path:String) {return file("images/" + path + ".xml");}
    public static function audio(path:String) {return file("audio/" + path + ".ogg");}
    public static function songFile(path:String, song:String) {return file("songs/" + song + "/" + path);}

	public static function isScriptPath(path:String) {
        for (ext in scriptExtensions) {
            if (path.endsWith(ext))
                return true;
        }
        return false;
	}

    public static function script(path:String) {
        for (ext in scriptExtensions) {
            final fullPath = file(path + ext);
            if (Paths.exists(fullPath, true))
                return fullPath;
        }
        return null;
    }
}