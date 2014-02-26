
import h2d.Graphics;
import h2d.Sprite;
import h2d.Text;
import h2d.TileGroup;
import h3d.Engine;
import haxe.Resource;
import haxe.Utf8;
import hxd.BitmapData;
import h2d.SpriteBatch;
class Demo 
{
	var engine : h3d.Engine;
	var scene : h2d.Scene;
	
	function new() 
	{
		engine = new h3d.Engine();
		engine.onReady = init;
		engine.backgroundColor = 0xFFCCCCCC;
		engine.init();
		
		#if flash
		flash.Lib.current.addChild(new openfl.display.FPS());
		#end
	}
	
	function onResize(_)
	{
	}
	
	function init() 
	{
		var a = haxe.ds.Vector.fromArrayCopy([1, 2, 3, 4]);
		a[2] = 5;
		
		
		hxd.System.setLoop(update);
	}
	
	
	function update() 
	{
		engine.render(scene);
	}
	
	static function main() 
	{
		hxd.Res.loader = new hxd.res.Loader(hxd.res.EmbedFileSystem.create());
		new Demo();
	}
}
