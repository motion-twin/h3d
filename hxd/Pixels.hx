package hxd;

enum Flags {
	ReadOnly;
	AlphaPremultiplied;
	Compressed;
	NoAlpha;
}

/**
 * REV 0 added no conversion flags for non integer textures
 * REV 1 added explicit param type for doc
 */
class Pixels {
	
	public var bytes : hxd.BytesView;
	public var format : PixelFormat;
	public var width : Int;
	public var height : Int;
	public var flags: haxe.EnumFlags<Flags>;
	
	/**
	 * @param	?offset=0 byte offset on the target buffer
	 */
	public function new(width : Int, height : Int, bytes : hxd.BytesView, format : hxd.PixelFormat) {
		hxd.Assert.notNull(bytes);
		this.width = width;
		this.height = height;
		this.bytes = bytes;
		this.format = format;
	}
	
	public inline function isDispose() {
		return bytes == null;
	}
		
	@:noDebug
	public function makeSquare( ?copy : Bool ) {
		var w = width, h = height;
		var tw = w == 0 ? 0 : 1, th = h == 0 ? 0 : 1;
		while( tw < w ) tw <<= 1;
		while( th < h ) th <<= 1;
		if( w == tw && h == th ) return this;
		var out = hxd.impl.Tmp.getBytesView(tw * th * 4);
		var p = 0;
		var b = 0;
		for( y in 0...h ) {
			out.blit(p, bytes, b, w * 4);
			p += w * 4;
			b += w * 4;
			for( i in 0...(tw - w) * 4 )
				out.set(p++, 0);
		}
		for( i in 0...(th - h) * tw * 4 )
			out.set(p++, 0);
		if( copy )
			return new Pixels(tw, th, out, format);
		if( !flags.has(ReadOnly) ) hxd.impl.Tmp.saveBytesView(bytes);
		bytes = out;
		width = tw;
		height = th;
		return this;
	}
	
	function copyInner() {
		var old = bytes;
		bytes = hxd.impl.Tmp.getBytesView(width * height * 4);
		bytes.blit(0, old, 0, width * height * 4);
		flags.unset(ReadOnly);
	}
	
	/**
	 * 
	 * @return true if some conversion was performed
	 */
	@:noDebug
	public function convert( target : PixelFormat ) {
		if ( format == target ) 
			return false;
			
		if( flags.has(ReadOnly) )
			copyInner();
			
		switch( [format, target] ) {
			case [BGRA, ARGB], [ARGB, BGRA]:
				// reverse bytes
				var mem = hxd.impl.Memory.select(bytes.bytes);
				for( i in 0...width*height ) {
					var p = (i << 2) + bytes.position;
					var a = mem.b(p);
					var r = mem.b(p+1);
					var g = mem.b(p+2);
					var b = mem.b(p+3);
					mem.wb(p, b);
					mem.wb(p+1, g);
					mem.wb(p+2, r);
					mem.wb(p+3, a);
				}
				mem.end();
			case [BGRA, RGBA],[RGBA, BGRA]:
				var mem = hxd.impl.Memory.select(bytes.bytes);
				for( i in 0...width*height ) {
					var p = (i << 2) + bytes.position;
					var b = mem.b(p);
					var r = mem.b(p+2);
					mem.wb(p, r);
					mem.wb(p+2, b);
				}
				mem.end();
				
			case [ARGB, RGBA]: {
				var mem = hxd.impl.Memory.select(bytes.bytes);
				for ( i in 0...width * height ) {
					var p = (i << 2) + bytes.position;
					var a = (mem.b(p));
					
					mem.wb(p, mem.b(p + 1));
					mem.wb(p + 1, mem.b(p + 2));
					mem.wb(p + 2, mem.b(p + 3));
					mem.wb(p + 3, a);				
				}
				mem.end();
			}
		
			default:
				throw "Cannot convert from " + format + " to " + target;
		}
		format = target;
		return true;
	}
	
	public function getPixel(x, y) : UInt {
		return switch(format) {
			case ARGB | BGRA | RGBA:
				var u = 0;
				var p = 4 * (y * width + x) + bytes.position;
				u |= bytes.get( p	);
				u |= bytes.get( p+1 )<<8;
				u |= bytes.get( p+2 )<<16;
				u |= bytes.get( p+3 )<<24;
				u;
				
			default: 0;
		}		
	}
	
	public function setPixel(x, y , argb:Int)  {
		switch(format) {
			case BGRA:
				var p = 4 * (y * width + x) + bytes.position;
				bytes.set( p, (argb>>>24)&0xFF );
				bytes.set( p+1, (argb>>16)&0xFF );
				bytes.set( p+2, (argb>>8)&0xFF );
				bytes.set( p+3, (argb)&0xFF );
				
			default: throw "assert";
		}		
	}
	
	public function dispose() {
		if( bytes != null && !flags.has( ReadOnly ) ) {
			hxd.impl.Tmp.saveBytes(bytes.bytes);
			bytes = null;
		}
	}
	
	public static function bytesPerPixel( format : PixelFormat ) {
		return switch( format ) {
			case ARGB, BGRA, RGBA: 4;
			default:0;
		}
	}
	
	public static function alloc( width, height, format ) {
		return new Pixels(width, height, hxd.impl.Tmp.getBytesView(width * height * bytesPerPixel(format)), format);
	}
	
	public function isMixed() {
		return 
		switch(format) {
			case Mixed(_, _, _, _): true;
			default:false;
		}
	}
	
}
