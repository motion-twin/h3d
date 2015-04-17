package h2d;
import h3d.mat.Texture;

class Bitmap extends Drawable {
	public var tile : Tile;
	
	/** 
	 * Passing in a similar shader ( same constants will vastly improve performances )
	 */
	public function new( ?tile:h2d.Tile, ?parent:h2d.Sprite, ?sh:h2d.Drawable.DrawableShader) {
	
		super(parent,sh);
		this.tile = tile;
	}
	
	override function getBoundsRec( relativeTo, out ) {
		super.getBoundsRec(relativeTo, out);
		if( tile != null ) addBounds(relativeTo, out, tile.dx, tile.dy, tile.width, tile.height);
	}
	
	public override function clone<T>( ?s:T ) : T {
		var b : Bitmap = (s==null) ? new Bitmap(tile, parent, null ) : cast s;
		return cast b;
	}
	
	override function draw( ctx : RenderContext ) {		
		if ( tile == null) 	return;
		
		if ( canEmit() )	emitTile(ctx, tile);
		else 				drawTile(ctx, tile);	
	}
	
	public override function set_width(w:Float):Float {
		scaleX = w / tile.width;
		return w;
	}
	
	public override function set_height(h:Float):Float {
		scaleY = h / tile.height;
		return h;
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
	
	public static inline function fromAssets(path:String,?retain=true,?fromCache=true,?parent) : h2d.Bitmap{
		return new h2d.Bitmap(h2d.Tile.fromAssets(path,retain,fromCache),parent,null);
	}
	#end
	
	public static inline function fromPixels(pix : hxd.Pixels,?parent) {
		return new Bitmap(Tile.fromPixels(pix),parent);
	}
	
	public static inline function fromTexture(tex:h3d.mat.Texture,?parent) {
		return new Bitmap(new h2d.Tile( tex ,0,0,tex.width,tex.height),parent);
	}
}