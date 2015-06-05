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
	var bitmaps:Map<String,flash.display.BitmapData> = new Map();
	var pathes : Array<String> = [];
	var verbose=false;
	var premul = true;
	var rr:Null<Int>=null;
	var rg:Null<Int>=null;
	var rb:Null<Int>=null;
	var ra:Null<Int>=null;
	var defaultReduce = true;
	var zipped = true;
	var writePNG = true;
	
	public function new(){
		var args = Sys.args();
		
		processArgs(args.copy());
		
		if ( args.length < 1 ) {
			if( verbose ) trace("opening box\n");
			pathes = systools.Dialogs.openFile("Open .png file to convert", "open", 
			{ count:1000, descriptions:[".png files"], extensions:["*.png", "*.PNG"] } );
		}
		else {
			if(args.length == 0 ) {
				usage();
				return;
			}
			
			if( verbose ) trace("args parsed\n");
		}
		
		if( verbose ){
			trace("pathes ("+pathes.length+"): \n");
			for( p in pathes )
				trace("-:"+p+"\n");
		}
		if( verbose ) trace("processing\n");
		process();
	}
	

	
	function process(){
		var curDir = Sys.getCwd();
		
		if( verbose ) trace("curdir :"+curDir+"\n");
		
		for( p in pathes ){
			Sys.setCwd(curDir);

			p = Path.normalize(p);
			var png =  null;
			if( verbose ) trace("reading "+p+"\n");
			png = readPng(p);
			if( png == null){
				trace("ERROR:cannot read image file"+p+"\n");
				continue;
			}
			
			if( verbose ) trace("read "+p+" successfully\n");
			if( verbose ) trace("generating data\n");
			
			var bo = new haxe.io.BytesOutput();
			var d = new hxd.fmt.idx.Writer(bo);
			
			if( !defaultReduce ){
				if( verbose ) trace("non default reduction");
				if( rr!=null ) d.reduceR = rr;
				if( rg!=null ) d.reduceG = rg;
				if( rb!=null ) d.reduceB = rb;
			}
			
			var data = d.makeBitmapData(png,premul);
			
			if( verbose ) trace("r reduce:"+data.reduceR);
			if( verbose ) trace("g reduce:"+data.reduceG);
			if( verbose ) trace("b reduce:"+data.reduceB);
			if( verbose ) trace("a reduce:"+data.reduceA);
			
			var filename = Path.getFile(p);
			
			if( verbose ) trace("generated filename "+filename+"\n");
			
			if( verbose ) trace("data width "+data.width+"\n");
			if( verbose ) trace("data height "+data.height+"\n");
			if( verbose ) trace("data index size "+data.index.length+"\n");
			if( verbose ) trace("data nbBits size "+data.nbBits+"\n");
			if( verbose ) trace("data palette size "+data.paletteByIndex.length+"\n");
			
			Sys.setCwd(Path.getBaseDir(p));
			
			if( writePNG ){
				if( verbose ) trace("feeding back to png\n");
				var out = new haxe.io.BytesOutput();
				var w = new format.png.Writer( out  );
				w.write( format.png.Tools.build32ARGB( data.width, data.height, data.toBmp32BGRA() ));
				var finalBytes = out.getBytes();
				saveFile( finalBytes, "png", filename);
				continue;
			}
			
			d.write( data );
			if( verbose ) trace("generated data\n");
			
			var bytes = bo.getBytes();
			if( verbose ) trace("uncomp len: "+bytes.length+" bytes\n");
			
			if( zipped ){
				if( verbose ) trace("generating zip\n");
				var comp = haxe.zip.Compress.run( bytes, 9 );
				if( verbose ) trace("saving "+comp.length+" bytes\n");
				saveFile( comp,"idx.z", filename );
			}
			else {
				if( verbose ) trace("saving "+bytes.length+" bytes\n");
				saveFile( bytes,"idx", filename );
			}
			if( verbose ) trace("saved.\n!");
		}
		
		if( verbose ) trace("finished.\n\n!");
	}
	
	
	public function usage(){
		trace("Usage : tex_idx <path>");
		trace("reduction args is the bit reduction of rgba channels. for instance 3000 will erase the lowest 3 bits of the red channel and leave others untouched");
		trace("default reduces 2 bits and no alpha (mask = 2220) ");
		
		trace("arguments: :");
		trace("-raw : no data zipping");
		trace("-z : data zipping");
		trace("-v : verbose");
		trace("-r : sets the reduction mask");
		
		trace("-png : write resulting data to a .png");
		trace("-idx : write resulting data to a .idx");
	}
	
	function processArgs( args:Array<String>){
		var i = 0;
		while(i < args.length ) {
			var arg = args[i];
			switch(arg) {
				case "-z": zipped = true;
				case "--raw": zipped = false;
				case "-v","--verbose": verbose=true;
				case "-r","--reduction":
					var reduc = args[i+1];
					if( verbose ) trace("reduce mask:"+reduc);
					rr = reduc.charCodeAt( 0 ) - '0'.code;
					rg = reduc.charCodeAt( 1 ) - '0'.code;
					rb = reduc.charCodeAt( 2 ) - '0'.code;
					ra = reduc.charCodeAt( 3 ) - '0'.code;
					defaultReduce=false;
					i++;
				case "-png":
					writePNG=true;
				case "-idx":
					writePNG=false;
				default: 
					if(verbose) trace("required file:"+arg+"\n");
					pathes.push( arg );
			}
			i++;
		}
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
		format.png.Tools.reverseBytes(bmdBytes);
		
		var bmd = new flash.display.BitmapData(header.width,header.height,true);
		bmd.setPixels( new flash.geom.Rectangle(0, 0, header.width, header.height), hxd.ByteConversions.bytesToByteArray( bmdBytes ));
		return bmd;
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
		new Convert();
		
		#if sys
		Sys.exit(0);
		#end
		
		return 0;
	}
	
}