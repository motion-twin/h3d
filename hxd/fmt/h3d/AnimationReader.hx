package hxd.fmt.h3d;

import hxd.fmt.h3d.Data;
import h3d.anim.Animation;
import haxe.crypto.Crc32;

class AnimationReader{
	var input : haxe.io.Input;
	static var MAGIC = "H3D.ANIM";
	static var VERSION = 1;
	
	public function new(o : haxe.io.Input) {
		input = o;
	}
	
	function make( anm : h3d.anim.Animation) {
		return anm.toData();
	}
	
	public function read() : h3d.anim.Animation {
		var anm  : format.h3d.Data.Animation = new format.h3d.Data.Animation();
		
		input.bigEndian = false;
		var s = input.readString( MAGIC.length );
		if ( s != MAGIC ) throw "invalid .h3d.anim magic";
		
		var version = input.readInt32();
		if ( version != VERSION ) throw "invalid .h3d.anim.version";
		
		var nameLen = input.readInt32(); 
		anm.name = input.readString( nameLen );
		
		anm.type = Type.createEnumIndex( AnimationType, input.readInt32() );
		anm.frameStart = input.readInt32();
		anm.frameEnd = input.readInt32();
		anm.frameCount = input.readInt32();
		
		anm.speed = input.readFloat();
		anm.sampling = input.readFloat();
		
		var nb = input.readInt32();
		var o = anm.objects = [];
		
		for ( i in 0...nb ) {
			var name = input.readString(input.readInt32());
			var ao = new format.h3d.AnimationObject();
			
			ao.targetObject = name;
			ao.format = Type.createEnumIndex( AnimationFormat,input.readInt32() );
			
			var dataLen = input.readInt32();
			ao.data = input.read(dataLen);
			o.push( ao );
		}
		
		return h3d.anim.Animation.make(  anm );
	}
	
}