import h2d.Tile;
import haxe.Resource;
import hxd.BitmapData;

class Demo {
	
	var engine : h3d.Engine;
	var scene : h2d.Scene;
	var spr : h2d.Sprite;
	
	function new() {
		engine = new h3d.Engine();
		engine.onReady = init;
		engine.backgroundColor = 0xFF000000;
		engine.init();
	}
	
	function init() {
		scene = new h2d.Scene();
		
		var s = new h2d.Sprite(scene);
		
		for (i in 0...6) {
			var e = new mt.heaps.HSprite(Data.slbPix, "road", i);
			//e.x = i * 40;
			e.x = 40;
			e.y = 400;
			e.alpha = 0.5 + Std.random(5) / 10;
			s.addChild(e);
		}
		
		trace(s.height);
		
		new mt.heaps.fx.Spawn(s);
		
		hxd.System.setLoop(update);
	}
	
	function update() {
		spr.rotation += 0.01;
		engine.render(scene);
	}
	
	static function main() {
		hxd.Res.loader = new hxd.res.Loader(hxd.res.EmbedFileSystem.create());
		new Demo();
	}
	
}