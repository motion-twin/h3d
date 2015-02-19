package hxd;

class FloatStack {
	var pos : Int;
	var buf : hxd.FloatBuffer;
	
	public var length(get, null) : Int;
	
	public inline function new() {
		buf = new hxd.FloatBuffer();
		pos = 0;
	}
	
	public inline function reset() {
		pos = 0;
	}
	
	public inline function reserve(nb) {
		if ( nb >= buf.length - 1 ) {
			buf.grow( hxd.Math.imax( Std.int(buf.length * 1.75), nb + 1 ));
		}
	}
	
	public inline function get_length() return pos;
	public inline function get(idx) 	return buf[idx];
	public inline function push(v) {
		if ( pos >= buf.length - 1 ) {
			buf.grow( hxd.Math.imax( Std.int(buf.length * 1.75), pos + 1 ));
		}
		
		buf[pos++] = v;
	}
	
	public inline function toData() : hxd.FloatBuffer {
		return buf;
	}
	
}