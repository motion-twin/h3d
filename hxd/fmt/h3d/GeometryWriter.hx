package hxd.fmt.h3d;

import hxd.fmt.h3d.Data;

class GeometryWriter {
	var output : haxe.io.Output;
	static var MAGIC = "H3D.GEOM";
	static var VERSION = 1;
	
	public function new(o : haxe.io.Output) {
		output = o;
	}
	
	function make( m : h3d.prim.Primitive ) : Geometry {
		var out = new Geometry();
		
		out.colors = m.buffer.
		return out;
	}
}
