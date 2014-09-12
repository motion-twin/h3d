
import h2d.Graphics;
import h2d.Sprite;
import h2d.Text;
import h2d.TileGroup;
import h3d.Engine;
import haxe.Resource;
import haxe.Utf8;
import hxd.BitmapData;
import h2d.SpriteBatch;
import hxd.Timer;
class Demo 
{
	var engine : h3d.Engine;
	var scene : h2d.Scene;
	var rotating : Graphics;
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
		scene = new h2d.Scene();
		
		var tileHaxe = hxd.Res.haxe.toTile();
		var tileNME = hxd.Res.nme.toTile();
		var tileOFL = hxd.Res.openfl.toTile();
		var oTileHaxe = tileHaxe;
		
		tileHaxe = tileHaxe.center( Std.int(tileHaxe.width / 2), Std.int(tileHaxe.height / 2) );
		tileNME = tileNME.center( Std.int(tileNME.width / 2), Std.int(tileNME.height / 2) );
		tileOFL = tileOFL.center( Std.int(tileOFL.width / 2), Std.int(tileOFL.height / 2) );
		
		var font = hxd.res.FontBuilder.getFont("arial", 32, { antiAliasing : false , chars : hxd.Charset.DEFAULT_CHARS } );
		var tf = fps=new h2d.Text(font, scene);
		tf.textColor = 0xFFFFFF;
		tf.dropShadow = { dx : 0.5, dy : 0.5, color : 0xFF0000, alpha : 0.8 };
		tf.text = "turlututu";
		tf.scale(2);
		tf.y = 100;
		tf.x = 100;
           
		
		var shape = new h2d.Graphics(scene); 
		shape.lineStyle(2, 0, 0.5); 
		for (h in 0...6) { 
		   var angle = 2 * Math.PI / 6 * h; 
		   var pointX = (30) * Math.cos(angle); 
		   var pointY = (30) * Math.sin(angle); 
		   if (h == 0) shape.addPoint(pointX + 60 / 2 + 1, pointY + 52 / 2 - 1); 
		   else shape.addPoint(pointX + 60 / 2 + 1, pointY + 52 / 2 - 1); 
		} 
		shape.endFill(); 
		 
		shape.x = 300; 
		shape.y = 300; 
		 
		var sh = new h2d.Graphics(scene); 
		sh.lineStyle(2, 0, 0.5); 
		sh.addPoint(0, 0); 
		sh.addPoint(50, 0); 
		sh.addPoint(50, 50); 
		sh.addPoint(0, 50); 
		sh.x = 100; 
		sh.y = 300; 
		sh.endFill();
		
		
		var q = new h2d.Graphics(scene);
		var b = sh.getBounds();
		q.beginFill(0xFF0000, 0.5);
		q.drawRect(b.x, b.y, b.width, b.height );
		q.endFill();
		
		
		var q = new h2d.Graphics(scene);
		var b = shape.getBounds();
		q.beginFill(0xFF0000, 0.5);
		q.drawRect(b.x, b.y, b.width, b.height );
		q.endFill();
		
		
		var q = new h2d.Graphics(scene);
		var b = tf.getBounds();
		q.beginFill(0xFF0000, 0.5);
		q.drawRect(b.x, b.y, b.width, b.height );
		q.endFill();
		
		
		var p = new h2d.Graphics(scene);
		p.x = 450;
		p.y = 150;
		
		p.lineStyle(1, 0xffffff, 1); 
		p.drawCircle(0,0, 100);
		p.addHole();
		p.drawCircle(0, 0, 50); 
		
		
		var p = rotating=new h2d.Graphics(scene);
		p.x = 50;
		p.y = 200;
		p.lineStyle(4.0, 0xffffff, 1); 
		p.beginFill(0xFFFf00Ff, 1.0);
		p.drawRotatedRect(20, 20, 20, 20, Math.PI / 6);
		p.endFill();
		
		
		var p = new h2d.Graphics(scene);
		p.x = 100;
		p.y = 200;
		
		p.lineStyle(1.0, 0xffffff, 1); 
		var a = [
			new h2d.col.Point(50,50),
			new h2d.col.Point(100, 100),
			new h2d.col.Point(100, 200),
		];
		
		var c = new hxd.tools.Catmull2(a);
		var b = c.plot();
		
		for ( p in b.toData() ) trace(p);
		
		for ( i in 0...(b.length>>1)-1 ) {
			var p0x = b.get((i << 1));
			var p0y = b.get((i << 1)+1);
			var p1x = b.get((i << 1)+2);
			var p1y = b.get((i << 1)+3);
			p.drawLine( p0x,p0y,p1x,p1y);
		}
		
		/*
		var c = new Catmull2(a);
		var b = c.plot();
		
		for ( p in b ) {
			trace(p);
		}
		
		for ( i in 0...b.length-1 ) {
			var p0 = b[i];
			var p1 = b[i+1];
			p.drawLine( p0.x,p0.y,p1.x,p1.y);
		}
		*/
		
		var p = new h2d.Graphics(scene);
		p.x = 200;
		p.y = 200;
		p.lineStyle(2.0, 0xffffff, 1); 
		p.beginFill(0xFFFf00Ff, 1.0);
		p.drawLine(0,0, 100,100);
		p.endFill();
		
		
		hxd.System.setLoop(update);
	}
	
	static var fps : Text;
	static var bmp : h2d.Bitmap;
	public var batch : SpriteBatch;
	
	var spin = 0;
	var count = 0;
	
	
	var a = 0.0;
	function update() 
	{
		count++; // Utilité du count ?
		if (spin++ >=5){
			fps.text = Std.string(Engine.getCurrent().fps);
			spin = 0;
		}
		
		a += Timer.oldTime;
		var p = rotating;
		p.clear();
		p.lineStyle(4.0, 0xffffff, 1); 
		p.beginFill(0xFFFf00Ff, 1.0);
		p.drawRotatedRect(0, 0, 20, 20, a,10,10);
		p.endFill();
		
		
		engine.render(scene);
	}
	
	static function main() 
	{
		hxd.Res.loader = new hxd.res.Loader(hxd.res.EmbedFileSystem.create());
		new Demo();
	}
}
