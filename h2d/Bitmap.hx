package h2d;

class Bitmap extends Drawable {
	public var tile : Tile;
	
	/** 
	 * Passing in a similar shader ( same constants will vastly improve performances )
	 */
	public function new( ?tile, ?parent, ?sh) {
		super(parent,sh);
		this.tile = tile;
	}
	
	public function clone() {
		var b = new Bitmap(tile, parent, shader);
		
		b.x = x;
		b.y = y;
		
		b.rotation = rotation;
		
		b.scaleX = scaleX;
		b.scaleY = scaleY;
		
		b.skewX = skewX;
		b.skewY = skewY;
		return b;
	}
	
	override function draw( ctx : RenderContext ) {
		#if !useEmitTile
		drawTile(ctx.engine, tile);
		#else 
		emitTile(ctx, tile);
		#end
	}
	
	override function getMyBounds() : h2d.col.Bounds {
		var m = getPixSpaceMatrix(tile);
		var bounds = h2d.col.Bounds.fromValues(0,0, tile.width,tile.height);
		bounds.transform( m );
		return bounds;
	}
	
	/************************ creator helpers ******************/
	/**
	 * .create( hxd.BitmapData.fromNative( bmp ))
	 */
	public static function create( bmp : hxd.BitmapData, ?parent, ?allocPos : h3d.impl.AllocPos ) {
		return new Bitmap(Tile.fromBitmap(bmp,allocPos),parent);
	}
	
	#if( flash || openfl )
	public static inline function fromBitmapData(bmd:flash.display.BitmapData,?parent) {
		return create( hxd.BitmapData.fromNative( bmd ), parent);
	}
	#end
	
	public static inline function fromPixels(pix : hxd.Pixels,?parent) {
		return new Bitmap(Tile.fromPixels(pix),parent);
	}
}