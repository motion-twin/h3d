package hxd;

abstract UString(String) from String to String {

	public var length(get,never) : Int;

	inline function get_length() : Int {
		#if (flash || js || hl)
		return this.length;
		#else
		return haxe.Utf8.length( this );
		#end
	}

	@:op(a + b) inline static function add( a : UString, b : UString ) : String {
		return (a:String) + (b:String);
	}

	public inline function charCodeAt( pos : Int ) : Int {
		#if (flash || js || hl)
		return this.charCodeAt( pos );
		#else
		return haxe.Utf8.charCodeAt( this, pos );
		#end
	}

	public inline function substr( pos : Int, #if (flash || hl || cpp) len = 0x7fffffff #else ?len : Int #end ) : UString {
		#if (flash || js || hl)
		return this.substr( pos, len );
		#else
		return haxe.Utf8.sub( this, pos, len );
		#end
	}

	public inline function charAt( pos : Int ) : UString {
		#if (flash || js || hl)
		return this.charAt( pos );
		#else
		return haxe.Utf8.sub( this, pos, 1 );
		#end
	}

}
