import hxd.Key;

class Demo extends flash.display.Sprite
{
	var engine : h3d.Engine;
	var scene : h2d.Scene;
	
	function new() {
		super();
		engine = new h3d.Engine();
		engine.onReady = init;
		engine.backgroundColor = 0xFFCCCCCC;
		engine.init();
		
	}
	
	function getBmp(path:String) {
		var n = openfl.Assets.getBitmapData( path );
		var b = hxd.BitmapData.fromNative( n );
		return b;
	}
	
	function getTile(path:String) {
		return h2d.Tile.fromAssets(path);
	}
	
	function init() {
		hxd.System.setLoop(update);
		
		hxd.Key.initialize();
		scene = new h2d.Scene();
		
		var font = hxd.res.FontBuilder.getFont("arial", 10);
		var tile = getTile("assets/haxe.png");
		tile.setCenterRatio(0.5, 0.5);
		
		var dcBg = getTile("assets/demoNight.png"); dcBg.setCenterRatio(0.5, 0.5);
		var dcOverlay = getTile("assets/rampedLight.png"); dcOverlay.setCenterRatio(0.5, 0.5);
		
		//create multiple gpu textures
		var tiles = [ getTile("assets/haxe.png"), getTile("assets/haxe.png"), getTile("assets/haxe.png"), getTile("assets/haxe.png") ];
		
		tiles = tiles.map(function(tile){
			tile.setCenterRatio(0.5, 0.5);
			return tile;
		});
		
		var cellX = 40.0;
		var baseline = 48;
		var bmp;
		var incr = 24;
		var txtBaseLine = 48;
		
		
		{
			//single bitmap no emit
			bmp = new h2d.Bitmap(tile,scene);
			bmp.x = cellX;
			bmp.y = baseline;
			var t = new h2d.Text( font, bmp );
			t.text = "Single Bitmap";
			t.maxWidth = 32;
			t.dropShadow = { dx : 1.0, dy : 1.0, color : 0xFF000000, alpha : 0.8 };
			t.y = txtBaseLine;
			t.x -= t.textWidth * 0.5;
			
			bmp.blendMode = Normal;
			var bmp = bmp;
			actions.push( function() bmp.alpha = Math.abs(Math.sin(hxd.Timer.oldTime) ) );
		}
		
		{
			cellX += bmp.width + incr;
			
			//single bitmap emit
			bmp = new h2d.Bitmap(tile,scene);
			bmp.x = cellX;
			bmp.y = baseline;
			bmp.emit = true;
			bmp.alpha = Math.random() * 0.25 + 0.5;
						
			var t = new h2d.Text( font, bmp );
			t.text = "Single Bitmap Emit";
			t.maxWidth = 32;
			t.dropShadow = { dx : 1.0, dy : 1.0, color : 0xFF000000, alpha : 0.8 };
			t.y = txtBaseLine;
			t.x -= t.textWidth * 0.5;
			
		}
		
		{
			cellX += bmp.width + incr + 16;
			
			var root = new h2d.Sprite(scene);
			root.x = cellX;
			root.y = baseline;
			
			//fout bitmap emit
			for( i in 0...4){
				bmp = new h2d.Bitmap(tiles[i], root);
				bmp.scaleX = bmp.scaleY = 0.33;
				bmp.x = 4 - (((i % 2) == 0) ? 0 : 16 );
				bmp.y = 4 - ((((i >> 1) % 2) == 0) ? 0 : 16);
				bmp.emit = true;
				bmp.alpha = Math.random() * 0.5 + 0.4;
			}
				
			var t = new h2d.Text( font, root );
			t.text = "Four Bitmap Emit";
			t.maxWidth = 32;
			t.dropShadow = { dx : 1.0, dy : 1.0, color : 0xFF000000, alpha : 0.8 };
			t.y = txtBaseLine;
			t.x -= t.textWidth * 0.5;
		}
		
		{
			cellX += 32 + incr;
			
			//single bitmap add no emit
			bmp = new h2d.Bitmap(tile,scene);
			bmp.x = cellX;
			bmp.y = baseline;
			bmp.blendMode = Add;
			var t = new h2d.Text( font, bmp );
			t.text = "Single Bitmap Add";
			t.maxWidth = 32;
			t.dropShadow = { dx : 1.0, dy : 1.0, color : 0xFF000000, alpha : 0.8 };
			t.y = txtBaseLine;
			t.x -= t.textWidth * 0.5;
		}
		
		{
			cellX += bmp.width + incr;
			
			//sprite match
			var sb = new h2d.SpriteBatch(tile, scene);
			var spread = 32;
			var rspread = 12;
			for ( i in 0...300) {
				var e = sb.alloc(tile);
				
				var ex = cellX 		+ spread * Math.random() - spread*0.5; 
				var ey = baseline 	+ spread * Math.random() - spread*0.5;
				
				e.x = ex;
				e.y = ey;
				
				e.scaleX = 0.2;
				e.scaleY = 0.2;
				
				actions.push(
				function() {
					e.x = ex + rspread * Math.random() - rspread * 0.5;
					e.y = ey + rspread * Math.random() - rspread * 0.5;
				});
			}
			
			var t = new h2d.Text( font, scene );
			t.x = cellX;
			t.y = baseline + txtBaseLine;
			t.text = "SpriteBatch";
			t.maxWidth = 32;
			t.dropShadow = { dx : 1.0, dy : 1.0, color : 0xFF000000, alpha : 0.8 };
			t.x -= t.textWidth * 0.5;
		}
		
		
		{
			cellX += 48 + incr;

			//single bitmap no emit
			var root = new h2d.CachedBitmap(scene,1024,1024);
			bmp = new h2d.Bitmap(tile, root);
			
			root.x = cellX - bmp.width;
			root.y = baseline - bmp.height;
			
			bmp.x = bmp.width;
			bmp.y = bmp.height;
			
			
			var t = new h2d.Text( font, root );
			t.text = "Single Bitmap Cached No Freeze";
			t.maxWidth = 32;
			t.dropShadow = { dx : 1.0, dy : 1.0, color : 0xFF000000, alpha : 0.8 };
			t.y = txtBaseLine + 32;
			
			var mbmp = bmp;
			actions.push(
			function() {
				mbmp.rotation += 0.1;
			});
		}
		
		
		{
			cellX += 48 + incr;

			//single bitmap no emit
			var root = new h2d.CachedBitmap(scene, 1024, 1024);
			root.name = "cached";
			root.freezed = true;
			var bmp = new h2d.Bitmap(tile, root);
			
			root.x = cellX - bmp.width;
			root.y = baseline - bmp.height;
			
			bmp.x = bmp.width;
			bmp.y = bmp.height;
			
			var t = new h2d.Text( font, root );
			var str = "Single Bitmap Cached"; 
			t.text = str ;
			t.maxWidth = 32;
			t.dropShadow = { dx : 1.0, dy : 1.0, color : 0xFF000000, alpha : 0.8 };
			t.y = txtBaseLine + 32;
			
			var spin = 0;
			var period  = 240;
			actions.push(
			function() {
				if ( spin >= (period >> 1) ) { 
					if( !root.freezed ){
						root.freezed = true; 
						t.text = str + " [FROZEN]";
						root.invalidate();
					}
				}
				
				if ( spin < (period>>1) ) { 
					root.freezed = false; 
					t.text = str; 
				}
				
				if ( spin == period)
					spin = 0;
				else 
					spin++;
				
				bmp.rotation += 0.1;
			});
		}
		
		{
			cellX += 48 + incr;
			//vector
			var gfx = new h2d.Graphics(scene);
			gfx.x = cellX;
			gfx.y = baseline;
			gfx.lineStyle(0.5, 0x0);
			gfx.beginFill( 0xFFFF00, 1.0);
			gfx.drawRect( -16, -16, 32, 32);
			gfx.endFill();
			
			var t = new h2d.Text( font, gfx );
			t.text = "Graphics";
			t.maxWidth = 32;
			t.dropShadow = { dx : 1.0, dy : 1.0, color : 0xFF000000, alpha : 0.8 };
			t.y = txtBaseLine;
			t.x -= t.textWidth * 0.5;
			
			t.x = Std.int( t.x );
		}
		
		{
			cellX += 64 + incr;
			
			bmp = new h2d.Bitmap(dcBg,scene);
			bmp.x = cellX;
			bmp.y = baseline;
			
			var bmp = new h2d.Bitmap(dcOverlay,scene);
			bmp.x = cellX;
			bmp.y = baseline;
			bmp.blendMode = SoftOverlay;
			
			var t = new h2d.Text( font, bmp );
			t.text = "Soft Overlay";
			t.maxWidth = 32;
			t.dropShadow = { dx : 1.0, dy : 1.0, color : 0xFF000000, alpha : 0.8 };
			t.y = txtBaseLine;
			t.x -= t.textWidth * 0.5;
			t.x = Std.int( t.x );
			
			actions.push(function (){
				bmp.alpha = Math.abs(Math.sin( hxd.Timer.oldTime * 2.0 ));
			});
		}
		
		{
			cellX += 96 + incr;
			
			var rt = new h2d.Mask(0,0,scene);
			
			//single bitmap no emit masked
			var bmp = new h2d.Bitmap(tile, rt);
			rt.x = cellX ;
			rt.y = baseline ;
			rt.offsetX = - bmp.width * 0.5;
			rt.offsetY = - bmp.height * 0.5;
			
			var t = new h2d.Text( font, bmp );
			t.text = "Single Bitmap Masked";
			t.maxWidth = 32;
			t.dropShadow = { dx : 1.0, dy : 1.0, color : 0xFF000000, alpha : 0.8 };
			t.y = txtBaseLine;
			t.x -= t.textWidth * 0.5;
			t.x = Std.int( t.x );
			bmp.blendMode = Normal;
			var bmp = bmp;
			
			actions.push( function() bmp.alpha = Math.abs(Math.sin(hxd.Timer.oldTime) ) );
			actions.push(function (){
				rt.width = Math.abs(Math.sin(hxd.Timer.oldTime) * bmp.width * 2);
				rt.height = Math.abs(Math.sin(hxd.Timer.oldTime) * bmp.height * 2);
			});
		}
		
		{
			cellX += 96 + incr;
			
			var t = new h2d.Text( font, scene );
			t.text = "Lorem ipsum dolor sit amet,\n consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.\n";
			t.dropShadow = { dx : 1.0, dy : 1.0, color : 0xFF000000, alpha : 0.8 };
			t.maxWidth = 128;
			t.x = cellX;
			t.y = baseline;
			t.x -= t.textWidth * 0.5;
			t.x = Std.int( t.x );
			
			actions.push( function() t.alpha = Math.abs(Math.sin(hxd.Timer.oldTime) ) );
		}
		
		
		{
			cellX += 96 + incr;
			
			var tile = h2d.Tile.fromAssets("assets/haxe.png", false);
			tile.getTexture().wrap = Repeat;
			//single bitmap no emit
			bmp = new h2d.Bitmap(tile,scene);
			bmp.x = cellX;
			bmp.y = baseline;
			var t = new h2d.Text( font, bmp );
			t.text = "Single Bitmap Repeat";
			t.maxWidth = 32;
			t.dropShadow = { dx : 1.0, dy : 1.0, color : 0xFF000000, alpha : 0.8 };
			t.y = txtBaseLine;
			t.x -= t.textWidth * 0.5;
			bmp.blendMode = Normal;
			var bmp = bmp;
			var tile = bmp.tile;
			var ow = tile.width;
			var oh = tile.height;
			tile.setSize( tile.width * 2, tile.height * 2 );
			bmp.x -= tile.width*0.5;
			bmp.y -= tile.height*0.5;
			
			var bu = @:privateAcces tile.u;
			var bu2 = @:privateAcces tile.u2;
			
			actions.push( function() {
				var r = hxd.Math.fumod(hxd.Timer.oldTime, 1.0);
				
				@:privateAcces tile.u = bu + r;
				@:privateAcces tile.u2 = bu2 + r;
			});
		}
	}
	
	var actions = [];
	
	function update() 	{
		hxd.Timer.update();
		for ( a in actions ) 
			a();
			
		engine.render(scene);
		engine.restoreOpenfl();
	}
	
	static function main() {
		new Demo();
	}
}
