import flash.Lib;
import h3d.Engine;
import h3d.impl.Shader;
import h3d.mat.Material;
import h3d.mat.MeshMaterial;
import h3d.mat.Texture;
import h3d.prim.Plan2D;
import h3d.prim.Primitive;
import h3d.scene.CustomObject;
import h3d.scene.Scene;
import h3d.Vector;
import hxd.BitmapData;
import openfl.Assets;

@:keep
class SpriteShader extends Shader{
	
	#if flash 
		static var SRC = {
			var input : {
				pos : Float3,
				uv : Float2,
			};
			
			var tuv : Float2;
			function vertex(mproj:Matrix) {
				out = input.pos.xyzw * mproj;
				tuv =  input.uv;
			}
			
			function fragment( tex : Texture, time:Float, strength:Float, waves:Float ) {
				var uv = tuv.xy;
				var impact = sin(uv.x*3.14);
				var distortion = strength * sin(time + uv.y * waves * 3.14);
				
				uv.x += uv.x * impact * distortion;
				
				out = tex.get(uv.xy);
			}
		};
	#else
		#error "fuck";
	#end
}


@:keep
class SpriteMaterial extends Material {
	public var tex : Texture;
	public var pshader : SpriteShader;
	var ortho : h3d.Matrix;
	public function new(tex) {
		this.tex = tex;
		pshader = new SpriteShader();
		
		ortho = new h3d.Matrix();
		var w = Lib.current.stage.stageWidth;
		var h = Lib.current.stage.stageHeight;
		ortho.makeOrtho(Lib.current.stage.stageWidth, Lib.current.stage.stageHeight);
		
		super(pshader);
		culling = None;
		depthTest = h3d.mat.Data.Compare.Always;
		depthWrite = false;
		blendMode = None;
	}
	
	override function setup( ctx : h3d.scene.RenderContext ) {
		super.setup(ctx);
		pshader.tex = tex;
		pshader.mproj = ortho;
		pshader.waves = 5;
		pshader.strength = .15;
	}
}

@:publicFields
class CustomPlan2D extends Plan2D {
	
	var x : Float;
	var y : Float;
	var z : Float;
	
	var width : Float;
	var height : Float;
	
	override function alloc( engine : h3d.Engine ) {
		var v = new hxd.FloatBuffer();
		
		v.push(x);
		v.push(y);
		v.push(z);
		
		v.push(0);
		v.push(0);

		v.push(x);
		v.push(y+height);
		v.push(z);
		
		v.push(0);
		v.push(1);

		v.push(x+width);
		v.push(y);
		v.push(z);
		
		v.push(1);
		v.push(0);

		v.push(x+width);
		v.push(y+height);
		v.push(z);
		
		v.push(1);
		v.push(1);
		
		buffer = engine.mem.allocVector(v,  3 + 2, 4);
	}
}

class Sprite extends CustomObject {
	
	public var tex(get,set) : Texture;
	public var sm:SpriteMaterial;
	public function new(tex,parent)
	{
		var prim = new CustomPlan2D();
		prim.x = 1;
		prim.y = 4;
		prim.z = 0;
		prim.width = 200;
		prim.height = 150;
		
		super(prim, sm = new SpriteMaterial(tex),parent);
	}	
	
	function get_tex() {
		return sm.tex;
	}
	
	function set_tex(v) {
		return sm.tex = v;
	}
}

class Demo {
	
	var engine : h3d.Engine;
	var time : Float;
	var scene : Scene;
	var sprite  : Sprite;
	
	function new() {
		time = 0;
		engine = new h3d.Engine();
		engine.debug = true;
		engine.backgroundColor = 0xFFcd20cd;
		engine.onReady = start;
		engine.init();
	}
	
	
	function start() {
		scene = new Scene();
		
		function onLoaded( bmp : hxd.BitmapData) {
			var tex :Texture = Texture.fromBitmap( bmp);
			sprite = new Sprite(tex,scene);
			update();
			hxd.System.setLoop(update);
			trace("looping!");
		}
		
		onLoaded( BitmapData.fromNative( Assets.getBitmapData( "assets/batman.png")));
	}
	
	function update() {	
		time += 0.025;
		sprite.sm.pshader.time = time;
		engine.render(scene);
		engine.restoreOpenfl();
	}
	
	static function main() {
		new Demo();
	}
}