import h3d.mat.Material;
import h3d.mat.MeshMaterial;
import h3d.mat.Texture;
import h3d.scene.Scene;
import h3d.scene.Mesh;
import h3d.Vector;
import haxe.Log;
import hxd.BitmapData;
import hxd.Key;
import hxd.System;
import openfl.Assets;
using StringTools;

class Demo {
	
	var engine : h3d.Engine;
	var time : Float;
	var scene : Scene;
	
	//map must reside in the "asset" directory
	//MODIFY CAMERA POSITION HERE
	//PRESS ENTER to dump cam pos
	static var cameraPosition : h3d.Vector 	= new h3d.Vector(15.6 /*x*/, 15.6, 2/*height*/);	
	
	//add rotation here
	static var rotation = 0.0; 
	static var meshName 					= "assets/VikRing.FBX";
	
	/**
	 * if mapName == null, maps are automatically fetched
	 */
	static var mapName 						= null;
	
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
		scene.addChild(o = curFbx.makeObject( function(str, mat) {
			
			var texName = mapName != null?mapName:
			{
				str = str.replace("\\", "/");
				str = str.replace("//", "/");
				str="assets/"+str;
			};
			
			//MODIFY TEXTURE FILTERS HERE
			var bmp = Assets.getBitmapData( texName, false);
					
			trace("Loading texture: "+str+" success:"+(bmp!=null));
			if ( bmp != null) {
				var filters = [
					//mt.deepnight.Color.getContrastFilter(0.5),
					//mt.deepnight.Color.getSaturationFilter(0.5),
					//mt.deepnight.Color.getBrightnessFilter(0.5),
					//mt.deepnight.Color.getColorizeFilter(0xFF00FF,1.0,1.0),
				];
				
				for( f in filters)
					bmp.applyFilter(bmp, bmp.rect, new flash.geom.Point(0,0), f);
			}
			
			var tex = Texture.fromBitmap( BitmapData.fromNative( bmp ) );
			if ( tex == null ) throw "no texture :-(";
			
			var mat = new h3d.mat.MeshMaterial(tex);
			mat.lightSystem = null;
			mat.culling = Front;
			//mat.culling = Front;
			mat.blend(SrcAlpha, OneMinusSrcAlpha);
			mat.depthTest = h3d.mat.Data.Compare.Less;
			//mat.depthTest = h3d.mat.Data.Compare.Always;
			mat.depthWrite = true; 
			//mat.depthWrite = false; 
			return mat;
		}));
	}
	
	var aa = 0.0;
	
	var oz = 0.0;
	var fr = 0;
	function update() {	
		trace("New frame !");
		var cp = cameraPosition;
		scene.camera.pos.set(cp.x * Math.sin(rotation), cp.y * Math.cos(rotation), cp.z + oz);
		
		var v = 0.1;
		
		if ( hxd.Key.isDown( hxd.Key.CTRL )) {
			if ( hxd.Key.isDown( hxd.Key.UP)) 		{ cp.x -= v; cp.y -= v; }
			if ( hxd.Key.isDown( hxd.Key.DOWN)) 	{ cp.x += v; cp.y += v; }
		}
		else {
			if ( hxd.Key.isDown( hxd.Key.UP)) 		oz += v;
			if ( hxd.Key.isDown( hxd.Key.DOWN)) 	oz -= v;
		}
		
		if ( hxd.Key.isDown( hxd.Key.LEFT)) 	rotation += v;
		if ( hxd.Key.isDown( hxd.Key.RIGHT)) 	rotation -= v;
		
		if ( hxd.Key.isReleased( hxd.Key.ENTER)) {
			trace("curCamPos:" + cameraPosition);
			trace("curRotation:"+rotation);
		}
		
		if ( fr>10 && hxd.Key.isReleased( hxd.Key.R)) 	{
			aa = 0.033;
		}
		
		rotation += aa;
			
		engine.render(scene);
		engine.restoreOpenfl();
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