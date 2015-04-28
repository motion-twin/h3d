package h2d;

import hxd.res.TiledMap;
import haxe.io.Path;

typedef TileInfo = {
	data    : TiledMapTileData, 
	tileset : TiledMapTileset,
}

class TiledLevel extends Sprite
{
	public var data    (default, null) : TiledMapData;
	public var batches (default, null) : Array<SpriteBatch>;
	
	var mainTiles : Map<Int, Tile>;
	var subTiles  : Map<Int, Tile>;
	
	static var tmpTileData : TiledMapTileData;
	
	public function new(map : TiledMap, ?p) {
		super(p);
		
		data      = map.toMap();
		batches   = [];
		mainTiles = new Map<Int, Tile>();
		subTiles  = new Map<Int, Tile>();
		
		var dir = Path.directory(map.entry.path);
		
		// creates the tile cache
		for (ts in data.tilesets) {
			if (ts.image != null) { 
				// the tileset is a single image
				var main = loadTile(ts, Path.join([dir, ts.image.source]));
				if (ts.margin != 0)
					main = main.sub(ts.margin, ts.margin, main.width - ts.margin * 2, main.height - ts.margin * 2);
				var tex = main.getTexture();
				mainTiles[tex.id] = main;
				var i = 0;
				for (t in main.grid(ts.tilewidth + ts.spacing)) {
					t.dy = -t.height;
					subTiles[ts.firstgid + i++] = t;
				}
			} else { 
				// the tileset is a collection of images
				for (td in ts.tiledata) {
					var sub = loadTile(ts, Path.join([dir, td.image.source]));
					if (sub == null) continue;
					sub.dy = -sub.height;
					subTiles[ts.firstgid + td.id] = sub;
				}
			}
		}
		
		// spawn layers
		var queueT = [];
		var queueX = [];
		var queueY = [];
		var queueR = [];
		
		for (l in data.layers) {
			if (l.data != null) {
				// layer of tiles
				for (y in 0...data.height) {
					for (x in 0...data.width) {
						var gid = l.data[x + y * data.width];
						if (gid <= 0) continue;
						var tinfo = getTileInfo(gid);
						if (!spawnTile(l, tinfo, x, y)) continue;
						queueT.push(subTiles[tinfo.tileset.firstgid + tinfo.data.id]);
						queueX.push(data.tilewidth * x);
						queueY.push(data.tileheight * (y + 1));
						queueR.push(0.0);
					}
				}
			} else if (l.objects != null) {
				// layer of objects
				for (o in l.objects) {
					var tinfo = getTileInfo(o.gid);
					if (!spawnObject(l, o, tinfo) || o.gid == 0 ) continue;
					
					queueT.push(subTiles[tinfo.tileset.firstgid + tinfo.data.id]);
					queueX.push(o.x);
					queueY.push(o.y);
					queueR.push(o.rotation);
				}
			}
		}
		
		var batch : SpriteBatch = null;
		var prevTex = -1;
		for (i in 0...queueT.length) {
			var tile = queueT[i];
			var tex  = tile.getTexture();
			if (tex.id != prevTex) {
				var main = mainTiles[tex.id];
				if (main == null) {
					main = Tile.fromTexture(tex);
					mainTiles[tex.id] = main;
				}
				batch = new SpriteBatch(main, this);
				prevTex = tex.id;
			}
			var be = batch.alloc(tile);
			be.x = queueX[i];
			be.y = queueY[i];
			be.rotation = queueR[i];
			batches.push(batch);
		}
	}

	/*
	 * This function is called when the level loads a texture to create its tile.
	 * Override this to change the texture source, or to retrive tiles from an atlas...  
	 */	
	public function loadTile(tileset : TiledMapTileset, path : String) : h2d.Tile {
		return hxd.Res.load(path).toTile();
	}
	
	/*
	 * Override this to do something on tile spawning
	 * ie. Spawn game entites, add physics ...
	 * return true to display the tile, or false to discard it
	 */
	public function spawnTile(layer : TiledMapLayer, tinfo : TileInfo, x : Int, y : Int) : Bool { return true; }
	
	/*
	 * Override this to do something on object spawning
	 * ie. Spawn game entites, add physics ...
	 * return true to display the object, or false to discard it
	 */
	public function spawnObject(layer : TiledMapLayer, obj : TiledMapObject, ?tinfo : TileInfo) : Bool { return true; }
	
	public function getLayer(name) {
		for (l in data.layers) if (l.name == name) return l;
		return null;
	}
	
	public function getTileset(name) {
		for (t in data.tilesets) if (t.name == name) return t;
		return null;
	}
	
	function getTileInfo(gid) : TileInfo {
		if (gid == 0) return null;
		
		if (tmpTileData == null)
			tmpTileData = { id : 0, properties : new Map<String, String>(), image : null };
			
		// find the tileset
		var tileset = data.tilesets[0];
		for (ts in data.tilesets) {
			if (ts.firstgid > gid) break;
			tileset = ts;
		}
		
		var id = gid - tileset.firstgid;
		var tileData = tileset.tiledata[id];
		
		if (tileData == null) {
			tileData = tmpTileData;
			tileData.id = id;
		}
		
		return { data : tileData, tileset : tileset };
	}
}