package h3d.prim;

class UV {
	public var u : hxd.Float32;
	public var v : hxd.Float32;
	
	public function new(u,v) {
		this.u = u;
		this.v = v;
	}
	
	public function clone() {
		return new UV(u, v);
	}
	
	function toString() {
		return "{" + hxd.Math.fmt(u) + "," + hxd.Math.fmt(v) + "}";
	}
	
	public inline function set(x = 0., y = 0.) {
		this.u = x;
		this.v = y;
	}

}