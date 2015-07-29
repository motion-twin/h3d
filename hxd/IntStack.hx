package hxd;

private class IntStackIterator {
	var b : Array<Int>;
	var len : Int;
	var pos : Int;
	public inline function new( b : Array<Int>,len:Int )  {
		this.b = b;
		this.len = len;
		this.pos = 0;
	}
	public inline function hasNext() {
		return pos < len;
	}
	public inline function next() {
		return b[pos++];
	}
}

class IntStack {
	var arr : Array<Int>=[];
	var pos = 0;
	
	public var length(get, never):Int; inline function get_length() return pos;
	
	public inline function new() {}
	
	public inline function reserve(n) {
		if (arr.length < n )
			arr[n] = 0;
	}
	
	public inline function push(v:Int) {
		arr[pos++] = v;
	}
	
	public inline function pop() : Int {
		if ( pos == 0 ) return 0;
			
		var v = arr[pos-1]; 
		arr[--pos] = 0;
		return v;
	}
	
	public inline function unsafeGet(idx:Int) {
		return arr[idx];
	}
	
	public inline function reset() {
		for ( i in 0...arr.length) arr[i] = 0;
		pos = 0;
	}
	
	public inline function iterator() {
		return new IntStackIterator(arr,get_length());
	}
	
	public inline function toString() {
		var s = "";
		for ( i in 0...pos) {
			s += Std.string(arr[i]);
		}
		return s;
	}
	
	public inline function toData() {
		return arr;
	}
}