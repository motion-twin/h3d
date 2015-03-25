#if false
package hxd;

import haxe.io.Bytes;
import hxd.BytesView;

private typedef InnerData = 
#if (flash||openfl)
	flash.display.BitmapData 
#elseif js
	js.html.ImageData 
#else 
	Int 
#end;

abstract BitmapData(InnerData) {

	public var width(get, never) : Int;
	public var height(get, never) : Int;
	
	public inline function new(width:Int, height:Int) {
		#if ((flash)||(openfl))
		this = new flash.display.BitmapData(width, height, true, 0);
		#else
		throw "TODO";
		#end
	}
	
	public inline function clear( color : Int ) {
		#if ((flash)||(openfl))
		this.fillRect(this.rect, color);
		#else
		throw "TODO";
		#end
	}
	
	public inline function fill( rect : h2d.col.Bounds, color : Int ) {
		#if ((flash)||(openfl))
		this.fillRect(new flash.geom.Rectangle(Std.int(rect.xMin), Std.int(rect.yMin), Math.ceil(rect.xMax - rect.xMin), Math.ceil(rect.yMax - rect.yMin)), color);
		#else
		throw "TODO";
		#end
	}

	public function line( x0 : Int, y0 : Int, x1 : Int, y1 : Int, color : Int ) {
		var dx = x1 - x0;
		var dy = y1 - y0;
		if( dx == 0 ) {
			if( y1 < y0 ) {
				var tmp = y0;
				y0 = y1;
				y1 = tmp;
			}
			for( y in y0...y1 + 1 )
				setPixel(x0, y, color);
		} else if( dy == 0 ) {
			if( x1 < x0 ) {
				var tmp = x0;
				x0 = x1;
				x1 = tmp;
			}
			for( x in x0...x1 + 1 )
				setPixel(x, y0, color);
		} else {
			throw "TODO";
		}
	}
	
	public inline function dispose() {
		#if ((flash)||(openfl))
		this.dispose();
		#end
	}
	
	public inline function getPixel( x : Int, y : Int ) {
		#if ( flash || openfl )
		return toNative().getPixel32(x, y);
		#else
		throw "TODO";
		return 0;
		#end
	}

	public inline function setPixel( x : Int, y : Int, c : Int ) {
		#if ((flash)||(openfl))
		this.setPixel32(x, y, c);
		#else
		throw "TODO";
		#end
	}
	
	inline function get_width() {
		return this.width;
	}

	inline function get_height() {
		return this.height;
	}
	
	/**
	 * This is bad, answer varies along how the tex was initialized...
	 */
	public inline function isAlphaPremultiplied() {
		#if flash
			return false;
		#else 
			return toNative().premultipliedAlpha;
		#end
	}
	/**
	 * According to flash spec, always return a non premultiplied zone (albeit information can be lost)
	 */
	public inline function getPixels() : Pixels {
		return nativeGetPixels(this);
	}

	public inline function setPixels( pixels : Pixels ) {
		nativeSetPixels(this, pixels);
	}
	
	public inline function toNative() : InnerData {
		return this;
	}
	
	public static inline function fromNative( bmp : InnerData ) : BitmapData {
		return cast bmp;
	}
	
	static function nativeGetPixels( b : InnerData ) : hxd.Pixels {
		#if flash
			 var p = new Pixels(b.width, b.height, BytesView.fromBytes(haxe.io.Bytes.ofData(b.getPixels(b.rect))), ARGB);
			 //NOP
			 //p.flags.set( AlphaPremultiplied );
			 return p;
		#elseif openfl
			var bRect = b.rect;
			var bPixels : Bytes = hxd.ByteConversions.byteArrayToBytes(b.getPixels(b.rect));
			var p = new Pixels(b.width, b.height, hxd.BytesView.fromBytes(bPixels), ARGB);
			if ( b.premultipliedAlpha  ) 
				p.flags.set( AlphaPremultiplied );
			return p;
		#else
			throw "TODO";
			return null;
		#end
	}
	
	static function nativeSetPixels( b : InnerData, pixels : Pixels ) {
		#if flash
			var ba = hxd.ByteConversions.bytesToByteArray( pixels.bytes.bytes );
			ba.position = 0;
			switch( pixels.format ) {
			case BGRA:
				ba.endian = flash.utils.Endian.LITTLE_ENDIAN;
			case ARGB:
				ba.endian = flash.utils.Endian.BIG_ENDIAN;
			case RGBA:
				pixels.convert(BGRA);
				ba.endian = flash.utils.Endian.LITTLE_ENDIAN;
			case Mixed(_,_,_,_) | Compressed(_): throw "inner format assert";
			}
			b.setPixels(b.rect, ba);
		#elseif ((js) || (cpp))
			var bv = pixels.bytes;
			var ba = bv.position == 0 ? flash.utils.ByteArray.fromBytes(bv.bytes)
			: {
				var ba = new flash.utils.ByteArray(bv.length);
				ba.writeBytes( bv.bytes, bv.position, bv.length);
				ba;
			};
			b.setPixels(b.rect, ba);
		#else
			throw "TODO";
		#end
	}
}
#end

package hxd;

typedef BitmapInnerData =
#if (flash || openfl || nme)
	flash.display.BitmapData;
#elseif js
	js.html.CanvasRenderingContext2D;
#else
	Int;
#end

class BitmapData {

	#if (flash || nme || openfl)
	static var tmpRect = new flash.geom.Rectangle();
	static var tmpPoint = new flash.geom.Point();
	static var tmpMatrix = new flash.geom.Matrix();
	#end

#if (flash||openfl||nme)
	var bmp : flash.display.BitmapData;
#elseif js
	var ctx : js.html.CanvasRenderingContext2D;
	var lockImage : js.html.ImageData;
	var pixel : js.html.ImageData;
#end

	public var width(get, never) : Int;
	public var height(get, never) : Int;
	public var alphaPremultiplied = false;

	public function new(width:Int, height:Int) {
		if( width == -101 && height == -102 ) {
			// no alloc
		} else {
			#if (flash||openfl||nme)
			bmp = new flash.display.BitmapData(width, height, true, 0);
			#elseif js
			var canvas = js.Browser.document.createCanvasElement();
			canvas.width = width;
			canvas.height = height;
			ctx = canvas.getContext2d();
			#else
			notImplemented();
			#end
		}
	}

	public function clear( color : Int ) {
		#if (flash||openfl||nme)
		bmp.fillRect(bmp.rect, color);
		#else
		fill(0, 0, width, height, color);
		#end
	}

	static inline function notImplemented() {
		throw "Not implemented";
	}

	public function fill( x : Int, y : Int, width : Int, height : Int, color : Int ) {
		#if (flash || openfl || nme)
		var r = tmpRect;
		r.x = x;
		r.y = y;
		r.width = width;
		r.height = height;
		bmp.fillRect(r, color);
		#elseif js
		ctx.fillStyle = 'rgba(${(color>>16)&0xFF}, ${(color>>8)&0xFF}, ${color&0xFF}, ${(color>>>24)/255})';
		ctx.fillRect(x, y, width, height);
		#else
		notImplemented();
		#end
	}

	public function draw( x : Int, y : Int, src : BitmapData, srcX : Int, srcY : Int, width : Int, height : Int, ?blendMode : h2d.BlendMode ) {
		#if (flash || openfl || nme)
		if( blendMode == null ) blendMode = Normal;
		var r = tmpRect;
		r.x = srcX;
		r.y = srcY;
		r.width = width;
		r.height = height;
		switch( blendMode ) {
		case None:
			var p = tmpPoint;
			p.x = x;
			p.y = y;
			bmp.copyPixels(src.bmp, r, p);
		case Normal:
			var p = tmpPoint;
			p.x = x;
			p.y = y;
			bmp.copyPixels(src.bmp, r, p, src.bmp, null, true);
		case Add:
			var m = tmpMatrix;
			m.tx = x - srcX;
			m.ty = y - srcY;
			r.x = x;
			r.y = y;
			bmp.draw(src.bmp, m, null, flash.display.BlendMode.ADD, r, false);
		case Erase:
			var m = tmpMatrix;
			m.tx = x - srcX;
			m.ty = y - srcY;
			r.x = x;
			r.y = y;
			bmp.draw(src.bmp, m, null, flash.display.BlendMode.ERASE, r, false);
		case Multiply:
			var m = tmpMatrix;
			m.tx = x - srcX;
			m.ty = y - srcY;
			r.x = x;
			r.y = y;
			bmp.draw(src.bmp, m, null, flash.display.BlendMode.MULTIPLY, r, false);
		
		case SoftOverlay,SoftAdd:
			throw "BlendMode not supported";
		}
		#else
		notImplemented();
		#end
	}

	public function drawScaled( x : Int, y : Int, width : Int, height : Int, src : BitmapData, srcX : Int, srcY : Int, srcWidth : Int, srcHeight : Int, ?blendMode : h2d.BlendMode, smooth = true ) {
		if( blendMode == null ) blendMode = Normal;
		#if (flash || openfl || nme)

		var b = switch( blendMode ) {
		case None:
			// todo : clear before ?
			flash.display.BlendMode.NORMAL;
		case Normal:
			flash.display.BlendMode.NORMAL;
		case Add:
			flash.display.BlendMode.ADD;
		case Erase:
			flash.display.BlendMode.ERASE;
		case Multiply:
			flash.display.BlendMode.MULTIPLY;
		case SoftOverlay,SoftAdd:
			throw "BlendMode not supported";
		}

		var m = tmpMatrix;
		m.a = width / srcWidth;
		m.d = height / srcHeight;
		m.tx = x - srcX * m.a;
		m.ty = y - srcY * m.d;

		var r = tmpRect;
		r.x = x;
		r.y = y;
		r.width = width;
		r.height = height;

		bmp.draw(src.bmp, m, null, b, r, smooth);
		m.a = 1;
		m.d = 1;

		#else
		notImplemented();
		#end
	}

	public function line( x0 : Int, y0 : Int, x1 : Int, y1 : Int, color : Int ) {
		var dx = x1 - x0;
		var dy = y1 - y0;
		if( dx == 0 ) {
			if( y1 < y0 ) {
				var tmp = y0;
				y0 = y1;
				y1 = tmp;
			}
			for( y in y0...y1 + 1 )
				setPixel(x0, y, color);
		} else if( dy == 0 ) {
			if( x1 < x0 ) {
				var tmp = x0;
				x0 = x1;
				x1 = tmp;
			}
			for( x in x0...x1 + 1 )
				setPixel(x, y0, color);
		} else {
			throw "TODO : brensenham line";
		}
	}

	public inline function dispose() {
		#if (flash||openfl||nme)
		bmp.dispose();
		#end
	}

	public function clone() {
		return sub(0,0,width,height);
	}

	public function sub( x, y, w, h ) : BitmapData {
		#if (flash || openfl || nme)
		var b = new flash.display.BitmapData(w, h);
		b.copyPixels(bmp, new flash.geom.Rectangle(x, y, w, h), new flash.geom.Point(0, 0));
		return fromNative(b);
		#else
		notImplemented();
		return null;
		#end
	}

	/**
		Inform that we will perform several pixel operations on the BitmapData.
	**/
	public function lock() {
		#if flash
		bmp.lock();
		#elseif js
		if( lockImage == null )
			lockImage = ctx.getImageData(0, 0, width, height);
		#end
	}

	/**
		Inform that we have finished performing pixel operations on the BitmapData.
	**/
	public function unlock() {
		#if flash
		bmp.unlock();
		#elseif js
		if( lockImage != null ) {
			ctx.putImageData(lockImage, 0, 0);
			lockImage = null;
		}
		#end
	}

	/**
		Access the pixel color value at the given position. Note : this function can be very slow if done many times and the BitmapData has not been locked.
	**/
	public #if (flash || openfl || nme) inline #end function getPixel( x : Int, y : Int ) : Int {
		#if ( flash || openfl || nme )
		return bmp.getPixel32(x, y);
		#elseif js
		var i = lockImage;
		var a;
		if( i != null )
			a = (x + y * i.width) << 2;
		else {
			a = 0;
			i = ctx.getImageData(x, y, 1, 1);
		}
		return (i.data[a] << 16) | (i.data[a|1] << 8) | i.data[a|2] | (i.data[a|3] << 24);
		#else
		notImplemented();
		return 0;
		#end
	}

	/**
		Modify the pixel color value at the given position. Note : this function can be very slow if done many times and the BitmapData has not been locked.
	**/
	public #if (flash || openfl || nme) inline #end function setPixel( x : Int, y : Int, c : Int ) {
		#if ( flash || openfl || nme)
		bmp.setPixel32(x, y, c);
		#elseif js
		var i : js.html.ImageData = lockImage;
		if( i != null ) {
			var a = (x + y * i.width) << 2;
			i.data[a] = (c >> 16) & 0xFF;
			i.data[a|1] = (c >> 8) & 0xFF;
			i.data[a|2] = c & 0xFF;
			i.data[a|3] = (c >>> 24) & 0xFF;
			return;
		}
		var i = pixel;
		if( i == null ) {
			i = ctx.createImageData(1, 1);
			pixel = i;
		}
		i.data[0] = (c >> 16) & 0xFF;
		i.data[1] = (c >> 8) & 0xFF;
		i.data[2] = c & 0xFF;
		i.data[3] = (c >>> 24) & 0xFF;
		ctx.putImageData(i, x, y);
		#else
		notImplemented();
		#end
	}

	inline function get_width() : Int {
		#if (flash || nme || openfl)
		return bmp.width;
		#elseif js
		return ctx.canvas.width;
		#else
		notImplemented();
		return 0;
		#end
	}

	inline function get_height() {
		#if (flash || nme || openfl)
		return bmp.height;
		#elseif js
		return ctx.canvas.height;
		#else
		notImplemented();
		return 0;
		#end
	}

	public function getPixels() : Pixels {
		#if (flash || nme )
		var p = new Pixels(width, height, BytesView.fromBytes(haxe.io.Bytes.ofData(bmp.getPixels(bmp.rect))), ARGB);
		//p.flags.set(AlphaPremultiplied);
		return p;
		#elseif openfl
		var bRect = bmp.rect;
		var bPixels : haxe.io.Bytes = hxd.ByteConversions.byteArrayToBytes(bmp.getPixels(bRect));
		var p = new Pixels(bmp.width, bmp.height, hxd.BytesView.fromBytes(bPixels), ARGB);
		if ( alphaPremultiplied  ) 
			p.flags.set( AlphaPremultiplied );
		return p;
		#elseif js
		var w = width;
		var h = height;
		var data = ctx.getImageData(0, 0, w, h).data;
			#if (haxe_ver < 3.2)
			var pixels = [];
			for( i in 0...w * h * 4 )
				pixels.push(data[i]);
			#else
			// starting from Haxe 3.2, bytes are based on native array
			var pixels = data;
			#end
		return new Pixels(w, h, haxe.io.Bytes.ofData(pixels), RGBA);
		#else
		notImplemented();
		return null;
		#end
	}

	public function setPixels( pixels : Pixels ) {
		#if flash
		var ba = hxd.ByteConversions.bytesToByteArray( pixels.bytes.bytes );
		ba.position = 0;
		switch( pixels.format ) {
		case BGRA:
			ba.endian = flash.utils.Endian.LITTLE_ENDIAN;
		case ARGB:
			ba.endian = flash.utils.Endian.BIG_ENDIAN;
		case RGBA:
			pixels.convert(BGRA);
			ba.endian = flash.utils.Endian.LITTLE_ENDIAN;
		case Mixed(_,_,_,_) | Compressed(_): throw "inner format assert";
		}
		bmp.setPixels(bmp.rect, ba);
		#elseif js
		var img = ctx.createImageData(pixels.width, pixels.height);
		pixels.convert(RGBA);
		for( i in 0...pixels.width*pixels.height*4 ) img.data[i] = pixels.bytes.get(i);
		ctx.putImageData(img, 0, 0);
		#elseif cpp
		var bv = pixels.bytes;
		var ba = bv.position == 0 ? flash.utils.ByteArray.fromBytes(bv.bytes)
		: {
			var ba = new flash.utils.ByteArray(bv.length);
			ba.writeBytes( bv.bytes, bv.position, bv.length);
			ba;
		};
		bmp.setPixels(bmp.rect, ba);
		#else
		notImplemented();
		#end
	}

	public inline function toNative() : BitmapInnerData {
		#if (flash || nme || openfl)
		return bmp;
		#elseif js
		return ctx;
		#else
		notImplemented();
		return 0;
		#end
	}

	public static function fromNative( data : BitmapInnerData ) : BitmapData {
		var b = new BitmapData( -101, -102 );
		#if (flash || nme || openfl)
		b.bmp = data;
			#if(openfl&&cpp)
			b.alphaPremultiplied = data.premultipliedAlpha;
			#end
		#elseif js
		b.ctx = data;
		#else
		notImplemented();
		#end
		return b;
	}

}