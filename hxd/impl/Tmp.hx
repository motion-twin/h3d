package hxd.impl;

class Tmp {

	static var bytes = new Array<haxe.io.Bytes>();
	static var matrices : List<h3d.Matrix> = null;
	
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
	
	public static function getMatrix() : h3d.Matrix{
		if ( matrices == null)
			matrices = new List();
		if ( matrices.length == 0 )
			return new h3d.Matrix();
		return matrices.pop();
	}
	
	public static function saveMatrix(m) {
		if ( matrices == null)
			matrices = new List();
		matrices.push( m );
	}
}