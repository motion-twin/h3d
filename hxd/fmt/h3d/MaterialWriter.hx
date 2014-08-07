package hxd.fmt.h3d;

import hxd.fmt.h3d.Data;

class MaterialWriter{
	var output : haxe.io.Output;
	static var MAGIC = "H3D.MTRL";
	static var VERSION = 1;
	
	public function new(o : haxe.io.Output) {
		output = o;
	}
	
	public static function make( m :h3d.mat.MeshMaterial ) : Material{
		var out = new Material();
		
		out.diffuseTexture 	= m.texture.name;
		
		out.blendSrc		= @:privateAccess m.blendSrc;
		out.blendDest		= @:privateAccess m.blendDst;
		
		out.blendMode 		= m.blendMode;
		out.culling 		= m.culling;
		
		out.alphaKill		= m.killAlpha ? m.killAlphaThreshold : null;
		out.alphaTexture	= m.alphaMap == null ? null : m.alphaMap.name;
		
		out.renderPass 		= m.renderPass;
		out.depthTest		= m.depthTest;
		out.depthWrite		= m.depthWrite;
		out.colorMask		= m.colorMask;
		
		if(m.colorMul!=null)
			out.colorMultiply 	= m.colorMul.clone();
		
		return out;
	}
	
	public function write( data : hxd.fmt.h3d.Data.Material ) {
		var t = Tools;
		output.bigEndian = false;
		output.writeString( MAGIC );
		output.writeInt32(VERSION);
		
		output.writeString( data.diffuseTexture );
		output.writeInt32( Type.enumIndex(data.blendMode ) ) ;
		output.writeInt32( Type.enumIndex(data.culling) );
		
		output.writeFloat( data.alphaKill==null?-1.0:data.alphaKill);
		output.writeString( data.alphaTexture );
		
		if(data.colorMultiply!=null)
			t.writeVec4( output,data.colorMultiply );
	}
	
}