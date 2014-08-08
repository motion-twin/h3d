package hxd.fmt.h3d;

import h3d.prim.FBXModel;
import h3d.prim.MeshPrimitive;
import h3d.prim.Primitive;
import hxd.fmt.h3d.Data;

using Type;
using hxd.fmt.h3d.Tools;

class GeometryReader{
	var input : haxe.io.Input;
	static var MAGIC = "H3D.GEOM";
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
	
	public function parse() : hxd.fmt.h3d.Data.Geometry {
		
		var geom : hxd.fmt.h3d.Data.Geometry = new hxd.fmt.h3d.Data.Geometry();
		
		input.bigEndian = false;
		var s = input.readString( MAGIC.length );	if ( s != MAGIC ) throw "invalid " + MAGIC + " magic";
		var version = input.readInt32(); 			if ( version != VERSION ) throw "invalid .h3d.anim.version "+VERSION;
		
		geom.type = Type.createEnumIndex( GeometryType, input.readInt32() );
		
		geom.skinIdxBytes = input.readInt32();
		geom.weightIdxBytes = input.readInt32();
		
		geom.gt = input.readVector4();
		
		geom.isMultiMaterial = input.readBool();
		geom.isSkinned = input.readBool();
		geom.isDynamic = input.readBool();
		
		geom.index = input.readBytes2();
		geom.positions = input.readBytes2();
		geom.normals = input.readBytes2();
		geom.uvs = input.readBytes2();
		
		geom.colors = input.condReadBytes2();
		geom.skinning = input.condReadBytes2();
		
		if ( input.readBool() ) {
			var a = [];
			var len = input.readInt32();
			for ( i in 0...len ) 
				a.push( input.readBytes2());
			geom.groupIndexes = a;
		}
		
		var extras = [];
		var len = input.readInt32();
		for ( i in 0...len ) {
			var extra = new SecondaryGeometry();
			extra.index = input.readBytes2();
			extra.positions = input.readBytes2();
			extra.normals = input.readBytes2();
			extras.push( extra );
		}
		geom.extra = extras;
		
		if ( input.readInt32() != 0xE0F ) throw "assert : file was not correctly parsed!";
		
		return geom;
	}
	
	
}