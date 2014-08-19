package h2d;
import h2d.col.Bounds;

private class TileLayerContent extends h3d.prim.Primitive {
	var tmp : hxd.FloatStack;

	public var xMin : Float;
	public var yMin : Float;
	public var xMax : Float;
	public var yMax : Float;
	
	public function new() {
		reset();
	}
	
	public function isEmpty() {
		return buffer == null;
	}
	
	public function reset() {
		if ( buffer != null ) {
			buffer.dispose();
			buffer = null;
		}
		
		if ( tmp == null ) 	tmp = new hxd.FloatStack();
		else 				tmp.reset();
		
		xMin = hxd.Math.POSITIVE_INFINITY;
		yMin = hxd.Math.POSITIVE_INFINITY;
		xMax = hxd.Math.NEGATIVE_INFINITY;
		yMax = hxd.Math.NEGATIVE_INFINITY;
	}
	
	
	
	public function add( p:h2d.Drawable, x : Int, y : Int, t : Tile ) {
		var sx = x + t.dx;
		var sy = y + t.dy;
		var sx2 = sx + t.width;
		var sy2 = sy + t.height; 
		
		tmp.push(sx);//0
		tmp.push(sy);
		tmp.push(t.u);
		tmp.push(t.v);
		
		tmp.push(sx2);//4
		tmp.push(sy);
		tmp.push(t.u2);
		tmp.push(t.v);
		
		tmp.push(sx);//8
		tmp.push(sy2);
		tmp.push(t.u);
		tmp.push(t.v2);
		
		tmp.push(sx2);//12
		tmp.push(sy2);
		tmp.push(t.u2);
		tmp.push(t.v2);
		
		if( sx < xMin ) xMin = sx;
		if( sy < yMin ) yMin = sy;
		if( sx2 > xMax ) xMax = sx2;
		if( sy2 > yMax ) yMax = sy2;
	}
	
	override public function triCount() {
		if( buffer == null )
			return tmp.length >> 3;
		var v = 0;
		var b = buffer;
		while( b != null ) {
			v += b.nvert;
			b = b.next;
		}
		return v >> 1;
	}
	
	override public function alloc(engine:h3d.Engine) {
		if ( tmp == null ) reset();
		buffer = engine.mem.allocStack(tmp, 4, 4,true);
	}

	public function doRender(engine, min, len) {
		if( len > 0 ){
			if ( buffer == null 
			|| ((tmp.length >> 2) > buffer.nvert) 
			|| buffer.isDisposed() ) 
				alloc(engine);
				
			engine.renderQuadBuffer(buffer, min, len);
		}
	}
	
	/**
	 * renders quads
	 */
	public function doEmitRender(ctx:RenderContext, p:h2d.TileGroup, min, len) {
		
		if ( len > 0 ) {
			var tile = p.tile;
			var texSlot = ctx.beginDraw(p,p.tile.getTexture());
			var color 	= p.color==null? h3d.Vector.ONE:p.color;
			var base 	= 0;
			var x 		= 0.0;
			var y 		= 0.0;
			var u 		= 0.0;
			var v 		= 0.0;
			
			var xTrs 	= 0.0;
			var yTrs 	= 0.0;
			
			for ( i in min...min + len) {
				for( j in 0...4 ){
					base 	= (i << 4) + (j << 2);
					
					x 		= tmp.get(base);
					y 		= tmp.get(base+1);

					xTrs 	= x * p.matA + y * p.matC + p.absX;
					yTrs 	= x * p.matB + y * p.matD + p.absY;
					
					u 		= tmp.get(base+2);
					v 		= tmp.get(base+3);
					
					ctx.emitVertex( xTrs,yTrs,u,v, color, texSlot);
				}
			}
		}
	}
	
}

/**
 * Allows to draw an arbitrary number of quads under one single texture tile
 */
class TileGroup extends Drawable {
	
	var content : TileLayerContent;
	
	public var tile : Tile;
	public var rangeMin : Int;
	public var rangeMax : Int;
	
	public function new(t,?parent) {
		tile = t;
		rangeMin = rangeMax = -1;
		content = new TileLayerContent();
		super(parent);
	}
	
	override function getBoundsRec( relativeTo, out ) {
		super.getBoundsRec(relativeTo, out);
		addBounds(relativeTo, out, content.xMin, content.yMin, content.xMax - content.xMin, content.yMax - content.yMin);
	}
	
	public function reset() {
		content.reset();
	}
	
	override function onDelete() {
		content.dispose();
		super.onDelete();
	}
	
	public inline function add(x, y, t) {
		content.add(this,x, y, t);
	}
	
	/**
	*Returns the number of tiles added to the group
	*/
	public function count() {
		return content.triCount() >> 1;
	}
		
	/**
	 * This code seems wrong the tile base is not ok
	 */
	override function draw(ctx:RenderContext) {
		var min = rangeMin < 0 ? 0 : rangeMin * 2;
		var max = content.triCount();
		if( rangeMax > 0 && rangeMax < max * 2 ) max = rangeMax * 2;
		var len = max - min;
		if ( len > 0 ) {
			if ( canEmit() ) {
				content.doEmitRender(ctx, this,min, len>>1);
			}
			else {
				ctx.flush();
				setupShader(ctx.engine, tile, Drawable.BASE_TILE_DONT_CARE);
				content.doRender(ctx.engine, min, len);
			}
		}
	}
}
