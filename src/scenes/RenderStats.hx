package scenes;

import blueprint.objects.ColorRect;
import blueprint.text.Text;

class RenderStats extends blueprint.Scene {
    var text:Text;
    var bg:ColorRect;
    var untilUpdate:Float = 1.0;
    var countedFrames:Int = 0;
    
    public function new() {
        super();

        add(bg = new ColorRect(5, 5, 0, 0));
        bg.tint.setFull(0, 0, 0, 0.5);
        bg.anchor.set();

        add(text = new Text(10, 10, "globalAssets/ESSENTIAL/fonts/montserrat.ttf", 16, "Wait a sec..."));
        text.anchor.set();
        bg.size.setFull(text.width + 10, text.height + 10);

        takeInput = false;
        mainCamera.keepOnSwitch = true;
        mainCamera.layer = 100;
    }

    override function update(elapsed:Float) {
        ++countedFrames;
        untilUpdate -= elapsed;
        if (untilUpdate <= 0.0) {
            text.text = countedFrames + " FPS";
            bg.size.setFull(text.width + 10, text.height + 10);

            untilUpdate = 1.0;
            countedFrames = 0;
        }
    }
}