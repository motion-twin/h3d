package hxd.fmt.h3d;

import h3d.prim.FBXModel;
import hxd.fmt.h3d.Data;

using Type;
using hxd.fmt.h3d.Tools;

class GeometryWriter {
	var output : haxe.io.Output;
	static var MAGIC = "H3D.GEOM";
	static var VERSION = 1;
	
	public inline function new(o : haxe.io.Output) {
		output = o;
	}
	
	public static function fromFbx( m : h3d.prim.FBXModel ) : Geometry {
		var out = new Geometry();
		var engine = h3d.Engine.getCurrent();
		m.alloc(engine);
		
		out.type = GT_FbxModel;
		
		out.isMultiMaterial = m.multiMaterial;
		out.isSkinned 	= m.skin != null;
		out.isDynamic 	= m.isDynamic;
		
		out.gt = new h3d.Vector(m.geomCache.gt.x,m.geomCache.gt.y,m.geomCache.gt.z);
		
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
			
			sh.name = shape.root.getName();
			out.extra.push(sh);
		}
		
		return out;
	}
	
	public function writeData( data : hxd.fmt.h3d.Data.Geometry ){
		output.bigEndian = false;
		
		output.writeString(MAGIC);
		output.writeInt32(VERSION);
		
		output.writeInt32(data.type.enumIndex());
		
		output.writeInt32(data.skinIdxBytes);
		output.writeInt32(data.weightIdxBytes);
		
		output.writeVector4(data.gt);
		
		output.writeBool	(data.isMultiMaterial);
		output.writeBool	(data.isSkinned);
		output.writeBool	(data.isDynamic);
		
		output.writeBytes2	(data.index);
		output.writeBytes2	(data.positions);
		output.writeBytes2	(data.normals);
		output.writeBytes2	(data.uvs);
		
		output.condWriteBytes2(data.colors);
		output.condWriteBytes2(data.skinning);
		
		output.writeBool(data.groupIndexes != null);
		if ( data.groupIndexes != null) {
			output.writeInt32( data.groupIndexes.length );
			for ( a in data.groupIndexes)
				output.writeBytes2( a );
		}
		
		output.writeInt32( data.extra.length );
		for ( a in data.extra) {
			output.writeBytes2( a.index );
			output.writeBytes2( a.positions );
			output.writeBytes2( a.normals );
		}
		
		output.writeInt32(0xE0F);
	}
}
