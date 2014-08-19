package h2d;
import h3d.mat.Texture;
import h3d.Vector;
import hxd.System;

/**
 * Renders all that is in its 0...width, beware for off screen parts
 * You can optimize speed by forcing width and height settings ( use child bbox for example
 * Currently only renders what is in 0...w and 0...y
 * you can use targetScale to perform efficient blurring
 */
class CachedBitmap extends Bitmap {

	public var freezed : Bool;
	public var targetScale = 1.0;
	
	public var renderDone : Bool;
	public var targetColor = 0x00000000;
	
	public var drawToBackBuffer = true;
	
	var realWidth : Int;
	var realHeight : Int;
	var tex : h3d.mat.Texture;
	
	var tmpZone : h3d.Vector;
	
	public function new( ?parent : Sprite, width = -1, height = -1 ) {
		super(parent);
		this.width = width;
		this.height = height;
		tmpZone = new h3d.Vector();
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
		if ( tile == null ) {
			var tw = 1, th = 1;
			var engine = h3d.Engine.getCurrent();
			realWidth = width < 0 ? engine.width : Math.ceil(width);
			realHeight = height < 0 ? engine.height : Math.ceil(height);
			while( tw < realWidth ) tw <<= 1;
			while ( th < realHeight ) th <<= 1;
			
			tex = new h3d.mat.Texture(tw, th, false,true);
			#if debug
			tex.name = 'CachedBitmap[$name]';
			#end
			tex.realloc = function() {
				invalidate();
				tex.alloc();
				tex.clear(0x0);
			};
			
			renderDone = false;
			tile = new Tile(tex,0, 0, realWidth, realHeight);
		}
		return tile;
	}

	override function drawRec( ctx : RenderContext ) {
		if( !visible ) return;

		tile.width = Std.int(realWidth  / targetScale);
		tile.height = Std.int(realHeight / targetScale);
		
		if (drawToBackBuffer) 
			draw(ctx);
	}
	
	override function sync( ctx : RenderContext ) {
		if( posChanged ) {
			calcAbsPos();
			for( c in childs )
				c.posChanged = true;
			posChanged = false;
		}
		
		var hasSizeChanged = false;
		if ( tex != null )
			if ( realWidth > tex.width || realHeight > tex.height)
				hasSizeChanged = true;
				
		if ( hasSizeChanged && !freezed)
			clean();
		
		if( !freezed || !renderDone ) {
			ctx.flush();

			var tile = getTile();
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
			
			//backup target
			var tmpTarget = engine.getTarget();
			
			//backup render zone
			var z = engine.getRenderZone(); if ( z != null ) tmpZone.load( z );
			
			//set my render data
				engine.setTarget(tex, false, targetColor);
				engine.setRenderZone(0, 0, realWidth, realHeight);
				
				//draw childs
				for ( c in childs )
					c.drawRec(ctx);
					
				//pop target
				engine.setTarget(tmpTarget,false,null);			
				
				//pop zone
				if(z == null)		engine.setRenderZone();
				else 				engine.setRenderZone(Std.int(tmpZone.x), Std.int(tmpZone.y), Std.int(tmpZone.z), Std.int(tmpZone.w));
			
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
			
			onOffscreenRenderDone(tile);
		}

		super.sync(ctx);
	}
	
	/**
	 * at this point the bitmap can be considered "filled" as the gpu commands are sent
	 */
	public dynamic function onOffscreenRenderDone( tile : h2d.Tile ) {
		
	}
}
