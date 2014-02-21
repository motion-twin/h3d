
import h2d.Text;
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
		
		for (i in 0...1000)
		{
			var s = batch.alloc(tileHaxe);
			s.x = engine.width >> 1;
			s.y = engine.height >> 1;
			s.scale = (0.1);
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
		
		/*
		var t = new Text("arial", root);
		t.alpha = 0.5;
		t.color = 0xFF0000;
		t.text = "SAPIN";
		t.x = 30;
		t.y = 30;
		*/
		
		var font = hxd.res.FontBuilder.getFont("arial", 32, { antiAliasing : false , chars : hxd.Charset.DEFAULT_CHARS } );
		var tf = new h2d.Text(font, root);
		tf.textColor = 0xFFFFFF;
		tf.dropShadow = { dx : 0.5, dy : 0.5, color : 0xFF0000, alpha : 0.8 };
		tf.text = "Hello Héllò h2d àáâã !";
		tf.scale(1);
		
		hxd.System.setLoop(update);
	}
	
	
	
	/*
	UTF8Char * CUTF8Utils::Char2UTF8( UTF8Char * _Dest, const Char * _Src, U32 _MaxLen  )
	{
		U32 i = 0;
		U32 dest_i = 0;

		U32 l_UCode = 0;
		do
		{
			if(i >= _MaxLen-2)
			{
				break;
			}

			l_UCode = (U32)(U8)_Src[i]; 
			if(l_UCode <= ((1<<7) - 1))
			{
				_Dest[dest_i++] = (UTF8Char)l_UCode;
			}
			else
			{
				U32 l_Code0 = ((U32) l_UCode >> 6);
				U32 l_Code1 = GetLastBits( l_UCode,6);

				_Dest[dest_i] = (U8) (l_Code0) | (1 << 7) | (1<<6);
				_Dest[dest_i+1] = (U8) (l_Code1) | (1 << 7);

				dest_i += 2;
			}
		}
		while(_Src[i++]);

		return _Dest;
	}
	*/
	
	function update() 
	{
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
