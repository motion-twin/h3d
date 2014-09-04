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
	public var flags(default, null) : haxe.EnumFlags<TextureFlags>;
	
	var lastFrame : Int;
	var bits : Int;
	public var mipMap(default,set) : MipMap;
	public var filter(default,set) : Filter;
	public var wrap(default, set) : Wrap;
	//public var alpha_premultiplied : Bool = false;

	/**
		If this callback is set, the texture is re-allocated when the 3D context has been lost and the callback is called
		so it can perform the necessary operations to restore the texture in its initial state
	**/
	public var realloc : Void -> Void;
	
	public var name:String;
	
	public function new( w, h, isCubic : Bool = false, isTarget : Bool = false, isMipMapped: Int = 0 #if debug ,?allocPos:haxe.PosInfos #end) {
		this.id = ++UID;
		
		//warning engine might be null for tools !
		var engine = h3d.Engine.getCurrent();
		
		this.mem = engine==null ? null : engine.mem;
		this.isTarget = isTarget;
		this.width = w;
		this.height = h;
		this.isCubic = isCubic;
		this.mipLevels = isMipMapped;
		this.mipMap = isMipMapped > 0 ? Nearest : None;
		this.filter = Linear;
		this.wrap = Clamp;
		this.lastFrame = engine==null ? 0 : engine.frameCount;
		bits &= 0x7FFF;
		#if !debug
		realloc = alloc;
		#else
		realloc = function() {
			hxd.System.trace2("allocating texture "+name+" without proper realloc from : "+allocPos);
			alloc();
		};
		#end
		
		this.flags = haxe.EnumFlags.ofInt(0);
		if ( isTarget ) this.flags.set( TextureFlags.AlphaPremultiplied );
		
		//for tools we don't run the engine
		if( this.mem != null) 
			alloc();
			
		#if debug this.allocPos = allocPos; #end
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

	@:noDebug
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
		
		if ( bmp.isAlphaPremultiplied() ) 
			flags.set(TextureFlags.AlphaPremultiplied) 
		else 
			flags.unset(TextureFlags.AlphaPremultiplied);
	}

	public function uploadPixels( pixels : hxd.Pixels, mipLevel = 0, side = 0 ) {
		mem.driver.uploadTexturePixels(this, pixels, mipLevel, side);
		
		if ( pixels.flags.has( hxd.Pixels.Flags.AlphaPremultiplied ) ) 
			flags.set(TextureFlags.AlphaPremultiplied) 
		else 
			flags.unset(TextureFlags.AlphaPremultiplied);
	}

	public function dispose() {
		if ( t != null ) {
			mem.deleteTexture(this);
			hxd.System.trace2("asking mem to delete "+name);
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
		var t = new Texture( 4, 4 );
		t.realloc = function() t.clear(color);
		if( t.mem != null )
			t.realloc();
		return t;
	}
	
	#if openfl
	public static function fromAssets(path:String) : h3d.mat.Texture{
		var tex = Texture.fromBitmap( hxd.BitmapData.fromNative( openfl.Assets.getBitmapData( path, true )));
		tex.name = path;
		return tex;
	}
	#end
}
