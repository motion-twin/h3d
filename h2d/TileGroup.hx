package h2d;
import h2d.col.Bounds;

private class TileLayerContent extends h3d.prim.Primitive {

	var tmp : hxd.FloatBuffer;
	var tiles : Array<Tile>;
	
	public function new() {
		reset();
	}
	
	public function isEmpty() {
		return buffer == null;
	}
	
	public function reset() {
		tmp = new hxd.FloatBuffer();
		tiles = [];
		
		if( buffer != null ) buffer.dispose();
		buffer = null;
	}
	
	public inline function getX( idx :Int) :Float{
		return tmp[idx<<4]+getTile(idx).dx;
	}
	
	public inline function getY( idx :Int ) :Float{
		return tmp[(idx<<4)+1]+getTile(idx).dy;
	}
	
	public inline function getWidth( idx :Int ) :Float{
		return getTile(idx).width;
	}
	
	public inline function getHeight( idx :Int ) :Float{
		return getTile(idx).height;
	}
	
	public inline function getTile( idx:Int) : Tile{
		return tiles[idx];
	}
	
	public inline function get2DBounds(idx:Int) {
		var b = new Bounds();
		var w = getWidth(idx);
		var h = getHeight(idx);
	
		b.xMin = getX(idx);
		b.xMax = b.xMin+w;
		
		b.yMin = getY(idx);
		b.yMax = b.yMin+h;
		
		return b;
	}
	
	public function add( x : Int, y : Int, t : Tile ) {
		var sx = x + t.dx;
		var sy = y + t.dy;
		var sx2 = sx + t.width;
		var sy2 = sy + t.height; 
		tiles[tmp.length >> 4] = t;
		//trace('sx:$sx sy:$sy sx2:$sx2 sy2:$sy2');
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
		if( tmp == null ) reset();
		buffer = engine.mem.allocVector(tmp, 4, 4,true);
	}

	public function doRender(engine, min, len) {
		if( buffer == null || buffer.isDisposed() ) alloc(engine);
		engine.renderQuadBuffer(buffer, min, len);
	}
	
}

/**
 * Allows to draw an arbitrary number of quads under one single texture tile
 * renders by bottom right...
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
	
	public function reset() {
		content.reset();
	}
	
	override function onDelete() {
		content.dispose();
		super.onDelete();
	}
	
	public inline function add(x, y, t) {
		content.add(x, y, t);
	}
	
	override function getMyBounds() {
		var b = null;
		var m = getPixSpaceMatrix(null);
		var rmin = (rangeMin < 0) ? 0 : rangeMin;
		var rmax = (rangeMax < 0) ? (content.triCount()>>1) : rangeMax;
		
		var otx = m.tx;
		var oty = m.ty;
		for ( i in rmin...rmax ) {
			otx = m.tx;
			oty = m.ty;
			
			var nb = content.get2DBounds(i);
			var tile = content.getTile(i);
			
			//m.tx = otx + tile.dx * m.a + tile.dy * m.c;
			//m.ty = oty + tile.dx * m.b + tile.dy * m.d;
			
			trace(i + " " +nb);
			
			nb.transform(m);
			
			if ( b == null)		b = nb;
			else 				b.add(nb);
			
			m.tx = otx;
			m.ty = oty;
		}
		
		return b;
	}
	
	/**
		Returns the number of tiles added to the group
	**/
	public function count() {
		return content.triCount() >> 1;
	}
		
	override function draw(ctx:RenderContext) {
		setupShader(ctx.engine, tile, 0);
		var min = rangeMin < 0 ? 0 : rangeMin * 2;
		var max = content.triCount();
		if( rangeMax > 0 && rangeMax < max * 2 ) max = rangeMax * 2;
		content.doRender(ctx.engine, min, max - min);
	}
}
