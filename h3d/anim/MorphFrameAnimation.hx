package h3d.anim;
import h3d.anim.Animation;
import h3d.prim.FBXModel;
import h3d.scene.Mesh;
import hxd.BitmapData;
import hxd.FloatBuffer;

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
		if( a == null ) a = new MorphFrameAnimation(name, frameCount, sampling);
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
	
	/**
	 * this will put callbacks on the target so that vertex buffers etc are harwritten before gpu sending
	 * it allows to customize the mesh without paying runtime price
	 * @param	fr, frame index
	 */
	public function writeTarget(fr:Int)
	{
		var frames = getFrames()[fr];
		
		//target is allways geometry source
		var targetObject = frames.targetObject;
		if ( Std.is(targetObject, Mesh)) {
			var t : Mesh = cast targetObject;
			var prim = t.primitive;
			if ( Std.is( prim, h3d.prim.FBXModel)) {
				var fbxPrim : h3d.prim.FBXModel = cast prim;
				
				var onnb = fbxPrim.onNormalBuffer;
				var onvb = fbxPrim.onVertexBuffer;
				
				fbxPrim.onNormalBuffer = function(nbuf:FloatBuffer) {
					var nbuf = onnb(nbuf);
					throw "todo";
					return nbuf;
				};
				
				fbxPrim.onVertexBuffer = function(vbuf:FloatBuffer) {
					var vbuf = onvb(vbuf);
					throw "todo";
					for ( v in vbuf) {
						
					}
					
					return vbuf;
				};
				
				trace("truc");
			}
		}
		else throw "unsupported";
	}
	
	public override function bind( base : h3d.scene.Object ) {
		super.bind(base);
		
	}
}