package h2d.col;
import hxd.Math;

class Point {
	
	public var x : hxd.Float32;
	public var y : hxd.Float32;
	
	public inline function new(x = 0., y = 0.) {
		this.x = x;
		this.y = y;
	}
	
	public inline function set(x = 0., y = 0.) {
		this.x = x;
		this.y = y;
	}
	
	public inline function clone() {
		return new Point(x,y);
	}
	
	public inline function distanceSq( p : Point ) {
		var dx = x - p.x;
		var dy = y - p.y;
		return dx * dx + dy * dy;
	}
	
	public inline function distance( p : Point ) {
		return Math.sqrt(distanceSq(p));
	}
	
	public function toString() {
		return "{" + Math.fmt(x) + "," + Math.fmt(y) + "}";
	}
		
	public inline function sub( p : Point ) {
		return new Point(x - p.x, y - p.y);
	}

	public inline function add( p : Point ) {
		return new Point(x + p.x, y + p.y);
	}

	public inline function dot( p : Point ) {
		return x * p.x + y * p.y;
	}

	public inline function lengthSq() {
		return x * x + y * y;
	}

	public inline function length() {
		return Math.sqrt(lengthSq());
	}

	public function normalize() {
		var k = lengthSq();
		if( k < Math.EPSILON ) k = 0 else k = Math.invSqrt(k);
		x *= k;
		y *= k;
	}

	public inline function scale( f : hxd.Float32 ) {
		x *= f;
		y *= f;
	}

	public static var ZERO = new Point(0, 0);
}