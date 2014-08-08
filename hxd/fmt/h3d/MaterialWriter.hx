package hxd.fmt.h3d;

import hxd.fmt.h3d.Data;
using Type;
using hxd.fmt.h3d.Tools;

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
		output.bigEndian = false;
		
		output.writeString(MAGIC);
		output.writeInt32(VERSION);
		
		output.writeString2( data.diffuseTexture );
		
		output.writeInt32( data.blendSrc.enumIndex() );
		output.writeInt32( data.blendDest.enumIndex() );
		output.writeInt32( data.blendMode.enumIndex() );
		output.writeInt32( data.culling.enumIndex());
		
		output.writeFloat( data.alphaKill==null?-1.0:data.alphaKill);
		output.condWriteString2( data.alphaTexture );
		
		output.writeInt32( data.renderPass );
		output.writeInt32( data.depthTest.enumIndex() );
		output.writeBool( data.depthWrite );
		output.writeInt32( data.colorMask );
		
		output.condWriteVector4( data.colorMultiply );
		
		output.writeInt32(0xE0F);
	}
	
}