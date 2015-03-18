package hxd.res;

typedef TiledMapLayer = {
	var data : Array<Int>;
	var name : String;
	var opacity : Float;
	var objects : Array<TiledObject>;
}

typedef TiledMapData = {
	var width : Int;
	var height : Int;
	var layers : Array<TiledMapLayer>;
}

enum TiledObjectType {
    POLYLINE;
    POLYGON;
    RECTANGLE;
    ELLIPSE;
}

typedef TiledObject = {
	var x : Int;
	var y : Int; 
	var name : String; 
	var type : String;
	var polyType : TiledObjectType;
	var polyPoints : Array<{ x: Int, y : Int}>;
	var properties : Map<String, String>;
}

class TiledMap extends Resource {
	
	public function toMap() : TiledMapData {
		var data = entry.getBytes().toString();
		var base = new haxe.crypto.BaseCode(haxe.io.Bytes.ofString("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"));
		var x = new haxe.xml.Fast(Xml.parse(data).firstElement());
		var layers = [];
		for( l in x.nodes.layer ) {
			var data = StringTools.trim(l.node.data.innerData);
			while( data.charCodeAt(data.length-1) == "=".code )
				data = data.substr(0, data.length - 1);
			var bytes = haxe.io.Bytes.ofString(data);
			var bytes = base.decodeBytes(bytes);
			bytes = format.tools.Inflate.run(bytes);
			var input = new haxe.io.BytesInput(bytes);
			var data = [];
			for( i in 0...bytes.length >> 2 )
				data.push(input.readInt32());
			layers.push( {
				name : l.att.name,
				opacity : l.has.opacity ? Std.parseFloat(l.att.opacity) : 1.,
				objects : [],
				data : data,
			});
		}
		for( l in x.nodes.objectgroup ) {
			var objs = [];
			for ( o in l.nodes.object ) {
				//if ( !o.has.name ) continue;
				var obj = {
					name : o.has.name ? o.att.name : null,
					type : o.has.type ? o.att.type : null, 
					x : Std.parseInt(o.att.x), 
					y : Std.parseInt(o.att.y),
					polyType : RECTANGLE,
					polyPoints : null,
					properties : new Map<String, String>()
				};
				
				for ( po in o.elements )  {
					switch(po.name) {
						case "polyline"  : { obj.polyType = POLYLINE; obj.polyPoints = parsePoints(po.att.points); }
						case "polygon"   : { obj.polyType = POLYGON;  obj.polyPoints = parsePoints(po.att.points); }
						case "ellipse"   : { obj.polyType = ELLIPSE; }
						case "properties": {
							for (pp in o.node.properties.elements)
								obj.properties.set(pp.att.name, pp.att.value);
						}
					}
				}
				
				objs.push(obj);
			}
			layers.push( {
				name : l.att.name,
				opacity : 1.,
				objects : objs,
				data : null,
			});
		}
		return {
			width : Std.parseInt(x.att.width),
			height : Std.parseInt(x.att.height),
			layers : layers,
		};
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