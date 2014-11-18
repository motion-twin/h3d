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
	static var texMan:Map<String,{pixels:hxd.Pixels,tex:h3d.mat.Texture}>
	= new Map();
	
	public static function makeTile(t:TileStyle) : h2d.Tile {
		var d;
		if ( !texMan.exists(t.file) ) {
			d = { pixels:null, tex:null };
			switch(t.mode) {
				case Assets:
					#if openfl
					var path = t.file;
					var bmp = hxd.BitmapData.fromNative( openfl.Assets.getBitmapData( path, false ));
					var pixels = bmp.getPixels();
					var tex = h3d.mat.Texture.fromPixels(pixels);
					
					#if flash
					tex.flags.set( AlphaPremultiplied );
					#end
					
					tex.realloc = function() {
						tex.alloc();
						tex.uploadPixels( pixels );
					};
					
					tex.name = path;
					d.tex = tex;
					d.pixels = pixels;
					#end 
			}
			texMan.set( t.file, d );
		}
		d = texMan.get(t.file);
			
		return new h2d.Tile(d.tex,
			Math.round(t.x), Math.round(t.y), 
			Math.round(t.w), Math.round(t.h), Math.round(t.dx), Math.round(t.dy));
	}
	
	public static function getFont( name : String, size : Int ) {
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