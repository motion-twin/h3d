package h3d.anim;
import h3d.anim.Animation;

class MorphFrameObject extends AnimatedObject {
	
	public var ratio : haxe.ds.Vector<Float>;
	
	/**
	 * index target a vertex for the morph
	 */
	public var index : haxe.ds.Vector<Int>;
	
	/**
	 * x y z
	 */
	public var vertex : haxe.ds.Vector<Float>;
	
	/**
	 * x y z
	 */
	public var normal : haxe.ds.Vector<Float>;
	
	override function clone() : AnimatedObject {
		var o = new MorphFrameObject(objectName);
		o.ratio = ratio;
		o.index = index;
		o.vertex = vertex;
		o.normal = normal;
		return o;
	}
}
	
class MorphFrameAnimation extends Animation {
	var syncFrame : Int;

	public function new(name, frame, sampling) {
		super(name, frame, sampling);
		syncFrame = -1;
	}
	
	public function addShape( objName, ratio ,index,vertex,normal ) {
		var f = new MorphFrameObject(objName);
		f.ratio = ratio; f.index = index; f.vertex = vertex; f.normal = normal;
		objects.push(f);
	}
	
	inline function getFrames() : Array<MorphFrameObject> {
		return cast objects;
	}
	
	override function clone(?a:Animation) {
		if( a == null )
			a = new MorphFrameAnimation(name, frameCount, sampling);
		super.clone(a);
		return a;
	}
	
	override function sync( decompose = false ) {

		if ( decompose ) throw "Decompose not supported on Frame Animation";
		
		var frame = Std.int(frame);
		if( frame < 0 ) frame = 0 else if( frame >= frameCount ) frame = frameCount - 1;
		if( frame == syncFrame )
			return;
			
		syncFrame = frame;
		for ( o in getFrames() ) {
			var r = o.ratio[frame];
			o.targetObject; 
			// for idx in 0...o.index.length
			//var vidx = o.index[idx]
			//o.vertex[vidx] += o.vertex[idx] * r;
			//o.normal[vidx] += o.normal[idx] * r;
			//throw "todo";
			
			//modify the vertex buffer in place
			
		}
	}
	
}