
import mt.deepnight.slb.BLib;

class Demo extends flash.display.Sprite
{
	var engine : h3d.Engine;
	var scene : h2d.Scene;
	
	var sb : h2d.SpriteBatch;
	
	function new() {
		super();
		engine = new h3d.Engine();
		engine.onReady = init;
		engine.backgroundColor = 0xFFCCCCCC;
		engine.init();
	}
	
	function init() {
		hxd.System.setLoop(update);
		scene = new h2d.Scene();
		
		var sc = 0.25;
		
		var slb :mt.deepnight.slb.BLib = mt.deepnight.slb.assets.TexturePacker.importXml( "assets/VikingFont.xml" );
		
		var sb = new h2d.SpriteBatch( slb.tile, scene);
		sb.filter = true;
		var e = slb.hbe_get(sb,"",0);
		e.x = 50;
		e.y = 50;
		e.scaleX = e.scaleY = sc;
		
		var e0 = slb.hbe_get(sb,"",1);
		e0.x = e.x + e.width;
		e0.y = 50;
		e0.scaleX = e0.scaleY = sc;
		
		var e1 = slb.hbe_get(sb,"S");
		e1.x = e0.x + e0.width;
		e1.y = 50;
		e1.scaleX = e1.scaleY = sc;
		
		var arr = [];
		var gs = slb.getGroups();
		
		arr.push( { code: 0, tile:new h2d.Tile( slb.tile.getTexture(), 0, 0, 0, 0) } );
		
		for ( k in gs.keys() ) {
			var v = gs.get(k);
			switch(k) {
				case "Space": 
					var fr = slb.getFrameData( k );
					var t : h2d.Tile = slb.getTile( k );
					t.setSize( fr.realFrame.realWid, fr.realFrame.realHei);
					arr.push( { code: 0xA0, tile:t } );
					arr.push( { code: 13,	tile:t } );
					arr.push( { code: 0x20, tile:t } );
					arr.push( { code: 0xA, tile:t } );
				case "": 
					for ( i in 0...10) 
						arr.push( {code: 0x30 + i, 
							tile: slb.getTile( k, i ) });	
				default:	arr.push( { code: haxe.Utf8.charCodeAt( k, 0 ), tile: slb.getTile( k ) });
			}
		}
		
		var fnt = new TileFont( "kraash_viking", 120, 280, arr );
		
		var t = new h2d.Text( fnt, scene);
		t.x = 100;
		t.y = 400;
		t.text = "01986 SAPIN";
		
		var t = new h2d.Text( fnt, scene);
		t.x = 500;
		t.y = 50;
		t.text = "ALI\nBABA";
		
		var t = new h2d.Text( mt.heaps.TileFont.fromSlb("viking",slb, 120, 280),scene );
		t.x = 700;
		t.y = 50;
		t.text = "ALI\nB0B0";
	}
	
	function update() 	{
		engine.render(scene);
		engine.restoreOpenfl();
	}
	
	static function main() {
		new Demo();
	}
}
