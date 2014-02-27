package h2d;
import hxd.Math;
import h2d.col.Point;


/**
 * most algorithms taken from nme code
 */
class Matrix
{
	public var a : Float;
	public var b : Float;
	public var c : Float;
	public var d : Float;
	
	public var tx : Float;
	public var ty : Float;
	
	/**
	 * Loaded with identity by default
	 */
	public inline function new(a=1.,b=0.,c=0.,d=1.,tx=0.,ty=0.) {
		setTo(a, b, c, d, tx, ty);
	}
	
	public inline function zero() {
		a = b = c = d = tx = ty = 0.0;
	}
	
	public inline function identity() {
		a = 1.; b = 0.; c = 0.; d = 1.; tx = 0.; ty = 0.;
	}
	
	public inline function setTo(a=1.,b=0.,c=0.,d=1.,tx=0.,ty=0.) {
		this.a = a;	
		this.b = b; 
		this.c = c;
		this.d = d;
		
		this.tx = tx;
		this.ty = ty;
	}
	
	public function invert ():Matrix {

		var norm = a * d - b * c;
		if (norm == 0) {

			a = b = c = d = 0;
			tx = -tx;
			ty = -ty;
		} else {
			norm = 1.0 / norm;
			var a1 = d * norm;
			d = a * norm;
			a = a1;
			b *= -norm;
			c *= -norm;

			var tx1 = - a * tx - c * ty;
			ty = - b * tx - d * ty;
			tx = tx1;
		}

		return this;

	}
	
	public inline function rotate (angle:Float):Void {

		var cos = Math.cos (angle);
		var sin = Math.sin (angle);

		var a1 = a * cos - b * sin;
		b = a * sin + b * cos;
		a = a1;

		var c1 = c * cos - d * sin;
		d = c * sin + d * cos;
		c = c1;

		var tx1 = tx * cos - ty * sin;
		ty = tx * sin + ty * cos;
		tx = tx1;

	}

	public inline function scale (x:Float, y:Float):Void {
		a *= x;
		b *= y;

		c *= x;
		d *= y;

		tx *= x;
		ty *= y;
	}

	public inline function setRotation (angle:Float, scale:Float = 1):Void {

		a = Math.cos (angle) * scale;
		c = Math.sin (angle) * scale;
		b = -c;
		d = a;
	}

	public function toString ():String {
		return "(a=" + a + ", b=" + b + ", c=" + c + ", d=" + d + ", tx=" + tx + ", ty=" + ty + ")";
	}

	public inline function transformPoint (point:Point):Point {
		return new Point (point.x * a + point.y * c + tx, point.x * b + point.y * d + ty);
	}
	
	/**
	 * Same as transformPoint except allow memory conservation
	 * @param	?res reuseable parameter
	 */
	public inline function transformPoint2 (pointx:Float, pointy : Float, ?res:Point):Point {
		var p  = res == null?new Point():res;
		var px = pointx;
		var py = pointy;
		p.x = px * a + py * c + tx;
		p.y = px * b + py * d + ty;
		return p;
	}
	
	public inline function transformPointX (px:Float, py : Float):Float{
		return px * a + py * c + tx;
	}
	
	public inline function transformPointY (px:Float, py : Float):Float{
		return px * b + py * d + ty;
	}

	public inline function translate (x:Float, y:Float):Void {
		tx += x;
		ty += y;
	}
	
}