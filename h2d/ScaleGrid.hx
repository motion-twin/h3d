package h2d;

class ScaleGrid extends h2d.TileGroup {
	
	public var borderWidth : Int;
	public var borderHeight : Int;
	public var tileBorders(default,set) : Bool;

	var w:Float;
	var h:Float;
	
	public function new( tile, borderW, borderH, ?parent ) {
		super(tile,parent);
		borderWidth = borderW;
		borderHeight = borderH;
		width = tile.width;
		height = tile.height;
	}
	
	function set_tileBorders(b) {
		this.tileBorders = b;
		reset();
		return b;
	}
	
	override function set_width(w:Float) {
		this.width = w;
		this.w = w;
		reset();
		return w;
	}

	override function set_height(h:Float) {
		this.height = h;
		this.h = h;
		reset();
		return h;
	}
	
	override function draw( ctx : RenderContext ) {
		if( content.isEmpty() ) {
			var bw = borderWidth, bh = borderHeight;
			var width = this.w, height = this.h;
			
			inline function int(v) return Std.int(v);
			// 4 corners
			content.add(0, 0, tile.sub(0, 0, bw, bh));
			content.add(int(width - bw), 0, tile.sub(tile.width - bw, 0, bw, bh));
			content.add(0, int(height-bh), tile.sub(0, tile.height - bh, bw, bh));
			content.add(int(width - bw), int(height - bh), tile.sub(tile.width - bw, tile.height - bh, bw, bh));

			var sizeX = tile.width - bw * 2;
			var sizeY = tile.height - bh * 2;
			
			if( !tileBorders ) {
				
				var w = int(width - bw * 2);
				var h = int(height - bh * 2);
				
				var t = tile.sub(bw, 0, sizeX, bh);
				t.scaleToSize(w, bh);
				content.add(int(bw), 0, t);

				var t = tile.sub(bw, tile.height - bh, sizeX, bh);
				t.scaleToSize(w, bh);
				content.add(int(bw), int(h + bh), t);

				var t = tile.sub(0, bh, bw, sizeY);
				t.scaleToSize(bw, h);
				content.add(0, bh, t);

				var t = tile.sub(tile.width - bw, bh, bw, sizeY);
				t.scaleToSize(bw, h);
				content.add(int(w + bw), bh, t);
				
			} else {
				
				var rw = int((width - bw * 2) / sizeX);
				for( x in 0...rw ) {
					content.add(int(bw + x * sizeX), 0, tile.sub(bw, 0, sizeX, bh));
					content.add(int(bw + x * sizeX), int(height - bh), tile.sub(bw, tile.height - bh, sizeX, bh));
				}
				var dx = int(width - bw * 2 - rw * sizeX);
				if( dx > 0 ) {
					content.add(int(bw + rw * sizeX), 0, tile.sub(bw, 0, dx, bh));
					content.add(int(bw + rw * sizeX), int(height - bh), tile.sub(bw, tile.height - bh, dx, bh));
				}

				var rh = Std.int((height - bh * 2) / sizeY);
				for( y in 0...rh ) {
					content.add(0, int(bh + y * sizeY), tile.sub(0, bh, bw, sizeY));
					content.add(int(width - bw), int(bh + y * sizeY), tile.sub(tile.width - bw, bh, bw, sizeY));
				}
				var dy = int(height - bh * 2 - rh * sizeY);
				if( dy > 0 ) {
					content.add(0, int(bh + rh * sizeY), tile.sub(0, bh, bw, dy));
					content.add(int(width - bw), int(bh + rh * sizeY), tile.sub(tile.width - bw, bh, bw, dy));
				}
			}
			
			var t = tile.sub(bw, bh, sizeX, sizeY);
			t.scaleToSize(int(width - bw * 2), int(height - bh * 2));
			content.add(bw, bh, t);
		}
		super.draw(ctx);
	}
	
}