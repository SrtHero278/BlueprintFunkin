package objects;

import bindings.CppHelpers;
import blueprint.graphics.Texture;

class HealthIcon extends blueprint.objects.Sprite {
    public var iconScale:Float = 1.0;
    public var iconSteps:Int = 2;
    public var health(default, set):Float = 1.0;
    public var invertHealth:Bool = false;

    public function new(x:Float, y:Float, icon:String) {
        super(x, y);
        loadIcon(icon);
        scale.set(iconScale);
    }

    public function loadIcon(icon:String) {
        var path = Paths.image("game/icons/" + icon);
        if (!sys.FileSystem.exists(path))
            path = Paths.image("game/icons/UNKNOWN-ICON");
        texture = Texture.getCachedTex(path);
        
        iconSteps = Math.round(texture.width / texture.height);
        sourceRect.width = texture.width / iconSteps;
        iconScale = 150.0 / texture.height;
    }

    function set_health(value:Float) {
        var hp = invertHealth ? (1.0 - value) : value;
        sourceRect.x = sourceRect.width * (CppHelpers.boolToInt(hp < 0.2) + CppHelpers.boolToInt(hp > 0.8) * 2);
        return health = value;
    }
}