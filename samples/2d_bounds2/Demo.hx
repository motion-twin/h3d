import haxe.Resource;
import haxe.Utf8;

import h2d.Graphics;
import h2d.Sprite;
import h2d.Text;
import h3d.Engine;
import hxd.BitmapData;

import mt.deepnight.slb.assets.TexturePacker;

class Demo 
{
	var engine : h3d.Engine;
	var scene : h2d.Scene;
	var blib:mt.deepnight.slb.BLib;
	
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
		blib = TexturePacker.importXmlOpenFl("assets/buildings.xml");
		var g =  new h2d.Graphics(scene );
		g.drawRect(0, 0, 32, 32);
		g.x += 32;
		g.y += 32;
		trace(g.width);
		trace(g.height);
		
		g.scaleX = 2.0;
		g.scaleY = 3.0;
		trace(g.width);
		trace(g.height);
		
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
