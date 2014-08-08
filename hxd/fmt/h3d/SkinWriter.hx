package hxd.fmt.h3d;

import h3d.anim.Skin.Joint;
import hxd.ByteConversions;
import hxd.BytesBuffer;
import hxd.FloatBuffer;
import hxd.FloatStack;
import hxd.fmt.h3d.Data;

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
	
	
}