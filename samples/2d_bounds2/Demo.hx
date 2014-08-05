import haxe.Resource;
import haxe.Utf8;

import h2d.Graphics;
import h2d.Sprite;
import h2d.Text;
import h3d.Engine;
import hxd.BitmapData;

class Demo 
{
	var engine : h3d.Engine;
	var scene : h2d.Scene;
	function new() 	{
		engine = new h3d.Engine();
		engine.onReady = init;
		engine.backgroundColor = 0xFFC0C0C0;
		engine.init();
		
		#if flash
			flash.Lib.current.addChild(new openfl.display.FPS());
		#end
	}
	
	function init() {
		scene = new h2d.Scene();
		
		var g = new h2d.Bitmap( h2d.Tile.fromColor(0xFFFF0000,32, 32), scene);
		g.x += 32;
		g.y += 32;
		g.scaleX = 2.0;
		trace(g.width);
		
		hxd.System.setLoop(update);
	}
	
	function update() {
		engine.render(scene);
	}
	
	static function main() 
	{
		new Demo();
	}
}
