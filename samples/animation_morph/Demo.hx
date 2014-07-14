import flash.Lib;
import flash.ui.Keyboard;
import h3d.anim.MorphFrameAnimation;
import h3d.impl.Shaders.LineShader;
import h3d.impl.Shaders.PointShader;
import h3d.mat.Material;
import h3d.mat.MeshMaterial;
import h3d.mat.Texture;
import h3d.scene.Scene;
import h3d.scene.Mesh;
import h3d.Vector;
import haxe.CallStack;
import haxe.io.Bytes;
import haxe.Log;
import hxd.BitmapData;
import hxd.Key;
import hxd.Pixels;
import hxd.Profiler;
import hxd.res.Embed;
import hxd.res.EmbedFileSystem;
import hxd.res.LocalFileSystem;
import hxd.System;
import openfl.Assets;


class Axis implements h3d.IDrawable {

	public function new() {
	}
	
	public function render( engine : h3d.Engine ) {
		engine.line(0,0,0,0,2,0, 0xFFFF0000);
	}
	
}

class LineMaterial extends Material{
	var lshader : LineShader;

	public var start(get,set) : h3d.Vector;
	public var end(get,set) : h3d.Vector;
	public var color(get,set) : Int;
	
	public function new() {
		lshader = new LineShader();
		super(lshader);
		depthTest = h3d.mat.Data.Compare.Always;
		depthWrite = false;
	}
	
	override function setup( ctx : h3d.scene.RenderContext ) {
		super.setup(ctx);
		lshader.mproj = ctx.engine.curProjMatrix;
		depthTest = h3d.mat.Data.Compare.Always;
		depthWrite = false;
	}
	
	public inline function get_start() return lshader.start;
	public inline function set_start(v) return lshader.start = v;
	
	public inline function get_end() return lshader.end;
	public inline function set_end(v) return lshader.end = v;
	
	public inline function get_color() return lshader.color;
	public inline function set_color(v) return lshader.color=v;
}

class Demo {
	
	var engine : h3d.Engine;
	var time : Float;
	var scene : Scene;
	
	function new() {
		time = 0;
		engine = new h3d.Engine();
		engine.debug = true;
		engine.backgroundColor = 0xFF203020;
		engine.onReady = start;
		
		engine.init();
		hxd.Key.initialize();
		Profiler.minLimit = -1.0;
		trace("new()");
	}
	
	
	function addLine(start,end,?col=0xFFffffff, ?size) {
		var mat = new LineMaterial();
		var line = new h3d.scene.CustomObject(new h3d.prim.Plan2D(), mat, scene);
		line.material.blend(SrcAlpha, OneMinusSrcAlpha);
		line.material.depthWrite = false;
		line.material.culling = None;
		
		mat.start = start;
		mat.end = end;
		mat.color = 0xFFFF00FF;
	}	
	
	function start() {
		scene = new Scene("root");
		
		var axis = new Axis();
		scene.addPass(axis);
		
		loadFbx();
		
		update();
		hxd.System.setLoop(update);
	}
	
	function loadFbx(){

		var file = Assets.getText("assets/sphereMorph.FBX");
		//var file = Assets.getText("assets/BaseFighter.FBX");
		loadData(file);
	}
	
	var curFbx : h3d.fbx.Library=null;
	var curData : String = "";
	
	function loadData( data : String, newFbx = true ) {
		curFbx = new h3d.fbx.Library();
		
		curData = data;
		var fbx = h3d.fbx.Parser.parse(data);
		curFbx.load(fbx);
		var frame = 0;
		var o : h3d.scene.Object = null;
		
		function loop(n:h3d.scene.Object) {
		trace(n.name);
		for ( c in n.childs ) 
			loop(c);
		}
		
		loop( scene );
		
		scene.addChild(o=curFbx.makeObject( function(str, mat) {
			var tex = Texture.fromBitmap( BitmapData.fromNative(Assets.getBitmapData("assets/map.png", false)) );
			if ( tex == null ) throw "no texture :-(";
			
			var mat = new h3d.mat.MeshMaterial(tex);
			mat.lightSystem = null;
			mat.culling = None;
			mat.blend(SrcAlpha, OneMinusSrcAlpha);
			mat.depthTest = h3d.mat.Data.Compare.Less;
			mat.depthWrite = true; 
			return mat;
		}));
		
	
		loop( scene );
		
		setSkin();
	}
	
	static public var animMode : h3d.fbx.Library.AnimationMode = h3d.fbx.Library.AnimationMode.FrameAnim;
	static public var manim : h3d.anim.Animation;
	function setSkin() {
		
		function loop(n:h3d.scene.Object) {
			trace(n.name);
			for ( c in n.childs ) 
				loop(c);
		}
		loop( scene );
			
		if ( true ){ // there are animations to find
			var morphAnim : MorphFrameAnimation = curFbx.loadMorphAnimation(animMode);
			if ( morphAnim != null )
			{
				if(true){
					//dynamic play
					var anim : h3d.anim.Animation = scene.playAnimation(morphAnim);
					
					//anim.pause = true;
					anim.loop = true;
				//	anim.setFrame(1);
					manim = anim;
				}
				else{
					//static play
					morphAnim.manualBind( scene );
					morphAnim.writeTarget( Std.int(morphAnim.frameCount * 3 / 4 ));
				}
			}
		}
		else { //if there are only blendShape to interpret
			var cs = scene.childs;
			function loop(n:h3d.scene.Object) {
				var mesh : h3d.scene.Mesh = Std.is( n, h3d.scene.Mesh ) ? (cast n ) : null;
				if(mesh!=null){
					var inst : h3d.prim.FBXModel = Std.is( mesh.primitive, h3d.prim.FBXModel) ? (cast mesh.primitive ) : null;
					if ( inst!=null ) {
						if ( inst.blendShapes.length > 0 ) {
							inst.shapeRatios = [0.5,1.0,0.5];
						}
					}
				}
				for ( c in n.childs )
					loop( c );
			}
			
			for ( c in cs )
				loop(c);
		}
		
		var anim = curFbx.loadAnimation(animMode);
		if ( anim != null )
			anim = scene.playAnimation(anim,1);
	}
	
	var fr = 0;
	function update() {	
		hxd.Profiler.end("Test::render");
			hxd.Profiler.begin("Test::update");
			var dist = 5.5;
			time += 0.01;
			scene.camera.pos.set(Math.cos(time) * dist, Math.sin(time) * dist, 2);
			engine.render(scene);
			hxd.Profiler.end("Test::update");
		hxd.Profiler.begin("Test::render");
	
		//#if android if( (fr++) % 100 == 0 ) trace("ploc"); #end
		if ( Key.isDown( Key.ENTER) ) {
			var s = hxd.Profiler.dump(); 
			if ( s != ""){
				trace( s );
				hxd.Profiler.clean();
			}
		}
		
		if ( Key.isDown( Key.SPACE) ) {
			function loop(n:h3d.scene.Object) {
				trace(n.name);
				for ( c in n.childs ) 
					loop(c);
			}
			loop( scene );
		}
		
		if ( Key.isDown( Key.LEFT) ) {
			manim.setFrame( manim.frame-1);
			trace(manim.frame);
		}
		
		if ( Key.isDown( Key.RIGHT) ) {
			manim.setFrame( manim.frame + 1);
			trace(manim.frame);
		}
	}
	
	static function main() {
		var p = haxe.Log.trace;
		
		trace("STARTUP");
		#if flash
		haxe.Log.setColor(0xFF0000);
		#end
		
		trace("Booting App");
		new Demo();
		
		
	}
	
}