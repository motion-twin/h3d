package hxd.res;
import haxe.Utf8;

typedef FontBuildOptions = {
	?antiAliasing : Bool,
	?chars : String,
	?alphaPremultiplied:Bool,
};

/**
	FontBuilder allows to dynamicaly create a Bitmap font from a vector font.
	Depending on the platform this might require the font to be available as part of the resources,
	or it can be embedded manually with hxd.res.Embed.embedFont
**/
@:access(h2d.Font)
@:access(h2d.Tile)
class FontBuilder {

	var font : h2d.Font;
	var options : FontBuildOptions;
	var innerTex : h3d.mat.Texture;
	
	
	function new(name, size, opt) {
		var name = FONT_ALIASES.exists( name ) ? FONT_ALIASES.get(name) : name;
		this.font = new h2d.Font(name, size);
		this.options = opt == null ? { } : opt;
		if( options.antiAliasing == null ) options.antiAliasing = true;
		if( options.chars == null ) options.chars = hxd.Charset.DEFAULT_CHARS;
		if( options.alphaPremultiplied == null ) options.alphaPremultiplied = true;
	}
	
	/**
	 * return s the correcponding array of int
	 */
	public function getUtf8StringAsArray(str:String) {
		var a = [];
		haxe.Utf8.iter( str, function(cc) {
			a.push(cc);
		});
		return a;
	}
	
	/*
	 * returns the corrresponding multi byte index ans length
	 */
	public function isolateUtf8Blocs(codes:Array<Int>) :Array<{pos:Int,len:Int}> {
		var a = [];
		var i = 0;
		var cl = 0;
		for ( cc in codes ) {
			cl = hxd.text.Utf8Tools.getByteLength(cc);
			a.push( { pos:i, len:cl } );
			i += cl;
		}
		
		return a;
	}
	
	#if (flash||openfl)
	function build() : h2d.Font {
		font.lineHeight = 0;
		var tf = new flash.text.TextField();
		var fmt = tf.defaultTextFormat;
		fmt.font = font.name;
		fmt.size = font.size;
		fmt.color = 0xFFFFFF;
		tf.defaultTextFormat = fmt;
		
		
		for( f in flash.text.Font.enumerateFonts() )
			if( f.fontName == font.name ) {
				tf.embedFonts = true;
				break;
			}
			
		#if(!flash&&openfl)
			if ( ! tf.embedFonts ) 
				throw "Impossible to interpret not embedded fonts, use one among " +
				Lambda.map(flash.text.Font.enumerateFonts(),function(fnt)return fnt.fontName);
		#end
			
		if( options.antiAliasing ) {
			tf.gridFitType = flash.text.GridFitType.SUBPIXEL;
			tf.antiAliasType = flash.text.AntiAliasType.ADVANCED;
		}
		
		var surf = 0;
		var sizes = [];
		var allChars = options.chars;
		var allCC = getUtf8StringAsArray(options.chars);
		#if sys
		var allCCBytes = isolateUtf8Blocs(allCC);
		#end
		
		for ( i in 0...allCC.length ) {
			#if flash
			tf.text = options.chars.charAt(i);
			#elseif sys
			tf.text = options.chars.substr(allCCBytes[i].pos, allCCBytes[i].len);
			#end
			var w = Math.ceil(tf.textWidth) + 1;
			if( w == 1 ) continue;
			var h = Math.ceil(tf.textHeight) + 1;
			surf += (w + 1) * (h + 1);
			if( h > font.lineHeight )
				font.lineHeight = h;
			sizes[i] = { w:w, h:h };
		}
		var side = Math.ceil( Math.sqrt(surf) );
		var width = 1;
		while( side > width )
			width <<= 1;
		var height = width;
		while( width * height >> 1 > surf )
			height >>= 1;
		var all, bmp;
		do {
			bmp = new flash.display.BitmapData(width, height, true, 0);
			bmp.lock();
			font.glyphs = new Map();
			all = [];
			var m = new flash.geom.Matrix();
			var x = 0, y = 0, lineH = 0;
			
			for ( i in 0...allCC.length ) {
				var size = sizes[i];
				if( size == null ) continue;
				var w = size.w;
				var h = size.h;
				if( x + w > width ) {
					x = 0;
					y += lineH + 1;
				}
				// no space, resize
				if( y + h > height ) {
					bmp.dispose();
					bmp = null;
					height <<= 1;
					break;
				}
				m.tx = x - 2;
				m.ty = y - 2;
				
				#if flash
				tf.text = options.chars.charAt(i);
				#elseif sys
				tf.text = options.chars.substr(allCCBytes[i].pos, allCCBytes[i].len);
				#end
				
				bmp.fillRect(new flash.geom.Rectangle(x, y, w, h), 0);
				bmp.draw(tf, m,true);
				var t = new h2d.Tile(null, x, y, w - 1, h - 1);
				all.push(t);
				font.glyphs.set(allCC[i], new h2d.Font.FontChar(t,w-1));
				// next element
				if( h > lineH ) lineH = h+2;
				x += w + 1;
			}
		} while( bmp == null );
		
		var pixels = hxd.BitmapData.fromNative(bmp).getPixels();
		bmp.dispose();
		
		// let's remove alpha premult (all pixels should be white with alpha)
		pixels.convert(BGRA);

		if( options.alphaPremultiplied ){
			pixels.flags.set( AlphaPremultiplied );

			inline function premul(v,a){
				return hxd.Math.f2b( hxd.Math.b2f(v)*hxd.Math.b2f(a) );
			}

			var mem = hxd.impl.Memory.select(pixels.bytes);
			for( i in 0...pixels.width*pixels.height ) {
				var p = (i << 2);

				var b = mem.b(p);
				var g = mem.b(p+1);
				var r = mem.b(p+2);
				var a = mem.b(p+3);
				
				mem.wb(p,   premul(b,a));
				mem.wb(p+1, premul(g,a));
				mem.wb(p+2, premul(r,a));
				mem.wb(p+3, a);
			}

			mem.end();
		}

		
		if( innerTex == null ) {
			innerTex = h3d.mat.Texture.fromPixels(pixels);
			font.tile = h2d.Tile.fromTexture(innerTex);
			for( t in all )
				t.setTexture(innerTex);
			innerTex.realloc = build;
		} else
			innerTex.uploadPixels(pixels);
		pixels.dispose();
		return font;
	}
	
	#else
	
	function build() {
		throw "Font building not supported on this platform";
		return null;
	}
	
	#end
	
	public static function addFontAlias(name:String, realName:String) {
		FONT_ALIASES.set( name, realName);
	}
	
	public static function getFont( name : String, size : Int, ?options : FontBuildOptions ) : h2d.Font {
		var key = name + "#" + size;
		if ( options != null){
			key += "opt-aa:" + options.antiAliasing;
			if( options.chars != null )
				key += ";opt-chars:" + haxe.crypto.Crc32.make(haxe.io.Bytes.ofString(options.chars));
			key += ";opt-premul:" + options.alphaPremultiplied;
		}
		
		var f = FONTS.get(key);
		if( f != null && f.tile.innerTex != null && !f.tile.innerTex.isDisposed() )
			return f;
		f = new FontBuilder(name, size, options).build();
		FONTS.set(key, f);
		return f;
	}
	
	public static function dispose() {
		for( f in FONTS )
			f.dispose();
		FONTS = new Map();
	}

	static var FONTS = new Map<String,h2d.Font>();
	static var FONT_ALIASES = new Map<String,String>();

}
