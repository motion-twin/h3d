package h3d.anim;

import format.h3d.Data;
import format.h3d.Tools;
import haxe.macro.Format;

import h3d.anim.Animation;
import haxe.io.BytesOutput;

class FrameObject extends AnimatedObject {
	public var frames : haxe.ds.Vector<h3d.Matrix>;
	public var alphas : haxe.ds.Vector<Float>;
	
	override function clone() : AnimatedObject {
		var o = new FrameObject(objectName);
		o.frames = frames;
		o.alphas = alphas;
		return o;
	}
}
	
class FrameAnimation extends Animation {

	var syncFrame : Int;

	public function new(name,frameCount,sampling) {
		super(name,frameCount,sampling);
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
	
	//should be a getObjects...because it will get you perObjectFrames
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
			
		//hxd.Profiler.begin("Object::Frameanimation::sync");
		
		syncFrame = frame;
		for( o in getFrames() ) {
			if( o.alphas != null ) {
				var mat = o.targetObject.toMesh().material;
				if( mat.colorMul == null ) {
					mat.colorMul = new Vector(1, 1, 1, 1);
					if( mat.blendDst == Zero )
						mat.blend(SrcAlpha, OneMinusSrcAlpha);
				}
				mat.colorMul.w = o.alphas[frame];
			} else if( o.targetSkin != null ) {
				o.targetSkin.currentRelPose[o.targetJoint] = o.frames[frame];
				o.targetSkin.jointsUpdated = true;
			} else
				o.targetObject.defaultTransform = o.frames[frame];
		}
		
		//hxd.Profiler.begin("Object::Frameanimation::sync");
	}
	
	public override function toData() : format.h3d.Data.Animation {
		var anim = super.toData(); 
		anim.type = AT_FrameAnimation;
		
		for ( o in getFrames()) {
			
			if( o.frames != null ){
				//TRS
				var a = new format.h3d.Data.AnimationObject();
				a.targetObject = o.objectName;
				a.format = PosRotScale;
				a.data = Tools.matrixVectorToFloatBytes( o.frames );
				anim.objects.push(a);
			}
			
			if( o.alphas != null){
				//Alpha
				var a = new format.h3d.Data.AnimationObject();
				a.targetObject = o.objectName;
				a.format = Alpha;
				a.data = Tools.floatVectorToFloatBytesFast( o.alphas );
				anim.objects.push(a);
			}
		}
		
		return anim;
	}
	
	public function ofData(anim : format.h3d.Data.Animation ) {
		
		for ( a in anim.objects )
			switch( a.format ) {
				case Alpha: 		addAlphaCurve( a.targetObject, Tools.floatBytesToFloatVector(a.data ));
				case PosRotScale: 	addCurve( a.targetObject, Tools.floatBytesToMatrixVector(a.data ));
					
				default:throw "unsupported";
			}
	}
}