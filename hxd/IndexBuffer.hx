package hxd;
import haxe.io.Bytes;

private typedef InnerData = #if flash flash.Vector<UInt> #else Array<Int> #end

private class InnerIterator {
	var b : InnerData;
	var len : Int;
	var pos : Int;
	public inline function new( b : InnerData )  {
		this.b = b;
		this.len = this.b.length;
		this.pos = 0;
	}
	public inline function hasNext() {
		return pos < len;
	}
	public inline function next() : Int {
		return b[pos++];
	}
}

abstract IndexBuffer(InnerData) {
	
	public var length(get, never) : Int;
	
	public inline function new(length = 0) {
		#if js
		this = untyped __new__(Array, length);
		#elseif cpp
		this = new InnerData();
		#else
		this = new InnerData(length);
		#end
	}
	
	 @:from
	public static inline function fromArray( arr: Array<Int> ) : IndexBuffer{
		var f = new IndexBuffer(arr.length);
		for ( v in 0...arr.length )
			f[v] = arr[v];
		return f;
	}
	
	public inline function push( v : Int ) {
		#if flash
		this[this.length] = v;
		#else
		this.push(v);
		#end
	}

	@:arrayAccess inline function arrayRead(key:Int) : Int {
		return this[key];
	}

	@:arrayAccess inline function arrayWrite(key:Int, value : Int) : Int {
		return this[key] = value;
	}
	
	public inline function getNative() : InnerData {
		return this;
	}

	public inline function iterator() {
		return new InnerIterator(this);
	}

	inline function get_length() : Int {
		return this.length;
	}
	
	public inline function toBytes() : haxe.io.Bytes {
		var b = haxe.io.Bytes.alloc( length << 2);
		for ( i in 0...length ) {
			var v = arrayRead(i );
			b.set( i * 4 , 		(v & 0xFF )); 
			b.set( i * 4 +1, 	(v>>8 & 0xFF ));
			b.set( i * 4 +2, 	(v>>16 & 0xFF ));
			b.set( i * 4 +3, 	(v>>>24 & 0xFF ));
		}
		return b;
	}
	
	//debuggin purpose, don't use this...
	public function slice( pos, len ) : Array<Int> {
		if ( pos < 0 ) pos = get_length() - pos;
		var a = [];
		for ( i in pos...pos + len) {
			if( pos < length )
				a.push( arrayRead(i));
		}
		return a;
	}
	
	public static inline function fromBytes(bytes) : hxd.IndexBuffer {
		var me = new IndexBuffer();
		var nbInt = bytes.length >> 2;
		var pos = 0;
		for (i in 0...nbInt) {
			me[i] = bytes.get(pos)
			| 	(bytes.get(pos+1)<<8)
			| 	(bytes.get(pos+2)<<16)
			| 	(bytes.get(pos+3)<<24);
			pos += 4;
		}
		return me;
	}
}