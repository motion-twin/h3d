import h2d.Tile;
import haxe.Resource;
import hxd.BitmapData;

//import SlicedClip;

class Demo extends flash.display.Sprite{
	
	var engine : h3d.Engine;
	var scene : h2d.Scene;
	
	function new() {
		super();
		engine = new h3d.Engine();
		engine.onReady = init;
		engine.backgroundColor = 0xFF000000;
		engine.init();
		
	}
	
	function init() {
		scene = new h2d.Scene();
		
		var s = new h2d.Sprite(scene);
		var t = hxd.Res.hxlogo.toTile();
		
		var bmp = new h2d.Bitmap( t, s );
		
		//var swf = openfl.Assets.getMovieClip("SlicedClips");
		var lib = new format.SWF(openfl.Assets.getBytes("assets/SlicedClip.swf"));
		var symbol = lib.createMovieClip("SlicedClip");
		trace(symbol);
		
		//symbol.scaleX = symbol.scaleY  = 3.0;
		symbol.x = 300;
		symbol.y = 200;
		symbol.height = 300;
		symbol.width = 300;
		
	//	symbol.scale9Grid = new flash.geom.Rectangle(-100, -7, 200, 10);
	//	symbol.flatten();
	//	symbol.gotoAndPlay(1);
	//	symbol.unflatten();
		
		flash.Lib.current.addChild( symbol );
		
		var bmp = mt.deepnight.Lib.flatten( symbol );
		
		var bmpSub = h2d.Bitmap.fromBitmapData( bmp.bitmapData , s );
		
		bmpSub.x = 200;
		bmpSub.y = 100;
		
		
		
		hxd.System.setLoop(update);
	}
	
	function update() {
		engine.render(scene);
		
		engine.restoreOpenfl();
	}
	
	static function main() {
		hxd.Res.loader = new hxd.res.Loader(hxd.res.EmbedFileSystem.create());
		new Demo();
	}
	
}