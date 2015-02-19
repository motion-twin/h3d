package hxd.tools;
import hxd.FloatStack;

class Catmull1 {
	public var points : Array<Float>;
	
	public inline function new( points : Array<Float>) {
		this.points = points;
	}
	
	/*
	 * Sample linearly and create a point buffer
	*/
	public function plot( ?res, tstep=0.1, start=0,end=-1 ) : hxd.FloatStack{
		if (end == -1) end = points.length;
		res = res == null?new  hxd.FloatStack():res;
		res.reset();
		var steps = Math.ceil(1.0 / tstep);
		var cstep = 0.0;
		for ( i in start...end) {
			var p0 = get(i-1);
			var p1 = get(i);
			var p2 = get(i+1);
			var p3 = get(i+2);
			cstep = 0.0;
			for (s in 0...steps ) {
				res.push( catmull(p0, p1, p2, p3, cstep) );
				cstep += tstep;
			}
		}
		return res;
	}
	
	public inline function plotWhole( t : Float ) {
		var rn : Float = points.length * t;
		var i = Std.int( points.length * t );
		var n : Float = rn - i;
		var p0 = get(i-1);
		var p1 = get(i);
		var p2 = get(i+1);
		var p3 = get(i+2);
		return catmull( p0, p1, p2, p3, n );
	}
	
	inline function get(idx) : Float {
		return points[ hxd.Math.iclamp( idx,0, points.length-1 ) ];
	}
	
	public static inline function catmull(p0 : hxd.Float32 , p1 : hxd.Float32 , p2 : hxd.Float32 , p3 : hxd.Float32 , t : hxd.Float32) : hxd.Float32 {
		var q 	: hxd.Float32 = 2.0 * p1;
		var t2 	: hxd.Float32 = t * t;
		
		q += (-p0 		+ p2) 					* t;
		q += (2.0*p0 	-5.0*p1 +4*p2	-p3) 	* t2;
		q += (-p0		+3*p1	-3*p2	+p3) 	* t2 * t;
		
		return 0.5 * q;
	}
}





