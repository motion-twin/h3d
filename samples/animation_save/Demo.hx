import flash.Lib;
import flash.ui.Keyboard;
import flash.utils.ByteArray;

import hxd.fmt.h3d.MaterialWriter;
import hxd.fmt.h3d.AnimationWriter;
import hxd.fmt.h3d.GeometryWriter;
import hxd.fmt.h3d.SkinWriter;

import hxd.fmt.h3d.MaterialReader;
import hxd.fmt.h3d.AnimationReader;
import hxd.fmt.h3d.GeometryReader;
import hxd.fmt.h3d.SkinReader;

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
	}
	
	function start() {
		scene = new Scene();
		loadFbx();
		update();
		hxd.System.setLoop(update);
	}
	
	function loadFbx(){
		//var file = Assets.getText("assets/Skeleton01_anim_attack.FBX");
		//var file = Assets.getText("assets/BaseFighter.FBX");
		var file = Assets.getText("assets/sphereMorph.FBX");
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
			var tex = Texture.fromAssets( "assets/map.png" );
			
			if ( tex == null ) throw "no texture :-(";
			
			var mat = new h3d.mat.MeshMaterial(tex);
			mat.lightSystem = null;
			mat.culling = Back;
			mat.blend(SrcAlpha, OneMinusSrcAlpha);
			mat.depthTest = h3d.mat.Data.Compare.Less;
			mat.depthWrite = true; 
			return mat;
		}));
		
		//setSkin();
		
		scene.traverse(function(obj){
			var mesh = Std.instance(obj, h3d.scene.Skin);
			if (mesh == null) return;
			
			var output = new BytesOutput();
			
			//do the mesh
			{
				var fbxPrim  = Std.instance(mesh.primitive,h3d.prim.FBXModel);
				if (fbxPrim == null) return;
				
				var data = GeometryWriter.fromFbx(fbxPrim);
				
				trace( "mesh:" + haxe.Serializer.run( data ) );
				
				var newPrim = GeometryReader.make(data);
				
				var p = 0;
			}
			
			//do the material
			{
				var mat = Std.instance( mesh.material, MeshMaterial );
				if ( mat == null ) return;
				
				var data : hxd.fmt.h3d.Material = MaterialWriter.make( mat );
				
				trace( "mat:" + haxe.Serializer.run( data ) );
				
				MaterialReader.TEXTURE_LOADER = function(path) {
					return h3d.mat.Texture.fromAssets(path);
				};
				
				var newMat = MaterialReader.make(data);
				
				/*
				for ( f in Type.getInstanceFields( MeshMaterial )) {
					trace("comparing:"+f+" cmp:"+Reflect.compare( Reflect.field(mat,f), Reflect.field(newMat,f)));
				}
				*/
				var a = 0;
			}
			
			//do the skin
			{
				var skin = mesh.skinData;
				if ( skin == null ) return;
				
				var data = SkinWriter.make( skin );
				
				trace( "skin:" + haxe.Serializer.run( data ) );
				
				var newSkin = SkinReader.make( data );
			}
			
			{
				var writer : hxd.fmt.h3d.Writer = new hxd.fmt.h3d.Writer( output );
				var data = writer.add( mesh );
				
				traceScene(mesh);
				trace("model:" + haxe.Serializer.run( data ) );
				
				var l = new hxd.fmt.h3d.Reader(null).makeLibrary(data);
				var m = 0;
				
				for ( c in l.models) {
					trace("reloaded:"+c.name+" type:"+Type.getClass(c));
				}
				
				var m0 = l.models[0];
				scene.addChild( m0 );
				//m0.x += 10;
				//scene.x += 10;
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