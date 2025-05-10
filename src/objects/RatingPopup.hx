package objects;

import blueprint.objects.AnimatedSprite;
import blueprint.objects.Sprite;
import blueprint.objects.Group;
import blueprint.graphics.Texture;
import bindings.CppHelpers;
import math.Vector4;
import objects.GameStats.Judgement;

class RatingPopup extends Group {
	var ratingPopup:Sprite;
	var ratingArrow:Sprite;
    var templateNum:AnimatedSprite;
    var nums:Group;
	var ratingTmr:Float = 0.0;

	final diffColors:Array<Vector4> = [
		new Vector4(255 / 255, 163 / 255, 77 / 255, 1.0),
		new Vector4(143 / 255, 206 / 255, 252 / 255, 1.0)
	];

    public function popup(judge:Judgement, stats:GameStats, diff:Float) {
        final highest = judge == stats.judgements[0];

        ratingPopup.texture = Texture.getCachedTex(Paths.image("game/popup/" + judge.image));
        ratingPopup.scale.set(0.8);
        ratingPopup.tint.a = 1.0;
        ratingPopup.visible = !highest || !Settings.hideHighJudge;

        ratingArrow.tint = diffColors[CppHelpers.boolToInt(diff > 0)];
        ratingArrow.visible = !highest;
        ratingArrow.scale.x = CppHelpers.boolToInt(diff > 0) - 0.5;
        ratingArrow.dynamicOffset.x = -230;

        ratingTmr = 10.0 * ratingArrow.scale.x;
        ratingPopup.rotation = Std.random(25) * -ratingArrow.scale.x;

        var comboStr = Std.string(stats.combo);
        while (nums.members.length < comboStr.length) {
            var num = new AnimatedSprite(0, -55);
            @:privateAccess {
                for (set in templateNum.frameSets)
                    num.pushFrameSet(set);
                num.animData = templateNum.animData;
            }
            nums.add(num);
        }

        for (i in 0...nums.members.length) {
            final num:AnimatedSprite = cast nums.members[i];
            if (i >= comboStr.length) {
                num.visible = false;
                continue;
            }
            num.visible = true;
            num.playAnim(comboStr.charAt(i));
            num.scale.set(0.8);
            num.position.x = 90 * 0.8 * (i + 0.5 - comboStr.length * 0.5);
        }
    }

    public function new() {
        super();

        templateNum = new AnimatedSprite(0, 0, Paths.file("images/game/popup/numbers.xml"));
        for (i in 0...10)
            templateNum.addPrefixAnim(Std.string(i), "num" + i, 24, true);

        add(ratingArrow = new Sprite(0, 0, Paths.image("game/popup/arrow")));
		ratingArrow.scale.set(0.0);
		ratingArrow.dynamicOffset.x = -180.0;

		add(ratingPopup = new Sprite(0, 0));
		ratingPopup.scale.set(0.7);
		ratingPopup.tint.a = 0.0;

        add(nums = new Group(0, 130));
    }

    override function update(elapsed:Float) {
        ratingTmr = MathExtras.lerp(ratingTmr, 0.0, elapsed * 5);

		ratingArrow.scale.x = ((ratingTmr < 0.0) ? Math.max(ratingTmr, -1.0) : Math.min(ratingTmr, 1.0)) * 0.5;
		ratingArrow.scale.y = Math.abs(ratingArrow.scale.x);
		ratingArrow.dynamicOffset.x = MathExtras.lerp(ratingArrow.dynamicOffset.x, -180.0, elapsed * 20);		

		ratingPopup.scale.x = MathExtras.lerp(ratingPopup.scale.x, 0.7, elapsed * 20);
		ratingPopup.scale.y = ratingPopup.scale.x;
		ratingPopup.tint.a = ratingArrow.scale.y * 2.0;

        nums.tint.a = (ratingArrow.scale.y + 0.5);
        nums.scale.x = nums.scale.y = (ratingPopup.scale.x * nums.tint.a) * 0.85;
    }
}