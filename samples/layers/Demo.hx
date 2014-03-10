import flash.display.Sprite;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import h2d.Bitmap;
import haxe.Timer;
class Demo 
{
	var spr : Sprite;
	var tf : TextField;
	
	#if !standalone
	var btn : Sprite;
	#end
	
	var engine : h3d.Engine;
	var scene : h2d.Scene;
	
	static var num = 0;
	static var DM_D0 = num++;
	static var DM_D1 = num++;
	static var DM_D2 = num++;
	
	static var DM_LAST = num++;

	public function new( ){
		init();
		
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
	
	public function init() {
		// init code sample 
		
		//spr = new Sprite();
		//
		//var gfx = spr.graphics;
		//gfx.beginFill(0xcdcdcd);
		//gfx.lineStyle(0.01, 0xFF0000);
		//gfx.drawRoundRect(0, 0, 75, 100,8);
		//gfx.endFill();
		//
		//addChild( spr );
		
		// Debug TextField
		
		//tf = new TextField();
		//tf.autoSize = TextFieldAutoSize.LEFT;
		//tf.multiline = true;
		//tf.text = 'Hello ${data.userName}';
		//addChild( tf );
		
		/*
		#if !standalone
		// Create "Home" button
		btn = new Sprite();
		btn.graphics.beginFill(0xFF0000);
		btn.graphics.drawRect( Metrics.px("-40a"), Metrics.px("-15a"), Metrics.px("80a"), Metrics.px("30a") );
		btn.graphics.endFill();
		
		var btf = new TextField();
		btf.text = 'HOME';
		btf.selectable = false;
		btf.x = - btf.textWidth / 2;
		btf.y = - btf.textHeight / 2;
		btn.addChild( btf );
		
		btn.addEventListener( MouseEvent.CLICK, goHome );
		
		addChild( btn );
		#end
		*/
		
		engine = new h3d.Engine();
		engine.onReady = initH3D;
		engine.backgroundColor = 0xFFaabbaa;
		engine.init();
		engine.restoreOpenfl();
	}
	
	
	public function initH3D() {
		
		scene = new h2d.Scene();
		Data.create();
		
		var lm = new h2d.Layers(scene);
		
		var hs1 = new mt.heaps.HSprite( Data.slbCarPlayers);
		hs1.playAnim( "wagon_anim"); 
		hs1.setCenter(0, 0.5);
		hs1.x = 150;
		hs1.y = 200;
		
		var hs2 = new mt.heaps.HSprite( Data.slbCarPlayers);
		hs2.playAnim( "cheval_anim"); 
		hs2.setCenter(0, 0.5);
		hs2.x = 200;
		hs2.y = 200;
		
		var batchMap = new h2d.SpriteBatch(Data.slbTerrain.tile);
		
		for (i in 0...16) {
			var e = Data.slbTerrain.getBatchElement(batchMap, "lowland", 0);
			e.x = i * 40;
			e.y = 200;
		}
		
		lm.add(hs2, DM_D0);
		lm.add(batchMap, DM_D1);
		lm.add(hs1, DM_D2);
		
		/*
		var b = new Bitmap(h2d.Tile.fromColor(0xFFFFFF00,50,50),scene);
		
		b.x = 100;
		b.y = 50;
		*/
		hxd.System.setLoop(update);
		engine.restoreOpenfl();
	}
	
	public function update() {
		mt.deepnight.SpriteLibBitmap.updateAll();
		if ( engine != null && scene != null ) {
			engine.render(scene);
		}
		
		if ( engine != null) { 
			engine.restoreOpenfl();
		}
	}
}
