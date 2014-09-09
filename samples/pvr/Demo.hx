
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
		
		if ( engine.driver.hasFeature( PVRTC ) ) {
			Profiler.begin("pvr pvrtc");
			var b = ByteConversions.byteArrayToBytes(Assets.getBytes("assets/test_quad_2k.pvrtc.pvr"));
			var t = new hxd.fmt.pvr.Reader(b);
			var d : hxd.fmt.pvr.Data = t.read();
			var bmp = h2d.Bitmap.fromPixels( d.toPixels() , scene );
			bmp.x += 256;
			bmp.y += 32;
			bmp.scaleX = bmp.scaleY = 0.05;
			Profiler.end("pvr pvrtc");
		}
		else if( engine.driver.hasFeature( S3TC ) ) {
			Profiler.begin("pvr bc3");
			var b = ByteConversions.byteArrayToBytes(Assets.getBytes("assets/test_quad_1k.bc3.m2.pvr"));
			var t = new hxd.fmt.pvr.Reader(b);
			var d : hxd.fmt.pvr.Data = t.read();
			var bmp = h2d.Bitmap.fromPixels( d.toPixels(0) , scene );
			bmp.x += 256;
			bmp.y += 32;
			bmp.scaleX = bmp.scaleY = 0.2;
			Profiler.end("pvr bc3");
		}
		else if ( engine.driver.hasFeature( ETC1 ) ) {
			Profiler.begin("pvr etc1");
			var b = ByteConversions.byteArrayToBytes(Assets.getBytes("assets/test_quad_2k.etc1.pvr"));
			var t = new hxd.fmt.pvr.Reader(b);
			var d : hxd.fmt.pvr.Data = t.read();
			var bmp = h2d.Bitmap.fromPixels( d.toPixels() , scene );
			bmp.x += 256;
			bmp.y += 32;
			bmp.scaleX = bmp.scaleY = 0.05;
			Profiler.end("pvr etc1");
		}
		
		Profiler.begin("png");
		var bmp = h2d.Bitmap.create( hxd.BitmapData.fromNative( Assets.getBitmapData("assets/test_quad_2k.png")) , scene );
		bmp.x += 512;
		bmp.y += 32;
		bmp.scaleX = bmp.scaleY = 0.05;
		Profiler.end("png");
		
		Profiler.begin("pvr");
		var b = ByteConversions.byteArrayToBytes(Assets.getBytes("assets/test_quad_2k.pvr"));
		var t = new hxd.fmt.pvr.Reader(b);
		var d : hxd.fmt.pvr.Data = t.read();
		var bmp = h2d.Bitmap.fromPixels( d.toPixels() , scene );
		bmp.y += 32;
		bmp.scaleX = bmp.scaleY = 0.05;
		Profiler.end("pvr");
		
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
