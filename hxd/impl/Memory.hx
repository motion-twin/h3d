package hxd.impl;

@:access(hxd.impl.Memory)
class MemoryReader {

	public function new() {
	}
	
	public inline function b( addr : Int ) {
		#if (flash||openfl)
		return flash.Memory.getByte(addr);
		#else
		return Memory.current.get(addr);
		#end
	}
	
	public inline function wb( addr : Int, v : Int ) {
		#if (flash||openfl)
		flash.Memory.setByte(addr, v);
		#else
		Memory.current.set(addr, v);
		#end
	}
	
	public inline function double( addr : Int ) : Float {
		#if (flash||openfl)
		return flash.Memory.getDouble(addr);
		#else
		throw "TODO";
		return 0.;
		#end
	}

	public inline function i32( addr : Int ) : Int {
		#if (flash||openfl)
		return flash.Memory.getI32(addr);
		#else
		throw "TODO";
		return 0;
		#end
	}
	
	public inline function end() {
		@:privateAccess Memory.end();
	}

}

class Memory {

	static var stack = new Array<haxe.io.Bytes>();
	static var current : haxe.io.Bytes = null;
	static var inst = new MemoryReader();
	
	public static function select( b : haxe.io.Bytes ) {
		#if (flash||openfl)
		var data =  hxd.ByteConversions.bytesToByteArray( b );
		#if flash
		if ( data.length < 1024 ) data.length = 1024;
		#end
		flash.Memory.select(data);
		#end
		if( current != null ) stack.push(current);
		current = b;
		return inst;
	}
	
	static function end() {
		current = stack.pop();
		#if (flash||openfl)
		if( current != null )
			flash.Memory.select(hxd.ByteConversions.bytesToByteArray(current));
		#end
	}

}