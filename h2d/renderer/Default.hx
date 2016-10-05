package h2d.renderer;

class Default extends Base
{
	@:access(h2d.Sprite)
	override public function process(s:h2d.Sprite) {
		ctx.begin();
		s.drawRec(ctx);
		ctx.end();
	}
}