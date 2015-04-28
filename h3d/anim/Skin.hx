package h3d.anim;

class Joint {

	public var index : Int;
	public var name : String;
	public var bindIndex : Int;
	public var splitIndex : Int;
	public var defMat : Null<h3d.Matrix>; // the default bone matrix
	public var transPos : Null<h3d.Matrix>; // inverse pose matrix
	public var parent : Joint;
	public var subs : Array<Joint>;
	
	public function new() {
		bindIndex = -1;
		subs = [];
	}
	
	public function toString() {
		return '$index $name $bindIndex $splitIndex '+((parent!=null)?Std.string(parent.index):"");
	}
	
}

private class Influence {
	
	public var j : Joint;
	public var w : Float;
	
	public function new(j, w) {
		this.j = j;
		this.w = w;
	}
	
	public function toString() {
		return '$j $w';
	}
}



class Skin {
	
	public var vertexCount(default, null) : Int;
	public var bonesPerVertex(default,null) : Int;
	public var vertexJoints : haxe.ds.Vector<Int>;
	public var vertexWeights : haxe.ds.Vector<Float>;
	public var rootJoints(default, null) : Array<Joint>;
	
	public var namedJoints:
	#if flash
		haxe.ds.UnsafeStringMap<Joint> 	= new haxe.ds.UnsafeStringMap();
	#else
		haxe.ds.StringMap<Joint>		= new haxe.ds.StringMap();
	#end
	
	public var allJoints(default,null) : Array<Joint>;
	public var boundJoints(default,null) : Array<Joint>;
	public var primitive : h3d.prim.Primitive;
	
	// spliting
	public var splitJoints(default, null) : Array<Array<Joint>>;
	public var triangleGroups : haxe.ds.Vector<Int>;
	
	//per vertex influences
	//will be nulled after inital computation of vertexJoints
	var envelop : Null<Array<Array<Influence>>>;
	
	public function new( vertexCount, bonesPerVertex ) {
		this.vertexCount = vertexCount;
		this.bonesPerVertex = bonesPerVertex;
		//avoid 3 alloc for binay loadings
		if( vertexCount>0&&bonesPerVertex>0){
			vertexJoints = new haxe.ds.Vector(vertexCount * bonesPerVertex);
			vertexWeights = new haxe.ds.Vector(vertexCount * bonesPerVertex);
			envelop = [];
		}
	}
	
	public function setJoints( joints : Array<Joint>, roots : Array<Joint> ) {
		rootJoints = roots;
		allJoints = joints;
		namedJoints = #if flash new haxe.ds.UnsafeStringMap() #else new haxe.ds.StringMap() #end;
		for( j in joints )
			if( j.name != null )
				namedJoints.set(j.name, j);
	}
	
	public inline function addInfluence( vid : Int, j : Joint, w : Float ) {
		var il = envelop[vid];
		if( il == null )
			il = envelop[vid] = [];
		il.push(new Influence(j,w));
	}

	function sortInfluences( i1 : Influence, i2 : Influence ) {
		return i2.w > i1.w ? 1 : -1;
	}
	
	public inline function isSplit() {
		return splitJoints != null;
	}
	
	public function initWeights() {
		boundJoints = [];
		var pos = 0;
		for( i in 0...vertexCount ) {
			var il = envelop[i];
			if( il == null ) il = [];
			il.sort(sortInfluences);
			if ( il.length > bonesPerVertex ) {
				#if !prod
				if ( h3d.fbx.Library.detectBadVertices) 
					hxd.System.trace1('vertex $i has too much bones attached ${il.length} bones detected -> '+il);
				#end
				il = il.slice(0, bonesPerVertex);
			}
			var tw = 0.;
			for( i in il )
				tw += i.w;
			tw = 1 / tw;
			for( i in 0...bonesPerVertex ) {
				var i = il[i];
				if( i == null ) {
					vertexJoints[pos] = 0;
					vertexWeights[pos] = 0;
				} else {
					if( i.j.bindIndex == -1 ) {
						i.j.bindIndex = boundJoints.length;
						boundJoints.push(i.j);
					}
					vertexJoints[pos] = i.j.bindIndex;
					vertexWeights[pos] = i.w * tw;
				}
				pos++;
			}
		}
		envelop = null;
	}
	
	public function split( maxBones : Int, index : Array<Int> ) {
		if( isSplit() )
			return true;
		if( boundJoints.length <= maxBones )
			return false;

		splitJoints = [];
		triangleGroups = new haxe.ds.Vector(Std.int(index.length / 3));
		
		// collect joints groups used by triangles
		var curGroup = new Array<Joint>(), curJoints = [];
		var ipos = 0, tpos = 0;
		while( ipos <= index.length ) {
			var tjoints = [], flush = false;
			if( ipos < index.length ) {
				for( k in 0...3 ) {
					var vid = index[ipos + k];
					for( b in 0...bonesPerVertex ) {
						var bidx = vid * bonesPerVertex + b;
						if( vertexWeights[bidx] == 0 ) continue;
						var j = boundJoints[vertexJoints[bidx]];
						if( curJoints[j.bindIndex] == null ) {
							curJoints[j.bindIndex] = j;
							tjoints.push(j);
						}
					}
				}
			}
			if( curGroup.length + tjoints.length <= maxBones && ipos < index.length ) {
				for( j in tjoints )
					curGroup.push(j);
				triangleGroups[tpos++] = splitJoints.length;
				ipos += 3;
			} else {
				splitJoints.push(curGroup);
				curGroup = [];
				curJoints = [];
				if( ipos == index.length ) break;
			}
		}
		
		// assign split indexes to joints
		var groups = [for( i in 0...splitJoints.length ) { id : i, reserved : [], joints : splitJoints[i] }];
		var joints = [for( j in boundJoints ) { j : j, groups : [], index : -1 } ];
		for( g in groups )
			for( j in g.joints )
				joints[j.bindIndex].groups.push(g);
		joints.sort(function(j1, j2) return j2.groups.length - j1.groups.length);
		for( j in joints ) {
			for( i in 0...maxBones ) {
				var ok = true;
				for( g in j.groups )
					if( g.reserved[i] != null ) {
						ok = false;
						break;
					}
				if( ok ) {
					j.j.splitIndex = i;
					for( g in j.groups )
						g.reserved[i] = j.j;
					break;
				}
			}
			// not very good news if this happen.
			// It means that we need a smarter way to assign the joint indexes
			// Maybe by presorting triangles based on bone usage to have more coherent groups
			if( j.j.splitIndex < 0 ) throw "Bone conflict while spliting groups";
		}

		// rebuild joints list (and fill holes)
		splitJoints = [];
		for( g in groups ) {
			var jl = [];
			for( i in 0...g.reserved.length ) {
				var j = g.reserved[i];
				if( j == null ) j = boundJoints[0];
				jl.push(j);
			}
			splitJoints.push(jl);
		}
		
		// rebind
		for( i in 0...vertexJoints.length )
			vertexJoints[i] = boundJoints[vertexJoints[i]].splitIndex;

		return true;
	}
	
	public function ofData( data : hxd.fmt.h3d.Data.Skin ) {
		var t = hxd.fmt.h3d.Tools;
		
		vertexCount = data.vertexCount;
		bonesPerVertex = data.bonesPerVertex;
		vertexJoints =  t.bytesToIntVector(data.vertexJoints);
		vertexWeights = t.floatBytesToFloatVector(data.vertexWeights);
		
		if ( data.triangleGroups != null )
			triangleGroups = t.bytesToIntVector( data.triangleGroups );
			
		var jmap : Map<Int,Joint> = new Map();
		namedJoints = #if flash new haxe.ds.UnsafeStringMap() #else new haxe.ds.StringMap() #end;
		
		function jointGet( jid ) return jmap.get(jid);
		
		for ( j in data.jointLibrary ) {
			var jnew = new Joint();
			jmap.set( j.id, jnew );
			if ( j.name != null ) 
				namedJoints.set( j.name, jnew );
			else 
				trace(j.id + " has no name");
		}
		
		var curJoint : Joint = null;
		for ( j in data.jointLibrary ) {
			curJoint = jmap.get( j.id );
			curJoint.name = j.name;
			curJoint.index = j.index;
			curJoint.bindIndex = j.bindIndex;
			curJoint.splitIndex = j.splitIndex;
			if(j.defaultMatrix!=null)
				curJoint.defMat = t.bytesToMatrix(j.defaultMatrix);
			if (j.transPos != null)
				curJoint.transPos = t.bytesToMatrix(j.transPos);

			curJoint.parent = jmap.get( j.parent );
			curJoint.subs = t.bytesToIntArray(j.subs)
			.map(jointGet);
		}
		
		this.allJoints = data.all.map( jointGet );
		this.boundJoints = data.bound.map( jointGet );
		this.rootJoints = data.roots.map( jointGet );
		
		if( data.splitJoints!=null )
			this.splitJoints = data.splitJoints.map(function(jset) {
				return jset.map( jointGet );
			});
			
		this.envelop = null;
	}
}