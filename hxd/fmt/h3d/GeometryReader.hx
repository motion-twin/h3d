package hxd.fmt.h3d;

import h3d.prim.FBXModel;
import h3d.prim.MeshPrimitive;
import h3d.prim.Primitive;
import hxd.fmt.h3d.Data;

class GeometryReader
{

	public function new() 
	{
		
	}

	static function make( geom :  hxd.fmt.h3d.Data.Geometry ) : h3d.prim.Primitive {
		
		var prim : h3d.prim.Primitive;
		
		prim = switch(geom.type) {
			case GT_FbxModel:	
				prim = new FBXModel(null, geom.isDynamic);
				
			case Gt_MeshPrim:	prim = new MeshPrimitive();
		}
		
		prim.ofData(geom);
		
		return prim;
	}
}