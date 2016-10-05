package h2d;
import haxe.ds.Vector;

@:access(h2d.RenderContext)
private class State {
	public var depthWrite  : Bool;
	public var depthTest   : h3d.mat.Data.Compare;
	public var front2back  : Bool;
	public var killAlpha   : Bool;
	public var onBeginDraw : h2d.Drawable->Bool;

	public function new() { }

	public function loadFrom( ctx : RenderContext ) {
		depthWrite  = ctx.pass.depthWrite;
		depthTest   = ctx.pass.depthTest;
		front2back  = ctx.front2back;
		killAlpha   = ctx.killAlpha;
		onBeginDraw = ctx.onBeginDraw;
	}

	public function applyTo( ctx : RenderContext ) {
		ctx.pass.depth(depthWrite, depthTest);
		ctx.front2back  = front2back;
		ctx.killAlpha   = killAlpha;
		ctx.onBeginDraw = onBeginDraw;
	}
}

private class DepthMap {
	var map : Map<Sprite, Float>;
	var max : Int;
	var len : Int;
	var sprites : Vector<Sprite>;


	public function new() {
		map = new Map();
		len = 0;
		max = 2;
		sprites = new Vector(max);
	}

	function grow() {
		var oldSprites = sprites;
		max *= 2;
		sprites = new Vector(max);
		Vector.blit(oldSprites, 0, sprites, 0, len);
	}

	function push( spr : Sprite ) {
		if (len == max) grow();
		sprites[len++] = spr;
	}

	function populate( spr : Sprite ) {
		for (c in spr) {
			if (!c.visible) continue;
			push(c);
			populate(c);
		}
	}

	public function build( spr : Sprite ) {
		len = 0;
		push(spr);
		populate(spr);

		// cleanup
		for (i in len...max) {
			map.remove(sprites[i]);
			sprites[i] = null;
		}

		// fill map
		for (i in 0...len)
			map.set(sprites[i], 1 - (i + 1) / len);
	}

	public function getDepth(spr : Sprite) {
		return map.get(spr);
	}
}

@:access(h2d.RenderContext)
class ZGroup extends Layers
{
	var depthMap : DepthMap;
	var ctx : RenderContext;

	var normalState : State;
	var transpState : State;
	var opaqueState : State;

	public function new(?p) {
		super(p);

		depthMap = new DepthMap();

		opaqueState = new State();
		opaqueState.depthWrite  = true;
		opaqueState.depthTest   = Less;
		opaqueState.front2back  = true;
		opaqueState.killAlpha   = true;
		opaqueState.onBeginDraw = onBeginOpaqueDraw;

		transpState = new State();
		transpState.depthWrite  = true;
		transpState.depthTest   = Less;
		transpState.front2back  = false;
		transpState.killAlpha   = false;
		transpState.onBeginDraw = onBeginTranspDraw;

		normalState = new State();
	}

	override function drawRec(ctx:RenderContext) {
		this.ctx = ctx;

		depthMap.build(this);
		ctx.engine.clear(null, 1);

		var oldOnPushFilter = ctx.onPushFilter;
		var oldOnPopFilter = ctx.onPopFilter;
		normalState.loadFrom(ctx);

		ctx.onPushFilter = onPushFilter;
		ctx.onPopFilter = onPopFilter;

		opaqueState.applyTo(ctx);
		super.drawRec(ctx);

		transpState.applyTo(ctx);
		super.drawRec(ctx);

		normalState.applyTo(ctx);
		ctx.onPushFilter = oldOnPushFilter;
		ctx.onPopFilter  = oldOnPopFilter;
	}

	function onBeginOpaqueDraw( obj : h2d.Drawable ) : Bool {
		if (obj.blendMode != None)
			return false;
		ctx.baseShader.zValue = depthMap.getDepth(obj);
		return true;
	}

	function onBeginTranspDraw( obj : h2d.Drawable ) : Bool {
		if (obj.blendMode == None)
			return false;
		ctx.baseShader.zValue = depthMap.getDepth(obj);
		return true;
	}

	function onPushFilter( spr : Sprite, first : Bool ) {
		if (ctx.front2back) return false; // opaque pass : do not render the filter
		if (first) normalState.applyTo(ctx);
		return true;
	}

	function onPopFilter( spr : Sprite, last : Bool ) {
		if (last) transpState.applyTo(ctx);
	}
}