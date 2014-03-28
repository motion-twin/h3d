
import flash.Lib;
import format.abc.Context;
import format.vtf.Data;
import format.vtf.Reader;
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
import haxe.Utf8;
import hxd.BitmapData;
import h2d.SpriteBatch;
import hxd.ByteConversions;
import hxd.Pixels;
import hxd.Profiler;
import hxd.res.Texture;
import hxd.System;
import mt.fx.Flash;
import openfl.Assets;
class Demo 
{
	var engine : h3d.Engine;
	var scene : h2d.Scene;
	var actions : List < Void->Void > ;
	
	function new() 
	{
		engine = new h3d.Engine();
		engine.onReady = init;
		engine.backgroundColor = 0xFFCCCCCC;
		//engine.autoResize = true;
		engine.init();
		
		#if flash
		flash.Lib.current.addChild(new openfl.display.FPS());
		#end
		//flash.Lib.current.addEventListener(flash.events.Event.RESIZE, onResize );
	}
	
	function onResize(_)
	{
		trace("resize");
		trace(flash.Lib.current.stage.stageWidth + " " + flash.Lib.current.stage.stageHeight);
	}
	
	function init() 
	{
		
		Profiler.begin("vtf");
		var t = new format.vtf.Reader(ByteConversions.byteArrayToBytes(Assets.getBytes("assets/test_quad_2k.vtf")));
		var d : format.vtf.Data = t.read();
		var bmp = h2d.Bitmap.fromPixels( d.toPixels() , scene );
		bmp.x += 32;
		bmp.y += 32;
		Profiler.end("vtf");
		
		
		Profiler.begin("vtf zip");
		var b = ByteConversions.byteArrayToBytes(Assets.getBytes("assets/test_quad_2k.vtf.zip"));
		var z = new format.zip.Reader(new haxe.io.BytesInput(b));
		var entry = z.read().first();
		entry.data = mt.Lib.inflate(entry.data, entry.fileSize);
		entry.compressed = false;
		
		trace("reading! "+entry.data.length);
		var t = new format.vtf.Reader(entry.data);
		trace("making reader");
		var d : format.vtf.Data = t.read();
		trace("read!");
		var bmp = h2d.Bitmap.fromPixels( d.toPixels() , scene );
		bmp.x += 32;
		bmp.y += 32;
		Profiler.end("vtf zip");
		
		
		
		Profiler.begin("png");
		var bmp = h2d.Bitmap.create( hxd.BitmapData.fromNative( Assets.getBitmapData("assets/test_quad_2k.png")) , scene );
		bmp.x += 256;
		bmp.y += 32;
		Profiler.end("png");
		
		trace("finished");
		
		scene = new h2d.Scene();
		var root = new h2d.Sprite(scene);
		
		var fontRoboto = hxd.res.FontBuilder.getFont("Roboto-Black", 32, { antiAliasing : false , chars : hxd.Charset.DEFAULT_CHARS } );
		
		trace(Profiler.dump(false));
		Profiler.clean();
		
		hxd.System.setLoop(update);
		
		
	}
	
	static var fps : Text;
	static var tf : Text;
	
	function update() 	{
		engine.render(scene);
	}
	
	static function main() 
	{
		//hxd.Res.loader = new hxd.res.Loader(hxd.res.EmbedFileSystem.create());
		new Demo();
	}
}
