import flash.Lib;
import flash.ui.Keyboard;
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

using StringTools;

class Demo {
	
	var engine : h3d.Engine;
	var time : Float;
	var scene : Scene;
	var curFbx : h3d.fbx.Library = null;
	var scale = 5;
	function new() {
		time = 0;
		engine = new h3d.Engine();
		engine.debug = true;
		engine.backgroundColor = 0xFF203020;
		engine.onReady = start;
		
		engine.init();
		hxd.Key.initialize();
	}
	
	function start() {
		scene = new Scene();
		
		loadFbx();
		
		update();
		hxd.System.setLoop(update);
	}
	
	function loadFbx(){
		//var file = Assets.getBytes("assets/Skeleton01_anim_attack.h3d");
		//loadH3DData( hxd.ByteConversions.byteArrayToBytes(file));
		
		//var file = Assets.getBytes("assets/Skeleton01_anim_attack.FBX");
		var file = Assets.getBytes("assets/BaseFighter.FBX"); scale = 1;
		loadFBXData(file.toString());
	}
	
	function loadH3DData(data:haxe.io.Bytes) {
		var m = new hxd.fmt.h3d.Reader( new haxe.io.BytesInput(data) );
		hxd.fmt.h3d.MaterialReader.DEFAULT_TEXTURE_LOADER = function(path) {
			return h3d.mat.Texture.fromAssets(path);
		};
		var lib = m.read();
		scene.addChild( lib.root );
		
		var a = 0;
	}
	
	var fbxs = [];
	function loadFBXData( data : String) {
		
		var t0 = haxe.Timer.stamp();
		curFbx = new h3d.fbx.Library();
		var fbx = h3d.fbx.Parser.parse(data);
		curFbx.load(fbx);
		var frame = 0;
		
		for ( i in 0...5) {
			var o : h3d.scene.Object = null;
			o = curFbx.makeObject( function(str, mat) {
				if ( i == 4 )
					return null;
					
				var texName = {
					str = str.replace("\\", "/");
					str = str.replace("//", "/");
					str = str.replace("//", "/");
				};
				
				//var tex = Texture.fromBitmap( BitmapData.fromNative(Assets.getBitmapData("assets/hxlogo.png", false)) );
				var tex = Texture.fromBitmap( BitmapData.fromNative(Assets.getBitmapData("assets/"+texName, false)) );
				if ( tex == null ) throw "no texture :-(";
				
				var mat = new h3d.mat.MeshMaterial(tex);
				mat.lightSystem = null;
				mat.culling = Back;
				mat.setBlendMode( Normal );
				mat.killAlpha = true;
				mat.depthTest = h3d.mat.Data.Compare.Less;
				mat.depthWrite = true; 
				
				return mat;
			});
			
			setSkin(o);
			o.setPos( - i * scale * 2, 0, 0);

			if ( i == 0 ) {
				var o = o.clone();
				scene.addChild(o);
				setSkin(o);
				o.setPos( - i * scale * 2, 0, 0);
				
				o.traverse(function(c){
					if ( c.isMesh()) {
						var mesh = c.toMesh();
						var fbx = Std.instance(mesh.primitive, h3d.prim.FBXModel );
						var mat =  mesh.material;
						mat.isOutline = true;
						mat.outlineColor = 0xFF00FF00;
						mat.outlineSize = 0.2;
						mat.culling = Front;
						mat.depthWrite = false;
						mat.setBlendMode( Normal );
						fbxs.push(fbx);
					}
				});
			}
			
			if ( i == 1 ) {
				o.traverse(function(c){
					if( c.isMesh()){
						var mesh = c.toMesh();
						var fbx = Std.instance(mesh.primitive, h3d.prim.FBXModel );
						var mat =  mesh.material;
						mat.rimColor = new h3d.Vector(0.8, 0.0, 0.0, 3.0);
						fbxs.push(fbx);
					}
				});
			}
			
			scene.addChild(o);
		}
		
		
		var t1 = haxe.Timer.stamp();
		trace("time to load " + (t1 - t0) + "s");
	}
	
	static public var animMode : h3d.fbx.Library.AnimationMode = h3d.fbx.Library.AnimationMode.LinearAnim;
	function setSkin(obj:h3d.scene.Object) {
		hxd.Profiler.begin("loadAnimation");
		var anim = curFbx.loadAnimation(animMode);
		hxd.Profiler.end("loadAnimation");
		
		if ( anim != null )
			anim = obj.playAnimation(anim);
		else {
			trace("CANNOT LOAD ANY ANIMATION");
		}
	}
	
	var fr = 0;
	function update() {	
		hxd.Profiler.end("Test::render");
		hxd.Profiler.begin("Test::update");
		//var dist = 60;
		//var height = 10.0;
		
		var dist = 5 * scale * 2;
		var height = 1.5 * scale * 2;
		
		time += 0.005;
		
		scene.camera.pos.set(Math.cos(time) * dist, Math.sin(time) * dist, height);
		engine.render(scene);
		hxd.Profiler.end("Test::update");
		hxd.Profiler.begin("Test::render");
	
		if ( Key.isDown( Key.ENTER) ) {
			var s = hxd.Profiler.dump(); 
			if ( s != ""){
				trace( s );
				hxd.Profiler.clean();
			}
		}
		
		if ( Key.isDown( Key.A) )
			for ( fbx in fbxs ) {
				var a = [2.0,2.0];
				fbx.setShapeRatios( haxe.ds.Vector.fromArrayCopy(a) );
			}
		
		if ( Key.isDown( Key.Z) )
			for ( fbx in fbxs ) {
				var a = [0.0];
				fbx.setShapeRatios( haxe.ds.Vector.fromArrayCopy(a) );
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