
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

@:publicFields 
class Bench {
	function new() {
		
	}
	
	function update() {
		
	}
}

@:publicFields 
class PixelBench extends Bench{
	var batch  : SpriteBatch;
	var fillRate : Int;
	var d : Demo;
	var cx = 0;
	var cy = 0;
	var bx = 0;
	var tile : h2d.Tile;
	var nb = 0;
	var slowFrames = 0;
	
	override function new( d:Demo) {
		this.d = d;
		super();
		batch = new SpriteBatch( tile = d.tileHaxe, d.scene);
		
		var e = batch.alloc( tile );
		e.x = 0;
		e.y = 0;
	}
	
	override function update() {
		Profiler.begin("update bench");
		fillRate = 0;
		
		nb = 0;
		for ( e in batch.getElements() ){
			nb++;
			fillRate += Math.ceil(e.tile.width * e.tile.height * e.scaleX * e.scaleY);
		}
		
		var frameRate = d.time.getFrameRate();
		
		if ( d.time.getFrameRate() <= 31.0 ) {
			slowFrames++;
			//trace(frameRate);
		}
		else {
			slowFrames = 0;
			var iter = 10;
			
			#if mobile
				iter = 5;
			#end 
			
			for( i in 0...iter){
				var e = batch.alloc( tile );
				e.x = cx;
				e.y = cy;
				cx += tile.width >> 3 ;
				
				if ( cx > d.sw ){
					cx = bx;
					cy += tile.height;
				}
				
				if ( cy > d.sh ) {
					cy = 0;
					cx = 0;
					bx += 2;
				}
			}
		}
		
		
		
		Profiler.end("update bench");
	}
}

@:publicFields
class Demo extends flash.display.Sprite {
	
	var engine : h3d.Engine;
	var scene : h2d.Scene;
	
	var fillrate : PixelBench;
	var b : Bench;
	
	var sw = 0.0;
	var sh = 0.0;
	
	var maxFillrate : Int;
	
	var tileHaxe : h2d.Tile;
	var tileNME : h2d.Tile;
	var tileOFL : h2d.Tile;
	var char : h2d.Tile;
	var idle_anim : Array<h2d.Tile>;
	
	var font : h2d.Font;
	var fontRoboto : h2d.Font;
	var time : mt.gx.Time;
	
	function new() {
		super();
		
		time = new mt.gx.Time(60);
		
		hxd.Key.initialize();
		engine = new h3d.Engine();
		engine.onReady = init;
		engine.backgroundColor = 0x0;
		engine.init();
		
		flash.Lib.current.addChild( new mt.flash.Stats( 0, flash.Lib.current.stage.stageHeight - 100) );
		flash.Lib.current.stage.addEventListener( flash.events.Event.RESIZE, onResize );
		
		#if mobile
		flash.display.Stage.setFixedOrientation( -1 );
		flash.display.Stage.shouldRotateInterface = function(_) return true;
		#end
		
		sw = flash.Lib.current.stage.stageWidth;
		sh = flash.Lib.current.stage.stageHeight;
		
		maxFillrate = Math.ceil(sw * sh * 3.0);
		
		hxd.Profiler.minLimit = 1.0;
		//hxd.FloatBuffer.test();
	}
	
	function onResize(_)
	{
		trace("Context resize");
		trace(flash.Lib.current.stage.stageWidth + " " + flash.Lib.current.stage.stageHeight);
	}
	
	function greyscale(s:h2d.Drawable) {
		s.colorMatrix = new h3d.Matrix();
		
		s.colorMatrix._11 = 0.21;
		s.colorMatrix._21 = 0.72;
		s.colorMatrix._31 = 0.07;
		
		s.colorMatrix._12 = 0.21;
		s.colorMatrix._22 = 0.72;
		s.colorMatrix._32 = 0.07;
		
		s.colorMatrix._13 = 0.21;
		s.colorMatrix._23 = 0.72;
		s.colorMatrix._33 = 0.07;
	}
	
	function makeData() {
		font = hxd.res.FontBuilder.getFont("arial", 32, { antiAliasing : false , chars : hxd.Charset.DEFAULT_CHARS } );
		fontRoboto = hxd.res.FontBuilder.getFont("Roboto-Black", 32, { antiAliasing : false , chars : hxd.Charset.DEFAULT_CHARS } );
		tileHaxe = hxd.Res.haxe.toTile();
		tileNME = hxd.Res.nme.toTile();
		tileOFL = hxd.Res.openfl.toTile();
		
		char = hxd.Res.char.toTile();
		var x = 0;
		var y = 0;
		var w = 48; var h = 32;
		idle_anim = [];
		for ( i in 0...6) {
			idle_anim.push( char.sub(x, y, w, h).center(w >> 1, h) );
			x += 48;
		}
		
	}
	
	function init() {
		scene = new h2d.Scene();
		
		makeData();
		
		fillrate = new PixelBench(this);
		b = fillrate;
		
		hxd.System.setLoop(update);
	}
	
	static var batch : SpriteBatch;
	
	function update() {
		Profiler.end("engine.vbl");
		Profiler.begin("myUpdate");
		
		time.update();
		b.update();
		
		Profiler.end("myUpdate");
		Profiler.begin("engine.render");
		engine.render(scene);
		engine.restoreOpenfl();
		Profiler.end("engine.render");
		Profiler.begin("engine.vbl");
		
		if (hxd.Key.isReleased(hxd.Key.ENTER) || (fillrate.slowFrames >= 120)) {
			fillrate.slowFrames = 0;
			trace(Profiler.dump());
			Profiler.clean();
			trace( "fillrate: " + (fillrate.fillRate>>10)+" Kpx maxFillrate:" + (maxFillrate>>10) +" KPx (3 screen) ");
			trace( "nbSprite: " + fillrate.nb );
			trace( "fps:" + time.getFrameRate() );
			
			#if cpp
			var driver : h3d.impl.GlDriver = cast h3d.Engine.getCurrent().driver;
			trace( Std.string(Engine.getCurrent().fps) + " shaderSwitch:" + driver.shaderSwitch + " textureSwitch:" + driver.textureSwitch + " resetSwitch:" + driver.resetSwitch);
			#end
		}
	}
	
	static function main() {
		hxd.Res.loader = new hxd.res.Loader(hxd.res.EmbedFileSystem.create());
		new Demo();
	}
}
