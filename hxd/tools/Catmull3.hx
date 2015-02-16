package hxd.tools;
import hxd.Float32;
import hxd.FloatStack;

class Catmull3 {
	public var points : Array<h3d.Vector>;
	
	public inline function new( points ) {
		this.points = points;
	}
	
	/*
	 * Sample linearly and create a point buffer
	*/
	public function plot( ?res,tstep=0.1, start=0,end=-1 ) : hxd.FloatStack {
		if (end == -1)  end  = points.length;
		res = res == null ? new FloatStack() : res;
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
				res.push(catmull(p0.x, p1.x, p2.x, p3.x, cstep)); 
				res.push(catmull(p0.y, p1.y, p2.y, p3.y, cstep)); 
				res.push(catmull(p0.z, p1.z, p2.z, p3.z, cstep)); 
				
				cstep += tstep;
			}
		}
		return res;
	}
	
	public inline function get(idx) : h3d.Vector {
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
	
	/**
	 * 0...numPoint
	 */
	public 
	#if debug inline #end
	function c3( i : Float , ?out : h3d.Vector) {
		if ( out == null ) out = new h3d.Vector();
		out.w = 1.0;
		
		var p0 = get(Std.int(i-1));
		var p1 = get(Std.int(i));
		var p2 = get(Std.int(i+1));
		var p3 = get(Std.int(i+2));
		
		var t = i - Std.int(i);
		out.x = catmull( p0.x, p1.x, p2.x, p3.x, t );
		out.y = catmull( p0.y, p1.y, p2.y, p3.y, t );
		out.z = catmull( p0.z, p1.z, p2.z, p3.z, t );
		return out;
	}
	
	public function plotWhole( t : Float , ?out : h3d.Vector ) {
		return c3( t*points.length,out );
	}
}





