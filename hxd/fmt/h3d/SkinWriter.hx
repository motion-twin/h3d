package hxd.fmt.h3d;

import h3d.anim.Skin.Joint;
import hxd.ByteConversions;
import hxd.BytesBuffer;
import hxd.FloatBuffer;
import hxd.FloatStack;
import hxd.fmt.h3d.Data;

using Type;
using hxd.fmt.h3d.Tools;

class SkinWriter {
	var output : haxe.io.Output;
	static var MAGIC = "H3D.SKIN";
	static var VERSION = 1;
	
	public function new(o : haxe.io.Output) {
		output = o;
	}
	
	public static function make( sk : h3d.anim.Skin ) : Skin {
		var out = new Skin();
	
		out.vertexCount  = sk.vertexCount;
		out.bonesPerVertex  = sk.bonesPerVertex;
		
		out.vertexJoints = Tools.intVectorToBytes( sk.vertexJoints );
		out.vertexWeights = Tools.floatVectorToFloatBytes( sk.vertexWeights );
		
		var jointLibrary : Map<String,Joint>= new Map();
		var jointUid = 0;
		
		function makeJoint(j) {
			if ( j == null) return -1;
			
			if ( jointLibrary.exists(j.name))
				return jointLibrary.get( j.name).id;
			else {
				trace("doing joint " + j.name);
				var id = jointUid++;
				var nj = new Joint();
				
				jointLibrary.set(j.name, nj);
				nj.id = id;
				nj.name = j.name;
				
				if (j.parent != null) 
					nj.parent = makeJoint(j.parent);
				else 
					nj.parent = -1;
					
				nj.index = j.index;
				nj.bindIndex = j.bindIndex;
				nj.splitIndex = j.splitIndex;
				if( j.defMat!=null)
					nj.defaultMatrix = Tools.matrixToBytes(j.defMat);
				if( j.transPos!=null)
					nj.transPos = Tools.matrixToBytes(j.transPos);
				nj.subs = Tools.intArrayToBytes(j.subs.map(function(j) return makeJoint(j)));
				
				return id;
			}
		}
		
		out.roots = sk.rootJoints.map(makeJoint);
		out.all = sk.allJoints.map(makeJoint);
		out.bound = sk.boundJoints.map(makeJoint);
		out.splitJoints = sk.splitJoints == null?null:sk.splitJoints.map( function(a) return a.map(makeJoint));
		out.triangleGroups = sk.triangleGroups == null?null:Tools.intVectorToBytes(sk.triangleGroups);
		
		var jar = Lambda.array(jointLibrary);
		jar.sort( function(j0, j1) return Reflect.compare( j0.id, j1.id ));
		out.jointLibrary = jar;
		
		return out;
	}
	
	function writeJoint( data : hxd.fmt.h3d.Data.Joint ) {
		output.writeInt32( data.id );
		output.writeInt32( data.index );
		output.condWriteString2(data.name);
		output.writeInt32( data.bindIndex);
		output.writeInt32( data.splitIndex);
		output.condWriteBytes2( data.defaultMatrix );
		output.condWriteBytes2( data.transPos );
		output.writeInt32( data.parent );
		output.condWriteBytes2( data.subs );
	}
	
	public function writeData( data : hxd.fmt.h3d.Data.Skin ) {
		output.bigEndian = false;
		
		output.writeString(MAGIC);
		output.writeInt32(VERSION);
	
		output.writeInt32( data.vertexCount );
		output.writeInt32( data.bonesPerVertex );
		
		output.writeBytes2( data.vertexJoints );
		output.writeBytes2( data.vertexWeights );
		
		output.writeInt32(data.jointLibrary.length);
		for ( a in data.jointLibrary ) 
			writeJoint( a );
			
		output.writeInt32( data.all.length );
		for ( a in data.all ) output.writeInt32( a );
		
		output.writeInt32( data.roots.length );
		for ( a in data.roots ) output.writeInt32( a );
		
		output.writeInt32( data.bound.length );
		for ( a in data.bound ) output.writeInt32( a );
		
		output.writeBool( data.splitJoints != null );
		if ( data.splitJoints != null ) {
			output.writeInt32( data.splitJoints.length );
			
			for ( a in data.splitJoints ) {
				output.writeInt32( a.length );
				for ( j in a ) {
					output.writeInt32( j );
				}
			}
		}
		
		output.condWriteBytes2( data.triangleGroups );
		
		output.writeInt32( 0xE0F );
	}
	
	
	
}