package hxd.fmt.h3d;

import h3d.prim.FBXModel;
import h3d.prim.MeshPrimitive;
import h3d.prim.Primitive;
import hxd.fmt.h3d.Data;

class GeometryReader{
	var input : haxe.io.Input;
	static var MAGIC = "H3D.ANIM";
	static var VERSION = 1;

	public function new(i) {
		input = i;
	}

	public static function make( geom :  hxd.fmt.h3d.Data.Geometry ) : h3d.prim.Primitive {
		
		var prim : h3d.prim.Primitive;
		
		prim = switch(geom.type) {
			case GT_FbxModel:	
				prim = new FBXModel(null, geom.isDynamic);
		}
		
		prim.ofData(geom);
		
		return prim;
	}
}