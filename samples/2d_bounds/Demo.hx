
import flash.display.Bitmap;
import h2d.Graphics;
import h2d.Sprite;
import h2d.Text;
import h2d.TileGroup;
import h3d.Engine;
import haxe.Resource;
import haxe.Utf8;
import hxd.BitmapData;
import h2d.SpriteBatch;
import mt.fx.Flash;
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
		actions = new List();
		scene = new h2d.Scene();
		var root = new h2d.Sprite(scene);
		
		var tileHaxe = hxd.Res.haxe.toTile();
		var tileNME = hxd.Res.nme.toTile();
		var tileOFL = hxd.Res.openfl.toTile();
		
		tileHaxe = tileHaxe.center( Std.int(0), Std.int(0) );
		//tileHaxe = tileHaxe.center( Std.int(tileHaxe.width / 2), Std.int(tileHaxe.height / 2) );
		//tileHaxe = tileHaxe.center( Std.int(tileHaxe.width), Std.int(tileHaxe.height) );
		
		tileNME = tileNME.center( Std.int(tileNME.width / 2), Std.int(tileNME.height / 2) );
		tileOFL = tileOFL.center( Std.int(tileOFL.width / 2), Std.int(tileOFL.height / 2) );
		gfx = new Graphics(scene);
		
		local = new Sprite(scene);
		
		var font = hxd.res.FontBuilder.getFont("arial", 32, { antiAliasing : false , chars : hxd.Charset.DEFAULT_CHARS } );
		var tf = fps=new h2d.Text(font, local);
		tf.textColor = 0xFFFFFF;
		tf.dropShadow = { dx : 0.5, dy : 0.5, color : 0xFF0000, alpha : 0.8 };
		tf.text = "Hello Héllò h2d àáâã !";
		tf.scale(1);
		tf.y = 100;
		tf.x = 100;
		
		local.rotation = Math.PI / 4 * 0.5;
		bmp = new h2d.Bitmap(tileHaxe, scene);
		bmp.x = 256;
		bmp.y = 128;
		bmp.color = new h3d.Vector(1,1,1,1);
		
		tg = new TileGroup(tileHaxe, scene);
		tg.rotation = Math.PI / 4 * 0.5;
		
		tg.add( 64, 64, tileHaxe);
		tg.add( 256, 128, tileHaxe);
		
		
		#if (flash || openfl)
		var g = new flash.display.Sprite();
		var gfx  = g.graphics;
		
		gfx.beginFill(0xFF00FF);
		gfx.drawRect(0, 0, 16, 16);
		gfx.endFill();
		
		var sp = h2d.Sprite.fromSprite(g, scene);
		
		sp.x = 130;
		#end
		
		hxd.System.setLoop(update);
	}
	
	public var gfx:Graphics;
	public var bmp:h2d.Bitmap;
	public var tg : TileGroup;
	public var local:h2d.Sprite;
	static var fps : Text;
	var spin = 0;
	var count = 0;
	
	function rand() {
		var a = [fps,local,tg,bmp];
		return	a[Std.random(a.length)];
	}
	
	function update() 
	{
		count++;
		if (spin++ >=5){
			fps.text = Std.string(Engine.getCurrent().fps);
			spin = 0;
		}
		
		if( spin ==0 ){
			gfx.clear();
			gfx.beginFill(0xFFFF00FF,0.4);
			var b = rand().getBounds();
			gfx.addPoint( b.xMin, b.yMin );
			gfx.addPoint( b.xMin, b.yMax );
			gfx.addPoint( b.xMax, b.yMax );
			gfx.addPoint( b.xMax, b.yMin );
			gfx.endFill();
		}
		
		engine.render(scene);
	}
	
	static function main() 
	{
		hxd.Res.loader = new hxd.res.Loader(hxd.res.EmbedFileSystem.create());
		new Demo();
	}
}
