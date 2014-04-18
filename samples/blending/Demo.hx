
import flash.Lib;
import h2d.Anim;
import h2d.Bitmap;
import h2d.Text;
import h3d.Engine;
import haxe.Resource;
import haxe.Timer;
import haxe.Utf8;
import hxd.BitmapData;
import h2d.SpriteBatch;
import hxd.Profiler;
import hxd.System;
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
		scene = new h2d.Scene();
		var root = new h2d.Sprite(scene);
		
		var premul_y = 16; 
		var straight_y = 64;
		
		var tileHaxe_Straight = hxd.Res.haxe.toTile();
		
		var asset = openfl.Assets.getBitmapData("assets/haxe.png");
		var tileHaxe_Premul = h2d.Tile.fromFlashBitmap(asset);
		
		var r = new format.tga.Reader( hxd.ByteConversions.byteArrayToBytes(openfl.Assets.getBytes( "assets/haxe.tga" )));
		var d = r.read();
		var tileHaxe_Straight_Tga = h2d.Tile.fromPixels( d.toPixels() );
		
		var r = new format.vtf.Reader( hxd.ByteConversions.byteArrayToBytes(openfl.Assets.getBytes( "assets/haxe.vtf" )));
		var d = r.read();
		var tileHaxe_Straight_Vtf = h2d.Tile.fromPixels( d.toPixels() );
		
		var b = new Bitmap( h2d.Tile.fromColor(0xcdcdcd,512,512), scene );
		
		var b = new Bitmap( tileHaxe_Premul, scene );
		b.x = 16;
		b.y = premul_y;
		
		var b = new Bitmap( tileHaxe_Straight, scene );
		b.x = 16;
		b.y = straight_y;
		
		var b = new Bitmap( tileHaxe_Straight_Tga, scene );
		b.x = 16;
		b.y = straight_y + 64;
		
		var b = new Bitmap( tileHaxe_Straight_Vtf, scene );
		b.x = 16;
		b.y = straight_y + 128;
		
		var add_x = 64;
		var b = new Bitmap( tileHaxe_Premul, scene );
		b.x = 16+add_x;
		b.y = premul_y;
		b.blendMode = Add;
		
		var b = new Bitmap( tileHaxe_Straight, scene );
		b.x = 16+add_x;
		b.y = straight_y;
		b.blendMode = Add;
		
		var b = new Bitmap( tileHaxe_Straight_Tga, scene );
		b.x = 16+add_x;
		b.y = straight_y + 64;
		b.blendMode = Add;
		
		var b = new Bitmap( tileHaxe_Straight_Vtf, scene );
		b.x = 16+add_x;
		b.y = straight_y + 128;
		b.blendMode = Add;
		
		add_x += 8;
		var b = new Bitmap( tileHaxe_Premul, scene );
		b.x = 16+add_x;
		b.y = premul_y;
		b.blendMode = Add;
		
		var b = new Bitmap( tileHaxe_Straight, scene );
		b.x = 16+add_x;
		b.y = straight_y;
		b.blendMode = Add;
		
		var b = new Bitmap( tileHaxe_Straight_Tga, scene );
		b.x = 16+add_x;
		b.y = straight_y + 64;
		b.blendMode = Add;
		
		var b = new Bitmap( tileHaxe_Straight_Vtf, scene );
		b.x = 16+add_x;
		b.y = straight_y + 128;
		b.blendMode = Add;
		
		
		var a = 0;
		
		hxd.System.setLoop(update);
	}
	
	
	

	function update() {
		engine.render(scene);
	}
	
	static function main() 
	{
		hxd.Res.loader = new hxd.res.Loader(hxd.res.EmbedFileSystem.create());
		new Demo();
	}
}
