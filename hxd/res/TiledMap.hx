package hxd.res;

typedef TiledMapData = {
	var width		: Int;
	var height		: Int;
	var tilewidth	: Int;
	var tileheight	: Int;
	var layers		: Array<TiledMapLayer>;
	var tilesets	: Array<TiledMapTileset>;
}

typedef TiledMapTileset = {
    var name	: String;
    var source	: String;
	var image   : { width : Int, height : Int, source : String };

    var firstgid	: Int;
    var tilewidth	: Int;
    var tileheight	: Int;
    var margin		: Int;
    var spacing		: Int;
	var offset		: { x: Int, y : Int };
	
	var properties  : Map<String,String>;
	var tiledata    : Map<Int, TiledMapTileData>;
}

typedef TiledMapTileData = {
	var id : Int;
	var properties : Map<String, String>;
	var image : { width : Int, height : Int, source : String };
}

typedef TiledMapLayer = {
	var data	: Array<Int>;
	var name	: String;
	var opacity	: Float;
	var objects	: Array<TiledMapObject>;
}

typedef TiledMapObject = {
	var x : Int;
	var y : Int;
	var rotation : Float;
	var id  : Int;
	var gid : Int;
	var name : String; 
	var type : String;
	var polytype : TiledMapObjectType;
	var polypoints : Array<{ x: Int, y : Int}>;
	var properties : Map<String, String>;
}

enum TiledMapObjectType {
    POLYLINE;
    POLYGON;
    RECTANGLE;
    ELLIPSE;
}

class TiledMap extends Resource {
	
	public function toMap() : TiledMapData {
		var data = entry.getBytes().toString();
		var base = new haxe.crypto.BaseCode(haxe.io.Bytes.ofString("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"));
		var x = new haxe.xml.Fast(Xml.parse(data).firstElement());
		
		var tilesets = new Array<TiledMapTileset>();
		for (ts in x.nodes.tileset)
			tilesets.push(parseTileset(ts));
		
		var layers = new Array<TiledMapLayer>();
		for( l in x.nodes.layer )
			layers.push(parseLayer(l, base));
		
		for( l in x.nodes.objectgroup ) {
			var objs = [];
			for ( o in l.nodes.object ) objs.push(parseObject(o));
			
			if (!l.has.draworder) {
				// top to down draw order
				objs.sort(function(a, b) { return a.y - b.y; });
			}
				
			layers.push({
				name    : l.att.name,
				opacity : 1.,
				objects : objs,
				data    : null,
			});
		}
		
		return {
			width      : Std.parseInt(x.att.width),
			height     : Std.parseInt(x.att.height),
			tilewidth  : Std.parseInt(x.att.tilewidth),
			tileheight : Std.parseInt(x.att.tileheight),
			tilesets   : tilesets,
			layers     : layers,
		};
	}
	
	function parseTileset (x : haxe.xml.Fast) {
		var firstgid = Std.parseInt(x.att.firstgid);
		var source = x.has.source ? x.att.source : null;
		
		if (source != null) {
			var dir = haxe.io.Path.directory(entry.path); 
			var subData = hxd.Res.load(haxe.io.Path.join([dir, source])).entry.getBytes().toString();
			x = new haxe.xml.Fast(Xml.parse(subData).firstElement());
		}
		
		var set = {
			name       : x.att.name,
			source     : source,
			image      : x.hasNode.image ? parseImage(x.node.image) : null,
			firstgid   : firstgid,
			tilewidth  : Std.parseInt(x.att.tilewidth),
			tileheight : Std.parseInt(x.att.tileheight),
			margin     : x.has.margin ? Std.parseInt(x.att.margin) : 0,
			spacing    : x.has.spacing ? Std.parseInt(x.att.spacing) : 0,
			offset     : x.hasNode.tileoffset ? { x : Std.parseInt(x.node.tileoffset.att.x), y : Std.parseInt(x.node.tileoffset.att.y) } : { x : 0, y : 0 },
			properties : parseProperties(x),
			tiledata   : new Map<Int, TiledMapTileData>()
		}
		
		for (t in x.nodes.tile) {
			set.tiledata.set(Std.parseInt(t.att.id), {
				id    : Std.parseInt(t.att.id),
				image : t.hasNode.image ? parseImage(t.node.image) : null,
				properties : parseProperties(t),
			});
		}
		
		return set;
	}
	
	function parseImage(x : haxe.xml.Fast) {
		return {
			width  : Std.parseInt(x.att.width), 
            height : Std.parseInt(x.att.height), 
			source : x.att.source,
		};
	}
	
	function parseLayer(l : haxe.xml.Fast, b : haxe.crypto.BaseCode) {
		var data = StringTools.trim(l.node.data.innerData);
		while( data.charCodeAt(data.length-1) == "=".code )
			data = data.substr(0, data.length - 1);
		var bytes = haxe.io.Bytes.ofString(data);
		var bytes = b.decodeBytes(bytes);
		bytes = format.tools.Inflate.run(bytes);
		var input = new haxe.io.BytesInput(bytes);
		var data = [];
		for( i in 0...bytes.length >> 2 )
			data.push(input.readInt32());
			
		return {
			name : l.att.name,
			opacity : l.has.opacity ? Std.parseFloat(l.att.opacity) : 1.,
			objects : new Array<TiledMapObject>(),
			data : data,
		};
	}
	
	function parseObject (o : haxe.xml.Fast) {
		var obj = {
			id   : Std.parseInt(o.att.id),
			gid  : o.has.gid  ? Std.parseInt(o.att.gid) : 0,
			name : o.has.name ? o.att.name : null,
			type : o.has.type ? o.att.type : null, 
			x : Std.parseInt(o.att.x), 
			y : Std.parseInt(o.att.y),
			rotation   : o.has.rotation ? Std.parseFloat(o.att.rotation) / 180.0 * Math.PI : 0.0,
			polytype   : RECTANGLE,
			polypoints : null,
			properties : parseProperties(o)
		};
		
		for ( po in o.elements )  {
			switch(po.name) {
				case "polyline"  : { obj.polytype = POLYLINE; obj.polypoints = parsePoints(po.att.points); }
				case "polygon"   : { obj.polytype = POLYGON;  obj.polypoints = parsePoints(po.att.points); }
				case "ellipse"   : { obj.polytype = ELLIPSE; }
			}
		}
		return obj;
	}
	
	function parseProperties(x : haxe.xml.Fast) {
		var props = new Map<String, String>();
		if (!x.hasNode.properties) 
			return props;
		
		for (pp in x.node.properties.nodes.property) 
			props.set(pp.att.name, pp.att.value);
		return props;
	}
	
	function parsePoints(str : String) {
		var points = [];
		var stra = str.split(" ");
		for (point in stra) {
			var coords = point.split(",");
			points.push( { x : Std.parseInt(coords[0]), y : Std.parseInt(coords[1]) } );
		}
		return points;
	}
}