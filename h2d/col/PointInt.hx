package h2d.col;
import hxd.Math;

class PointInt {
	
	public var x : Int;
	public var y : Int;
	
	public inline function new(x = 0, y = 0) {
		this.x = x;
		this.y = y;
	}
	
	public inline function set(x = 0, y = 0) {
		this.x = x;
		this.y = y;
	}
	
	public inline function clone() {
		return new PointInt(x,y);
	}

	public static var ZERO = new PointInt(0, 0);
}