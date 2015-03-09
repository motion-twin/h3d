package h3d.scene;
import h3d.mat.MeshMaterial;
import h3d.mat.Texture;
import h3d.Matrix;
import h3d.Vector;
import openfl.display3D.textures.CubeTexture;

/*
class SkyboxShader extends h3d.impl.Shader{
	#if flash 
		static var SRC = {
			var input : {
				pos : Float3,
			};
		
			var uvw : Float3;
			
			var cubeTex : CubeTexture;
			var color : Float4;
			var hasCubeTex : Bool;
			
			function vertex(eyePos:Float4, mworld:Matrix, mproj:Matrix) {
				var vpos = input.pos.xyzw * mworld;
				out = (vpos  * mproj).xyww;
				var t = eyePos.xyz - vpos.xyz;
				uvw = -[t.x, t.z, t.y];
			}
			
			function fragment() {
				if( hasCubeTex )
					out = get(cubeTex , uvw, linear, mm_linear);
				else 
					out = color;
			}
		};
	
	#else
	static var VERTEX = "
		attribute vec3 pos;
		
		uniform vec3 eyePos;
		
		uniform mat4 mworld;
		uniform mat4 mproj;
		
		varying vec3 uvw;	
		
		void main(void) {
			vec4 vpos = vec4(pos.x, pos.y, pos.z, 1.0) * mworld;
			gl_Position = (vpos * mproj).xyww;
			vec3 t = eyePos.xyz - vpos.xyz;
			uvw = - vec3( t.x, t.z, t.y);
		}
	";
	
	static var FRAGMENT = "
		varying vec3 uvw;
		
		uniform samplerCube cubeTex;
		uniform vec4 color;
		
		void main( ) {
			#if hasCubeTex
			gl_FragColor = textureCube(cubeTex , uvw );
			#else 
			gl_FragColor = color;
			#end
		}
	";
	
	override function getConstants() {
		var cst = [];
		if ( cubeTex != null )
			cst.push("#define hasCubeTex");
		return cst;
	}
	#end
}
*/
class SkyboxMaterial extends h3d.mat.MeshMaterial{
	public var cubeTex : h3d.mat.Texture;
	public function new( t: h3d.mat.Texture ) {
		cubeTex = t;	
		super(null);
		culling = Back;
		depthTest = h3d.mat.Data.Compare.LessEqual;
		depthWrite = false;
		blendMode = None;
	}
	
	override function setup( ctx : h3d.scene.RenderContext ) {
		super.setup(ctx);
		if( cubeTex!=null && cubeTex.isCubic ){
			mshader.cubeTexture 	= cubeTex;
			mshader.hasCubeTexture 	= true;
		}
	}
}

class Skybox extends h3d.scene.Mesh {
	public var smaterial : SkyboxMaterial;
	
	public function new(?t:h3d.mat.Texture, ?p) {
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
		super(prim,smaterial=new SkyboxMaterial(t), p);
	}
	
	override function sync( ctx : RenderContext) {
		x = ctx.camera.pos.x;
		y = ctx.camera.pos.y;
		z = ctx.camera.pos.z;
		setScale( ctx.camera.zFar / Math.sqrt( 2 ) );
		super.sync(ctx);
	}
	
	override function draw( ctx : RenderContext ) {
		
		super.draw(ctx);
	}
}

