package h2d;
import hxd.System;

/**
 * Renders all that is in its 0...width, beware for off screen parts
 * You can optimize speed by forcing width and height settings ( use child bbox for example
 * Currently only renders what is in 0...w and 0...y
 * you can use targetScale to perform efficient blurring
 */
class CachedBitmap extends Drawable {

	public var freezed : Bool;
	public var targetScale = 1.0;
	
	public var renderDone : Bool;
	public var targetColor = 0xFF000000;
	
	var realWidth : Int;
	var realHeight : Int;
	var tile : Tile;
	var tex : h3d.mat.Texture;
	
	public function new( ?parent, width = -1, height = -1 ) {
		super(parent);
		this.width = width;
		this.height = height;
	}
	
	public function invalidate() {
		renderDone = false;
	}

	function clean() {
		if( tex != null ) {
			tex.dispose();
			tex = null;
		}
		tile = null;
	}

	override function onDelete() {
		clean();
		super.onDelete();
	}
	
	override function get_width() {
		return width;
	}
	
	override function get_height() {
		return height;
	}
	
	override function set_width(w) {
		clean();
		width = w;
		return w;
	}

	override function set_height(h) {
		if( tex != null ) {
			tex.dispose();
			tex = null;
		}
		height = h;
		return h;
	}
	
	public function getTile() {
		if( tile == null ) {
			var tw = 1, th = 1;
			var engine = h3d.Engine.getCurrent();
			realWidth = width < 0 ? engine.width : Math.ceil(width);
			realHeight = height < 0 ? engine.height : Math.ceil(height);
			while( tw < realWidth ) tw <<= 1;
			while ( th < realHeight ) th <<= 1;
			
			tex = engine.mem.allocTargetTexture(tw, th);
			renderDone = false;
			tile = new Tile(tex,0, 0, realWidth, realHeight);
		}
		return tile;
	}

	override function drawRec( ctx : RenderContext ) {
		tile.width = Std.int(realWidth  / targetScale);
		tile.height = Std.int(realHeight / targetScale);
		drawTile(ctx.engine, tile);
	}
	
	override function sync( ctx : RenderContext ) {
		if( posChanged ) {
			calcAbsPos();
			for( c in childs )
				c.posChanged = true;
			posChanged = false;
		}
		
		if ( tex != null 
		&& ( !freezed ||((width < 0 && tex.width < ctx.engine.width) || (height < 0 && tex.height < ctx.engine.height)) ))
			clean();
			
		//System.trace2("cachedBitmap synced");
		var tile = getTile();
		if( !freezed || !renderDone ) {
			var oldA = matA, oldB = matB, oldC = matC, oldD = matD, oldX = absX, oldY = absY;
			
			var w = 2 / tex.width * targetScale;
			var h = -2 / tex.height * targetScale;
			var m = Tools.getCoreObjects().tmpMatrix2D;
			
			m.identity();
			m.scale(w, h);
			m.translate( - 1, 1);
			
			#if !flash
			m.scale(1, -1);
			#end
			
			matA=m.a;
			matB=m.b;
			matC=m.c;
			matD=m.d;
			absX=m.tx;
			absY=m.ty;

			// force full resync
			for( c in childs ) {
				c.posChanged = true;
				c.sync(ctx);
			}
			
			var engine = ctx.engine;
			var oc = engine.triggerClear;
			engine.triggerClear = true;
			engine.setTarget(tex,false,targetColor);
			engine.setRenderZone(0, 0, realWidth, realHeight);
			for ( c in childs )
				c.drawRec(ctx);
			engine.setTarget(null);
			engine.setRenderZone();
			engine.triggerClear = oc;
			
			// restore
			matA = oldA;
			matB = oldB;
			matC = oldC;
			matD = oldD;
			absX = oldX;
			absY = oldY;
			
			//System.trace2("cachedBitmap cached");
			renderDone = true;
		}

		super.sync(ctx);
	}
	
}