package format.h3d;

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

class Geometry {
	public var positions : haxe.io.Bytes;
	public var normals : haxe.io.Bytes;
	public var colors : haxe.io.Bytes;
	public var uvs : haxe.io.Bytes;
	public var skinning : haxe.io.Bytes; // indexes + weights
	public function new() {
	}
}

class Material {
	public var diffuseTexture : Null<String>;
	public var blendMode : BlendMode;
	public var culling : h3d.mat.Data.Face;
	public var alphaKill : Null<Float>;
	public var alphaTexture : Null<String>;
	public var emissiveTexture : Null<String>;
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
	public function new() {
	}
}

class Model {
	public var name : String;
	public var pos : ModelPosition;
	public var geometries : Array<Index<Geometry>>;
	public var materials : Array<Index<Material>>;
	public var subModels : Array<Index<Model>>;
	// TODO : skin
	
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
