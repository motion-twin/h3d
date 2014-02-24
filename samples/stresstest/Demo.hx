
import h2d.Text;
import h3d.Engine;
import haxe.Resource;
import haxe.Utf8;
import hxd.BitmapData;
import h2d.SpriteBatch;
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
		
		tileHaxe = tileHaxe.center( Std.int(tileHaxe.width / 2), Std.int(tileHaxe.height / 2) );
		tileNME = tileNME.center( Std.int(tileNME.width / 2), Std.int(tileNME.height / 2) );
		tileOFL = tileOFL.center( Std.int(tileOFL.width / 2), Std.int(tileOFL.height / 2) );
		
		var batch = new h2d.SpriteBatch(tileHaxe, root);
		batch.hasRotationScale = true;
		batch.blendMode = None;
		batch.shader.hasVertexAlpha = false;
		for (i in 0...2000)
		{
			var s = batch.alloc(tileHaxe);
			s.x = engine.width >> 1;
			s.y = engine.height >> 1;
			s.scale = (0.4);
			var vx = mt.MLib.frandRangeSym(5);
			var vy = mt.MLib.frandRangeSym(5);
			var vr = mt.MLib.frandRangeSym(0.2);
			
			function act () {
				s.rotation += vr;
				s.x += vx;
				s.y += vy;
				if( s.x < 0 ) vx = -vx;
				if( s.y < 0 ) vy = -vy;
				if( s.x > engine.width ) vx = -vx;
				if( s.y > engine.height ) vy = -vy;
			};
			actions.add(act);
		}
		
		
		
		var font = hxd.res.FontBuilder.getFont("arial", 32, { antiAliasing : false , chars : hxd.Charset.DEFAULT_CHARS } );
		/*
		var tf = new h2d.Text(font, root);
		tf.textColor = 0xFFFFFF;
		tf.dropShadow = { dx : 0.5, dy : 0.5, color : 0xFF0000, alpha : 0.8 };
		tf.text = "Hello Héllò h2d àáâã !";
		tf.scale(1);
		
		
		var fill = new h2d.css.Fill(root);
		fill.fillRectColor( 32 , 128 , 32 , 32, 0xffFF0000);
		fill.fillRectColor( 64 , 128 , 32 , 32, 0xff00FF00);
		fill.fillRectColor( 96 , 128 , 32 , 32, 0xff0000FF);
		
		var bmp = new h2d.Bitmap(tileHaxe, scene);
		bmp.x = 256;
		bmp.y = 128;
		bmp.color = new h3d.Vector();
		bmp.color.x = 1.0;//r
		bmp.color.y = 0.0;//g
		bmp.color.z = 0.0;//b
		bmp.color.w = 0.5;//a
*/
		var tf = fps=new h2d.Text(font, root);
		tf.textColor = 0xFFFFFF;
		tf.dropShadow = { dx : 0.5, dy : 0.5, color : 0xFF0000, alpha : 0.8 };
		tf.text = "Hello Héllò h2d àáâã !";
		tf.scale(1);
		tf.y = 100;
		
		
		hxd.System.setLoop(update);
	}
	
	static var fps : Text;
	var spin = 0;
	function update() 
	{
		if(spin++>=10){
			fps.text = Std.string(Engine.getCurrent().fps);
			spin = 0;
		}
		for (action in actions )
		{
			action();
		}
		engine.render(scene);
	}
	
	static function main() 
	{
		hxd.Res.loader = new hxd.res.Loader(hxd.res.EmbedFileSystem.create());
		new Demo();
	}
}
