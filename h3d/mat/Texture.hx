package h3d.mat;

import h3d.mat.Data;
import hxd.BitmapData;
import hxd.System;

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
	
	public var flags(default, null) : haxe.EnumFlags<TextureFlags>;
	
	public var isCubic(get, null) : Bool; 		function get_isCubic() return flags.has( TextureFlags.Cubic );
	public var isTarget(get, null) : Bool;		function get_isTarget() return flags.has( TextureFlags.Target );
	
	var lastFrame : Int;
	var bits : Int;
	public var mipMap(default,set) : MipMap;
	public var filter(default,set) : Filter;
	public var wrap(default, set) : Wrap;
	public var anisotropicLevel = 0;
	
	/**
		If this callback is set, the texture is re-allocated when the 3D context has been lost and the callback is called
		so it can perform the necessary operations to restore the texture in its initial state
	**/
	public var realloc : Void -> Void;
	public var name:String;
	
	public var pixels : Null<hxd.Pixels>;
	public var bmp : Null<hxd.BitmapData>;
	
	public function new( w, h, ?flags : haxe.EnumFlags<TextureFlags> #if debug ,?allocPos:haxe.PosInfos #end) {
		this.id = ++UID;
		if ( flags == null ) flags = haxe.EnumFlags.ofInt(0);
		
		//warning engine might be null for tools !
		var engine = h3d.Engine.getCurrent();
		
		this.mem = engine==null ? null : engine.mem;
		this.width = w;
		this.height = h;
		this.filter = Linear;
		this.wrap = Clamp;
		this.lastFrame = engine == null ? 0 : engine.frameCount;
		
		this.flags = 		flags;
		this.mipMap =		flags.has( MipMapped ) ? Nearest : None;
		if ( this.flags.has(Target))	this.flags.set( TextureFlags.AlphaPremultiplied );
		
		bits &= 0x7FFF;

		#if !debug
		realloc = alloc;
		#else
		realloc = function() {
			hxd.System.trace2("allocating texture "+name+" without proper realloc from : "+allocPos);
			alloc();
		};
		#end
		
		//for tools we don't run the engine
		if( this.mem != null && !flags.has( NoAlloc )) 
			alloc();
			
		#if debug this.allocPos = allocPos; #end
		
		#if debug 
		name = "Texture #" + id;
		#end
	}

	public static inline function TargetFlag() {
		var p = haxe.EnumFlags.ofInt(0);
		p.set( Target );
		return p;
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

	public inline function isDisposed() {
		return t == null;
	}
	
	public inline function toNative() {
		return t;
	}
	
	public function resize(width, height) {
		dispose();
		realloc();
	}
	
	public inline function alloc() {
		if( t == null ) mem.allocTexture(this);
	}

	@:noDebug
	public function clear( color : Int ) {
		var p = hxd.Pixels.alloc(width, height, BGRA);
		var k = 0;
		var b = color & 0xFF;
		var g = (color >> 8) & 0xFF;
		var r = (color >> 16) & 0xFF;
		var a = color >>> 24;
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
		alloc();
		mem.driver.uploadTextureBitmap(this, bmp, mipLevel, side);
		
		if ( bmp.alphaPremultiplied ) 
			flags.set(TextureFlags.AlphaPremultiplied) 
		else 
			flags.unset(TextureFlags.AlphaPremultiplied);
	}

	public function uploadPixels( pixels : hxd.Pixels, mipLevel = 0, side = 0 ) {
		alloc();
		mem.driver.uploadTexturePixels(this, pixels, mipLevel, side);
		
		if ( pixels.flags.has( hxd.Pixels.Flags.AlphaPremultiplied ) ) 
			flags.set(TextureFlags.AlphaPremultiplied) 
		else 
			flags.unset(TextureFlags.AlphaPremultiplied);
	}

	public function dispose() {
		#if debug
		hxd.System.trace3("disposing texture " + name);
		#end
		if ( t != null ) {
			mem.deleteTexture(this);
			#if debug
			hxd.System.trace3("asking mem to delete " + name);
			#end
		}
	}
	public function destroy( mem : Bool = false ) {
		dispose();
		realloc = alloc;
		if ( mem ) {
			if ( pixels != null ) pixels.dispose();
			if ( bmp != null ) bmp.dispose();
		}
		pixels = null; //not owner not freeyer
		bmp = null;
	}
	
	public static function fromBitmap( bmp : hxd.BitmapData, retain = true, ?allocPos : h3d.impl.AllocPos ) {
		var fl = haxe.EnumFlags.ofInt(0);
		if( bmp.alphaPremultiplied)
			fl.set(AlphaPremultiplied);
		var t = new Texture(bmp.width, bmp.height,fl);
		if( h3d.Engine.getCurrent() !=null )
			t.uploadBitmap(bmp);
		if ( retain ) t.bmp = bmp;
		if ( retain ) t.realloc = function() t.uploadBitmap(bmp);
		return t;
	}
	
	//this does not seem to work sometimes, ...
	public static function fromPixels( pixels : hxd.Pixels, retain = true, ?allocPos : h3d.impl.AllocPos ) {
		var p = haxe.EnumFlags.ofInt(0);
		
		if ( pixels.flags.has(hxd.Pixels.Flags.Compressed) )
			p.set(Compressed);
		if ( pixels.flags.has(hxd.Pixels.Flags.NoAlpha) )
			p.set(NoAlpha);
		if ( pixels.flags.has(hxd.Pixels.Flags.AlphaPremultiplied) )
			p.set(AlphaPremultiplied);
			
		var t = new Texture(pixels.width, pixels.height, p);
		t.uploadPixels(pixels);
		
		if ( retain ) t.pixels = pixels;
		if ( retain ) t.realloc = function() t.uploadPixels(pixels);
		return t;
	}
	
	static var tmpPixels : hxd.Pixels = null;
	
	/**
		Creates a 4x4 texture using the ARGB color passed as parameter.
		because on mobile gpu a 1x1 texture can be meaningless due to compression
		Warning, one should no pool those
	**/
		
	static var fromColorUid = 0;
	public static function fromColor( color : Int, ?allocPos : h3d.impl.AllocPos ) {
		var fl = haxe.EnumFlags.ofInt(0);
		fl.set(NoAlloc);
		var t = new Texture( 4, 4, fl);
		t.name = "h3d.fromColor#" + fromColorUid;
		
		var color = color;
		t.realloc = function() t.clear(color);
		
		if ( t.mem != null ) 
			t.realloc();
		else 
		{	
			#if debug
			hxd.System.trace2("Engine not init, will not send tex to gpu.");
			#end
		}
		return t;
	}
	
	
	#if openfl
	public static function fromAssets(path:String, retain = true, fromCache = true) : h3d.mat.Texture {
		var bmd : flash.display.BitmapData = openfl.Assets.getBitmapData( path, fromCache );
		var bmp =  hxd.BitmapData.fromNative( bmd );
		
		#if flash
		bmp.alphaPremultiplied = true;
		#end
		
		var tex = Texture.fromBitmap(bmp, retain);
		tex.name = "h3d.fromAssets("+path+")";
		
		#if flash
		tex.flags.set( AlphaPremultiplied );
		#end
		
		tex.name = path;
		return tex;
	}
	#end
	
	public inline function getMipLevels(  ) {
		if( !flags.has(MipMapped) )
			return 0;
		var levels = 0;
		while( width > (1 << levels) || height > (1 << levels) )
			levels++;
		return levels;
	}
}
