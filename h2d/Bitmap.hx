package h2d;


class Bitmap extends Drawable {
	public var tile : Tile;
	public var bitmapData : hxd.BitmapData;
	
	public function new( ?tile, ?parent, ?bmp:hxd.BitmapData, ?sh) {
		super(parent,sh);
		this.tile = tile;
		bitmapData = bmp;
		if ( this.tile == null && bmp!=null) {
			this.tile = Tile.fromBitmap(bmp);
		}
	}
	
	override function draw( ctx : RenderContext ) {
		drawTile(ctx.engine,tile);
	}
			
	/**
	 * .create( hxd.BitmapData.fromNative( bmp ))
	 */
	public static function create( bmp : hxd.BitmapData, ?allocPos : h3d.impl.AllocPos ) {
		return new Bitmap(Tile.fromBitmap(bmp,allocPos));
	}
	
	#if( flash || openfl )
	public static inline function fromBitmapData(bmd:flash.display.BitmapData) {
		return create( hxd.BitmapData.fromNative( bmd ));
	}
	#end
	
	override function getMyBounds() : h2d.col.Bounds {
		var m = getPixSpaceMatrix(tile);
		var bounds = h2d.col.Bounds.fromValues(0,0, tile.width,tile.height);
		bounds.transform( m );
		return bounds;
	}
	
}