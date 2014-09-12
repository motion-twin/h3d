package hxd.tools;

class Element{
	public var x:Int=0;
	public var y:Int=0;
	
	public var bd : flash.display.BitmapData;
	
	public var t: h2d.Tile;
	public var onComputed : Array<Element->Void>;
	
	public function new (bd:flash.display.BitmapData,onComputed) {
		this.bd = bd;
		this.onComputed = onComputed;
	}
	
	public function destroy() {
		bd.dispose();
		bd = null;
		
		t.dispose();
		t = null;
		
		onComputed = null;
	}
}

class Packer{
	public var atlas:flash.display.BitmapData;
	public var library: Map<String, Element>;
	
	public var masterTile : h2d.Tile;
	public var sizeSq = 2048;
	public var padding = 2;//2 pixels side ways
	
	public function new() {
		library = new Map();
	}
	
	/**
	 * id is idSprite + frame. Ex : "forest8"
	 * @param	id
	 * @param	?bd
	 */
	public function push(id:String, bd : flash.display.BitmapData, onComputed   ) {
		if ( library.exists( id ) ) {
			library.get(id).onComputed.push(onComputed);
		}
		else{
			var e = new Element(bd,[onComputed]);
			library.set(id, e);
		}
	}
	
	function compTex(e0:Element , e1:Element) :Int{
		var t0 = e0.bd;
		var t1 = e1.bd;
		return t0.width * t0.height - t1.width * t1.height;
	}
	
	
	public function process():flash.display.BitmapData {
		// Trier arSprite
		var pad = padding<<1; // Only even
		var hPad = pad >> 1;
		
		
		var wsum = 0;
		var hsum = 0;
		for ( l in library) {
			wsum += l.bd.width;
			hsum += l.bd.height;
		}
		
		while( sizeSq>1 ){
			if( sizeSq /2 > wsum && sizeSq /2 > hsum )
				sizeSq>>=1;
			else 
				break;
		}
		
		var bn = new BinPacker(sizeSq, sizeSq);
		var r :flash.geom.Rectangle; 
		
		var a = [];
		for ( l in library) a.push(l);
		var lib :Array<Element> = a;
		
		if ( lib == null ) throw "argh";
		lib.sort( compTex );
		
		for (e in lib) {
			r = bn.quickInsert(e.bd.width + pad, e.bd.height + pad);
			e.x = Std.int(r.x) + hPad;
			e.y = Std.int(r.y) + hPad;
		}
		
		// Draw BD	
		atlas = new flash.display.BitmapData(sizeSq, sizeSq, true,0x0);
		for (e in library) 
			atlas.copyPixels(e.bd, e.bd.rect, new flash.geom.Point(e.x, e.y), null, null, true);
		
		masterTile = h2d.Tile.fromBitmap(hxd.BitmapData.fromNative(atlas));
		
		for (e in library) {
			e.t = masterTile.sub(e.x, e.y, e.bd.width, e.bd.height);	
			for ( proc in e.onComputed ) {
				proc( e );
			}
		}
		
		return atlas;
	}
	
	public inline function get(id:String):Element {
		return library.get(id);
	}
	
	public function destroy() {
		for (e in library) {
			e.destroy();
			e = null;
		}
		
		atlas.dispose();
		
		masterTile.dispose();
		
		library = null;
		atlas = null;
		masterTile = null;
	}
}