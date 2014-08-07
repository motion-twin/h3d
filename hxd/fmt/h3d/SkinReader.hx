package hxd.fmt.h3d;

import hxd.fmt.h3d.Data;

class SkinReader {

	var input : haxe.io.Input;
	static var MAGIC = "H3D.ANIM";
	static var VERSION = 1;
	
	public function new(i) {
		input = i;
	}
	
	public static function make( sk : hxd.fmt.h3d.Data.Skin ) : h3d.anim.Skin  {
		var resSk = new h3d.anim.Skin(0,0);
		resSk.ofData( sk );
		return resSk;
	}
	
}