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

private class DepthEntry {
	public var spr   : Sprite;
	public var depth : Float;
	public var keep  : Bool;
	public function new() { }
}

private class DepthMap {
	var map : Map<Sprite, DepthEntry>;
	var max : Int;
	var len : Int;
	var entries : Vector<DepthEntry>;

	var curIndex : Int;

	public function new() {
		map = new Map();
		len = 0;
		max = 0;
	}

	function grow() {
		var oldEntries = entries;
		max = max * 2 + 8;
		entries = new Vector(max);
		if (oldEntries != null) Vector.blit(oldEntries, 0, entries, 0, len);
		for (i in len...max) entries[i] = new DepthEntry();
	}

	inline function createEntry() {
		if (len == max) grow();
		return entries[len++];
	}

	function push(spr : Sprite) {
		var e = map.get(spr);
		if (e == null) e = createEntry();

		e.spr   = spr;
		e.keep  = true;
		e.depth = curIndex++;
		map.set(spr, e);
	}

	function populate(spr : Sprite) {
		for (c in spr) {
			if (!c.visible) continue;
			push(c);
			populate(c);
		}
	}

	public function build(spr : Sprite) {
		curIndex = 0;

		for (i in 0...len) {
			var e = entries[i];
			e.keep = false;
		}

		push(spr);
		populate(spr);

		var i = 0;
		while (i < len) {
			var e = entries[i];
			while (!e.keep) {
				map.remove(e.spr);
				e.spr = null;
				--len;
				if (i == len - 1) return;
				var last = entries[len];
				entries[len] = e;
				e = entries[i] = last;
			}
			e.depth = 1 - (i + 1) / curIndex;
			++i;
		}
	}

	public function getDepth(spr : Sprite) {
		return map.get(spr).depth;
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

		var oldOnEnterFilter = ctx.onEnterFilter;
		var oldOnLeaveFilter = ctx.onLeaveFilter;
		normalState.loadFrom(ctx);

		ctx.onEnterFilter = onEnterFilter;
		ctx.onLeaveFilter = onLeaveFilter;

		opaqueState.applyTo(ctx);
		super.drawRec(ctx);

		transpState.applyTo(ctx);
		super.drawRec(ctx);

		normalState.applyTo(ctx);
		ctx.onEnterFilter = oldOnEnterFilter;
		ctx.onLeaveFilter = oldOnLeaveFilter;
	}

	function onBeginOpaqueDraw(obj : h2d.Drawable) : Bool {
		if (obj.blendMode != None)
			return false;
		ctx.baseShader.zValue = depthMap.getDepth(obj);
		return true;
	}

	function onBeginTranspDraw(obj : h2d.Drawable) : Bool {
		if (obj.blendMode == None)
			return false;
		ctx.baseShader.zValue = depthMap.getDepth(obj);
		return true;
	}

	function onEnterFilter(spr : Sprite) {
		if (ctx.front2back) return false; // opaque pass : do not render the filter
		normalState.applyTo(ctx);
		return true;
	}

	function onLeaveFilter(spr : Sprite) {
		transpState.applyTo(ctx);
	}
}