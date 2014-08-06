package hxd.fmt.h3d;
import haxe.io.Bytes;

typedef Index<T> = Int;

enum BlendMode {
	Opaque;
	Transparent;
	Additive;
}

enum AnimationFormat {
	Alpha;
	Pos;
	PosRot;
	PosScale;
	PosRotScale;
	Matrix;
	//later
	//UVScroll;
	
}

enum AnimationType {
	AT_FrameAnimation;
	AT_LinearAnimation;
}

//storage for morphtargets and other secondary shapes like
class SecondaryGeometry {
	public var index : haxe.io.Bytes;
	public var positions : haxe.io.Bytes;
	public var normals : haxe.io.Bytes;
	
	public inline function new() {}
}

class Geometry {
	
	public var isMultiMaterial : Bool;
	public var isSkinned : Bool;
	
	public var index : haxe.io.Bytes;
	public var positions : haxe.io.Bytes;
	public var normals : haxe.io.Bytes;
	public var uvs : haxe.io.Bytes;
	
	public var colors : Null<haxe.io.Bytes>;
	
	public var skinning : haxe.io.Bytes; // indexes + weights
	public var skinIdxBytes = 3;
	public var weightIdxBytes = 1;
	
	public var groupIndexes : Array<haxe.io.Bytes>;
	
	public var extra  : Array<SecondaryGeometry>;
	
	public inline function new() {}
}

class Material {
	
	public var diffuseTexture : Null<String>;
	public var blendMode : h2d.BlendMode;
	public var culling : h3d.mat.Data.Face;
	public var alphaKill : Null<Float>;
	public var alphaTexture : Null<String>;
	
	public function new() {
	}
}

class ModelPosition {
	public var x : Float;
	public var y : Float;
	public var z : Float;
	public var rx : Float;
	public var ry : Float;
	public var rz : Float;
	public var sx : Float;
	public var sy : Float;
	public var sz : Float;
	public function new() { }
}

class Joint {
	public var id				: JointId;
	public var index 			: Int;
	public var name 			: String;
	public var bindIndex 		: Int;
	public var splitIndex 		: Int;
	public var defaultMatrix 	: haxe.io.Bytes;//h3d.Matrix;
	public var transPos 		: haxe.io.Bytes;//h3d.Matrix;
	public var parent 			: JointId;
	public var subs 			: haxe.io.Bytes;//: Array<JointId>;
	
	public function new() { }
}	

typedef JointId = Int;//the jointid

/**
 * see h3d.anim.skin;
*/
class Skin {
	public var vertexCount : Int;
	public var bonesPerVertex : Int;
	
	public var vertexJoints : haxe.io.Bytes; // : haxe.ds.Vector<Int>[vertexCount*bonesPerVertex];
	public var vertexWeights : haxe.io.Bytes; //: haxe.ds.Vector<Float>[vertexCount*bonesPerVertex];
	
	//seems useless but i put them here still
	public var jointLibrary : Array<Joint>;
	
	public var all : Array<JointId>;
	
	public var roots : Array<JointId>;
	public var bound : Array<JointId>;
	
	// spliting
	public var splitJoints : Null<Array<Array<JointId>>>;
	public var triangleGroups : Null<haxe.io.Bytes>;

	inline public function new() {
	}
}

class Model {
	public var name : String;
	public var pos : ModelPosition;
	public var geometries : Array<Index<Geometry>>;
	public var materials : Array<Index<Material>>;
	public var subModels : Array<Index<Model>>;
	public var skin : Skin;
	
	inline public function new() {
	}
}

class AnimationObject {
	public var targetObject : String;
	public var format : AnimationFormat;
	public var data : haxe.io.Bytes;
	inline public function new() {
		
	}
}

class Animation {
	
	public var name 		: String;
	public var type 		: AnimationType;
	
	public var frameStart	: Int;
	public var frameEnd		: Int;
	public var frameCount 	: Int;
	
	public var speed 		: Float;
	public var sampling		: Float;
	
	public var objects 		: Array< AnimationObject > = [];
	public var frameLabels 	: Array<{ label : String, frame : Int }>;
	
	
	inline public function new() {
		
	}
	
	
}

class Data {
	
	public var geometries : Array<Geometry>;
	public var materials : Array<Material>;
	public var models : Array<Model>;
	public var animations : Array<Animation>;
	
	public function new() {
	}
}
