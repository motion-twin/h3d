
import flash.Lib;

import hxd.fmt.vtf.Data;
import hxd.fmt.vtf.Reader;

import h2d.Anim;
import h2d.Bitmap;
import h2d.Text;
import h3d.Engine;

import haxe.io.BufferInput;
import haxe.io.Bytes;
import haxe.io.BytesInput;

import haxe.macro.Format;
import haxe.Resource;
import haxe.Timer;

import hxd.BitmapData;
import h2d.SpriteBatch;
import hxd.ByteConversions;
import hxd.Pixels;
import hxd.Profiler;
import hxd.res.Texture;
import hxd.System;
import openfl.Assets;

class Demo {
	var engine : h3d.Engine;
	var scene : h2d.Scene;
	
	function new() 	{
		engine = new h3d.Engine();
		engine.onReady = init;
		engine.backgroundColor = 0xFFCCCCCC;
		engine.init();
		
	}
	
	function init() {
		
		scene = new h2d.Scene();
		
		Profiler.begin("vtf");
		var t = new hxd.fmt.vtf.Reader(ByteConversions.byteArrayToBytes(Assets.getBytes("assets/test_quad_2k.vtf")));
		var d : hxd.fmt.vtf.Data = t.read();
		var bmp = h2d.Bitmap.fromPixels( d.toPixels() , scene );
		bmp.x += 32;
		bmp.y += 32;
		bmp.scaleX = bmp.scaleY = 0.1;
		Profiler.end("vtf");
		
		Profiler.begin("vtf zip");
		var b = ByteConversions.byteArrayToBytes(Assets.getBytes("assets/test_quad_2k.vtf.zip"));
		var z = new format.zip.Reader(new haxe.io.BytesInput(b));
		var entry = z.read().first();
		entry.data = mt.Lib.inflate(entry.data, entry.fileSize);
		entry.compressed = false;
		
		var t = new hxd.fmt.vtf.Reader(entry.data);
		var d : hxd.fmt.vtf.Data = t.read();
		var bmp = h2d.Bitmap.fromPixels( d.toPixels() , scene );
		bmp.x += 32;
		bmp.y += 32;
		bmp.scaleX = bmp.scaleY = 0.1;
		Profiler.end("vtf zip");
		
		Profiler.begin("png");
		var bmp = h2d.Bitmap.create( hxd.BitmapData.fromNative( Assets.getBitmapData("assets/test_quad_2k.png")) , scene );
		bmp.x += 256;
		bmp.y += 32;
		bmp.scaleX = bmp.scaleY = 0.1;
		Profiler.end("png");
		
		trace(Profiler.dump(false));
		Profiler.clean();
		
		hxd.System.setLoop(update);
	}
	
	function update() 	{
		engine.render(scene);
	}
	
	static function main() 	{
		new Demo();
	}
}
