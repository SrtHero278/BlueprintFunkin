package objects;

import math.Vector2;
import blueprint.objects.AnimatedSprite;
import blueprint.objects.Sprite;
import blueprint.text.Text.TextAlignment;

// might modify this later on but this will do.
// Basically blueprint.objects.Text but with AnimatedSprite stuff.
class SparrowText extends AnimatedSprite {
    var lineGap:Float = 70;
    var defaultAdvance:Float = 40;

    var _queueSize:Bool = true;
    var _failedChars:Array<String> = [];
	var _lineWidths:Array<Float> = [];
	var _textWidth:Float;
	var _textHeight:Float;
	var _lineMult:Float = 0.5;
	public var text(default, set):String;
	public var alignment(default, set):TextAlignment = MIDDLE;

    var _curX:Float = 0;
    var _curLine:Int = 0;

    public function new(x:Float, y:Float, text:String) {
        super(x, y, Paths.file("images/menus/bold.xml"));
        this.text = text;
    }

    override public function draw() {
		if (_queueTrig)
			updateTrigValues();
		if (_queueSize)
			updateTextSize();

		_curX = 0.0;
		_curLine = 0;
        final oldAnimTime = animTime;
        shader.setUniform("tint", tint);
		for (i in 0...text.length) {
            var charAt = text.charAt(i);
			if (charAt == '\n') {
				_curLine++;
				_curX = (_textWidth - _lineWidths[_curLine]) * _lineMult;
				continue;
			}

			final anim = tryAnim(charAt);
            if (anim.indexes.length > 0) {
                animTime = oldAnimTime;
                curAnim = charAt;
                super.draw();
                _curX += anim.width;
            } else
                _curX += defaultAdvance;
		}
	}
	override function prepareShaderVars() {
		final frame = (frames == null || frames.length <= 0) ? AnimatedSprite.backupFrame : frames[curFrame];
		final uMult = bindings.CppHelpers.boolToInt(flipX);
		final vMult = bindings.CppHelpers.boolToInt(flipY);

		final sourceWidth = super.get_sourceWidth();
		final sourceHeight = super.get_sourceHeight();
		final width = sourceWidth * scale.x;
		final height = sourceHeight * scale.y;

		shader.transform.reset(1.0);
		shader.transform.translate(Sprite._refVec3.set(
            (_curX + dynamicOffset.x + frame.offsetX + (sourceWidth * 0.5) - (_textWidth * 0.5)) / sourceWidth,
            (lineGap * _curLine + dynamicOffset.y + frame.offsetY + (lineGap - sourceHeight) + (sourceHeight * 0.5) - (_textHeight * 0.5)) / sourceHeight,
            0
        ));
		shader.transform.scale(Sprite._refVec3.set(width, height, 1));
		if (rotation != 0)
			shader.transform.rotate(_sinMult, _cosMult, Sprite._refVec3.set(0, 0, 1));
		shader.transform.translate(Sprite._refVec3.set(
            position.x + renderOffset.x,
            position.y + renderOffset.y,
            0
		));
		shader.setUniform("transform", shader.transform);

		bindings.Glad.uniform4f(bindings.Glad.getUniformLocation(shader.ID, "sourceRect"),
			((sourceRect.x + frame.sourceX) + sourceWidth * uMult) / texture.width,
			((sourceRect.y + frame.sourceY) + sourceHeight * vMult) / texture.height,
			((sourceRect.x + frame.sourceX) + sourceWidth * (1 - uMult)) / texture.width,
			((sourceRect.y + frame.sourceY) + sourceHeight * (1 - vMult)) / texture.height
		);
	}

    override function calcRenderOffset(?parentScale:Vector2, ?parentSin:Float, ?parentCos:Float) {
		renderOffset.copyFrom(positionOffset);
		if (parentScale != null)
			renderOffset.multiplyEq(parentScale);
		renderOffset.x += (_textWidth * scale.x) * (0.5 - anchor.x);
		renderOffset.y += (_textHeight * scale.y) * (0.5 - anchor.y);
		if (parentSin != null && parentSin != null)
			renderOffset.rotate(parentSin, parentCos);
    }

    function updateTextSize() {
        _queueSize = false;
        _lineWidths.splice(0, _lineWidths.length);
        _textWidth = 0.0;
        _textHeight = lineGap;
        _curX = 0.0;

		for (i in 0...text.length) {
            var charAt = text.charAt(i);
			if (charAt == '\n') {
				_lineWidths.push(_curX);
				_textHeight += lineGap;
				_curX = 0.0;
				continue;
			}

			final anim = tryAnim(charAt);
			_curX += (anim.indexes.length > 0) ? anim.width : defaultAdvance;
			_textWidth = Math.max(_curX, _textWidth);
		}
		_lineWidths.push(_curX);
    }
    function tryAnim(char:String) {
        if (!animData.exists(char))
            addPrefixAnim(char, char + "0", 24, true);
        return animData.get(char);
    }

    override function get_sourceWidth():Float {
        if (_queueSize)
            updateTextSize();
        return _textWidth;
    }
    override function get_sourceHeight():Float {
        if (_queueSize)
            updateTextSize();
        return _textHeight;
    }

    function set_text(newText:String) {
        _queueSize = _queueSize || (text != newText);
        return text = newText;
    }

	function set_alignment(newAlign:TextAlignment) {
		switch (newAlign) {
			case Left | LEFT:
				_lineMult = 0;
				alignment = Left;
			case Middle | Center | MIDDLE | CENTER:
				_lineMult = 0.5;
				alignment = Center;
			case Right | RIGHT:
				_lineMult = 1.0;
				alignment = Right;
		}
		return alignment;
	}
}