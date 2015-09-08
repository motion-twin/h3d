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
	
	public var onBeforeRealloc : Void->Void;
	public var onAfterRealloc : Void->Void;
	
	/**
	 * This tile always is always filled with something, it starts as an empty tile and then gets hotloaded with content 
	 * as it is rendered
	 * EXPERIMENTAL
	 */
	public var permaTile: h2d.Tile;
	
	public function new( ?parent : Sprite, width = -1, height = -1 ) {
		super(parent);
		
		permaTile = h2d.Tools.getEmptyTile().clone();
		
		this.width = width;
		this.height = height;
		
		tmpZone = new h3d.Vector();
		
		#if sys
		shader.leavePremultipliedColors = true;
		#end
	}
	
	public function invalidate() {
		renderDone = false;
	}
	
	public override function dispose() {
		clean();
		super.dispose();
	}

	function clean() {
		if( tex != null ) {
			tex.dispose();
			tex = null;
		}
		tile = null;
		permaTile.copy( h2d.Tools.getEmptyTile() );
		if ( width >= 0 ) permaTile.setWidth( Math.round(width) );
		if ( height >=0 ) permaTile.setHeight( Math.round(height) );
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
		permaTile.setHeight(Math.round(w));
		return w;
	}

	override function set_height(h) {
		clean();
		height = h;
		permaTile.setHeight(Math.round(h));
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
			
			if ( tex != null) throw "assert";
			
			tex = new h3d.mat.Texture(tw, th, h3d.mat.Texture.TargetFlag() );
			#if debug
			tex.name = 'CachedBitmap[$name]';
			#end
			tex.realloc = function() {
				if (onBeforeRealloc != null) onBeforeRealloc();
				invalidate();
				tex.alloc();
				tex.clear(targetColor);
				if (onAfterRealloc != null) onAfterRealloc();
			};
			
			renderDone = false;
			tile = new Tile(tex, 0, 0, realWidth, realHeight);
			permaTile.copy(tile);
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
			//
			var w =  2 / tex.width  * targetScale;
			var h = -2 / tex.height * targetScale;
			var m = Tools.getCoreObjects().tmpMatrix2D;
			
			m.identity();
			m.scale(w, h);
			m.translate(-1, 1);
			
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
			tmpZone = engine.getRenderZone(tmpZone);// we pass also as argument to avoid allocation
			
			//set my render data
			engine.setTarget(tex, false, targetColor);
			//OpenGL scale -1 on Y Axis ! so the blank part of the texture at the botton would be rendered
			//if we do not set the Y pos properly
			var renderZoneY = #if flash oldY #else oldY + (tex.height - realHeight)#end;
			engine.setRenderZone(Std.int(oldX), Std.int(renderZoneY), Math.round(realWidth), Math.round(realHeight));
			
			//draw childs
			for ( c in childs )
				c.drawRec(ctx);
			
			//pop target
			engine.setTarget(tmpTarget,false,null);			
			
			if ( tmpZone != null ) 
				engine.setRenderZone(Std.int(tmpZone.x), Std.int(tmpZone.y), Std.int(tmpZone.z), Std.int(tmpZone.w));
			else
				engine.setRenderZone();
			
			engine.triggerClear = oc;
			
			// restore
			matA = oldA;
			matB = oldB;
			matC = oldC;
			matD = oldD;
			absX = oldX;
			absY = oldY;
			
			renderDone = true;
			
			permaTile.copy(tile);
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
