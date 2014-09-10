package hxd;

import haxe.io.Bytes;

/**
 * Tries to provide consistent access to haxe.io.bytes from any primitive
 */
class ByteConversions{

	
	#if (flash || openfl)
	public static function byteArrayToBytes( v: flash.utils.ByteArray ) : haxe.io.Bytes {
		return
		#if flash
		Bytes.ofData( v );
		#elseif (js&&openfl)
		{
			var b :Bytes = Bytes.alloc(v.length);
			for ( i in 0...v.length )
				b.set(i,v[i]);
			b;
		};
		#elseif (openfl)
		v; 
		#else
		throw "unsupported on this platform";
		#end
	}
	#end 
	
	#if (flash || openfl)
	public static inline function byteArrayToBytesView( v: flash.utils.ByteArray ) : hxd.BytesView {
		return BytesView.fromBytes(byteArrayToBytes(v));
	}
	#end 
	
	#if js
	public static inline function arrayBufferToBytes( v : js.html.ArrayBuffer ) : haxe.io.Bytes{
		return byteArrayToBytes(flash.utils.ByteArray.nmeOfBuffer(v));
	}
	#end
		
	#if (flash || openfl)
	public static function bytesToByteArray( v: haxe.io.Bytes ) :  flash.utils.ByteArray {
		#if flash
		return v.getData();
		#elseif openfl
		return flash.utils.ByteArray.fromBytes(v);
		#else
		throw "unsupported on this platform";
		#end
	}
	#end 
	
	#if (flash || openfl)
	public static function bytesViewToByteArray( bv: hxd.BytesView ) :  flash.utils.ByteArray {
		#if flash
		if ( bv.position == 0)
			return bv.bytes.getData();
		else {
			var ba = new flash.utils.ByteArray();
			ba.writeBytes( bv.bytes.getData(), bv.position, bv.length);
			return ba;
		}
		#elseif openfl
		var bv = pixels.bytes;
		var ba = bv.position == 0 ? flash.utils.ByteArray.fromBytes(bv.bytes)
		: {
			var ba = new flash.utils.ByteArray(bv.length);
			ba.writeBytes( bv.bytes, bv.position, bv.length);
			ba;
		};
		#else
		throw "unsupported on this platform";
		#end
	}
	#end 
}
