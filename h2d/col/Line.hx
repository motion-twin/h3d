package h2d.col;

class Line {

	public var p1 : Point;
	public var p2 : Point;

	public inline function new(p1,p2) {
		this.p1 = p1;
		this.p2 = p2;
	}
	
	public inline function side( p : Point ) {
		return (p2.x - p1.x) * (p.y - p1.y) - (p2.y - p1.y) * (p.x - p1.x);
	}
	
	public inline function project( p : Point ) {
		var dx = p2.x - p1.x;
		var dy = p2.y - p1.y;
		var k = ((p.x - p1.x) * dx + (p.y - p1.y) * dy) / (dx * dx + dy * dy);
		return new Point(dx * k + p1.x, dy * k + p1.y);
	}
	
	public 
	#if !debug inline #end
	function intersect( l : Line ) {
		var d = (p1.x - p2.x) * (l.p1.y - l.p2.y) - (p1.y - p2.y) * (l.p1.x - l.p2.x);
		if( hxd.Math.abs(d) < hxd.Math.EPSILON )
			return null;
		var a = p1.x*p2.y - p1.y * p2.x;
		var b = l.p1.x*l.p2.y - l.p1.y*l.p2.x;
		return new Point( (a * (l.p1.x - l.p2.x) - (p1.x - p2.x) * b) / d, (a * (l.p1.y - l.p2.y) - (p1.y - p2.y) * b) / d );
	}

	public inline function intersectWith( l : Line, pt : Point ) {
		var d = (p1.x - p2.x) * (l.p1.y - l.p2.y) - (p1.y - p2.y) * (l.p1.x - l.p2.x);
		if( hxd.Math.abs(d) < hxd.Math.EPSILON )
			return false;
		var a = p1.x*p2.y - p1.y * p2.x;
		var b = l.p1.x*l.p2.y - l.p1.y*l.p2.x;
		pt.x = (a * (l.p1.x - l.p2.x) - (p1.x - p2.x) * b) / d;
		pt.y = (a * (l.p1.y - l.p2.y) - (p1.y - p2.y) * b) / d;
		return true;
	}

	public inline function lengthSq() 
		return hxd.Math.sqr( p2.x - p1.x ) + hxd.Math.sqr(p2.y - p1.y);
		
	public inline function length() 
		return Math.sqrt( lengthSq() );
	
	public inline function distanceSq( p : Point ) {
		var dx = p2.x - p1.x;
		var dy = p2.y - p1.y;
		var k = ((p.x - p1.x) * dx + (p.y - p1.y) * dy) / (dx * dx + dy * dy);
		var mx = dx * k + p1.x - p.x;
		var my = dy * k + p1.y - p.y;
		return mx * mx + my * my;
	}
	
	public inline function distance( p : Point ) {
		return hxd.Math.sqrt(distanceSq(p));
	}
	
	public function toString() {
		return '{ p1:$p1, p2:$p2}';
	}
	
	public function segmentIntersect( l1:h2d.col.Line) {
		var p = intersect(l1);
		
		var l0LenSq = lengthSq();
		var l1LenSq = l1.lengthSq();
		
		if ( p1.distanceSq(p) > l0LenSq ) 
			return null;
		if ( p2.distanceSq(p) > l0LenSq ) 
			return null;
		
		if ( l1.p1.distanceSq(p) > l1LenSq ) 
			return null;
		if ( l1.p2.distanceSq(p) > l1LenSq ) 
			return null;
			
		return p;
	}
	
}