package h3d.anim;

import h3d.mat.Data;
import h3d.mat.Material;
import h3d.anim.Animation;

import hxd.fmt.h3d.Tools;

class FrameObject extends AnimatedObject {
	public var frames : haxe.ds.Vector<h3d.Matrix>;
	public var alphas : haxe.ds.Vector<Float>;
	public var uvs : haxe.ds.Vector<Float>;
	public var shapes : haxe.ds.Vector<haxe.ds.Vector<Float>>;
	
	override function clone() : AnimatedObject {
		var o = new FrameObject(objectName);
		o.frames = frames;
		o.alphas = alphas;
		o.uvs = uvs;
		o.shapes = shapes;
		return o;
	}
}
	
class FrameAnimation extends Animation {

	var syncFrame : Int;

	public function new(name,frame,sampling) {
		super(name,frame,sampling);
		syncFrame = -1;
	}
	
	public function addCurve( objName, frames ) {
		var f = new FrameObject(objName);
		f.frames = frames;
		objects.push(f);
	}
	
	public function addAlphaCurve( objName, alphas ) {
		var f = new FrameObject(objName);
		f.alphas = alphas;
		objects.push(f);
	}

	public function addUVCurve( objName, uvs ) {
		var f = new FrameObject(objName);
		f.uvs = uvs;
		objects.push(f);
	}
	
	public function addShapes( objName, shapes ) {
		var f = new FrameObject(objName);
		f.shapes = shapes;
		objects.push(f);
	}
	
	inline function getFrames() : Array<FrameObject> {
		return cast objects;
	}
	
	override function initInstance() {
		super.initInstance();
		for( a in getFrames() )
			if( a.alphas != null && (a.targetObject == null || !a.targetObject.isMesh()) )
				throw a.objectName + " should be a mesh";
	}
	
	override function clone(?a:Animation) {
		if( a == null )
			a = new FrameAnimation(name, frameCount, sampling);
		super.clone(a);
		return a;
	}
	
	@:access(h3d.scene.Skin)
	override function sync( decompose = false ) {
		if( decompose ) throw "Decompose not supported on Frame Animation";
		var frame = Std.int(frame);
		if( frame < 0 ) frame = 0 else if( frame >= frameCount ) frame = frameCount - 1;
		if( frame == syncFrame )
			return;
		syncFrame = frame;
		for( o in getFrames() ) {
			if( o.alphas != null ) {
				var mat : h3d.mat.MeshMaterial = o.targetObject.toMesh().material;
				if( mat.colorMul == null ) {
					mat.colorMul = new Vector(1, 1, 1, 1);
					if( mat.blendMode == None  )
						mat.blendMode = Normal;
				}
				mat.colorMul.w = o.alphas[frame];
			}
			else if ( o.shapes != null ) {
				var fbx = Std.instance( o.targetObject.toMesh().primitive, h3d.prim.FBXModel );
				if ( fbx != null) 
					if( frame < o.shapes.length )
						fbx.setShapeRatios( o.shapes[frame] );
			}
			else if( o.targetSkin != null ) {
				o.targetSkin.currentRelPose[o.targetJoint] = o.frames[frame];
				o.targetSkin.jointsUpdated = true;
			} else if(o.targetObject != null ) // sometime we skip some joints when thery are not skinned
				o.targetObject.defaultTransform = o.frames[frame];
		}
		
		//hxd.Profiler.begin("Object::Frameanimation::sync");
	}
	
	public override function toData() : hxd.fmt.h3d.Data.Animation {
		var anim = super.toData(); 
		anim.type = AT_FrameAnimation;
		
		for ( o in getFrames()) {
			
			var a = new  hxd.fmt.h3d.Data.AnimationObject();
			a.targetObject = o.objectName;
				
			if( o.frames != null ){
				//TRS
				a.format = hxd.fmt.h3d.Data.AnimationFormat.Matrix;
				a.data = Tools.matrixVectorToFloatBytesFast( o.frames );
			}
			
			if( o.alphas != null){
				//Alpha
				a.format = Alpha;
				a.data = Tools.floatVectorToFloatBytesFast( o.alphas );
			}
			
			if ( o.uvs != null) {
				a.format = UVDelta;
				a.data = Tools.floatVectorToFloatBytesFast( o.uvs );
			}
			
			if ( o.shapes != null ) {
				a.format = Shapes;
				
				var b = Tools.makeShapeBytes(o.shapes);
				
				a.data =  b;
			}
			
			anim.objects.push(a);
			
		}
		
		return anim;
	}
	
	public override function ofData(anim : hxd.fmt.h3d.Data.Animation ) {
		for ( a in anim.objects )
			switch( a.format ) {
				
				case Alpha: 		
					addAlphaCurve( a.targetObject, Tools.floatBytesToFloatVectorFast(a.data ));
					
				case Matrix: 	
					addCurve( a.targetObject, Tools.floatBytesToMatrixVectorFast(a.data ));
					
				case UVDelta:
					addUVCurve( a.targetObject, hxd.fmt.h3d.Tools.floatBytesToFloatVectorFast(a.data ));
					
				case Shapes: addShapes( a.targetObject, hxd.fmt.h3d.Tools.unmakeShapeBytes( a.data ));
					
				default:throw "unsupported";
			}
			
		super.ofData(anim);
	}
}