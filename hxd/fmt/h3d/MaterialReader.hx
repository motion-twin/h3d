package hxd.fmt.h3d;

class MaterialReader {
	var input : haxe.io.Input;
	static var MAGIC = "H3D.MTRL";
	static var VERSION = 1;
	
	public static var TEXTURE_LOADER = function(path) {
		trace("please set TEXTURE_LOADER to interpret texture loading");
		return null;
	}
	
	public function new(i) {
		input = i;
	}
	
	public static function make(mat:hxd.fmt.h3d.Data.Material) : h3d.mat.Material {
		var resMat : h3d.mat.Material;
		resMat = switch( mat.type ) {
			case MT_MeshMaterial: resMat = new h3d.mat.MeshMaterial(null, null);
		}
		resMat.ofData(mat,TEXTURE_LOADER);
		return resMat;
	}
	
}