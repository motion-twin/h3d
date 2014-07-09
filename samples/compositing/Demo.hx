
import flash.Lib;
import h2d.Anim;
import h2d.Bitmap;
import h2d.CachedBitmap;
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
	
	var char : h2d.Tile;
	var mask : h2d.Tile;
	var tileDeathStand : h2d.Tile;
	var tilePeonStand : h2d.Tile;
	
	//test compositing and deferring to other sprites
	var gfx : h2d.Graphics;
	
	var root : h2d.Scene;
	var global : h2d.Scene;
	
	var sceneDark : h2d.Scene;
	var sceneLight : h2d.Scene;
	
	var cbFirst : h2d.CachedBitmap;
	var cbSecond : h2d.CachedBitmap;
	
	var cbBoth : h2d.CachedBitmap;
	
	function new() 
	{
		engine = new h3d.Engine();
		engine.onReady = init;
		engine.backgroundColor = 0xcd0707CC;
		engine.init();
		
	}
	
	function init() {
		
		hxd.Key.initialize();
		
		root = new h2d.Scene();
		
		char = hxd.Res.char.toTile();
		tileDeathStand = char.sub(0, 0, 50, 34);
		tilePeonStand = char.sub(0, 430, 32, 32);
		mask = hxd.Res.mask.toTile();
		
		sceneDark = makeDark();
		sceneLight = makeLight();
		global = new h2d.Scene();
		
		root.addPass( sceneDark,true );
		root.addPass( sceneLight,true );
		root.addPass( global,true );
		
		gfx = new h2d.Graphics(global);

		var subCachedY = 256;
		
		cbBoth = new CachedBitmap( global, 512, 512 );
		cbBoth.freezed = true;
		cbBoth.y = subCachedY;
		
		//test sub cached bitmap
		cbFirst = new CachedBitmap(cbBoth);
		cbFirst.hasAlpha=true;
		new Bitmap( tileDeathStand, cbFirst );
		
		cbSecond = new CachedBitmap(cbBoth);
		cbSecond.hasAlpha=true;
		new Bitmap( tilePeonStand, cbSecond );
		cbSecond.x = 64;
		
		Timer.delay( function() {
			cbFirst.alpha = 0.5;
			cbSecond.alpha = 0.5;
			trace("fading sub");
		},500);
		
		Timer.delay( function() {
			cbBoth.invalidate();
		},2000);
		
		
		hxd.System.setLoop(update);
	}
	
	
	function makeDark() {
		var scene = new h2d.Scene();
		var cached = new h2d.CachedBitmap(scene, 128, 128);
		cached.name = "cb";
		//cached.drawToBackBuffer = false;
		var sb : h2d.SpriteBatch = new h2d.SpriteBatch(char, cached);
		
		var e = sb.alloc(tileDeathStand.center());
		
		e.x = 32;
		e.y = 48;
		cached.freezed = true;
		
		return scene;
	}
	
	function makeLight() {
		var scene = new h2d.Scene();
		var cached = new h2d.CachedBitmap(scene, 128, 128);
		cached.y = 32;
		cached.name = "cb";
		//cached.drawToBackBuffer = false;
		var sb : h2d.SpriteBatch = new h2d.SpriteBatch(char, cached);
		
		var e = sb.alloc(tilePeonStand.centerRatio(0.5,0.5));
		
		e.x = 32;
		e.y = 32;
		
		e.scaleX = e.scaleY = 2.0;
		scene.x = 128;
		
		cached.freezed = true;
		
		return scene;
	}
	
	var spriteCompo : h2d.Sprite;

	var spin = 0;
	
	function update() {
		
		gfx.clear();
		gfx.lineStyle(1.0, 0xFF00FF00,0.5);
		gfx.beginFill(0x0000FF,0.5);
		gfx.drawRect(200, 0, 256, 256);
		gfx.endFill();
		
		spin++;
		
		if ( hxd.Key.isReleased( hxd.Key.ENTER) && spin > 50) {
			if ( spriteCompo != null) { spriteCompo.remove(); spriteCompo = null; }
			
			spriteCompo = new h2d.Sprite(global);
			spriteCompo.x = 200;
			spriteCompo.y = 0;
			
			var cb : h2d.CachedBitmap = cast sceneDark.getChildByName("cb");
			var bDark = new h2d.Bitmap( cb.getTile(), spriteCompo );
			
			var cb : h2d.CachedBitmap = cast sceneLight.getChildByName("cb");
			var bLight = new h2d.Bitmap( cb.getTile(), spriteCompo );
			bLight.alphaMap = mask;
			
			trace("rendered");
			
			spriteCompo.scaleX = spriteCompo.scaleY = 2.0;
		}
		
		if ( sceneDark != null )
			sceneDark.y = 48 + Math.sin( spin * 0.1 ) * 4;
		
		if( cbFirst != null )
			cbFirst.y = 16 + Math.sin( spin * 0.1 ) * 4;
		engine.render(root);
		engine.restoreOpenfl();
	}
	
	static function main() 
	{
		hxd.Res.loader = new hxd.res.Loader(hxd.res.EmbedFileSystem.create());
		new Demo();
	}
}
