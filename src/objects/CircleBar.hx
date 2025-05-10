package objects;

import math.Vector2;
import math.Vector4;
import blueprint.graphics.Shader;
import blueprint.objects.Sprite;

class CircleBar extends Sprite {
    public static var barShader:Shader = null;
    public var percent:Float;
    public var emptyTint:Vector4 = new Vector4(0.0, 0.0, 0.0, 1.0);
    public var centerPoint:Vector2 = new Vector2(0.5, 0.5);
    public var angleOffset(get, set):Float;
    public var radianOffset:Float = 0.0;
    public var invert:Bool = false;

    public function new(x:Float, y:Float, ?imagePath:String) {
        super(x, y, imagePath);

        if (barShader == null) {
            barShader = new Shader("#version 330 core

            out vec4 FragColor;
			in vec2 TexCoord;

			uniform vec4 tint;
            uniform vec4 emptyTint;
			uniform sampler2D bitmap;

            uniform vec2 center;
            uniform float angleOffset;
            uniform float percent;
            uniform float offset;
            const float pi = 3.14159265359;
            const float tau = pi * 2.0;

            void main() {
                float dx = TexCoord.x - center.x;
                float dy = TexCoord.y - center.y;
                float mult = smoothstep(percent, percent + offset, abs(mod(atan(dx, dy) + pi + angleOffset, tau)));
                gl_FragColor = texture(bitmap, TexCoord) * mix(tint, emptyTint, mult);
            }", Shader.defaultVertexSource);
            barShader.keepIfUnused = true;
        }
        shader = barShader;
    }

    override function prepareShaderVars() {
        final uMult = bindings.CppHelpers.boolToInt(flipX);
		final vMult = bindings.CppHelpers.boolToInt(flipY);

		final sourceWidth = sourceWidth; // so im not constantly calling the setters.
		final sourceHeight = sourceHeight;
		final width = width;
		final height = height;
		
		shader.transform.reset(1.0);
		shader.transform.translate(Sprite._refVec3.set(dynamicOffset.x / sourceWidth, dynamicOffset.y / sourceHeight, 0));
		shader.transform.scale(Sprite._refVec3.set(width, height, 1));
		if (rotation != 0)
			shader.transform.rotate(_sinMult, _cosMult, Sprite._refVec3.set(0, 0, 1));
		shader.transform.translate(Sprite._refVec3.set(
			position.x + renderOffset.x,
			position.y + renderOffset.y,
			0
		));
		shader.setUniform("transform", shader.transform);

        shader.setUniform("offset", 0.15 * (1 - Math.pow(2 * percent - 1, 4)));
        shader.setUniform("angleOffset", radianOffset);
        shader.setUniform("center", centerPoint);
        if (invert) {
            shader.setUniform("percent", (1.0 - percent) * Math.PI * 2);
            shader.setUniform("tint", emptyTint);
            shader.setUniform("emptyTint", tint);
        } else {
            shader.setUniform("percent", percent * Math.PI * 2);
            shader.setUniform("tint", tint);
            shader.setUniform("emptyTint", emptyTint);
        }
		bindings.Glad.uniform4f(bindings.Glad.getUniformLocation(shader.ID, "sourceRect"),
			(sourceRect.x + sourceWidth * uMult) / texture.width,
			(sourceRect.y + sourceHeight * vMult) / texture.height,
			(sourceRect.x + sourceWidth * (1 - uMult)) / texture.width,
			(sourceRect.y + sourceHeight * (1 - vMult)) / texture.height
		);
    }

    function get_angleOffset() {
        return radianOffset * 180 / Math.PI;
    }

    function set_angleOffset(to:Float) {
        radianOffset = to * Math.PI / 180;
        return to;
    }
}