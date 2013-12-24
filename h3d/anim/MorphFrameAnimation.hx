package h3d.anim;
import h3d.anim.Animation;
import h3d.prim.FBXModel;
import h3d.scene.Mesh;
import hxd.BitmapData;
import hxd.FloatBuffer;


class MorphShape {
	public inline function new(i,v,n) {
		index = i;
		vertex = v;
		normal = n;
	}
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
}

class MorphObject extends AnimatedObject {

	public var ratio : Array<Array<Float>>;
	
	public inline function new (name) { 
		super(name); 
		
	};
	
	override function clone() : AnimatedObject {
		var o = new MorphObject( objectName );
		o.ratio = ratio;
		return o;
	}
}

	
class MorphFrameAnimation extends Animation {
	var syncFrame : Int;
	public var shapes : Array<MorphShape>;
	
	public function new(name, frame, sampling) {
		super(name, frame, sampling);
		shapes = [];
		syncFrame = -1;
	}
	
	public inline function getObjects() : Array<MorphObject>
	{
		return cast objects;
	}
	
	public function addObject(name,nbShape) {
		var fr = new MorphObject(name);
		objects.push( fr );
		fr.ratio = [ for (i in 0...nbShape) [for (j in 0...frameCount) 0.0] ];
		return fr;
	}
	
	public function addShape( index,vertex,normal ) {
		var f = new MorphShape(index,vertex,normal);
		f.index = index; f.vertex = vertex; f.normal = normal;
		shapes.push(f);
	}
	
	override function clone(?a:Animation) {
		if ( a == null ){
			var m = new MorphFrameAnimation(name, frameCount, sampling);
			m.shapes = shapes;
			a = m;
		}
		
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
		
		throw "todo";
	}
	
	
	public inline function norm3(fb : FloatBuffer) {
		var nx = 0.0, ny = 0.0, nz = 0.0, l = 0.0;
		var len = Std.int( fb.length / 3 + 0.5 );
		for ( i in 0...len) {
			nx = fb[i * 3 		];
			ny = fb[i * 3 + 1	];
			nz = fb[i * 3 + 2	];
			
			l = 1.0 / Math.sqrt(nx * nx  + ny * ny +nz * nz);
			
			nx *= l;
			ny *= l;
			nz *= l;
			
			fb[i * 3	]	= nx;
			fb[i * 3 + 1]	= ny;
			fb[i * 3 + 2]	= nz;
		}
		return fb;
	}
	
	/**
	 * this will put callbacks on the target so that vertex buffers etc are harwritten before gpu sending
	 * it allows to customize the mesh without paying runtime price
	 * @param	fr, frame index
	 */
	public function writeTarget(fr:Int) {
		if ( fr >= getObjects()[0].ratio[0].length ) throw "invalid frame";
		
		for ( obj in getObjects()){
		
			var targetObject = obj.targetObject;
			if ( targetObject == null) throw "scene object is not bound !";
			
			if ( Std.is(targetObject, Mesh)) {
				var t : Mesh = cast targetObject;
				var prim = t.primitive;
				if ( Std.is( prim, h3d.prim.FBXModel)) {
					var fbxPrim : h3d.prim.FBXModel = cast prim;
					
					var onnb = fbxPrim.onNormalBuffer;
					var onvb = fbxPrim.onVertexBuffer;
					
					fbxPrim.onNormalBuffer = function(nbuf:FloatBuffer) {
						var originalN = nbuf;
						var computedN = onnb(nbuf);
						var vlen = Std.int(originalN.length / 3);
						var nx = 0.0;
						var ny = 0.0;
						var nz = 0.0;
						var l = 0.0;
						
						var resN = new FloatBuffer(computedN.length);
						//resN.blit(computedN,computedN.length);
						for ( i in 0...resN.length ) resN[i] = 0.0;
						
						for ( si in 0...shapes.length) {
							var shape = shapes[si];
							
							var i = 0;
							var r = obj.ratio[si][fr];
							for ( idx in shape.index ){
								resN[idx*3] 	+= shape.normal[i*3] 	* r;
								resN[idx*3+1] 	+= shape.normal[i*3+1] 	* r;
								resN[idx*3+2] 	+= shape.normal[i*3+2] 	* r;
								i++;
							}
						}
						
						return norm3(resN);
					};
					
					fbxPrim.onVertexBuffer = function(vbuf:FloatBuffer) {
						var originalV = vbuf;
						var computedV = onvb(vbuf);
						
						var resV = new FloatBuffer(computedV.length);
						resV.blit(computedV,computedV.length);
						
						for ( si in 0...shapes.length) {
							var shape = shapes[si];
							var i = 0;
							
							var dx = 0.0;
							var dy = 0.0;
							var dz = 0.0;
							
							var r = obj.ratio[si][fr];
							for ( idx in shape.index ) {
								
								dx = (shape.vertex[i*3] 	- originalV[idx*3]);
								dy = (shape.vertex[i*3+1] 	- originalV[idx*3+1]);
								dz = (shape.vertex[i*3+2] 	- originalV[idx*3+2]);
								
								//no normalize needed
								resV[idx*3] 	+= dx * r;
								resV[idx*3+1] 	+= dy * r;
								resV[idx*3+2] 	+= dz * r;
								
								i++;
							}
						}
						
						return resV;
					};
				}
			}
			else throw "unsupported";
		
		}
	}
	
	/**
	 * use with writeTarget to force shape writing
	 */
	public function manualBind(base : h3d.scene.Object) {
		super.bind(base);
	}
	
	public override function bind( base : h3d.scene.Object ) {
		super.bind(base);
		
		for( obj in getObjects()){
		if ( Std.is(obj.targetObject, Mesh)) {
				var t : Mesh = cast obj.targetObject;
				var prim = t.primitive;
				if ( Std.is( prim, h3d.prim.FBXModel)) {
					var fbxPrim : h3d.prim.FBXModel = cast prim;
					if( !fbxPrim.isDynamic ){
						fbxPrim.dispose();
						fbxPrim.isDynamic = true;
					}
				}
			}
		}
	}
	
}