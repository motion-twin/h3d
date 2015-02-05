package hxd;
import flash.utils.ByteArray;
import haxe.io.Bytes;

private typedef InnerData = #if flash flash.Vector<Float> 
#elseif (openfl && cpp)
openfl.utils.Float32Array
#else
Array<Float> 
#end

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
	public inline function next() {
		return b[pos++];
	}
}

abstract FloatBuffer(InnerData) {

	public var length(get, never) : Int;
		
	public inline function new(length = 0) {
		#if js
		this = untyped __new__(Array, length);
		#elseif cpp
		this = new InnerData(length);
		#else
		this = new InnerData(length);
		#end
	}
	
	public inline function push( v : hxd.Float32 ) {
		#if (flash || openfl )
		var l = this.length;
		grow(l + 1);
		arrayWrite( l, v);
		#else
		this.push(v);
		#end
	}
	
	/**
	 * creates a back copy
	 */
	@:from
	public static inline function fromArray( arr: Array<hxd.Float32> ) :FloatBuffer{
		var f = new FloatBuffer(arr.length);
		for ( v in 0...arr.length )
			f[v] = arr[v];
		return f;
	}
	
	public static inline function makeView( arr: Array<hxd.Float32> ) : FloatBuffer {
		#if flash
		var f = new FloatBuffer(arr.length);
		for ( v in 0...arr.length )
			f[v] = arr[v];
		return f;
		#else 
		return cast arr;
		#end
	}
	
	public inline function grow( v : Int ) {
		#if (openfl && cpp )
		this.__setLength(v);
		#elseif flash
		if( v > this.length ) this.length = v;
		#else
		while( this.length < v ) this.push(0.);
		#end
	}

	
	@:arrayAccess public inline function arrayRead(key:Int) : hxd.Float32 {
		#if cpp 
			#if (haxe_ver >= 3.13)
				return this.__getF32( key );
			#else 
				return this.__get( key );
			#end
		#else
		return this[key];
		#end
	}

	@:arrayAccess public inline function arrayWrite(key:Int, value : hxd.Float32 ) : hxd.Float32 {
		
		#if debug
			if( this.length <= key)
				throw "need regrow until " + key;
		#end
		
		#if cpp 
			#if (haxe_ver >= 3.13)
				this.__setF32( key , value);
			#else 
				this.__set( key , value);
			#end
		#else
		this[key] = value;
		#end
		return value;
	}
	
	//debuggin purpose, don't use this...
	public function slice( pos, len ) : Array<hxd.Float32> {
		if ( pos < 0 ) pos = get_length() + pos;
		var a = [];
		for ( i in pos...pos + len) {
			if( pos < length )
				a.push( arrayRead(i));
		}
		return a;
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
	
	public inline function blit( src : FloatBuffer, count:Int) {
		for ( i in 0...count)  arrayWrite( i, src[i]);
	}
		
	public inline function zero() {
		for ( i in 0...length)  arrayWrite( i, 0 );
	}
	
	public inline function clone() {
		var v = new FloatBuffer(length);
		for ( i in 0...length)  v.arrayWrite( i, arrayRead(i) );
		return v;
	}
	
	public static inline function fromNative( data:InnerData ) : hxd.FloatBuffer {
		return cast data;
	}
	
	/**
	 * Warning does not necessarily make a copy
	 */
	@:noDebug
	public static function fromBytes( bytes:haxe.io.Bytes ) : hxd.FloatBuffer{
		#if flash
		var nbFloats = bytes.length >> 2;
		var f = new FloatBuffer(nbFloats);
		var pos = 0;
		for ( i in 0...nbFloats){
			f[i] = bytes.getFloat(pos);
			pos += 4;
		}
		return f;
		#else
		var ba = hxd.ByteConversions.bytesToByteArray( bytes );
		return fromNative( new openfl.utils.Float32Array( ba ) );
		#end
	}
	
	public inline function toBytes() : haxe.io.Bytes {
		var ba = new flash.utils.ByteArray();
		ba.endian = flash.utils.Endian.LITTLE_ENDIAN;
		
		for (v in this )
			ba.writeFloat(v);
		
		#if flash
		return haxe.io.Bytes.ofData(ba);
		#else
		return ba;
		#end
	}
}