
import flash.Lib;
import mt.Assets;
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
		h2d.Drawable.DEFAULT_FILTER = true;
		scene = new h2d.Scene();
			
		//if ( engine.driver.hasFeature( ETC1 ) ) {
			//Profiler.begin("pvr etc1");
			//var b = ByteConversions.byteArrayToBytes(Assets.getBytes("assets/test_quad_2k.etc1.pvr"));
			//var t = new hxd.fmt.pvr.Reader(b);
			//var d : hxd.fmt.pvr.Data = t.read();
			//var bmp = h2d.Bitmap.fromPixels( d.toPixels() , scene );
			//bmp.x += 256;
			//bmp.y += 32;
			//bmp.scaleX = bmp.scaleY = 0.05;
			//Profiler.end("pvr etc1");
		//}
		//else if ( engine.driver.hasFeature( PVRTC1 ) ) {
			//Profiler.begin("pvr pvrtc1");
			//var b = ByteConversions.byteArrayToBytes(Assets.getBytes("assets/test_quad_2k.pvrtc.pvr"));
			//var t = new hxd.fmt.pvr.Reader(b);
			//var d : hxd.fmt.pvr.Data = t.read();
			//var bmp = h2d.Bitmap.fromPixels( d.toPixels() , scene );
			//bmp.x += 256;
			//bmp.y += 32;
			//bmp.scaleX = bmp.scaleY = 0.05;
			//Profiler.end("pvr pvrtc1");
		//}
		//else if( engine.driver.hasFeature( S3TC ) ) {
			//Profiler.begin("pvr bc3");
			//var b = ByteConversions.byteArrayToBytes(Assets.getBytes("assets/test_quad_1k.bc3.m2.pvr"));
			//var t = new hxd.fmt.pvr.Reader(b);
			//var d : hxd.fmt.pvr.Data = t.read();
			//var bmp = h2d.Bitmap.fromPixels( d.toPixels() , scene );
			//bmp.x += 256;
			//bmp.y += 32;
			//bmp.scaleX = bmp.scaleY = 0.2;
			//Profiler.end("pvr bc3");
		//}
		//
		//Profiler.begin("png");
		//var bmp = h2d.Bitmap.create( hxd.BitmapData.fromNative( Assets.getBitmapData("assets/test_quad_2k.png")) , scene );
		//bmp.x += 512;
		//bmp.y += 32;
		//bmp.scaleX = bmp.scaleY = 0.05;
		//Profiler.end("png");
		//
		//
		
		var bmp = h2d.Bitmap.fromAssets( "assets/test_quad_1k.png", scene );
		bmp.y += 32;
		bmp.scaleX = bmp.scaleY = 0.15;
		
		var bmp = new h2d.Bitmap(mt.Assets.getTile( "assets/test_quad_1k.4444.pvr" )(),scene);
		bmp.x += 256;
		bmp.y += 32;
		bmp.scaleX = bmp.scaleY = 0.15;
		
		var bmp = new h2d.Bitmap(mt.Assets.getTile( "assets/test_quad_1k.565.pvr" )(),scene);
		bmp.y += 256;
		bmp.scaleX = bmp.scaleY = 0.15;
		
		var bmp = new h2d.Bitmap(mt.Assets.getTile( "assets/test_quad_1k.a8.pvr" )(), scene);
		bmp.x += 256;
		bmp.y += 256;
		bmp.scaleX = bmp.scaleY = 0.15;
		
		
		/*
		var bmp = new h2d.Bitmap(mt.Assets.getTile( "assets/test_quad_1k.l8.pvr" )(), scene);
		bmp.x += 512;
		bmp.y += 256;
		bmp.scaleX = bmp.scaleY = 0.15;
		*/
		/*
		var bmp = new h2d.Bitmap(mt.Assets.getTile( "assets/test_quad_1k.etc1.pvr" )(),scene);
		bmp.y += 256;
		bmp.scaleX = bmp.scaleY = 0.15;
		*/
		
		/*
		Profiler.begin("pvr");
		var b = ByteConversions.byteArrayToBytes(Assets.getBytes("assets/test_quad_1k.pvr"));
		var t = new hxd.fmt.pvr.Reader(b);
		var d : hxd.fmt.pvr.Data = t.read();
		for ( m in d.meta) {
			trace(m);
		}
		var bmp = h2d.Bitmap.fromPixels( d.toPixels() , scene );
		bmp.x += 128;
		bmp.y += 32;
		bmp.scaleX = bmp.scaleY = 0.05;
		bmp.rotation = Math.PI * 0.25;
		Profiler.end("pvr");
		
		
		var bmp = h2d.Bitmap.fromAssets( "assets/benchNineFont.png", scene );
		bmp.x += 256;
		bmp.y += 32;
		bmp.scaleX = bmp.scaleY = 0.2;
		
		var bmp = new h2d.Bitmap( mt.Assets.getTile( "assets/appLaunch.565.pvr.z")(), scene );
		bmp.x += 384;
		bmp.y += 32;
		bmp.scaleX = bmp.scaleY = 0.2;
		*/
		/*
		var bmp = new h2d.Bitmap( mt.Assets.getTile("assets/benchNineFont.png"), scene );
		bmp.x += 128;
		bmp.y += 32;
		bmp.scaleX = bmp.scaleY = 0.2;
		*/
		/*
		var bmp = new h2d.Bitmap( mt.Assets.getTile("assets/5551.pvr"), scene );
		bmp.x += 96;
		bmp.y += 32;
		bmp.scaleX = bmp.scaleY = 8.0;
		*/
		
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
