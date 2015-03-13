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
import hxd.BytesBuffer;
import hxd.Float32;
import hxd.Pixels;
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
			
			function fragment( tex : Texture, times:Float4, strengths:Float4 ) {
				var tout = tex.get(tuv.xy);
				
				var uv = tuv;
				uv.x += uv.y * 0.15;//0.15 => pente de la bande
				
				tout = shine(times.x, 0.5 * strengths.x, uv, tout);
				tout = shine(times.y, 0.5 * strengths.y, uv, tout);
				tout = shine(times.z, 0.5 * strengths.z, uv, tout);
				tout = shine(times.w, 0.5 * strengths.w, uv, tout);
				
				out = tout;
			}
			
			function shine(time:Float, midwide:Float, uv:Float2, col:Float4):Float4 {
				var inRange = (uv.x - (time - midwide)) * (time + midwide - uv.x);//>0 si dedans  <0 autrement
				var inRangeNormalized = (inRange + abs(inRange))/(inRange+inRange);//1 si dedans, 0 autrement
				col.rgb = mix3( col.rgb, col.rgb / luminance(col.rgb), inRangeNormalized );
				return col;
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
			
			function luminance( c:Float3 ):Float {
				return dot( c, vec3(0.22, 0.707, 0.071) );
			}
			
			//Experimental, à vérifier  si jamais ca peut etre valide et utile !
			function rgb2hsv(c:Float3):Float3 {
				var k:Float4 = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
				var p:Float4 = mix4(vec4(c.b, c.g, k.w, k.z), vec4(c.g, c.b, k.x, k.y), step(c.b, c.g));
				var q:Float4 = mix4(vec4(p.x, p.y, p.w, c.r), vec4(c.r, p.y, p.z, p.x), step(p.x, c.r));
				
				var d:Float = q.x - min(q.w, q.y);
				var e:Float = 1.0e-10;
				return [abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x];
			}
			function hsv2rgb(c:Float3):Float3 {
				var k:Float4 = [1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0];
				var p:Float3 = abs(frac(c.xxx + k.xyz) * 6.0 - k.www);
				return c.z * mix3(k.xxx, clamp3(p - k.xxx, 0.0, 1.0), c.y);
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
		// normal does the alpha blending trick with pre-multiplied alpha for us (if texture has the flag !!)
		blendMode = Normal;
	}
	
	override function setup( ctx : h3d.scene.RenderContext ) {
		super.setup(ctx);
		pshader.tex = tex;
		pshader.mproj = ortho;
		//largeur des bandes
		var bandes = new h3d.Vector (1 / 10, 1 / 15, 1 / 20, 1 / 30);
		pshader.strengths = bandes;
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
	public function new(tex:Texture, parent)
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
	var times : h3d.Vector;
	var speeds : h3d.Vector;
	var scene : Scene;
	var sprite  : Sprite;
	
	function new() {
		times = new h3d.Vector();
		speeds = new h3d.Vector(0.002, 0.01, 0.008, 0.005);
		engine = new h3d.Engine();
		engine.debug = true;
		engine.backgroundColor = 0xFF000000;
		engine.onReady = start;
		engine.init();
	}
	
	function start() {
		scene = new Scene();
		function onLoaded() {
			var tex :Texture = Texture.fromAssets("assets/logo.png");
			sprite = new Sprite(tex, scene);
			update();
			hxd.System.setLoop(update);
			trace("looping!");
		}
		onLoaded();
	}
	
	function update() {	
		times.add(speeds, times);
		times.x %= 1.0;
		times.y %= 1.0;
		times.z %= 1.0;
		times.w %= 1.0;
		sprite.sm.pshader.times = times;
		engine.render(scene);
		engine.restoreOpenfl();
	}
	
	static function main() {
		new Demo();
	}
}