package hxd.fmt.h3d;

import hxd.fmt.h3d.Data;

using Type;
using hxd.fmt.h3d.Tools;

class SkinReader {

	var input : haxe.io.Input;
	static var MAGIC = "H3D.SKIN";
	static var VERSION = 1;
	
	public inline function new(i) {
		input = i;
	}
	
	public static function make( sk : hxd.fmt.h3d.Data.Skin ) : h3d.anim.Skin  {
		var resSk = new h3d.anim.Skin(0,0);
		resSk.ofData( sk );
		return resSk;
	}
	
	function readJoint() : hxd.fmt.h3d.Data.Joint {
		var data 			= new hxd.fmt.h3d.Data.Joint();
		data.id				= input.readInt32();
		data.index 			= input.readInt32( );
		data.name			= input.condReadString2();
		data.bindIndex		= input.readInt32();
		data.splitIndex		= input.readInt32();
		data.defaultMatrix	= input.condReadBytes2();
		data.transPos		= input.condReadBytes2();
		data.parent			= input.readInt32();
		data.subs			= input.condReadBytes2();
		return data;
	}
	
	public function parse() : hxd.fmt.h3d.Data.Skin {
		var data : hxd.fmt.h3d.Data.Skin = new hxd.fmt.h3d.Data.Skin();
		input.bigEndian = false;
		var s = input.readString( MAGIC.length );	if ( s != MAGIC ) throw "invalid " + MAGIC + " magic";
		var version = input.readInt32(); 			if ( version != VERSION ) throw "invalid .h3d.anim.version "+VERSION;
		
		data.vertexCount = input.readInt32();
		data.bonesPerVertex = input.readInt32();
		
		data.vertexJoints = input.readBytes2();
		data.vertexWeights = input.readBytes2(); 
		
		var jl = [];
		var jlLen = input.readInt32();
		for ( i in 0...jlLen ) 
			jl.push( readJoint() );
		data.jointLibrary = jl;
		
		{
			var arrLen = input.readInt32();
			var arr = [];
			for ( i in 0...arrLen ) arr.push( input.readInt32() );
			data.all = arr;
		}
		
		{
			var arrLen = input.readInt32();
			var arr = [];
			for ( i in 0...arrLen ) arr.push( input.readInt32() );
			data.roots = arr;
		}
		
		{
			var arrLen = input.readInt32();
			var arr = [];
			for ( i in 0...arrLen ) arr.push( input.readInt32() );
			data.bound = arr;
		}
		
		if ( input.readBool() ) {
			var a = [];
			var al = input.readInt32();
			for ( i in 0...al ) {
				var b = [];
				var blen = input.readInt32();
				for ( j in 0...blen )
					b.push( input.readInt32() ); 
				a.push(b);
			}
		}
		
		data.triangleGroups = input.condReadBytes2();
		
		if ( input.readInt32() != 0xE0F ) throw "assert : file was not correctly parsed!";
		
		return data;
	}
	
}