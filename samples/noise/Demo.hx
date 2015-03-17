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
			
			function fragment( tex : Texture, time:Float ) {
				var uv:Float2 = time * 
				80 * tuv.xy;
				var p:Float2 = uv - frac(uv);//int(uv);
				var f:Float2 = frac(uv);
				//hermite
				var h:Float2 = f * f * (3.0 - 2.0 * f);
				var n:Float = p.x + p.y * 57.0;
				var noise:Float4 = vec4(n, n + 1, n + 57.0, n + 58.0);
				noise = frac(sin(noise) * 437.585453);
				//out = vec4(1.0, 1.0, 1.0, 1.0) * lerp(lerp(noise.x, noise.y, h.x), lerp(noise.z, noise.w, h.x), h.y); 
				out = tex.get(tuv.xy) * lerp(lerp(noise.x, noise.y, h.x), lerp(noise.z, noise.w, h.x), h.y); 
			}
			
			// pour se simplifier la vie quoi
			function mix( x : Float, y : Float, v : Float ) {
				return x * (1.0 - v) + y * v;
			}
			
			function clamp( v:Float, min:Float, max:Float ) {
				return max(min, min(max, v));
			}
			
			function clamp3( v:Float3, min:Float, max:Float ) {
				return [clamp(v.x, min, max),
						clamp(v.y, min, max),
						clamp(v.z, min, max)];
			}
			
			function mix3( x : Float3, y : Float3, v : Float ) {
				return [mix(x.x, y.x, v),
						mix(x.y, y.y, v),
						mix(x.z, y.z, v)];
			}
			
			function mix4( x : Float4, y : Float4, v : Float ) {
				return [mix(x.x, y.x, v),
						mix(x.y, y.y, v),
						mix(x.z, y.z, v),
						mix(x.w, y.w, v)];
			}
			
			function vec3(x:Float, y:Float, z:Float):Float3 {
				return [x, y, z];
			}
			
			function vec4(x:Float, y:Float, z:Float, w:Float):Float4 {
				return [x, y, z, w];
			}
			
			function step(a:Float, b:Float ) {
				return a > b;
			}
			
			function lerp( x : Float, y : Float, v : Float ) {
				return x * (1 - v) + y * v;
			}
			function lerp3( a : Float3, b : Float3, v : Float ) {
				return [lerp(a.x, b.x, v), 
						lerp(a.y, b.y, v),
						lerp(a.z, b.z, v)];
			}
			function lerp4( a : Float4, b : Float4, v : Float ) {
				return [lerp(a.x, b.x, v), 
						lerp(a.y, b.y, v),
						lerp(a.z, b.z, v),
						lerp(a.w, b.w, v)];
			}

			function luminance( c:Float3 ):Float {
				return dot( c, vec3(0.22, 0.707, 0.071) );
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
	public function new(tex:Texture,parent)
	{
		var prim = new CustomPlan2D();
		prim.x = 0;
		prim.y = 0;
		prim.z = 0;
		prim.width = tex.width;
		prim.height = tex.height;
		
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
		
		function onLoaded(path:String) {
			var tex :Texture = Texture.fromAssets(path);
			sprite = new Sprite(tex,scene);
			update();
			hxd.System.setLoop(update);
			trace("looping!");
		}
		
		onLoaded("assets/logo.png");
	}
	
	function update() {	
		time += Math.random();
		sprite.sm.pshader.time = time;
		engine.render(scene);
		engine.restoreOpenfl();
	}
	
	static function main() {
		new Demo();
	}
}