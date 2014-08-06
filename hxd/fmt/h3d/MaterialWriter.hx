package hxd.fmt.h3d;

import hxd.fmt.h3d.Data;

class MaterialWriter{
	var output : haxe.io.Output;
	static var MAGIC = "H3D.MTRL";
	static var VERSION = 1;
	
	public function new(o : haxe.io.Output) {
		output = o;
	}
	
	function make( m :h3d.mat.MeshMaterial ) : Material{
		var out = new Material();
		
		out.diffuseTexture 	= m.texture.name;
		
		out.blendMode 		= m.blendMode;
		out.culling 		= m.culling;
		
		out.alphaKill		= m.killAlpha ? m.killAlphaThreshold : null;
		out.alphaTexture	= m.alphaMap.name;
		
		return out;
	}
	
	public function write( m : h3d.mat.Material ) {
		var data = make(m);
		
		output.bigEndian = false;
		output.writeString( MAGIC );
		output.writeInt32(VERSION);
		
		output.writeString( data.diffuseTexture );
		output.writeInt( Type.enumIndex(data.blendMode ) ) ;
		output.writeInt( Type.enumIndex(data.culling) );
		
		output.writeFloat( out.alphaKill==null?-1.0:out.alphaKill);
		output.writeString( data.alphaTexture );
	}
	
}