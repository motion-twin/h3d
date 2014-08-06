package hxd.fmt.h3d;

import hxd.fmt.h3d.Data;
import haxe.crypto.Crc32;

class MeshReader{
	var input : haxe.io.Input;
	static var MAGIC = "H3D.MESH";
	static var VERSION = 1;
	
	public function new(o : haxe.io.Input) {
		input = o;
	}
	
	function make( anm : h3d.scene.Mesh) {
		return anm.toData();
	}
	
	public function read() : h3d.scene.Mesh {
		//determin whether its a mesh or a multimaterial
		return null;
	}
	
}