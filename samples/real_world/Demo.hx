


import h2d.Anim;
import h2d.Bitmap;
import h2d.Text;
import h2d.SpriteBatch;
import h2d.Tile;

import h3d.Engine;

import haxe.Resource;
import haxe.Timer;
import haxe.Utf8;

import hxd.BitmapData;
import hxd.Profiler;
import hxd.System;

class Demo extends flash.display.Sprite
{
	var engine : h3d.Engine;
	var scene : h2d.Scene;
	var actions : List < Void->Void > ;
	
	function new() {
		super();
		engine = new h3d.Engine();
		engine.onReady = init;
		engine.backgroundColor = 0xFFCCCCCC;
		engine.init();
		
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
	
	function getTile(path:String) {
		var n = openfl.Assets.getBitmapData( path );
		return h2d.Tile.fromBitmap( hxd.BitmapData.fromNative( n ));
	}
	
	function init() 
	{
		hxd.System.setLoop(update);
		scene = new h2d.Scene();
		var root = new h2d.Sprite(scene);
		
		var font = hxd.res.FontBuilder.getFont("arial", 24, { antiAliasing : false , chars : hxd.Charset.DEFAULT_CHARS } );
		var fontRoboto = hxd.res.FontBuilder.getFont("Roboto-Black", 24, { antiAliasing : false , chars : hxd.Charset.DEFAULT_CHARS } );
		
		var tileHaxe = getTile("assets/haxe.png");
		var tileNME = getTile("assets/nme.png"); 
		var tileOFL = getTile("assets/openfl.png"); 
		var char = getTile("assets/char.png"); 
		
		var oTileHaxe = tileHaxe;
		
		tileHaxe = tileHaxe.center( Std.int(tileHaxe.width / 2), Std.int(tileHaxe.height / 2) );
		tileNME = tileNME.center( Std.int(tileNME.width / 2), Std.int(tileNME.height / 2) );
		tileOFL = tileOFL.center( Std.int(tileOFL.width / 2), Std.int(tileOFL.height / 2) );
		
		var idle_anim : Array<h2d.Tile> = [];
		
		var x = 0;
		var y = 0;
		var w = 48; var h = 32;
		var idle_anim = [];
		for ( i in 0...6) {
			idle_anim.push( char.sub(x, y, w, h).center(w >> 1, h) );
			x += 48;
		}
		
		/*
		var stw = flash.Lib.current.stage.stageWidth;
		var sth = flash.Lib.current.stage.stageHeight;
		
		var fill = new h2d.Bitmap(tileHaxe.center(0,0), scene);
		fill.scaleX =  stw / tileHaxe.width;
		fill.scaleY =  sth / tileHaxe.height * 0.7;
		fill.toBack();
		fill.name = "fill";
		
		
		var subHaxe = oTileHaxe.sub(0, 0, 16, 16).center(8, 8);
		batch = new SpriteBatch( tileHaxe, scene );
		batch.hasVertexColor = true;
		batch.hasVertexAlpha = true;
		batch.hasRotationScale = true;
		
		for ( i in 0...16*16) {
			var e = batch.alloc(tileHaxe);
			e.x = (i % 16) * 16; 
			e.y = Std.int(i / 16) * 16;
			e.tile = subHaxe;
			e.color.x = Math.random();
			e.color.y = Math.random();
			e.color.z = Math.random();
			e.width = 16;
			e.height = 16;
			e.skewY = Math.PI / 4;
			var p = -5 + Std.random(10);
			e.changePriority(p);
		}
		batch.name = "batch";
		
		
		fps=new h2d.Text(font, root);
		fps.textColor = 0xFFFFFF;
		fps.dropShadow = { dx : 0.5, dy : 0.5, color : 0xFF0000, alpha : 0.8 };
		fps.text = "";
		fps.x = 0;
		fps.y = 500;
		fps.name = "tf";
		
		tf = new h2d.Text(font, root);
		tf.textColor = 0xFFFFFF;
		tf.dropShadow = { dx : 0.5, dy : 0.5, color : 0xFF0000, alpha : 0.8 };
		tf.text = "This is a large batch of text\n that is representative about\n real world pavé.";
		tf.y = 300;
		tf.x = System.height * 0.5;
		tf.name = "tf";
		
		
		
		anim = new Anim(idle_anim,scene);
		anim.x = 16;
		anim.y = 200; 
		anim.name = "anim";
		*/
		//anim.blendMode = None;
		//anim.killAlpha = true;
		
		/*
		bmp = new Bitmap( getTile( "assets/aneurism.png" ) , scene);
		bmp.tile.getTexture().alpha_premultiplied = false;
		bmp.x = 64;
		bmp.y = 250; 
		bmp.blendMode = None;
		bmp.killAlpha = true;
		*/
		
		bmp = new Bitmap( Tile.fromColor(0xFFff00ff,64,64), scene);
		bmp.name = "bitmap";
		bmp.x = 16;
		bmp.y = 250; 
		
		#if sys
		bmp.textures = [tileHaxe.getTexture(),tileNME.getTexture(),tileOFL.getTexture() ];
		//bmp.alpha = 0.5;
		#end
		anims = [];
		/*
		greyscale(bmp);
		
		bmp = new Bitmap(idle_anim[1], scene);
		bmp.name = "bitmap";
		bmp.x = 100;
		bmp.y = 250; 
		
		var shCircle = new flash.display.Shape();
		shCircle.graphics.beginFill(0xFF0000);
		shCircle.graphics.drawCircle(60, 400, 50);
		shCircle.graphics.endFill();
		
		var shSquare = new flash.display.Shape();
		shSquare.graphics.beginFill(0x004080);
		shSquare.graphics.drawRect(100, 400, 50, 50);
		shSquare.graphics.endFill();
		
		h2d.Sprite.fromSprite(shCircle, scene);
		h2d.Sprite.fromSprite(shSquare, scene);
				
		var local = new h2d.Sprite(scene);
		local.name = "local";
		var a = null;
		for ( i in 0...16 * 16) {
			
			anims.push( a = new Anim(idle_anim, anim.shader, local));
			a.name = "anim"+i;
			a.x = 300 + i%16 * 16;
			a.y = 16 + Std.int(i / 16) * 16;
		}
		
		var s = new h2d.Graphics(scene);
		s.beginFill(0xFFFFFF);
		s.drawRect(0, 0, 50, 50);
		s.endFill();
		
		s.x = 300;
		s.y = 300;
		square = s;
		
		var s = new h2d.Graphics(s);
		s.beginFill(0xFF00FF);
		s.drawCircle(0, 0, 30, 30);
		s.endFill();
		
		s.x = 50;
		s.y = 50;
		sphere = s;
		
		bds = new h2d.Graphics(scene);
		
		square = new Bitmap(idle_anim[1], scene);
		square.name = "bitmap";
		square.x = 200;
		square.y = 250; 
		
		sphere = new Bitmap(idle_anim[1], square);
		sphere.name = "bitmap";
		sphere.x = 50;
		sphere.y = 50; 
		
		
		rect = new flash.display.Shape();
		var g = rect.graphics;
		g.beginFill(0xFF00FF);
		g.drawRect( -50, -100, 100, 200 );
		g.endFill();
		
		rect.x = 200;
		rect.y = 200;
		flash.Lib.current.addChild( rect );
		
		hrect = new h2d.Graphics(scene);
		hrect.beginFill(0xFF00FF);
		hrect.drawRect( -50, -100, 100, 200 );
		hrect.endFill();
		
		hrect.x = 400;
		hrect.y = 200;*/
		
	}
	
	static var square: h2d.Sprite;
	static var sphere : h2d.Sprite;
	static var bds : h2d.Graphics;
	
	static var rect : flash.display.Shape;
	static var hrect : h2d.Graphics;
	
	static var fps : Text;
	static var tf : Text;
	static var batch : SpriteBatch;
	static var bmp : Bitmap;
	static var anim : h2d.Anim;
	static var anims : Array<h2d.Anim>;
	
	var spin = 0;
	var count = 0;
	function update() 
	{
		Profiler.end("engine.vbl");
		Profiler.begin("myUpdate");
		
		if( sphere !=null){
			sphere.rotation += 0.02;
			square.rotation += 0.001;
			square.scaleX = square.scaleY = 0.5 + 0.5 * Math.abs(Math.sin(count* 0.01 ));
			sphere.scaleX = sphere.scaleY = 0.5 + 0.5 * Math.abs(Math.sin(count * 0.1 ));
			
			//bmp.rotation += 0.003;
			bmp.skewX = Math.PI / 8;
			bmp.skewY = Math.PI / 8;
			bmp.scaleX = 1.0 + 0.1 * Math.abs(Math.sin(count * 0.1 ));
			
			bds.clear();
			bds.beginFill(0xFF00FF, 0.2); 
			var b = bmp.getBounds();
			bds.drawRect(b.x, b.y, b.width, b.height);
			bds.endFill();
			
			for ( e in batch.getElements()) {
				e.rotation += 0.1;
			}
			//batch.alpha = 0.5;
			
			if(rect!=null){
				rect.rotation += hxd.Math.RAD2DEG * 0.1;
				hrect.rotation += 0.1;
			}
		}
		Profiler.end("myUpdate");
		
		Profiler.begin("engine.render");
		engine.render(scene);
		engine.restoreOpenfl();
		Profiler.end("engine.render");
		
		Profiler.begin("engine.vbl");
		if (batch!=null && count > 100) {
			batch.alpha = 1.0-batch.alpha;
			trace(Profiler.dump());
			Profiler.clean();
			count = 0;
		}
		
		count++;
		
		#if cpp
		var driver : h3d.impl.GlDriver = cast Engine.getCurrent().driver;
		
		if(spin++>=10 && fps != null){
			fps.text = Std.string(Engine.getCurrent().fps) + " ssw:" + driver.shaderSwitch + " tsw:" + driver.textureSwitch + " rsw" + driver.resetSwitch + "\n"
			+driver.renderer+" by "+driver.vendor;
			spin = 0;
		}
		#end
		
	}
	
	static function main() {
		//hxd.Res.loader = new hxd.res.Loader(hxd.res.EmbedFileSystem.create());
		new Demo();
	}
}
