package hxd.fmt.h3d;

import h3d.mat.Data;

using Type;
using hxd.fmt.h3d.Tools;

class MaterialReader {
	var input : haxe.io.Input;
	static var MAGIC = "H3D.MTRL";
	static var VERSION = 1;
	
	public static var DEFAULT_TEXTURE_LOADER : String -> h3d.mat.Texture = function(path) {
		hxd.System.trace1("please set TEXTURE_LOADER to interpret texture loading");
		return null;
	}
	
	public inline function new(i) {
		input = i;
	}
	
	public static function make(mat:hxd.fmt.h3d.Data.Material) : h3d.mat.Material {
		var resMat : h3d.mat.Material;
		resMat = switch( mat.type ) {
			case MT_MeshMaterial: resMat = new h3d.mat.MeshMaterial(null, null);
		}
		
		resMat.ofData(mat,DEFAULT_TEXTURE_LOADER);
		return resMat;
	}
	
	public function parse() : hxd.fmt.h3d.Data.Material {
		var m = new hxd.fmt.h3d.Data.Material();
		input.bigEndian = false;
		
		var s = input.readString( MAGIC.length );	if ( s != MAGIC ) throw "invalid " + MAGIC + " magic";
		var version = input.readInt32(); 			if ( version != VERSION ) throw "invalid  .h3d version "+VERSION;
	
		m.diffuseTexture = input.readString2();
		
		m.blendSrc = Type.createEnumIndex( Blend, input.readInt32());
		m.blendDest = Type.createEnumIndex( Blend, input.readInt32());
		var bl = input.readInt32();
		m.blendMode = bl==-1?null:Type.createEnumIndex( h2d.BlendMode, input.readInt32());
		m.culling = Type.createEnumIndex( Face, input.readInt32());
		
		var ak = input.readFloat();
		if ( ak >= 0 )	m.alphaKill = ak;
		else 			m.alphaKill = null;
		
		m.alphaTexture = input.condReadString2();
		m.renderPass = input.readInt32();
		m.depthTest = Type.createEnumIndex( Compare, input.readInt32());
		m.depthWrite = input.readBool();
		m.colorMask = input.readInt32();
		m.colorMultiply = input.condReadVector4();
		
		if ( input.readInt32() != 0xE0F ) throw "assert : file was not correctly parsed!";
		
		return m;
	}
	
}