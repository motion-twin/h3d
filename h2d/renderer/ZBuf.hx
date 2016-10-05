package h2d.renderer;

class ZBuf extends Base
{
	@:access(h2d.Sprite)
	@:access(h2d.RenderContext)
	override public function process(s:h2d.Sprite) {
		ctx.engine.clear(null, 1);

		ctx.drawableFilter = onlyFull;
		ctx.front2back = true;
		ctx.skipFilters = true;
		ctx.killAlpha = true;
		ctx.pass.depth(true, Less);

		ctx.begin();
		s.drawRec(ctx);
		ctx.end();

		ctx.drawableFilter = onlySemi;
		ctx.front2back = false;
		ctx.skipFilters = false;
		ctx.killAlpha = false;
		ctx.pass.depth(false, Less);

		ctx.begin();
		s.drawRec(ctx);
		ctx.end();
	}

	function onlyFull(obj : h2d.Drawable) : Bool {
		return obj.blendMode == None;
	}

	function onlySemi(obj : h2d.Drawable) : Bool {
		return obj.blendMode != None;
	}
}