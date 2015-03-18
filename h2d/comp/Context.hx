package h2d.comp;

import h2d.css.Defs;

class Context {
	
	// measure props
	/**
	 * Indicates that we are in the measure pass
	 */
	public var measure : Bool;
	public var maxWidth : Float = 0.;
	public var maxHeight : Float = 0.;
	// arrange props
	public var xPos : Null<Float> = null;
	public var yPos : Null<Float> = null;
	
	public function new(w, h) {
		this.maxWidth = w;
		this.maxHeight = h;
		measure = true;
	}
	
	// ------------- STATIC API ---------------------------------------
	static var texMan:Map<String,h3d.mat.Texture>
	= new Map();
	
	public static function makeTile(t:TileStyle) : h2d.Tile {
		var d : h3d.mat.Texture = null;
		if ( !texMan.exists(t.file) ) {
			switch(t.mode) {
				case Assets:
					#if openfl
					var path = t.file;
					var bmp = hxd.BitmapData.fromNative( openfl.Assets.getBitmapData( path, true ));
					var tex = h3d.mat.Texture.fromBitmap(bmp);
					tex.filter = Linear;
					#if flash
					tex.flags.set( AlphaPremultiplied );
					#end
					
					tex.realloc = function() {
						tex.alloc();
						tex.uploadBitmap( bmp );
					};
					
					tex.name = path;
					d = tex;
					#end 
					
				case Custom:
					d = t.getCustomTexture();
			}
			texMan.set( t.file, d );
		}
		d = texMan.get(t.file);
			
		var w = Math.round(t.w);
		var h = Math.round(t.h);
		
		if ( t.widthAsPercent ) w = Math.round(t.w / 100.0) * d.width;
		if ( t.heightAsPercent ) h = Math.round(t.h / 100.0) * d.height;
		
		t.nativeWidth = w;
		t.nativeHeight = h;
		
		return new h2d.Tile(d, Math.round(t.x), Math.round(t.y),w,h, Math.round(t.dx), Math.round(t.dy));
	}
	
	public static function getFont( name : String, size : Int ) {
		h2d.css.Parser.fontResolver(name, size);
		return hxd.res.FontBuilder.getFont(name, size);
	}
	
	public static function makeTileIcon( pixels : hxd.Pixels ) : h2d.Tile {
		var t = cachedIcons.get(pixels);
		if( t != null && !t.isDisposed() )
			return t;
		t = h2d.Tile.fromPixels(pixels);
		cachedIcons.set(pixels, t);
		return t;
	}
	
	static var cachedIcons = new Map<hxd.Pixels,h2d.Tile>();
	public static var DEFAULT_CSS = hxd.res.Embed.getFileContent("h2d/css/default.css");
	
	static var DEF = null;
	public static function getDefaultCss() {
		if( DEF != null )
			return DEF;
		var e = new h2d.css.Engine();
		e.addRules(DEFAULT_CSS);
		return e;
	}
	
}