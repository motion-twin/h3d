package hxd;
import flash.utils.ByteArray;
import haxe.io.Bytes;
import openfl.utils.Float32Array;

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
	
	public inline function push( v : Float ) {
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
	public static inline function fromArray( arr: Array<Float> ) :FloatBuffer{
		var f = new FloatBuffer(arr.length);
		for ( v in 0...arr.length )
			f[v] = arr[v];
		return f;
	}
	
	public static inline function makeView( arr: Array<Float> ) : FloatBuffer {
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

	
	@:arrayAccess public inline function arrayRead(key:Int) : Float {
		#if cpp 
		return this.__get( key );
		#else
		return this[key];
		#end
	}

	@:arrayAccess public inline function arrayWrite(key:Int, value : Float) : Float {
		
		#if debug
			if( this.length <= key)
				throw "need regrow until " + key;
		#end
		
		#if cpp 
		this.__set( key , value);
		#else
		this[key] = value;
		#end
		return value;
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
	
	/**
	 * Warning does not necessarily make a copy
	 */
	public static function fromBytes( bytes:haxe.io.Bytes) : hxd.FloatBuffer{
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
		return new openfl.utils.Float32Array( bytes );
		#end
	}
	
	public inline function toBytes() : haxe.io.Bytes {
		var ba = new flash.utils.ByteArray();
		#if flash
		for (v in this )
			ba.writeFloat(v);
		#else 
		for (v in this )
			ba.writeFloat(v);
		#end
		
		#if flash
		return haxe.io.Bytes.ofData(ba);
		#else
		return ba;
		#end
	}
}