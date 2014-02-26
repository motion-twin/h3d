package h2d.col;

class Bounds {
	
	public var xMin : Float;
	public var yMin : Float;

	public var xMax : Float;
	public var yMax : Float;
	
	public var width(get,null) : Float;
	public var height(get,null) : Float;
	
	public inline function new() {
		empty();
	}
	
	function get_width() 	return xMax - xMin;
	function get_height() 	return yMax - yMin;
	
	public inline function collide( b : Bounds ) {
		return !(xMin > b.xMax || yMin > b.yMax || xMax < b.xMin || yMax < b.yMin);
	}
	
	public inline function include( p : Point ) {
		return p.x >= xMin && p.x < xMax && p.y >= yMin && p.y < yMax;
	}
	
	public inline function add( b : Bounds ) {
		if( b.xMin < xMin ) xMin = b.xMin;
		if( b.xMax > xMax ) xMax = b.xMax;
		if( b.yMin < yMin ) yMin = b.yMin;
		if( b.yMax > yMax ) yMax = b.yMax;
	}
	
	/**
	 * @param	x
	 * @param	y
	 * @param	w
	 * @param	h
	 * 
	 * set the bounding box with 4 floats
	 */
	public inline function add4( x:Float, y:Float, w:Float, h:Float ) {
		var ixMin = x;
		var iyMin = y;
		
		var ixMax = x+w;
		var iyMax = y+h;
		
		if( ixMin < xMin ) xMin = ixMin;
		if( ixMax > xMax ) xMax = ixMax;
		if( iyMin < yMin ) yMin = iyMin;
		if( iyMax > yMax ) yMax = iyMax;
	}

	public inline function addPoint( p : Point ) {
		if( p.x < xMin ) xMin = p.x;
		if( p.x > xMax ) xMax = p.x;
		if( p.y < yMin ) yMin = p.y;
		if( p.y > yMax ) yMax = p.y;
	}
	
	public inline function addPoint2( px:Float,py:Float ) {
		if( px < xMin ) xMin = px;
		if( px > xMax ) xMax = px;
		if( py < yMin ) yMin = py;
		if( py > yMax ) yMax = py;
	}
	
	public inline function setMin( p : Point ) {
		xMin = p.x;
		yMin = p.y;
	}

	public inline function setMax( p : Point ) {
		xMax = p.x;
		yMax = p.y;
	}
	
	public inline function load( b : Bounds ) {
		xMin = b.xMin;
		yMin = b.yMin;
		xMax = b.xMax;
		yMax = b.yMax;
	}
	
	public inline function scaleCenter( v : Float ) {
		var dx = (xMax - xMin) * 0.5 * v;
		var dy = (yMax - yMin) * 0.5 * v;
		var mx = (xMax + xMin) * 0.5;
		var my = (yMax + yMin) * 0.5;
		xMin = mx - dx * v;
		yMin = my - dy * v;
		xMax = mx + dx * v;
		yMax = my + dy * v;
	}
	
	public inline function offset( dx : Float, dy : Float ) {
		xMin += dx;
		xMax += dx;
		yMin += dy;
		yMax += dy;
	}
	
	public inline function getMin() {
		return new Point(xMin, yMin);
	}
	
	public inline function getCenter() {
		return new Point((xMin + xMax) * 0.5, (yMin + yMax) * 0.5);
	}

	public inline function getSize() {
		return new Point(xMax - xMin, yMax - yMin);
	}
	
	public inline function getMax() {
		return new Point(xMax, yMax);
	}
	
	public inline function empty() {
		xMin = 1e20;
		yMin = 1e20;
		xMax = -1e20;
		yMax = -1e20;
	}

	public inline function all() {
		xMin = -1e20;
		yMin = -1e20;
		xMax = 1e20;
		yMax = 1e20;
	}
	
	public inline function clone() {
		var b = new Bounds();
		b.xMin = xMin;
		b.yMin = yMin;
		b.xMax = xMax;
		b.yMax = yMax;
		return b;
	}
	
	public inline function translate(x, y) {
		xMin += x;
		xMax += x;
		
		yMin += y;
		yMax += y;
	}
	
	/**
	 * in place transforms
	 */
	public inline function transform( m : h2d.Matrix ) : Bounds {
		
		var p0 = new Point(xMin,yMin);
		var p1 = new Point(xMin,yMax);
		var p2 = new Point(xMax,yMin);
		var p3 = new Point(xMax,yMax);
		
		m.transformPoint2( p0.x, p0.y, p0 );
		m.transformPoint2( p1.x, p1.y, p1 );
		m.transformPoint2( p2.x, p2.y, p2 );
		m.transformPoint2( p3.x, p3.y, p3 );
		
		setMin(p0); setMax(p0);
		
		addPoint(p1);
		addPoint(p2);
		addPoint(p3);
		
		p0 = null; p1 = null; p2 = null; p3 = null;
		return this;
	}
	
	public function toString() {
		return "{" + getMin() + "," + getMax() + "}";
	}

	public static inline function fromValues( x0 : Float, y0 : Float, width : Float, height : Float ) {
		var b = new Bounds();
		b.xMin = x0;
		b.yMin = y0;
		b.xMax = x0 + width;
		b.yMax = y0 + height;
		return b;
	}
	
	public static inline function fromPoints( min : Point, max : Point ) {
		var b = new Bounds();
		b.setMin(min);
		b.setMax(max);
		return b;
	}
	
}