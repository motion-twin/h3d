import flash.Lib;

import h3d.Engine;
import h3d.impl.Shader;
import h3d.mat.Material;
import h3d.mat.Texture;
import h3d.prim.Primitive;
import h3d.scene.CustomObject;
import h3d.scene.Scene;
import h3d.Vector;
import mt.MLib;

@:keep
class ParticleShader extends Shader{
	
	#if flash 
		static var SRC = {
			
			var input : {
				pos : Float2,
				uv : Float2,
				speed:Float2,
				rotation:Float,
				mass:Float,
				life:Float,
			};
			
			var fuv : Float2;
			function vertex(mmodel:Matrix, mproj:Matrix, gravity:Float2, damping:Float2, time:Float) {
				var p = [0, 0, 0, 1];
				var dt = (time - input.life);
				var s = input.speed;
				var r = input.rotation;
				// angular speed
				var cang = cos(dt * r);
				var sang = sin(dt * r);
				p.x = (input.pos.x * cang + input.pos.y * sang);
				p.y = (-input.pos.x * sang + input.pos.y * cang);
				// acceleration
				s += (gravity / input.mass) * dt;
				// damping
				s *= damping;
				// move
				p.xy += s * dt;
				// projection
				out = p * mmodel * mproj;
				fuv =  input.uv;
			}
			
			function fragment( tex : Texture ) {
				out = tex.get(fuv.xy);
			}
		};
	
	#else
		#error "not for now"
	#end
}

@:keep
class ParticleMaterial extends Material {
	public var tex : Texture;
	public var pshader : ParticleShader;
	var ortho : h3d.Matrix;
	public function new(tex) {
		this.tex = tex;
		pshader = new ParticleShader();
		//bon on le fait ici mais bon...
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
		//may not be done here !
		pshader.gravity = new h3d.Vector(0, 0.005);
		pshader.damping = new h3d.Vector(.95, .95);
		pshader.mproj = ortho;
	}
}

@:publicFields
class Particle extends h3d.prim.Primitive {
	
	public function new() {
		
	}
	
	override function alloc( engine : h3d.Engine ) {
		var buf = new hxd.FloatBuffer();
		
		inline function pushVertex(x:Float, y:Float, u:Float, v:Float, vx:Float, vy:Float, vr:Float, mass:Float, time:Float) {
			buf.push(x); buf.push(y);
			buf.push(u); buf.push(v);
			buf.push(vx); buf.push(vy);
			buf.push(vr);
			buf.push(mass);
			buf.push(time);
		}
		inline function makeQuad(size:Float, vx:Float, vy:Float, vr:Float, mass:Float, time:Float) {
			var s2 = size / 2;
			pushVertex(-s2, -s2, 0, 1, vx, vy, vr, mass, time);
			pushVertex(-s2,  s2, 0, 0, vx, vy, vr, mass, time);
			pushVertex( s2, -s2, 1, 1, vx, vy, vr, mass, time);
			pushVertex( s2,  s2, 1, 0, vx, vy, vr, mass, time);
		}
		
		var stride = 2 + 2 + 2 + 1 + 1 + 1;
		var numQuads = 2000;//4000max
		for ( i in 0...numQuads )
			makeQuad(10, MLib.frandRangeSym(1), -MLib.frandRange(1,2), MLib.frandRangeSym(0.2), MLib.frandRange(1, 2), MLib.randRange(1,100));
		
		buffer = engine.mem.allocVector(buf, stride, Std.int(buf.length / stride));
	}
	
	override function render(engine:h3d.Engine) {
		if( buffer == null ) alloc(engine);
		engine.renderQuadBuffer(buffer);
	}
}

class ParticleSystem extends CustomObject {
	public var sm:ParticleMaterial;
	
	public function new(tex, parent) {
		var prim = new Particle();
		super(prim, sm = new ParticleMaterial(tex), parent);
	}	
	
	override function draw( ctx : h3d.scene.RenderContext ) {
		//on passe la matrice du modele au shader
		sm.pshader.mmodel = absPos;
		super.draw(ctx);
	}
}

class Demo {
	
	var engine : h3d.Engine;
	var time : Float;
	var scene : Scene;
	
	var system  : ParticleSystem;
	
	function new() {
		time = 0;
		engine = new h3d.Engine();
		engine.debug = true;
		engine.backgroundColor = 0xFFcd20cd;
		engine.onReady = start;
		engine.init();
	}
	
	function start() {
		trace("start !");
		
		scene = new Scene();
		function onLoaded() {
			var bmp : hxd.BitmapData = hxd.BitmapData.fromNative(openfl.Assets.getBitmapData( "assets/batman.png"));
			//on positionne notre petit particle system
			system = new ParticleSystem(Texture.fromBitmap(bmp), scene);
			system.x = 400;
			system.y = 250;
			
			update();
			hxd.System.setLoop(update);
			trace("looping!");
		}
		onLoaded();
	}
	
	function update() {	
		time += 1;
		system.sm.pshader.time = time;
		//visiblement pas besoin, c'est invalidé directement...
		//system.material.shader.invalidate();
		
		engine.render(scene);
		engine.restoreOpenfl();
	}
	
	static function main() {
		#if flash
		haxe.Log.setColor(0xFF0000);
		#end
		new Demo();
	}
	
}