

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
		var n = openfl.Assets.getBitmapData( path );
		var tile =  h2d.Tile.fromBitmap( hxd.BitmapData.fromNative( n  ));
		#if flash
		tile.getTexture().flags.set( AlphaPremultiplied );
		#end
		tile.getTexture().name = path;
		return tile;
	}
	
	function init() {
		hxd.System.setLoop(update);
		scene = new h2d.Scene();
		
		var font = hxd.res.FontBuilder.getFont("arial", 10);
		var tile = getTile("assets/haxe.png");
		tile.setCenterRatio(0.5, 0.5);
		
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
		}
		
		{
			cellX += bmp.width + incr;
			
			//single bitmap emit
			bmp = new h2d.Bitmap(tile,scene);
			bmp.x = cellX;
			bmp.y = baseline;
			bmp.emit = true;
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
			
			actions.push(
			function() {
				bmp.rotation += 0.1;
			});
		}
		
		
		{
			cellX += 48 + incr;

			//single bitmap no emit
			var root = new h2d.CachedBitmap(scene, 1024, 1024);
			root.name = "cached";
			root.freezed = true;
			bmp = new h2d.Bitmap(tile, root);
			
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
		}
	}
	
	var actions = [];
	
	function update() 	{
		for ( a in actions ) 
			a();
		
		engine.render(scene);
		engine.restoreOpenfl();
	}
	
	static function main() {
		new Demo();
	}
}
