package h2d.col;

abstract Rect(h3d.Vector) {
	public function new(x, y, z, w) { 
		this = new h3d.Vector( x, y, z, w);
	};
	
	public var left(get, set): Float; 		function get_left() 	return this.x; 	function set_left(v) return this.x=v;
	public var top(get, set): Float; 		function get_top() 		return this.y; 	function set_top(v) return this.y=v;
	public var right(get, set): Float; 		function get_right() 	return this.z; 	function set_right(v) return this.z=v;
	public var bottom(get, set): Float; 	function get_bottom() 	return this.w; 	function set_bottom(v) return this.w=v;
}