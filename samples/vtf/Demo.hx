
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
		var t = new format.vtf.Reader(ByteConversions.byteArrayToBytes(Assets.getBytes("assets/test_quad_75_mip.vtf")));
		var d : format.vtf.Data = t.read();
		trace(d.dump());
		
		trace(d.getPixel(0, 0,-2));
		
		scene = new h2d.Scene();
		var root = new h2d.Sprite(scene);
		
		var fontRoboto = hxd.res.FontBuilder.getFont("Roboto-Black", 32, { antiAliasing : false , chars : hxd.Charset.DEFAULT_CHARS } );
		
		trace(Profiler.dump(false));
		Profiler.clean();
		
		hxd.System.setLoop(update);
		
		
	}
	
	static var fps : Text;
	static var tf : Text;
	
	var spin = 0;
	var count = 0;
	function update() 
	{
	
		Profiler.end("myUpdate");
		Profiler.begin("engine.render");
		engine.render(scene);
		Profiler.end("engine.render");
		Profiler.begin("engine.vbl");
		
		//if (count > 100) 
		if( false)
		{
			trace(Profiler.dump());
			Profiler.clean();
			count = 0;
		}
		
		#if cpp
		var driver : h3d.impl.GlDriver = cast Engine.getCurrent().driver;
		count++;
		Profiler.end("engine.vbl");
		Profiler.begin("myUpdate");
		if(spin++>=10){
			fps.text = Std.string(Engine.getCurrent().fps) + " ssw:"+driver.shaderSwitch+" tsw:"+driver.textureSwitch+" rsw"+driver.resetSwitch;
			spin = 0;
		}
		#end
	}
	
	static function main() 
	{
		hxd.Res.loader = new hxd.res.Loader(hxd.res.EmbedFileSystem.create());
		new Demo();
	}
}
