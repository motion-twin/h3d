import haxe.Resource;
import haxe.Utf8;

import h2d.Graphics;
import h2d.Sprite;
import h2d.Text;
import h2d.SpriteBatch;
import h3d.Engine;
import hxd.BitmapData;

import mt.deepnight.slb.assets.TexturePacker;

class Demo 
{
	var engine : h3d.Engine;
	var scene : h2d.Scene;
	var bm:h2d.SpriteBatch;
	var blib:mt.deepnight.slb.BLib;
	var c:Container;
	
	function new() 
	{
		engine = new h3d.Engine();
		engine.onReady = init;
		engine.backgroundColor = 0xFFC0C0C0;
		//engine.autoResize = true;
		engine.init();
		
		#if flash
			flash.Lib.current.addChild(new openfl.display.FPS());
		#end
		//flash.Lib.current.addEventListener(flash.events.Event.RESIZE, onResize );
	}
	
	function onResize(_) {
		trace("resize");
		trace(flash.Lib.current.stage.stageWidth + " " + flash.Lib.current.stage.stageHeight);
	}
	
	function init() 
	{
		// Flash
		
		blib = TexturePacker.importXml("assets/buildings.xml");
		
		// H2D
		scene = new h2d.Scene();
		
		c = new Container();
		c.x = mt.Metrics.w() / 2;
		c.y = mt.Metrics.h() / 2;
		c.scaleX = 0.5;
		trace( c.getBounds() );
		
		var g = new h2d.Bitmap( h2d.Tile.fromColor(0xFFFF0000,32, 32),c);
		g.x += 32;
		g.y += 32;
		//g.scaleX = 0.5;
		trace(g.width);
		trace(c.width);
		
		var b = new h2d.col.Bounds();
		b.add4(0, 0, 2, 2);
		
		h2d.Graphics.fromBounds(b, c, 0x000000);
		
		scene.addChild(c);
		
		hxd.System.setLoop(update);
	}
	
	function update() {
		c.update();
		
		engine.render(scene);
	}
	
	static function main() 
	{
		new Demo();
	}
}
