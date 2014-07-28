package h3d.mat;

import h3d.mat.Data;

@:allow(h3d)
class Texture {

	static var UID = 0;
	
	var t : h3d.impl.Driver.Texture;
	var mem : h3d.impl.MemoryManager;
	#if debug
	var allocPos : h3d.impl.AllocPos;
	#end
	public var id(default,null) : Int;
	public var width(default, null) : Int;
	public var height(default, null) : Int;
	public var isCubic(default, null) : Bool;
	public var isTarget(default, null) : Bool;
	public var mipLevels(default, null) : Int;
	
	var bits : Int;
	public var mipMap(default,set) : MipMap;
	public var filter(default,set) : Filter;
	public var wrap(default, set) : Wrap;
	public var alpha_premultiplied : Bool = false;

	/**
		If this callback is set, the texture is re-allocated when the 3D context has been lost and the callback is called
		so it can perform the necessary operations to restore the texture in its initial state
	**/
	public var realloc : Void -> Void;
	public var lastFrame = 0;
	public var name:String;
	
	public function new( w, h, isCubic : Bool = false, isTarget : Bool = false, isMipMapped: Int = 0) {
		this.id = ++UID;
		var engine = h3d.Engine.getCurrent();
		this.mem = engine.mem;
		this.isTarget = isTarget;
		this.width = w;
		this.height = h;
		this.isCubic = isCubic;
		this.mipLevels = isMipMapped;
		this.mipMap = isMipMapped > 0 ? Nearest : None;
		this.filter = Linear;
		this.wrap = Clamp;
		bits &= 0x7FFF;
		realloc = alloc;
		alloc();
	}

	function set_mipMap(m:MipMap) {
		bits |= 0x80000;
		bits = (bits & ~(3 << 0)) | (Type.enumIndex(m) << 0);
		return mipMap = m;
	}

	function set_filter(f:Filter) {
		bits |= 0x80000;
		bits = (bits & ~(3 << 3)) | (Type.enumIndex(f) << 3);
		return filter = f;
	}
	
	function set_wrap(w:Wrap) {
		bits |= 0x80000;
		bits = (bits & ~(3 << 6)) | (Type.enumIndex(w) << 6);
		return wrap = w;
	}
	
	inline function hasDefaultFlags() {
		return bits & 0x80000 == 0;
	}

	public function isDisposed() {
		return t == null;
	}
	
	public function resize(width, height) {
		dispose();
		realloc();
	}
	
	public function alloc() {
		if( t == null )
			mem.allocTexture(this);
	}
	
	public function clear( color : Int ) {
		var p = hxd.Pixels.alloc(width, height, BGRA);
		var k = 0;
		var b = color & 0xFF, g = (color >> 8) & 0xFF, r = (color >> 16) & 0xFF, a = color >>> 24;
		for( i in 0...width * height ) {
			p.bytes.set(k++,b);
			p.bytes.set(k++,g);
			p.bytes.set(k++,r);
			p.bytes.set(k++,a);
		}
		uploadPixels(p);
		p.dispose();
	}
	
	public function uploadBitmap( bmp : hxd.BitmapData, ?mipLevel = 0, ?side = 0 ) {
		mem.driver.uploadTextureBitmap(this, bmp, mipLevel, side);
		
		#if flash
		alpha_premultiplied = bmp.toNative()!=null;	
		#elseif cpp
		alpha_premultiplied = bmp.toNative().premultipliedAlpha ;	
		#end
	}

	public function uploadPixels( pixels : hxd.Pixels, mipLevel = 0, side = 0 ) {
		mem.driver.uploadTexturePixels(this, pixels, mipLevel, side);
		alpha_premultiplied = pixels.flags.has( hxd.Pixels.Flags.ALPHA_PREMULTIPLIED );
	}

	public function dispose() {
		if ( t != null ) {
			mem.deleteTexture(this);
		}
	}
	
	public static function fromBitmap( bmp : hxd.BitmapData, ?allocPos : h3d.impl.AllocPos ) {
		var mem = h3d.Engine.getCurrent().mem;
		var t = new Texture(bmp.width, bmp.height);
		t.uploadBitmap(bmp);
		return t;
	}
	
	public static function fromPixels( pixels : hxd.Pixels, ?allocPos : h3d.impl.AllocPos ) {
		var mem = h3d.Engine.getCurrent().mem;
		var t = new Texture(pixels.width, pixels.height);
		t.uploadPixels(pixels);
		return t;
	}
	
	static var tmpPixels : hxd.Pixels = null;
	
	/**
		Creates a 4x4 texture using the ARGB color passed as parameter.
		because on mobile gpu a 1x1 texture can be meaningless due to compression
	**/
	public static function fromColor( color : Int, ?allocPos : h3d.impl.AllocPos ) {
		var mem = h3d.Engine.getCurrent().mem;
		var t = new Texture( 4, 4 );
		t.clear( color );
		t.realloc = function() t.clear(color);
		return t;
	}

}