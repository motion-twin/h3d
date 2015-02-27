package h2d;
import h2d.Font.FontChar;

class Kerning {
	public var prevChar : Int;
	public var offset : Int;
	public var next : Null<Kerning>;
	public function new(c, o) {
		this.prevChar = c;
		this.offset = o;
	}
}

class FontChar {
	public var t : h2d.Tile;
	public var width : Int;
	var kerning : Null<Kerning>;
	
	public function new(t,w) {
		this.t = t;
		this.width = w;
	}
	
	public function addKerning( prevChar : Int, offset : Int ) {
		var k = new Kerning(prevChar, offset);
		k.next = kerning;
		kerning = k;
	}
	
	public function getKerningOffset( prevChar : Int ) {
		var k = kerning;
		while( k != null ) {
			if( k.prevChar == prevChar )
				return k.offset;
			k = k.next;
		}
		return 0;
	}
	
	public function clone() {
		var f =  new FontChar(t.clone(), width);
		f.kerning = kerning;
		return f;
	}

}

/**
 * 
 * 
 * example where font can be find by the flash subsystem ( flash or openfl )
 * @usage
 * var font = hxd.res.FontBuilder.getFont("arial", 32, { antiAliasing : false , chars : hxd.Charset.DEFAULT_CHARS } );
 * 
 */
class Font {
	
	public var name(default, null) : String;
	public var size(default, null) : Int;
	public var lineHeight(default, null) : Int;
	public var tile(default,null) : h2d.Tile;
	public var charset : hxd.Charset;
	
	var glyphs : Map<Int,FontChar>;
	var defaultChar : FontChar;
	
	function new(name,size) {
		this.name = name;
		this.size = size;
		glyphs = new Map();
		defaultChar = new FontChar(new Tile(null, 0, 0, 0, 0),0);
		charset = hxd.Charset.getDefault();
	}
	
	public //inline 
	function getChar( code : Int ) : FontChar{
		var c = glyphs.get(code);
		if( c == null ) {
			c = charset.resolveChar(code, glyphs);
			#if debug
			if ( c == null ) 
				throw "cannot resolve tile for character : 0x" + StringTools.hex(code);
			#end
			if ( c == null ) c = defaultChar;
		}
		//trace("code:"+code+" str:"+ String.fromCharCode(code) +" tile:"+c.t);
		return c;
	}
	
	/**
		This is meant to create smoother fonts by creating them with double size while still keeping the original glyph size.
	**/
	public function resizeTo( size : Int ) {
		var ratio = size / this.size;
		for ( c in glyphs ) {
			c.width = Std.int(c.width * ratio);
			c.t.scaleToSize(Std.int(c.t.width * ratio), Std.int(c.t.height * ratio));
		}
		lineHeight = Std.int(lineHeight * ratio);
		this.size = size;
	}
	
	public function iter( f : FontChar -> Void ) {
		for( c in glyphs ) 
			f(c);
	}
	
	public function hasChar( code : Int ) {
		return glyphs.get(code) != null;
	}
	
	public function aliasGlyph( dest:Int, from:Int) {
		glyphs.set( dest , glyphs.get(from).clone() );
	}
	
	public function dispose() {
		tile.dispose();
		glyphs = null;
		tile = null;
		charset = null;
		defaultChar = null;
	}
	
}
