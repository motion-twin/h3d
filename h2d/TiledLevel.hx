package h2d;

import hxd.res.TiledMap;

class TiledLevel extends Sprite
{
	public var data (default, null) : TiledMapData;
	
	var batches  : Map<String, SpriteBatch>;
	var sheets   : Map<String, Tile>;
	var tilesets : Map<String, Array<Tile>>;
	
	public function new(map : TiledMapData, ?p) {
		super(p);
		batches  = new Map<String, SpriteBatch>();
		sheets   = new Map<String, Tile>();
		tilesets = new Map<String, Array<Tile>>();
		data     = map;
		
		// populate tilesets
		for (ts in data.tilesets) {
			if (ts.image != null) {
				// tileset from a single image
				var master = hxd.Res.load(ts.image.source).toTile();
				sheets  [ts.name] = master;
				tilesets[ts.name] = master.grid(ts.tilewidth);
			} else {
				// tileset from a collection of images
				var set = [];
				for (td in ts.tiledata)
					set.push(hxd.Res.load(td.image.source).toTile());
				tilesets[ts.name] = set;
			}
		}
		
		// spawn layers
		for (l in data.layers) {
			if (l.data != null) {
				// layer of tiles
				for (y in 0...data.height) {
					for (x in 0...data.width) {
						var gid = l.data[x + y * data.width];
						if (gid <= 0) continue;
						spawnTile(l, gid, x * data.tilewidth, y * data.tileheight);
					}
				}
			} else if (l.objects != null) {
				// layer of objects
				for (o in l.objects) {
					var keepTile = spawnObject(o);
					if (o.gid > 0 && keepTile) spawnTile(l, o.gid, o.x, o.y, true);
				}
			}
		}
		for (b in batches) b.optimizeForStatic(true);
	}
	
	/*
	 * Override this to do something on object spawning
	 * if the object is a tile, return true to display it, or false to discard it
	 */
	public function spawnObject(obj : TiledMapObject) : Bool { return true; }
	
	public function getLayer(name) {
		for (l in data.layers) if (l.name == name) return l;
		return null;
	}
	
	public function getTileset(name) {
		for (t in data.tilesets) if (t.name == name) return t;
		return null;
	}
	
	function spawnTile(layer, gid, x, y, obj = false) {
		var ts = getTilesetGid(gid);
		var id = gid - ts.firstgid;
		
		if (sheets.exists(ts.name)) { 
			// tile from an image region
			var t = getBatch(layer.name, ts.name).alloc(tilesets[ts.name][id]);
			t.x = x;
			t.y = obj ? y - t.height : y;
		} else {
			// tile from an image
			var t = new Bitmap(tilesets[ts.name][id], this);
			t.x = x;
			t.y = obj ? y - t.height : y;
		}
	}
	
	function getTilesetGid(gid) {
		var res = data.tilesets[0];
		for (ts in data.tilesets) {
			if (ts.firstgid > gid) return res;
			res = ts;
		}
		return res;
	}
	
	function getBatch(layer : String, tileset : String) : SpriteBatch {
		var key = layer + tileset;
		if (batches.exists(key))
			return batches[key];
		
		var sb = new SpriteBatch(sheets[tileset], this);
		batches[key] = sb;
		return sb;
	}
}