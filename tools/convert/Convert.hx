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

using StringTools;

class Convert {
	
	var engine : h3d.Engine;
	var time : Float;
	var scene : Scene;
	
	var curFbx : h3d.fbx.Library = null;
	var animMode : h3d.fbx.Library.AnimationMode = h3d.fbx.Library.AnimationMode.LinearAnim;
	var anim : Animation = null;
	var saveAnimsOnly = false;
	var saveModelOnly = false; // no anmations
	
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
		
		for ( i in 0...args.length ) {
			var arg = args[i].toLowerCase();
			switch(arg) {
				case "--mode": 
					var narg = args[i + 1].toLowerCase();
					switch(narg) {
						case "linear": animMode = h3d.fbx.Library.AnimationMode.LinearAnim;
						case "frame": animMode = h3d.fbx.Library.AnimationMode.FrameAnim;
					}
					
				case "--animations":
					saveAnimsOnly = true;
					
				case "--mesh":
					saveModelOnly = true;
					
				default: pathes.push( arg );
			}
		}
		
		return pathes;
	}
	
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
		
		for ( path in pathes) {
			trace("Converting : " + path + "\n");
			
			#if sys
			var file = sys.io.File.getContent(path);
			#else
			var fref =  new flash.net.FileReference();
			fref.addEventListener(flash.events.Event.SELECT, function(_) fref.load());
			fref.addEventListener(flash.events.Event.COMPLETE, function(_){
			var file = (haxe.io.Bytes.ofData(fref.data)).toString();
			#end
				loadData(file);
				
				scene.traverse(function(obj) {
					trace("read " + obj.name);
					if ( obj.parent != null ) 
						trace("parent is :" + obj.parent.name);
				});
					
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
	
	function loadData( data : String, newFbx = true ) {
		curFbx = new h3d.fbx.Library();
		var fbx = h3d.fbx.Parser.parse(data);
		curFbx.load(fbx);
		var frame = 0;
		var o : h3d.scene.Object = null;
		scene.addChild(o = curFbx.makeObject( function(str, mat) {
			var m = h3d.mat.Texture.fromColor(0xFFFF00FF);
			m.name = str;
			return new MeshMaterial(m);
		}));
		setSkin(o);
		trace("loaded " + o.name);
	}
	
	function setSkin(obj:h3d.scene.Object) {
		anim = curFbx.loadAnimation(animMode);
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