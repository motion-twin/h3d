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
	
	public function transcode( target : PixelFormat ) : hxd.Pixels {
		var dst = hxd.impl.Tmp.getBytesView( width * height * bytesPerPixel(target) );
		
		switch( [format, target]) {
			default: throw "usupported " + [format, target];
			
			case [ARGB,Mixed(4,4,4,4)]:
				var mem = hxd.impl.Memory.select(bytes.bytes);
				for ( i in 0...width * height ) {
					var p = (i<<2) + bytes.position;
					var col = (mem.i32(p));
					var a = col			&0xff;
					var r = (col>>8	)	&0xff;
					var g = (col>>16)	&0xff;
					var b = (col>>> 24)	&0xff;
					var bits = (a >> 4) | ((b >> 4) << 4) | ((g >> 4) << 8) | ((r >> 4) << 12);
					dst.bytes.set( (i<<1), 		(bits & 0xff) );
					dst.bytes.set( (i<<1)+1, 	(bits>>8) );
				}
				mem.end();
			
			case [BGRA,Mixed(4,4,4,4)]:
				var mem = hxd.impl.Memory.select(bytes.bytes);
				for ( i in 0...width * height ) {
					var p = (i<<2) + bytes.position;
					var col = (mem.i32(p));
					var b = col			&0xff;
					var g = (col>>8	)	&0xff;
					var r = (col>>16)	&0xff;
					var a = (col>>>24)	&0xff;
					var bits = (a >> 4) | ((b >> 4) << 4) | ((g >> 4) << 8) | ((r >> 4) << 12);
					dst.bytes.set( (i<<1), 	(bits & 0xff) );
					dst.bytes.set( (i<<1)+1,(bits>>8) );
				}
				mem.end();
		}
		return new Pixels(width,height,dst,target);
	}
	
	public function getPixel(x, y) : UInt {
		return switch(format) {
			case BGRA:
				var u = 0;
				var p = ((y * width + x)<<2) + bytes.position;
				u |= bytes.get( p	);
				u |= bytes.get( p+1 )<<8;
				u |= bytes.get( p+2 )<<16;
				u |= bytes.get( p+3 )<<24;
				u;
				
			case RGBA:
				var u = 0;
				var p = ((y * width + x)<<2) + bytes.position;
				u |= bytes.get( p	)<<16;
				u |= bytes.get( p+1 )<<8;
				u |= bytes.get( p+2 );
				u |= bytes.get( p+3 )<<24;
				u;
				
			case ARGB:
				var u = 0;
				var p = ((y * width + x)<<2) + bytes.position;
				u |= bytes.get( p	)<<24;
				u |= bytes.get( p+1 )<<16;
				u |= bytes.get( p+2 )<<8;
				u |= bytes.get( p+3 );
				u;
			
			//warning mixed format are gpu endianness...(too easy...)
			case Mixed(4, 4, 4, 4):
				var p = ((y * width + x) << 1) + bytes.position;
				var color = (bytes.get(p)) | (bytes.get(p + 1) << 8);
				
				var a = color			&0x0f;	a |= (a << 4);
				var b = (color >> 4)	&0x0f;	b |= (b << 4);
				var g = (color >> 8)	&0x0f; 	g |= (g << 4);
				var r = (color >> 12)	&0x0f; 	r |= (r << 4);
				
				(a << 24) | (r << 16) | (g << 8) | b;
				
			default: 0;
		}		
	}
	
	public function clear() {
		var z = 0;
		switch bytesPerPixel(format) {
			case 4:
				for ( i in 0...width * height ) {
					var p = (i << 2);
					bytes.set(		p+bytes.position,z);
					bytes.set(1	+	p+bytes.position,z);
					bytes.set(2	+	p+bytes.position,z);
					bytes.set(3	+	p+bytes.position,z);
				}
				
			case 2:
				for ( i in 0...width * height ) {
					var p = (i << 1);
					bytes.set(		p+bytes.position,z);
					bytes.set(1	+	p+bytes.position,z);
				}
		};
	}
	
	public function setPixel(x, y , color)  {
		var p = bytes.position;
		
		if( bytesPerPixel(format) == 4) 
			p += ((x + y * width) << 2);
		else if( bytesPerPixel(format) == 2) 
			p += ((x + y * width) << 1);
			
		var a = color >>> 24;
		var r = (color >> 16) & 0xFF;
		var g = (color >> 8) & 0xFF;
		var b = color & 0xFF;
		switch(format) {
			case BGRA:
				bytes.set(p, 	b);
				bytes.set(p+1, 	g);
				bytes.set(p+2, 	r);
				bytes.set(p+3, 	a);
			case RGBA:
				bytes.set(p, 	r);
				bytes.set(p+1,	g);
				bytes.set(p+2, 	b);
				bytes.set(p+3, 	a);
			case ARGB:
				bytes.set(p, 	a);
				bytes.set(p+1, 	r);
				bytes.set(p+2, 	g);
				bytes.set(p+3, 	b);
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
			case Mixed(r, g, b, a):
				return (r + g + b + a) >> 3;
			default:0;
		}
	}
	
	public function asString() {
		var s = new StringBuf();
		for( y in 0...height){
			for ( x in 0...width)
				s.add("0x" + StringTools.lpad(StringTools.hex( getPixel(x, y) ),"0",8) + "\t");
			s.add("\n");
		}
		return s.toString();
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
	
	public static function fromBitmap(bmp:hxd.BitmapData ) {
		bmp.lock();
		var pix = alloc( bmp.width, bmp.height, BGRA);
		for ( y in 0...bmp.height)
			for ( x in 0...bmp.width)
				pix.setPixel( x, y, bmp.getPixel( x, y ));
		bmp.unlock();
		return pix;
	}
	
}
