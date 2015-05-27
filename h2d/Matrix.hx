package h2d;

import hxd.Math;
import h2d.col.Point;

class Matrix {
	
	public var a : hxd.Float32;
	public var b : hxd.Float32;
	public var c : hxd.Float32;
	public var d : hxd.Float32;
	
	public var tx : hxd.Float32;
	public var ty : hxd.Float32;
	
	/**
	 * Loaded with identity by default
	 */
	public inline function new(a = 1., b = 0., c = 0., d = 1., tx = 0., ty = 0.) {
		setTo(a, b, c, d, tx, ty);
	}
	
	public inline function zero() {
		a = b = c = d = tx = ty = 0.;
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
	
	public inline function rotate(angle:hxd.Float32):Void {
		var c = Math.cos(angle);
		var s=  Math.sin(angle);
		concat32(	c, s, 
					-s, c,
					0.0,0.0 );
	}

	public inline function scale (x:hxd.Float32, y:hxd.Float32):Void {
		a *= x;
		b *= y;

		c *= x;
		d *= y;

		tx *= x;
		ty *= y;
	}
	
	inline
	public 
	function skew(x, y) {
		concat32(	1.0, Math.tan(x), 
					Math.tan(y), 1.0,
					0.0,0.0 			);
	}
	
	inline 
	public 
	function makeSkew(x:hxd.Float32, y:hxd.Float32):Void {
		identity();
		b = Math.tan( x );
		c = Math.tan( y );
	}

	public inline function setRotation (angle:hxd.Float32, scale:hxd.Float32 = 1):Void {
		a = Math.cos (angle) * scale;
		c = Math.sin (angle) * scale;
		b = -c;
		d = a;
		tx = ty = 0;
	}
	
	public inline function setTranslation (x:hxd.Float32, y:hxd.Float32):Void {
		identity();
		translate(x, y);
	}
	
	public inline function setScale(x:hxd.Float32, y:hxd.Float32):Void {
		identity();
		scale(x, y);
	}

	public function toString ():String {
		return "(a=" + a + ", b=" + b + ", c=" + c + ", d=" + d + ", tx=" + tx + ", ty=" + ty + ")";
	}

	public inline function transformPoint (point:Point):Point {
		return new Point (point.x * a + point.y * c + tx, point.x * b + point.y * d + ty);
	}
	
	public inline function concat(m:Matrix):Void {
		var a1 : hxd.Float32= a * m.a + b * m.c;
		b = a * m.b + b * m.d;
		a = a1;

		var c1 : hxd.Float32 = c * m.a + d * m.c;
		d = c * m.b + d * m.d;

		c = c1;

		var tx1 : hxd.Float32 = tx * m.a + ty * m.c + m.tx;
		ty = tx * m.b + ty * m.d + m.ty;
		tx = tx1;
	}
	
	/**
	 * Does not apply tx/ty
	 */
	public inline function concat22(m:Matrix):Void {
		var a1 :hxd.Float32 = a * m.a + b * m.c;
		b = a * m.b + b * m.d;
		a = a1;

		var c1 = c * m.a + d * m.c;
		d = c * m.b + d * m.d;

		c = c1;
	}
	
	public inline function concat32(ma:hxd.Float32,mb:hxd.Float32,mc:hxd.Float32,md:hxd.Float32,mtx:hxd.Float32,mty:hxd.Float32):Void {
		var a1 = a * ma + b * mc;
		b = a * mb + b * md;
		a = a1;

		var c1 = c * ma + d * mc;
		d = c * mb + d * md;

		c = c1;

		var tx1 = tx * ma + ty * mc + mtx;
		ty = tx * mb + ty * md + mty;
		tx = tx1;
	}
	
	/**
	 * Same as transformPoint except allow memory conservation
	 * @param	?res reuseable parameter
	 */
	public inline function transformPoint2 (pointx:hxd.Float32, pointy:hxd.Float32, ?res:Point):Point {
		var p  = res == null?new Point():res;
		var px = pointx;
		var py = pointy;
		p.x = px * a + py * c + tx;
		p.y = px * b + py * d + ty;
		return p;
	}
	
	public inline function transformX (px:hxd.Float32, py : hxd.Float32):hxd.Float32{
		return px * a + py * c + tx;
	}
	
	public inline function transformY (px:hxd.Float32, py : hxd.Float32):hxd.Float32{
		return px * b + py * d + ty;
	}

	public inline function translate (x:hxd.Float32, y:hxd.Float32):Void {
		tx += x;
		ty += y;
	}
	
	
	
}