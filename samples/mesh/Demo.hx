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

class Demo {
	
	var engine : h3d.Engine;
	var time : Float;
	var scene : Scene;
	
	static var cameraPosition : h3d.Vector 	= new h3d.Vector(5 /*x*/,5/*y*/,2/*height*/);	
	static var meshName 					= "assets/sphere.FBX";
	static var mapName 						= "assets/map.png";
	static var leftHand						= false;
	
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
		
		if ( leftHand ) scene.camera = new h3d.Camera(false);
		loadFbx();
		
		update();
		hxd.System.setLoop(update);
	}
	
	function loadFbx(){
		var file = Assets.getText(meshName);
		loadData(file);
	}
	
	var curFbx : h3d.fbx.Library = null;
	
	function loadData( data : String, newFbx = true ) {
		curFbx = new h3d.fbx.Library();
		var fbx = h3d.fbx.Parser.parse(data);
		curFbx.load(fbx);
		if ( leftHand ) curFbx.leftHandConvert();
		var frame = 0;
		var o : h3d.scene.Object = null;
		scene.addChild(o=curFbx.makeObject( function(str, mat) {
			var tex = Texture.fromBitmap( BitmapData.fromNative(Assets.getBitmapData( mapName, false)) );
			if ( tex == null ) throw "no texture :-(";
			
			var mat = new h3d.mat.MeshMaterial(tex);
			mat.lightSystem = null;
			mat.culling = Back;
			mat.blend(SrcAlpha, OneMinusSrcAlpha);
			mat.depthTest = h3d.mat.Data.Compare.Less;
			mat.depthWrite = true; 
			return mat;
		}));
	}
	
	var aa = 0.0;
	var a = 0.0;
	var oz = 0.0;
	var oy = 0.0;
	var ox = 0.0;
	var fr = 0;
	function update() {	
		
		var cp = cameraPosition;
		scene.camera.pos.set(cp.x * Math.sin(a) + ox, cp.y * Math.cos(a) +oy, cp.z + oz);
		
		var v = 0.2;
		
		if ( hxd.Key.isDown( hxd.Key.CTRL )) {
			if ( hxd.Key.isDown( hxd.Key.UP)) 		{ ox += v; oy += v; }
			if ( hxd.Key.isDown( hxd.Key.DOWN)) 	{ ox -= v; oy -= v; }
		}
		else {
			if ( hxd.Key.isDown( hxd.Key.UP)) 		oz += v;
			if ( hxd.Key.isDown( hxd.Key.DOWN)) 	oz -= v;
		}
		
		if ( hxd.Key.isDown( hxd.Key.LEFT)) 	a += v;
		if ( hxd.Key.isDown( hxd.Key.RIGHT)) 	a -= v;
		
		
		if ( fr>10 && hxd.Key.isReleased( hxd.Key.R)) 	{
			aa = 0.033;
		}
		
		a += aa;
			
		engine.render(scene);
		fr++;
	}
	
	static function main() {
		var p = haxe.Log.trace;
		
		#if flash
		haxe.Log.setColor(0xFF0000);
		#end
		
		new Demo();
	}
	
}