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
	
	@:generic
	function vectorSlice<T>(lthis:haxe.ds.Vector<T>, pos, len) :Array<T>{
		if ( pos < 0 ) pos = lthis.length + pos;
		var a = [];
		for ( i in pos...pos + len) {
			if( pos < lthis.length )
				a.push( lthis[i]);
		}
		return a;
	}
	
	function loadFbx(){
		//var file = Assets.getText("assets/Skeleton01_anim_attack.FBX");
		var file = Assets.getText("assets/BaseFighter.FBX");
		//var file = Assets.getText("assets/sphereMorph.FBX");
		loadData(file);
	}
	
	var curFbx : h3d.fbx.Library=null;
	var curData : String = "";
	var object:h3d.scene.Object;
	
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
		object = o;
		
		//setSkin();
	
		
		scene.traverse(function(obj){
			var skinned = Std.instance(obj, h3d.scene.Skin);
			var mesh = Std.instance(obj, h3d.scene.Mesh);
			if (mesh == null) return;
			
			var output = new BytesOutput();
			
			//do the mesh
			{
				var fbxPrim  = Std.instance(mesh.primitive,h3d.prim.FBXModel);
				if (fbxPrim == null) return;
				
				var data = GeometryWriter.fromFbx(fbxPrim);
				trace( "mesh:" + haxe.Serializer.run( data ) );
				var newPrim = GeometryReader.make(data);
				
				var b;
				var writer = new GeometryWriter( b=new haxe.io.BytesOutput());
				writer.write( data );
				var bytes = b.getBytes();

				var reader = new GeometryReader( new haxe.io.BytesInput( bytes ));
				var dataNew : hxd.fmt.h3d.Data.Geometry = reader.parse();
				
				var p = 0;
			}
			
			//do the material
			{
				var mat = Std.instance( mesh.material, MeshMaterial );
				if ( mat == null ) return;
				
				var data : hxd.fmt.h3d.Material = MaterialWriter.make( mat );
				trace( "mat:" + haxe.Serializer.run( data ) );
				MaterialReader.TEXTURE_LOADER = function(path) { return h3d.mat.Texture.fromAssets(path);};
				
				var newMat = MaterialReader.make(data);
				
				
				var b;
				var writer = new MaterialWriter( b=new haxe.io.BytesOutput());
				writer.write( data );
				var bytes = b.getBytes();
				var reader = new MaterialReader( new haxe.io.BytesInput( bytes ));
				var dataNew = reader.parse();
				var a = 0;
			}
			
			//do the skin
			if(skinned!=null)
			{
				var skin = skinned.skinData;
				if ( skin == null ) return;
				
				var data = SkinWriter.make( skin );
				trace( "skin:" + haxe.Serializer.run( data ) );
				var newSkin = SkinReader.make( data );
				
				var b;
				var writer = new hxd.fmt.h3d.SkinWriter( b=new haxe.io.BytesOutput());
				writer.write( data );
				var bytes = b.getBytes();
				var reader = new SkinReader( new haxe.io.BytesInput( bytes ));
				var dataNew = reader.parse();
				
				var a = 0;
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
				
				
			}
			
		});
		
		//traceScene( scene );
		
		var t1 = haxe.Timer.stamp();
		trace("time to load " + (t1 - t0) + "s");
		
		{
			var writer : hxd.fmt.h3d.Writer = new hxd.fmt.h3d.Writer( null );
			var bindata = writer.add( object );
			
			//trace("model:" + haxe.Serializer.run( bindata ) );
			
			MaterialReader.TEXTURE_LOADER = function(path) {
					return h3d.mat.Texture.fromAssets(path);
				};
				
			var l = new hxd.fmt.h3d.Reader(null).makeLibrary(bindata);
			
			for ( c in l.models) {
				trace("reloaded:"+c.name+" type:"+Type.getClass(c));
			}
			
			var m0 : h3d.scene.Object = l.root;
			object.parent.addChild( m0 );
			//m0.x += 3;
			//m0.y += 3;
			//m0.z += 3;
			
			trace( object.x +" => " + m0.x );
			trace( object.y +" => " + m0.y );
			trace( object.z +" => " + m0.z );
			
			trace( object.scaleX +" => " + m0.scaleX );
			trace( object.scaleY +" => " + m0.scaleY );
			trace( object.scaleZ +" => " + m0.scaleZ );
			
			trace( object.getRotation() +" => " + m0.getRotation() );
			
			trace( object.childs.map(function(c) return c.name)
			+"<>"
			+m0.childs.map(function(c) return c.name));
			
			var c1 = object.childs[0];
			var m1 = m0.childs[0];
			
			trace( c1.x +" => " + m1.x );
			trace( c1.y +" => " + m1.y );
			trace( c1.z +" => " + m1.z );
			
			trace( c1.scaleX +" => " + m1.scaleX );
			trace( c1.scaleY +" => " + m1.scaleY );
			trace( c1.scaleZ +" => " + m1.scaleZ );
			
			trace( c1.getRotation() +" => " + m1.getRotation() );
			
			var mm_c1 : h3d.scene.Mesh = Std.instance(c1,h3d.scene.Mesh);
			var mm_m1 : h3d.scene.Mesh = Std.instance(m1,h3d.scene.Mesh);
			
			trace( mm_c1.material.texture.name+" =>" + mm_m1.material.texture.name);
			
			var fbx_c1 : h3d.prim.FBXModel = Std.instance(mm_c1.primitive,h3d.prim.FBXModel); 
			var fbx_m1 : h3d.prim.FBXModel = Std.instance(mm_m1.primitive,h3d.prim.FBXModel);
			
			//scene.x += 10;
			
			trace( fbx_c1.geomCache.secShapesIndex.length + " =>" 
			+ fbx_m1.geomCache.secShapesIndex.length); 
			
			trace( fbx_c1.geomCache.pbuf.slice(0, 1) + " =>"
			+ 		fbx_m1.geomCache.pbuf.slice(0, 1) );
			
			trace( fbx_c1.geomCache.pbuf.slice(3, 1) + " =>"
			+ 		fbx_m1.geomCache.pbuf.slice(3, 1) );
			
			trace( fbx_c1.geomCache.pbuf.slice(-3, 1) + " =>"
			+ 		fbx_m1.geomCache.pbuf.slice(-3, 1) );
			
			trace( fbx_c1.geomCache.pbuf.length + " =>"
			+ 		fbx_m1.geomCache.pbuf.length );
			
			trace( fbx_c1.geomCache.tbuf.slice(3, 1) + " =>"
			+ 		fbx_m1.geomCache.tbuf.slice(3, 1) );
			
			trace( fbx_c1.geomCache.tbuf.length + " =>"
			+ 		fbx_m1.geomCache.tbuf.length );
			
			var c = fbx_c1.geomCache.idx;
			var m = fbx_m1.geomCache.idx;
			trace( c.slice(0, 1) 	+ " =>" + m.slice(0, 1) );
			trace( c.slice(3, 1) 	+ " =>" + m.slice(3, 1) );
			trace( c.slice(-3, 1) 	+ " =>" + m.slice(-3, 1) );
			trace( c.length 		+ " =>" + m.length );
			
			trace( mm_c1.material.texture.name + " =>" + mm_m1.material.texture.name );
			trace( mm_c1.material.killAlpha + " =>" + mm_m1.material.killAlpha );
			trace( mm_c1.material.colorMul + " =>" + mm_m1.material.colorMul );
			
			var sk_c = fbx_c1.skin;
			var sk_m = fbx_m1.skin;
			
			trace( sk_c.vertexCount + " =>" + sk_m.vertexCount );
			trace( sk_c.bonesPerVertex + " =>" + sk_m.bonesPerVertex );
			trace( sk_c.namedJoints + "=>" );
			trace( sk_m.namedJoints );
			
			trace( sk_c.rootJoints + " =>" + sk_m.rootJoints );
			trace( sk_c.triangleGroups + " =>" + sk_m.triangleGroups );
			
			trace("BOUND");
			trace( sk_c.boundJoints + " =>" );
			trace( sk_m.boundJoints );
			
			trace("ALL");
			trace( sk_c.allJoints + " =>" );
			trace( sk_m.allJoints );
			
			
			{
				var c = sk_c.vertexJoints;
				var m = sk_m.vertexJoints;
				trace( vectorSlice(c,0, 1) 	+ " =>" + vectorSlice(m,0, 1) );
				trace( vectorSlice(c,3, 1) 	+ " =>" + vectorSlice(m,3, 1) );
				trace( vectorSlice(c,-3, 1) + " =>" + vectorSlice(m,-3, 1) );
				trace( c.length 		+ " =>" + m.length );
			}
			
			{
				var c = sk_c.vertexWeights;
				var m = sk_m.vertexWeights;
				trace( vectorSlice(c,0, 1) 	+ " =>" + vectorSlice(m,0, 1) );
				trace( vectorSlice(c,3, 1) 	+ " =>" + vectorSlice(m,3, 1) );
				trace( vectorSlice(c,-10, 10) + " =>" + vectorSlice(m,-10, 10) );
				trace( c.length 		+ " =>" + m.length );
			}
			
			if(fbx_c1.geomCache.sbuf!=null){
				trace("SKIN");
				var c : hxd.BytesBuffer = fbx_c1.geomCache.sbuf;
				var m : hxd.BytesBuffer = fbx_m1.geomCache.sbuf;
				trace( c.slice(0, 1) 	+ " =>" + m.slice(0, 1) );
				trace( c.slice(3, 1) 	+ " =>" + m.slice(3, 1) );
				trace( c.slice(200, 1) 	+ " =>" + m.slice(200, 1) );
				trace( c.slice(-10, 10) + " =>" + m.slice(-10, 10) );
				trace( c.length 		+ " =>" + m.length );
			}
			
			/*
			 * 
			for( k in  sk_c.namedJoints.keys())	{
				var jc = sk_c.namedJoints.get(k);
				var jm = sk_m.namedJoints.get(k);
				
				trace( jc + " =>" + jm);
				trace( jc.bindIndex + " =>" + jm.bindIndex);
				trace( jc.defMat + " =>" + jm.defMat);
				trace( jc.transPos + " =>" + jm.transPos);
				trace( jc.splitIndex + " =>" + jm.splitIndex);
				trace( "parent:"+jc.parent + " =>" + jm.parent);
				trace( "subs:"+jc.subs + " =>" + jm.subs);
			}
			*/
			
			fbx_m1.alloc(h3d.Engine.getCurrent());
			//c1.visible = false;
			//m1.visible = false;
			var k = 0;
		}
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
		var dist = 10;
		var height = 0;
		time += 0.005;
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