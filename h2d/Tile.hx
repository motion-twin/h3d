package h2d;
import haxe.CallStack;
import hxd.BitmapData;
import hxd.Math;
import hxd.Profiler;
import hxd.System;

@:allow(h2d)
/**
 * A tile is a portion of a texture aka sub texture
 * Is can be used to address an atlas etc
 * to create a random tile you can new(tex,x,y,w,h) it or call fromColor
 */
class Tile {

	static inline var EPSILON_PIXEL : hxd.Float32 = 0.001;

	var 		innerTex : h3d.mat.Texture;

	public var 	u(default,null) : hxd.Float32;
	public var 	v(default,null) : hxd.Float32;
	public var 	u2(default,null) : hxd.Float32;
	public var 	v2(default,null) : hxd.Float32;

	public var dx : Int;
	public var dy : Int;
	
	public var x(default,null) : Int;
	public var y(default, null) : Int;
	
	/** 
	 * width is the logical width in pixels ( compared to the backing texture width which is power of 2 )
	 */
	public var width(default,null) : Int; 
	
	/** 
	 * height is the logical width in pixels ( compared to the backing texture width which is power of 2 )
	 */
	public var height(default,null) : Int;

	/**
	 * see Tile.fromXXXX rather than trying to create me directly
	 */
	public function new(tex : h3d.mat.Texture, x:Int, y:Int, w:Int, h:Int, dx=0, dy=0) {
		this.innerTex = tex;
		this.x = x;
		this.y = y;
		this.width = w;
		this.height = h;
		this.dx = dx;
		this.dy = dy;
		if( tex != null ) setTexture(tex);
	}

	#if(flash || openfl)
	public static function fromFlashBitmap( bmp : flash.display.BitmapData, ?allocPos : h3d.impl.AllocPos ) : Tile {
		return fromBitmap(BitmapData.fromNative( bmp ),allocPos);
	}
	#end
	
	public static function fromBitmap( bmp : hxd.BitmapData, ?allocPos : h3d.impl.AllocPos ) :Tile {
		var w = hxd.Math.nextPow2(bmp.width);
		var h = hxd.Math.nextPow2(bmp.height);
		
		var tex = new h3d.mat.Texture(w, h);
		var t = new Tile(tex, 0, 0, bmp.width, bmp.height);
		if ( h3d.Engine.getCurrent() != null)  
			t.upload(bmp);
		return t;
	}
	
	public static function fromTexture( t : h3d.mat.Texture ) {
		return new Tile(t, 0, 0, t.width, t.height);
	}
	
	public static function fromPixels( pixels : hxd.Pixels, ?allocPos : h3d.impl.AllocPos ) {
		if ( pixels.flags.has(Compressed) ) {
			var t = h3d.mat.Texture.fromPixels(pixels);
			return new Tile( t, 0, 0, pixels.width, pixels.height);
		}
			
		var pix2 = pixels.makeSquare(true);
		var t = h3d.mat.Texture.fromPixels(pix2);
		if( pix2 != pixels ) pix2.dispose();
		return new Tile(t, 0, 0, pixels.width, pixels.height);
	}
	
	#if (flash || openfl)
	/**
	 * If you can prefer my baby brother wich takes rray as argument cuz it will pack all in a single large texture
	 */
	public static inline function fromSprite( sprite : flash.display.DisplayObject, ?allocPos : h3d.impl.AllocPos ) {
		return fromSprites([sprite])[0];
	}
	
	/**
	 * todo enhance atlasing so that we never exceeed 2048 
	 */
	public static function fromSprites( sprites : Array<flash.display.DisplayObject>, ?allocPos : h3d.impl.AllocPos ) {
		var tmp = [];
		var width = 0;
		var height = 0;
		for( s in sprites ) {
			var g = s.getBounds(s);
			var dx = Math.floor(g.left);
			var dy = Math.floor(g.top);
			var w = Math.ceil(g.right) - dx;
			var h = Math.ceil(g.bottom) - dy;
			tmp.push( { s : s, x : width, dx : dx, dy : dy, w : w, h : h } );
			width += w;
			if( height < h ) height = h;
		}
		var rw = 1, rh = 1;
		while( rw < width )
			rw <<= 1;
		while( rh < height )
			rh <<= 1;
			
		#if mobile
		//make it square for better perfs
		rh = hxd.Math.imax(rw, rh);
		rw = hxd.Math.imax(rw, rh);
		#end
		
		var bmp = new flash.display.BitmapData(rw, rh, true, 0);
		var m = new flash.geom.Matrix();
		for( t in tmp ) {
			m.tx = t.x-t.dx;
			m.ty = -t.dy;
			bmp.draw(t.s, m);
		}
		var main = fromBitmap(hxd.BitmapData.fromNative(bmp), allocPos);
		bmp.dispose();
		var tiles = [];
		for( t in tmp )
			tiles.push(main.sub(t.x, 0, t.w, t.h, t.dx, t.dy));
		return tiles;
	}
	#end
	
	public static function fromAssets( str:String ) {
		return fromTexture( h3d.mat.Texture.fromAssets(str) );
	}
	
	//I wonder if returning the empty texture is useful...
	public function getTexture() : h3d.mat.Texture {
		if ( innerTex == null ) 
			return Tools.getCoreObjects().getEmptyTexture();
		return innerTex;
	}

	public function isDisposed() {
		return innerTex == null || innerTex.isDisposed();
	}

	function setTexture(tex:h3d.mat.Texture) {
		this.innerTex = tex;
		if( tex != null ) {
			this.u = (x + EPSILON_PIXEL) / tex.width;
			this.v = (y + EPSILON_PIXEL) / tex.height;
			this.u2 = (x + width - EPSILON_PIXEL) / tex.width;
			this.v2 = (y + height - EPSILON_PIXEL) / tex.height;
		}
	}

	public inline function switchTexture( t : Tile ) {
		setTexture(t.innerTex);
	}

	/**
	 * Returns a new sub tile which is centered on the new dx, dy coordinates and is a crop of previous tile
	 * @return the new cropped/centered tile
	 */
	public function sub( x:Int, y:Int, w:Int, h:Int, dx = 0, dy = 0 ) : h2d.Tile {
		return new Tile(innerTex, this.x + x, this.y + y, w, h, dx, dy);
	}

	/**
	 * Returns a new tile which is centered on the new dx, dy coordinates
	 * @param	dx Int offset that will serve as new X pivot coord for this tile
	 * @param	dy Int offset that will serve as new Y pivot coord for this tile
	 * @return a shallow centered tile !!!
	 */
	public inline function center(?dx:Int, ?dy:Int)  : h2d.Tile {
		if ( dx == null) dx = width>>1;
		if ( dy == null) dy = height>>1;
		return sub(0, 0, width, height, -dx, -dy);
	}

	public inline function centerRatio(?px:Float=0.5, ?py:Float=0.5)  : h2d.Tile {
		return sub(0, 0, width, height, -Std.int(px*width), -Std.int(py*height));
	}
	
	public inline function setCenter(?dx:Int, ?dy:Int) : Void
		copy( center( dx, dy) );
	
	public inline function setCenterRatio(?px:Float=0.5, ?py:Float=0.5) : Void
		copy( centerRatio( px, py) );
	
	public function setPos(x, y) {
		this.x = x;
		this.y = y;
		var tex = innerTex;
		if( tex != null ) {
			u = (x + EPSILON_PIXEL) / tex.width;
			v = (y + EPSILON_PIXEL) / tex.height;
			u2 = (width + x - EPSILON_PIXEL) / tex.width;
			v2 = (height + y - EPSILON_PIXEL) / tex.height;
		}
	}

	public function setSize(w, h) {
		this.width = w;
		this.height = h;
		var tex = innerTex;
		if( tex != null ) {
			u2 = (w + x - EPSILON_PIXEL) / tex.width;
			v2 = (h + y - EPSILON_PIXEL) / tex.height;
		}
	}

	public function scaleToSize( w, h ) {
		this.width = w;
		this.height = h;
	}

	public function scrollDiscrete( dx : Float, dy : Float ) {
		var tex = innerTex;
		u += dx / tex.width;
		v -= dy / tex.height;
		u2 += dx / tex.width;
		v2 -= dy / tex.height;
		x = Std.int(u * tex.width);
		y = Std.int(v * tex.height);
	}

	public function flipX() {
		var tmp = u; u = u2; u2 = tmp;
		dx = -dx - width;
	}

	public function flipY() {
		var tmp = v; v = v2; v2 = tmp;
		dy = -dy - height;
	}
	
	public function targetFlipY() {
		var tv = v2;
-		v2 = v;
-		v = tv;
	}

	public function dispose() {
		if( innerTex != null ) innerTex.dispose();
		innerTex = null;
	}

	public function clone() {
		var t = new Tile(null, x, y, width, height, dx, dy);
		t.innerTex = innerTex;
		t.u = u;
		t.u2 = u2;
		t.v = v;
		t.v2 = v2;
		return t;
	}

	public function copy(t:h2d.Tile) {
		innerTex = t.innerTex;
		u = t.u;
		u2 = t.u2;
		v = t.v;
		v2 = t.v2;
		dx = t.dx;
		dy = t.dy;
		return t;
	}
	
	
	public function split( frames : Int = 0, vertical = false ) {
		var tl = [];
		if( vertical ) {
			if( frames == 0 )
				frames = Std.int(height / width);
			var stride = Std.int(height / frames);
			for( i in 0...frames )
				tl.push(sub(0, i * stride, width, stride));
		} else {
			if( frames == 0 )
				frames = Std.int(width / height);
			var stride = Std.int(width / frames);
			for( i in 0...frames )
				tl.push(sub(i * stride, 0, stride, height));
		}
		return tl;
	}

	public function toString() {
		return "Tile(" + x + "," + y + "," + width + "x" + height + (dx != 0 || dy != 0 ? "," + dx + ":" + dy:"") + ")";
	}

	function upload( bmp:hxd.BitmapData ) {
		System.trace3('uploading from tile ');
		
		var w = innerTex.width;
		var h = innerTex.height;
		
		#if ((flash||openfl))
		if ( w != bmp.width || h != bmp.height ) {
			hxd.System.trace1('Resizing to final tex size $w $h <> ${bmp.width} ${bmp.height}');
			var bmp2 = new flash.display.BitmapData(w, h, true, 0);
			var p0 = new flash.geom.Point(0, 0);
			var bmp = bmp.toNative();
			hxd.System.trace3('copying pixels');
			bmp2.copyPixels(bmp, bmp.rect, p0, bmp, p0, true);
			hxd.System.trace3('uploading dual bitmap');
			innerTex.uploadBitmap(hxd.BitmapData.fromNative(bmp2));
			hxd.System.trace3('uploaded bitmap');
			bmp2.dispose();
			bmp2 = null;
		} 
		else
		#end
		{
			hxd.System.trace3('uploading bitmap');
			innerTex.uploadBitmap(bmp);
			hxd.System.trace3('uploaded bitmap');
		}
		hxd.System.trace2('tile upload done');
	}

	static var COLOR_CACHE = new Map<Int,h3d.mat.Texture>();
	public static function fromColor( color : Int,width = 4, ?height = 4, ?allocPos : h3d.impl.AllocPos ) {
		
		var t = COLOR_CACHE.get(color);
		if( t == null || t.isDisposed() ) {
			t = h3d.mat.Texture.fromColor(color, allocPos);
			COLOR_CACHE.set(color, t);
		}
		var t = new Tile(t, 0, 0, 4, 4);
		// scale to size
		t.width = width;
		t.height = height;
		return t;
	}

	public static function autoCut( bmp : hxd.BitmapData, width : Int, ?height : Int, ?allocPos : h3d.impl.AllocPos ) {
		if( height == null ) height = width;
		var colorBG = bmp.getPixel(bmp.width - 1, bmp.height - 1);
		var tl = new Array();
		var w = 1, h = 1;
		while( w < bmp.width )
			w <<= 1;
		while( h < bmp.height )
			h <<= 1;
		var tex = new h3d.mat.Texture(w, h);
		for( y in 0...Std.int(bmp.height / height) ) {
			var a = [];
			tl[y] = a;
			for( x in 0...Std.int(bmp.width / width) ) {
				var sz = isEmpty(bmp, x * width, y * height, width, height, colorBG);
				if( sz == null )
					break;
				a.push(new Tile(tex,x*width+sz.dx, y*height+sz.dy, sz.w, sz.h, sz.dx, sz.dy));
			}
		}
		var main = new Tile(tex, 0, 0, bmp.width, bmp.height);
		main.upload(bmp);
		return { main : main, tiles : tl };
	}

	static function isEmpty( b : hxd.BitmapData, px, py, width, height, bg : Int ) {
		var empty = true;
		var xmin = width, ymin = height, xmax = 0, ymax = 0;
		for( x in 0...width )
			for( y in 0...height ) {
				var color : Int = b.getPixel(x+px, y+py);
				if( color != bg ) {
					empty = false;
					if( x < xmin ) xmin = x;
					if( y < ymin ) ymin = y;
					if( x > xmax ) xmax = x;
					if( y > ymax ) ymax = y;
				}
				if( color == bg )
					b.setPixel(x+px, y+py, 0);
			}
		return empty ? null : { dx : xmin, dy : ymin, w : xmax - xmin + 1, h : ymax - ymin + 1 };
	}

}