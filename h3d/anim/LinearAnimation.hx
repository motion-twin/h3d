package h3d.anim;
import h3d.anim.Animation;
import h3d.mat.Material;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;

//import format.h3d.Data;
//import format.h3d.Tools;

class LinearFrame {
	public var tx : Float;
	public var ty : Float;
	public var tz : Float;
	
	public var qx : Float;
	public var qy : Float;
	public var qz : Float;
	public var qw : Float;
	
	public var sx : Float;
	public var sy : Float;
	public var sz : Float;
	
	public static inline var SIZE = 3 + 4 + 3;
	
	public function new() {	}
	
	public function toString() {
		return 'tx:$tx ty:$ty tz:$tz';
	}
}

class LinearObject extends AnimatedObject {
	public var hasRotation : Bool;
	public var hasScale : Bool;
	public var frames : haxe.ds.Vector<LinearFrame>;
	public var alphas : haxe.ds.Vector<Float>;
	public var uvs : haxe.ds.Vector<Float>;
	public var shapes : haxe.ds.Vector<haxe.ds.Vector<Float>>;
	public var matrix : h3d.Matrix;
	override function clone() : AnimatedObject {
		var o = new LinearObject(objectName);
		o.hasRotation = hasRotation;
		o.hasScale = hasScale;
		o.frames = frames;
		o.alphas = alphas;
		o.uvs = uvs;
		o.shapes = shapes;
		return o;
	}
}
	
class LinearAnimation extends Animation {

	var syncFrame : Float;

	public function new(name,frame,sampling) {
		super(name,frame,sampling);
		syncFrame = -1;
	}
	
	public function addCurve( objName, frames, hasRot, hasScale ) {
		var f = new LinearObject(objName);
		f.frames = frames;
		f.hasRotation = hasRot;
		f.hasScale = hasScale;
		objects.push(f);
	}
	
	public function addAlphaCurve( objName, alphas ) {
		var f = new LinearObject(objName);
		f.alphas = alphas;
		objects.push(f);
	}

	public function addUVCurve( objName, uvs ) {
		var f = new LinearObject(objName);
		f.uvs = uvs;
		objects.push(f);
	}
	
	public function addShapesCurve( objName, shapes ) {
		var f = new LinearObject(objName);
		f.shapes = shapes;
		objects.push(f);
	}
	
	inline function getFrames() : Array<LinearObject> {
		return cast objects;
	}
	
	override function initInstance() {
		super.initInstance();
		for( a in getFrames() ) {
			a.matrix = new h3d.Matrix();
			a.matrix.identity();
			if( a.alphas != null && (a.targetObject == null || !a.targetObject.isMesh()) )
				throw a.objectName + " should be a mesh";
		}
	}
	
	override function clone(?a:Animation) {
		if( a == null )
			a = new LinearAnimation(name, frameCount, sampling);
		super.clone(a);
		return a;
	}
	
	override function endFrame() {
		return loop ? frameCount : frameCount - 1;
	}
	
	@:access(h3d.scene.Skin)
	override function sync( decompose = false ) {
		if( frame == syncFrame && !decompose )
			return;
		var frame1 = Std.int(frame);
		var frame2 = (frame1 + 1) % frameCount;
		var k2 = frame - frame1;
		var k1 = 1 - k2;
		if( frame1 < 0 ) frame1 = frame2 = 0 else if( frame >= frameCount ) frame1 = frame2 = frameCount - 1;
		syncFrame = frame;
		for( o in getFrames() ) {
			if( o.alphas != null ) {
				var mat : h3d.mat.MeshMaterial = o.targetObject.toMesh().material;
				if( mat.colorMul == null ) {
					mat.colorMul = new Vector(1, 1, 1, 1);
					if( mat.blendMode == None  )
						mat.blendMode = Normal;
				}
				mat.colorMul.w = o.alphas[frame1] * k1 + o.alphas[frame2] * k2;
				continue;
			}
			if( o.uvs != null ) {
				var mat = o.targetObject.toMesh().material;
				if( mat.uvDelta == null ) {
					mat.uvDelta = new Vector();
					mat.texture.wrap = Repeat;
				}
				mat.uvDelta.x = o.uvs[frame1 << 1] * k1 + o.uvs[frame2 << 1] * k2;
				mat.uvDelta.y = o.uvs[(frame1 << 1) | 1] * k1 + o.uvs[(frame2 << 1) | 1] * k2;
				continue;
			}
			
			if ( o.shapes != null ) {
				var nbShapes = o.shapes[0].length;
				var v = new haxe.ds.Vector( nbShapes );
				for (i in 0...nbShapes)
					v[i] = o.shapes[frame1][i] * k1 + o.shapes[frame2][i] * k2;
				var fbx = Std.instance( o.targetObject.toMesh().primitive, h3d.prim.FBXModel );
				if ( fbx != null) fbx.setShapeRatios( v );
				
				v = null;
				continue;
			}
			
			var f1 = o.frames[frame1], f2 = o.frames[frame2];
			
			var m = o.matrix;
			
			m._41 = f1.tx * k1 + f2.tx * k2;
			m._42 = f1.ty * k1 + f2.ty * k2;
			m._43 = f1.tz * k1 + f2.tz * k2;
			
			if( o.hasRotation ) {
				// qlerp nearest
				var dot = f1.qx * f2.qx + f1.qy * f2.qy + f1.qz * f2.qz + f1.qw * f2.qw;
				var q2 = dot < 0 ? -k2 : k2;
				var qx = f1.qx * k1 + f2.qx * q2;
				var qy = f1.qy * k1 + f2.qy * q2;
				var qz = f1.qz * k1 + f2.qz * q2;
				var qw = f1.qw * k1 + f2.qw * q2;
				// make sure the resulting quaternion is normalized
				var ql = 1 / Math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw);
				qx *= ql;
				qy *= ql;
				qz *= ql;
				qw *= ql;
				
				if( decompose ) {
					m._12 = qx;
					m._13 = qy;
					m._21 = qz;
					m._23 = qw;
					if( o.hasScale ) {
						m._11 = f1.sx * k1 + f2.sx * k2;
						m._22 = f1.sy * k1 + f2.sy * k2;
						m._33 = f1.sz * k1 + f2.sz * k2;
					}
				} else {
					// quaternion to matrix
					var xx = qx * qx;
					var xy = qx * qy;
					var xz = qx * qz;
					var xw = qx * qw;
					var yy = qy * qy;
					var yz = qy * qz;
					var yw = qy * qw;
					var zz = qz * qz;
					var zw = qz * qw;
					m._11 = 1 - 2 * ( yy + zz );
					m._12 = 2 * ( xy + zw );
					m._13 = 2 * ( xz - yw );
					m._21 = 2 * ( xy - zw );
					m._22 = 1 - 2 * ( xx + zz );
					m._23 = 2 * ( yz + xw );
					m._31 = 2 * ( xz + yw );
					m._32 = 2 * ( yz - xw );
					m._33 = 1 - 2 * ( xx + yy );
					if( o.hasScale ) {
						var sx = f1.sx * k1 + f2.sx * k2;
						var sy = f1.sy * k1 + f2.sy * k2;
						var sz = f1.sz * k1 + f2.sz * k2;
						m._11 *= sx;
						m._12 *= sx;
						m._13 *= sx;
						m._21 *= sy;
						m._22 *= sy;
						m._23 *= sy;
						m._31 *= sz;
						m._32 *= sz;
						m._33 *= sz;
					}
				}
				
			} else if( o.hasScale ) {
				m._11 = f1.sx * k1 + f2.sx * k2;
				m._22 = f1.sy * k1 + f2.sy * k2;
				m._33 = f1.sz * k1 + f2.sz * k2;
			}
			
			
			if( o.targetSkin != null ) {
				o.targetSkin.currentRelPose[o.targetJoint] = o.matrix;
				o.targetSkin.jointsUpdated = true;
			} else if(o.targetObject != null )
				o.targetObject.defaultTransform = o.matrix;
		}
	}
	
	public override function toData() : hxd.fmt.h3d.Data.Animation {
		var anim = super.toData(); 
		anim.type = AT_LinearAnimation;
		
		for ( o in getFrames()) {
			var a = new  hxd.fmt.h3d.Data.AnimationObject();
			a.targetObject = o.objectName;
				
			if( o.frames != null ){
				//filter out flags
				if( o.hasRotation && o.hasScale)
					a.format = PosRotScale;
				else if ( o.hasRotation )
					a.format = PosRot;
				else 
					a.format = PosScale;
				
				var pos = 0;
				
				var inBytes = haxe.io.Bytes.alloc(LinearFrame.SIZE * 4 * o.frames.length);
				
				//write the thing
				for ( f in o.frames ) {
					inBytes.setFloat(pos	,f.tx);
					inBytes.setFloat(pos+4	,f.ty);
					inBytes.setFloat(pos+8	,f.tz);
					pos += 12;
					
					inBytes.setFloat(pos	,f.qx);
					inBytes.setFloat(pos+4	,f.qy);
					inBytes.setFloat(pos+8	,f.qz);
					inBytes.setFloat(pos+12	,f.qw);
					pos += 16;
					
					inBytes.setFloat(pos	,f.sx);
					inBytes.setFloat(pos+4	,f.sy);
					inBytes.setFloat(pos+8	,f.sz);
					pos += 12;
				}
				a.data = inBytes;
				
			}
			
			if( o.alphas != null){
				a.format = Alpha;
				a.data =  hxd.fmt.h3d.Tools.floatVectorToFloatBytesFast( o.alphas );
				
				anim.objects.push(a);
			}
			
			if ( o.uvs != null) {
				a.format = UVDelta;
				a.data = hxd.fmt.h3d.Tools.floatVectorToFloatBytesFast( o.uvs );
			}
			
			if ( o.shapes != null ) {
				a.format = Shapes;
				
				var b = new haxe.io.BytesBuffer();
				
				var nbKeys = o.shapes.length;
				var nbShapes = o.shapes[0].length; 
				
				//write nb Keys
				b.addByte(o.shapes.length&255);
				b.addByte(o.shapes.length>>8);
				
				//write nb shapes
				b.addByte(o.shapes[0].length&255);
				b.addByte(o.shapes[0].length>>8);
				
				for( ki in 0...nbKeys )
				for ( si in 0...nbShapes ) 
					b.addFloat( o.shapes[ki][si] );
					
				a.data = b.getBytes();
			}
			
			anim.objects.push(a);
		}
		
		return anim;
	}
	
	
	public override function ofData(anim : hxd.fmt.h3d.Data.Animation ) {
		function readFrame( stream : haxe.io.BytesInput ) : LinearFrame {
			var n  = new LinearFrame();
			n.tx = stream.readFloat();
			n.ty = stream.readFloat();
			n.tz = stream.readFloat();
			
			n.qx = stream.readFloat();
			n.qy = stream.readFloat();
			n.qz = stream.readFloat();
			n.qw = stream.readFloat();
			
			n.sx = stream.readFloat();
			n.sy = stream.readFloat();
			n.sz = stream.readFloat();
			return n;
		}
	
		for ( a in anim.objects )
			switch( a.format ) {
				
				case Alpha: 		
					addAlphaCurve( a.targetObject, hxd.fmt.h3d.Tools.floatBytesToFloatVectorFast(a.data ));
					
				case PosRot|PosRotScale: 	
					var nbElem = Math.round( a.data.length / (4 * LinearFrame.SIZE ) );
					var vec : haxe.ds.Vector<LinearFrame> = new haxe.ds.Vector( nbElem );
					var stream = new BytesInput(a.data);
					for ( i in 0...nbElem) 
						vec[i] = readFrame(stream);
					
					addCurve( a.targetObject, vec, 
						switch(a.format) { case PosRot|PosRotScale:true; default:false; }, 
						switch(a.format) { case PosScale|PosRotScale:true; default:false; } 
					);
					
				case UVDelta:
					addUVCurve( a.targetObject, hxd.fmt.h3d.Tools.floatBytesToFloatVectorFast(a.data ));
					
				case Shapes:
				
					
					
				default:throw "unsupported";
			}
		super.ofData(anim);
	}
	
}