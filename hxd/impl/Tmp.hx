package hxd.impl;

class Tmp {

	static var bytes = new Array<haxe.io.Bytes>();
	
	public static inline function getBytesView( size : Int ) {
		var b = getBytes(size);
		return new hxd.BytesView(b, 0, size);
	}
	
	public static function getBytes( size : Int ) {
		for( i in 0...bytes.length ) {
			var b = bytes[i];
			if( b.length >= size ) {
				bytes.splice(i, 1);
				return b;
			}
		}
		var sz = 1024;
		while( sz < size )
			sz = (sz * 3) >> 1;
		return haxe.io.Bytes.alloc(sz);
	}
	
	public static function saveBytesView( b : hxd.BytesView ) {
		saveBytes(b.bytes);
	}
	
	public static function saveBytes( b : haxe.io.Bytes ) {
		for( i in 0...bytes.length ) {
			if( bytes[i].length <= b.length ) {
				bytes.insert(i, b);
				if( bytes.length > 8 )
					bytes.pop();
				return;
			}
		}
		bytes.push(b);
	}
	
}