package hxd.fmt.h3d;

import h3d.prim.FBXModel;
import hxd.fmt.h3d.Data;

class GeometryWriter {
	var output : haxe.io.Output;
	static var MAGIC = "H3D.GEOM";
	static var VERSION = 1;
	
	public function new(o : haxe.io.Output) {
		output = o;
	}
	
	public static function fromFbx( m : h3d.prim.FBXModel ) : Geometry {
		var out = new Geometry();
		var engine = h3d.Engine.getCurrent();
		m.alloc(engine);
		
		out.isMultiMaterial = m.multiMaterial;
		out.isSkinned 	= m.skin != null;
		out.isDynamic 	= m.isDynamic;
		
		out.gtX = 		m.geomCache.gt.x;
		out.gtY = 		m.geomCache.gt.y;
		out.gtZ = 		m.geomCache.gt.z;
		
		out.index 		= m.geomCache.idx.toBytes();
		out.positions 	= m.geomCache.pbuf.toBytes();
		out.normals 	= m.geomCache.nbuf.toBytes();
		out.uvs 		= m.geomCache.tbuf.toBytes();
		
		if (m.geomCache.cbuf != null)
			out.colors 	= m.geomCache.cbuf.toBytes();
			
		if( m.geomCache.sbuf != null)
			out.skinning 	= m.geomCache.sbuf.getBytes();
		
		if(m.geomCache.sidx!=null ||  m.geomCache.midx !=null)
		out.groupIndexes = m.geomCache.midx != null 
		? m.geomCache.midx.map(Tools.indexbufferToBytes)
		: m.geomCache.sidx.map(Tools.indexbufferToBytes);
		else 
		out.groupIndexes = [];
		
		out.extra = [];
		
		for ( i in 0...m.blendShapes.length) {
			var sh = new SecondaryGeometry();
			var shape = m.blendShapes[i];
			
			sh.index = Tools.intArrayToBytes(m.geomCache.secShapesIndex[i]);
			sh.positions = Tools.floatArrayToBytes(m.geomCache.secShapesVertex[i]);
			
			if( m.geomCache.secShapesNormal!=null)
				sh.normals =Tools.floatArrayToBytes(m.geomCache.secShapesNormal[i]);
			
			out.extra.push(sh);
		}
		
		
		return out;
	}
}
