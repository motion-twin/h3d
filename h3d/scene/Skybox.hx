package h3d.scene;
import h3d.mat.Texture;
import h3d.Matrix;
import h3d.Vector;
import openfl.display3D.textures.CubeTexture;

class SkyboxShader extends h3d.impl.Shader{

	#if flash 
		static var SRC = {
			var input : {
				pos : Float3,
			};
		
			var uvw : Float3;
			
			function vertex(eyePos:Float4, mworld:Matrix, mproj:Matrix) {
				var vpos = input.pos.xyzw * mworld;
				var epos = eyePos.xyzw;
				out = vpos  * mproj;
				var t = epos.xyz - vpos.xyz;
				uvw = - [t.x, t.z, t.y];
			}
			
			function fragment( cubeTex:CubeTexture ) {
				out = get(cubeTex , normalize(uvw),clamp,linear,mm_linear);
			}
		};
	
	#else
	
	#end
}

class SkyboxMaterial extends h3d.mat.Material{
	public var cubeTex : h3d.mat.Texture;
	public var skyShader : SkyboxShader;
	
	var matrix : Matrix = new h3d.Matrix();
	var eyeDir : h3d.Vector = new h3d.Vector();
	
	public function new( t: h3d.mat.Texture ) {
		cubeTex = t;	
		skyShader = new SkyboxShader();
		super(skyShader);
		culling = Back;
		depthTest = h3d.mat.Data.Compare.Always;
		depthWrite = false;
		blendMode = None;
	}
	
	override function setup( ctx : h3d.scene.RenderContext ) {
		super.setup(ctx);
		skyShader.cubeTex 	= cubeTex;
		skyShader.eyePos	= ctx.camera.pos;
		skyShader.mworld 	= ctx.localPos;
		skyShader.mproj 	= ctx.engine.curProjMatrix;
	}
}

class Skybox extends h3d.scene.CustomObject {
	
	public function new(t:h3d.mat.Texture, ?p) {
		var prim = new h3d.prim.Cube();
		for ( i in 0...prim.points.length ) {
			var pt = prim.points[i];
			pt.x *= 2.0; 
			pt.y *= 2.0; 
			pt.z *= 2.0; 
			pt.x -= 1.0;
			pt.y -= 1.0;
			pt.z -= 1.0;
		}
		super(prim,new SkyboxMaterial(t), p);
	}
	
	override function sync( ctx : RenderContext) {
		x = ctx.camera.pos.x;
		y = ctx.camera.pos.y;
		z = ctx.camera.pos.z;
		setScale( 4.0 );
		super.sync(ctx);
	}
	
	override function draw( ctx : RenderContext ) {
		
		super.draw(ctx);
	}
}

