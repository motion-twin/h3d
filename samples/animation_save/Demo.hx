import flash.Lib;
import flash.ui.Keyboard;
import flash.utils.ByteArray;
import hxd.fmt.h3d.MaterialWriter;

import hxd.fmt.h3d.AnimationWriter;
import hxd.fmt.h3d.GeometryWriter;
import hxd.fmt.h3d.SkinWriter;
import hxd.fmt.h3d.Data;
import hxd.fmt.h3d.Tools;

import h3d.anim.Animation;
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
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.Log;
import haxe.Serializer;
import haxe.Unserializer;
import hxd.BitmapData;
import hxd.ByteConversions;
import hxd.Key;
import hxd.Pixels;
import hxd.Profiler;
import hxd.res.Embed;
import hxd.res.EmbedFileSystem;
import hxd.res.LocalFileSystem;
import hxd.System;
import openfl.Assets;

import hxd.fmt.h3d.AnimationReader;
import hxd.fmt.h3d.AnimationWriter;

import hxd.fmt.h3d.GeometryReader;
import hxd.fmt.h3d.GeometryWriter;

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
		scene = new Scene();
		
		var axis = new Axis();
		scene.addPass(axis);
		
		loadFbx();
		
		update();
		hxd.System.setLoop(update);
		
		
	}
	
	function loadFbx(){

		//var file = Assets.getText("assets/Skeleton01_anim_attack.FBX");
		var file = Assets.getText("assets/BaseFighter.FBX");
		loadData(file);
	}
	
	var curFbx : h3d.fbx.Library=null;
	var curData : String = "";
	
	function loadData( data : String, newFbx = true ) {
		
		hxd.fmt.h3d.Tools.test();
		
		var t0 = haxe.Timer.stamp();
		
		curFbx = new h3d.fbx.Library();
		
		curData = data;
		var fbx = h3d.fbx.Parser.parse(data);
		curFbx.load(fbx);
		var frame = 0;
		var o : h3d.scene.Object = null;
		scene.addChild(o=curFbx.makeObject( function(str, mat) {
			var tex = Texture.fromBitmap( BitmapData.fromNative(Assets.getBitmapData("assets/map.png", false)) );
			if ( tex == null ) throw "no texture :-(";
			
			var mat = new h3d.mat.MeshMaterial(tex);
			mat.lightSystem = null;
			mat.culling = Back;
			mat.blend(SrcAlpha, OneMinusSrcAlpha);
			mat.depthTest = h3d.mat.Data.Compare.Less;
			mat.depthWrite = true; 
			return mat;
		}));
		
		setSkin();
		
		scene.traverse(function(obj){
			var mesh = Std.instance(obj, h3d.scene.Skin);
			if (mesh == null) return;
			
			var output = new BytesOutput();
			
			//do the mesh
			{
				var fbxPrim  = Std.instance(mesh.primitive,h3d.prim.FBXModel);
				if (fbxPrim == null) return;
				
				var writer = new hxd.fmt.h3d.GeometryWriter(output);
				var data = writer.fromFbx(fbxPrim);
				
				trace( "mesh:"+haxe.Serializer.run( data ) );
			}
			
			//do the material
			{
				var mat = Std.instance( mesh.material, MeshMaterial );
				if ( mat == null ) return;
				
				var writer = new MaterialWriter( output);
				var data = writer.make( mat );
				
				trace( "mat:"+haxe.Serializer.run( data ) );
			}
			
			//do the skin
			{
				var skin = mesh.skinData;
				if ( skin == null ) return;
				
				var writer : SkinWriter = new SkinWriter( output );
				var data = writer.make( skin );
				
				trace( "skin:"+haxe.Serializer.run( data ) );
			}
			
		});
		
		traceScene( scene );
		
		var t1 = haxe.Timer.stamp();
		
		trace("time to load " + (t1 - t0) + "s");
	}
	
	
	function traceScene(s:h3d.scene.Object, n = 0 ) {
		trace("depth:" + n + "<" + Std.string(Type.getClassName(Type.getClass(s))) + "> -- " + s.name);
		
		for ( a in s.animations ) {
			trace("A--" +a.name);
		}
		
		for ( c in s )
			traceScene( c, n + 1 );
	}
	
	static public var animMode : h3d.fbx.Library.AnimationMode = h3d.fbx.Library.AnimationMode.LinearAnim;
	function setSkin() {
		
		var t0 = haxe.Timer.stamp();
		var anim = curFbx.loadAnimation(animMode);
		var t1 = haxe.Timer.stamp();
		trace("time to load anim " + (t1 - t0) + "s");
		
		var t0 = haxe.Timer.stamp();
		var aData = anim.toData();
		var t1 = haxe.Timer.stamp();
		trace("time to data-fy anim " + (t1 - t0) + "s");
		
		var t0 = haxe.Timer.stamp();
		var unData = Animation.make( aData );
		var t1 = haxe.Timer.stamp();
		trace("time to undata-fy anim " + (t1 - t0) + "s");
		
		
			
		var out = new BytesOutput();
		var builder = new hxd.fmt.h3d.AnimationWriter(out);
		builder.write(anim);
		
		var bytes = out.getBytes();
		
		#if flash
		var f = new flash.net.FileReference();
		var ser = Serializer.run(bytes.toString());
		f.save( ByteConversions.bytesToByteArray( bytes) );
		
		var bi = new BytesInput(bytes);
		var bAnim = new hxd.fmt.h3d.AnimationReader( bi ).read();
		
		if ( anim != null )
			anim = scene.playAnimation(bAnim);
			
		#elseif sys
		sys.io.File.saveBytes( anim.name+".h3d.anim", bytes );
		
		var v = new hxd.fmt.h3d.AnimationReader( new BytesInput( sys.io.File.getBytes(anim.name+".h3d.anim") ));
		var nanm = v.read();
		
		if ( anim != null )
			anim = scene.playAnimation(nanm);
		#end
		
	}
	
	var fr = 0;
	function update() {	
		hxd.Profiler.end("Test::render");
		hxd.Profiler.begin("Test::update");
		var dist = 50;
		var height = 0;
		//time += 0.005;
		//time = 0;
		scene.camera.pos.set(Math.cos(time) * dist, Math.sin(time) * dist, height);
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