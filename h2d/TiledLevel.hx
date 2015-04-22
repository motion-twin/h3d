package h2d;

import haxe.io.Path;

class TiledLevel extends Sprite {
	
	public var data (default, null) : hxd.res.TiledMapData;
	
	var batches  : Map<String, SpriteBatch>;
	var sheets   : Map<String, Tile>;
	var tilesets : Map<String, Array<Tile>>;
	
	static var tmpTileData : hxd.res.TiledMapTileData;
	
	public function new(map : hxd.res.TiledMap, ?p) {
		super(p);
		
		batches  = new Map<String, SpriteBatch>();
		sheets   = new Map<String, Tile>();
		tilesets = new Map<String, Array<Tile>>();
		data     = map.toMap();
		
		var dir = Path.directory(map.entry.path);
		
		// populate tilesets
		for (ts in data.tilesets) {
			if (ts.image != null) {
				// tileset from a single image
				var master = loadImage(Path.join([dir, ts.image.source]), true);
				sheets  [ts.name] = master;
				tilesets[ts.name] = master.grid(ts.tilewidth);
			} else {
				// tileset from a collection of images
				var set = [];
				for (td in ts.tiledata)
					set[td.id] = loadImage(Path.join([dir, td.image.source]), false);
				tilesets[ts.name] = set;
			}
		}
		
		onLoaded();
		
		// spawn layers
		var ts = data.tilesets[0];
		for (l in data.layers) {
			if (l.data != null) {
				// layer of tiles
				for (y in 0...data.height) {
					for (x in 0...data.width) {
						var gid = l.data[x + y * data.width];
						if (gid <= 0) continue;
						var tinfo = getTileInfo(gid);
						var keepTile = spawnTile(l, tinfo.data, x, y);
						if (keepTile) _spawnTile(l, ts, tinfo.data.id, x * data.tilewidth, y * data.tileheight);
					}
				}
			} else if (l.objects != null) {
				// layer of objects
				for (o in l.objects) {
					var tinfo = getTileInfo(o.gid);
					var keepTile = spawnObject(l, o, tinfo.data);
					if (tinfo != null && keepTile) _spawnTile(l, tinfo.tileset, tinfo.data.id, o.x, o.y, o.rotation);
				}
			}
		}
		for (b in batches) b.optimizeForStatic(true);
	}
	
	public function onLoaded() {}
	
	/*
	 * Override this to do something on object spawning
	 * ie. Replace it with a custom sprites, add physics ...
	 * if the object is a tile, return true to display it, or false to discard it
	 */
	public function spawnObject(layer : TiledMapLayer, obj : TiledMapObject, ?tile : TiledMapTileData) : Bool { return true; }
	
	/*
	 * Override this to do something on tile spawning
	 * ie. Replace it with custom sprites, add physics ...
	 * return true to display it, or false to discard it
	 */
	public function spawnTile(layer : TiledMapLayer, tile : TiledMapTileData, x : Int, y : Int) : Bool { return true; }
	
	/*
	 * Override this to do something change the way images are loaded
	 * "tileset" specifies if the image is a tileset or a single image
	 * ie. get images from a TexturePacker atlas
	 */	
	public function loadImage(path : String, tileset : Bool) : h2d.Tile {
		var t = hxd.Res.load(path).toTile();
		t.setCenterRatio(0, 1);
		return t;
	}
	
	public function getLayer(name) {
		for (l in data.layers) if (l.name == name) return l;
		return null;
	}
	
	public function getTileset(name) {
		for (t in data.tilesets) if (t.name == name) return t;
		return null;
	}
	
	function _spawnTile(layer, tileset, id, x, y, ?rotation) {
		if (sheets.exists(tileset.name)) { 
			// tile from an image region
			var t = getBatch(layer.name, tileset.name).alloc(tilesets[tileset.name][id]);
			t.x = x;
			t.y = y;
			if (rotation != null) t.rotation = rotation;
		} else {
			// tile from an image
			var t = new Bitmap(tilesets[tileset.name][id], this);
			t.x = x;
			t.y = y;
			if (rotation != null) t.rotation = rotation;
		}
	}
	
	function getBatch(layer : String, tileset : String) : SpriteBatch {
		var key = layer + tileset;
		if (batches.exists(key))
			return batches[key];
		
		var sb = new SpriteBatch(sheets[tileset], this);
		sb.hasVertexAlpha = false;
		sb.hasVertexColor = false;
		batches[key] = sb;
		return sb;
	}
	
	function getTileInfo(gid) : {data : TiledMapTileData, tileset : TiledMapTileset} {
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