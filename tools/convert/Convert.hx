import flash.Lib;
import flash.utils.ByteArray;
import hxd.fmt.h3d.AnimationWriter;
import hxd.fmt.h3d.Data;
import hxd.fmt.h3d.Tools;
import h3d.anim.Animation;
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
import hxd.Pixels;
import hxd.Profiler;
import hxd.res.LocalFileSystem;
import hxd.System;

import format.png.Data;

using StringTools;

class Convert {
	
	var engine : h3d.Engine;
	var time : Float;
	var scene : Scene;
	
	var curFbx : h3d.fbx.Library = null;
	var animMode : h3d.fbx.Library.AnimationMode = h3d.fbx.Library.AnimationMode.LinearAnim;
	var anim : Animation = null;
	var saveAnimsOnly = false;
	var saveModelOnly = false; // no animations
	var verbose = #if debug true #else false #end;
	var texturePath = "Textures";
	
	//todo change
	var makeAtlas = true;
	function new() {
		hxd.System.debugLevel = 0;
		start();
	}
	
	function start() {
		scene = new Scene();
		loadFbx();
	}
	
	function processArgs( args:Array<String>){
		var pathes = [];
		
		var i = 0;
		while(i < args.length ) {
			var arg = args[i].toLowerCase();
			switch(arg) {
				case "--mode": 
					var narg = args[i + 1].toLowerCase();
					switch(narg) {
						case "linear": animMode = h3d.fbx.Library.AnimationMode.LinearAnim;
						case "frame": animMode = h3d.fbx.Library.AnimationMode.FrameAnim;
					}
					i++;
					
				case "--animations":
					saveAnimsOnly = true;
					
				case "--mesh":
					saveModelOnly = true;
					
				case "-v","--verbose":
					verbose = true;
					
				case "--make-atlas":
					makeAtlas = true;
					
				case "-tp":
					texturePath = args[i + 1];
					i++;
					
					
				default: pathes.push( arg );
			}
			i++;
		}
		
		return pathes;
	}
	
	
	var bitmaps:Map<String,flash.display.BitmapData> = new Map();
	
	function getFile(path:String) :String{
		path = path.replace("\\", "/");
		var a = path.split("/");
		return a[a.length - 1];
	}
	
	function getBaseDir(path) {
		var root = sys.FileSystem.fullPath(path);
		root = root.replace("\\", "/");
		var dir = root.split("/");
		dir.splice(dir.length - 1, 1);
		root = dir.join("/");
		return root+"/";
	}
	
	function getDir(path:String):String {
		var root = path;
		root = root.replace("\\", "/");
		var dir = root.split("/");
		dir.splice(dir.length - 1, 1);
		root = dir.join("/");
		return root+"/";
	}
	
	function makeRelative(path) {
		var cwd = Sys.getCwd();
		return path.substr(cwd.length, path.length);
	}
	
	function removeLastExtension(path) {
		var a = path.split(".");
		if ( a.length > 1 )
			a.splice( a.length - 1, 1);
		return a.join(".");
	}
	
	function normalizePath(str:String):String {
		return str.replace("\\", "/");
	}
	
	function readPng(path) :flash.display.BitmapData {
		if (verbose) trace("Reading PNG:" + path);	
		var bytes = sys.io.File.getBytes( path );
		var bi = new haxe.io.BytesInput(bytes);
		var data = new format.png.Reader( bi ).read();
		var header : format.png.Data.Header=null;
		for ( l in data) {
			switch(l) { case CHeader(h): header = h;
				default:
			}
		}
		var bmdBytes = format.png.Tools.extract32(data);
		var bmd = new flash.display.BitmapData(header.width,header.height,true);
		bmd.setPixels( new flash.geom.Rectangle(0, 0, header.width, header.height), hxd.ByteConversions.bytesToByteArray( bmdBytes ));
		return bmd;
	}
	
	function loadData( path:String,data : String, newFbx = true ) {
		curFbx = new h3d.fbx.Library();
		var fbx = h3d.fbx.Parser.parse(data);
		curFbx.load(fbx);
		var frame = 0;
		var o : h3d.scene.Object = null;
		scene.addChild(o = curFbx.makeObject( function(str, mat) {
			var baseName = str;
			str = getBaseDir(path) + str;
			if ( !sys.FileSystem.exists(str) ) {
				if (verbose) trace("Reading default texture (" + str + " not found ) ");	
				if ( makeAtlas ) throw "Cannot do atlas without reference textures :"+str;
				var m = h3d.mat.Texture.fromColor(0xFFFF00FF);
				m.name = baseName;
				return new MeshMaterial(m);
			}
			else {
				var bmd = readPng( str );
				if( !bitmaps.exists( baseName ))
					bitmaps.set( baseName, bmd );
				var m = h3d.mat.Texture.fromColor(0xFFFF00FF);
				m.name = baseName;
				return new MeshMaterial(m);
			}
		}));
		setSkin(o);
	}
	
	var i = 0;
	function loadFbx(){
		var pathes = null;
		#if sys
		var args = Sys.args();
		if ( args.length < 1 ) {
			pathes = systools.Dialogs.openFile("Open .fbx to convert", "open", 
			{ count:1000, descriptions:[".fbx files"], extensions:["*.fbx", "*.FBX"] } );
			
		}
		else pathes = processArgs(args);
		#else
		pathes = [""];
		#end
		
		var curDir = Sys.getCwd();
		for ( path in pathes) {
			path = normalizePath(path);
			if(verbose) trace("Converting : " + path + "\n");
			
			#if sys
			var file = sys.io.File.getContent(path);
			#else
			var fref =  new flash.net.FileReference();
			fref.addEventListener(flash.events.Event.SELECT, function(_) fref.load());
			fref.addEventListener(flash.events.Event.COMPLETE, function(_){
			var file = (haxe.io.Bytes.ofData(fref.data)).toString();
			#end
			
				Sys.setCwd(curDir);
				loadData(path, file);
				Sys.setCwd(getBaseDir(path));
				
				/*
				scene.traverse(function(obj) {
					trace("read " + obj.name);
					if ( obj.parent != null ) 
						trace("parent is :" + obj.parent.name);
				});
				*/
					
				//add filters or process here
				if (makeAtlas) {
					var packer = new hxd.tools.Packer();
					packer.padding = 8;
					
					var file = removeLastExtension(getFile(path)) +"_atlas.png";
					
					try{
						sys.FileSystem.createDirectory(texturePath);
					}
					catch (d:Dynamic) {
						trace("Directory creation failed : " + d);
					}
					
					var outputName = texturePath+"/"+file;
					if ( verbose ) trace("generating atlas " + outputName);
						
					scene.traverse(function(obj:h3d.scene.Object) {
						if ( obj.isMesh()) {
							i++;
							var m  = obj.toMesh();
							var name = m.material.texture.name;
							var tex = m.material.texture;
							var bmp = bitmaps.get( name );
							var fbx = Std.instance(m.primitive, h3d.prim.FBXModel);
							if ( fbx != null ) {
								packer.push( name, bmp, function(e) {
									var deltaX = e.x / packer.sizeSq;
									var deltaY = e.y / packer.sizeSq;
									var scaleX = bmp.width / packer.sizeSq;
									var scaleY = bmp.height / packer.sizeSq;
									
									if ( fbx.geomCache == null) 
										fbx.alloc(null);
									
									for ( i in 0...fbx.geomCache.tbuf.length>>1 ) {
										var u = fbx.geomCache.tbuf[i << 1];
										var v = fbx.geomCache.tbuf[(i << 1) + 1];
										u *= scaleX;
										v *= scaleY;
										u += deltaX;
										v += deltaY;
										fbx.geomCache.tbuf[i << 1] 		= u;
										fbx.geomCache.tbuf[(i << 1) + 1] = v;
									}
									if(verbose) trace("launching repack query for" + name);
								});
								
								tex.name = outputName;
							}
						}
					});
					
					var res = packer.process();
					var bytes = hxd.ByteConversions.byteArrayToBytes(res.getPixels(res.rect));
					var out = new haxe.io.BytesOutput();
					var w = new format.png.Writer( out  );
					w.write( format.png.Tools.build32BGRA( packer.sizeSq,packer.sizeSq, bytes ));
					
					var finalBytes = out.getBytes();
					sys.io.File.saveBytes( outputName,finalBytes);
				}
				
				if( saveAnimsOnly )
					saveAnimation(path);
				else if( saveModelOnly )
					saveLibrary( path, false );
				else 
					saveLibrary( path, true );
						
				while (scene.childs.length > 0 )  scene.childs[0].remove();	
					
				curFbx = null;
			
			#if flash
			});
			fref.browse( [new flash.net.FileFilter("Kaydara ASCII FBX (*.FBX)", "*.FBX") ] );
			#end
		}
		
		return;
	}
	
	
	function setSkin(obj:h3d.scene.Object) {
		anim = curFbx.loadAnimation(animMode);
		
		#if debug
		for( o in anim.objects){
			trace( "read anim of object:" + o.objectName+" "+o);
		}
		#end
		
		if ( anim != null ) anim = scene.getChildAt(0).playAnimation(anim);
		else throw "no animation found";
	}
	
	public function saveLibrary( path:String , saveAnims : Bool) {
		var o = scene.childs[0];
		if ( !saveAnims ) o.animations = [];
			
		var b;
		var a = new hxd.fmt.h3d.Writer( b=new haxe.io.BytesOutput() );
		a.write( o );
		
		var b = b.getBytes();
		if( saveAnims ) saveFile( b, "h3d.data", path );
		else 			saveFile( b, "h3d.model", path );
	}
	
	public function saveAnimation(path:String){
		var aData = anim.toData();
		
		var out = new haxe.io.BytesOutput();
		var builder = new hxd.fmt.h3d.AnimationWriter(out);
		builder.write(anim);
		var bytes = out.getBytes();
		
		saveFile( bytes, "h3d.anim", path);
	}
	
	public function saveFile(bytes:haxe.io.Bytes,ext:String,path:String) {
		var temp = path.split(".");
		temp.splice( temp.length - 1, 1);
		var outpath = temp.join(".") + ((temp.length<=1)?".":" ") +ext;
		
		#if windows 
		outpath = outpath.replace("/", "\\");
		#end
		
		#if flash
		var f = new flash.net.FileReference();
		var ser = Serializer.run(bytes.toString());
		f.save( ByteConversions.bytesToByteArray( bytes) );
		
		#elseif sys
		sys.io.File.saveBytes( outpath, bytes );
		#end
	}
	
	static function main() {
		
		#if flash
		haxe.Log.setColor(0xFF0000);
		#end
		
		new Convert();
		
		#if sys
		Sys.exit(0);
		#end
		return 0;
	}
	
}