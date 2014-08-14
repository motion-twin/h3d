
class ShaderSignature {
	var vertexColor : Bool;
	var hasAlpha : Bool;
	var alphaPremul:Bool;
	var nbTextures : Int;
	
	var sig :Int;
	public inline function new(vertexColor : Bool, hasAlpha : Bool, alphaPremul:Bool, nbTextures : Int) {
		this.vertexColor=vertexColor;
		this.hasAlpha=hasAlpha; 
		this.alphaPremul=alphaPremul;
		this.nbTextures = nbTextures;
		sig = mkSig();
	}
	
	function mkSig() :Int {
		var sig = 0;
		var i = 0;
		
		sig = bitToggle( sig , 1 << i, vertexColor);				i++;
		sig = bitToggle( sig , 1 << i, hasAlpha);					i++;
		sig = bitToggle( sig , 1 << i, alphaPremul);				i++;
		
		sig = bitToggle( sig , 1 << i, nbTextures & 1);				i++;
		sig = bitToggle( sig , 1 << i, nbTextures & 3);				i++;
		
		return sig;
	}
}

class ShaderLibrary {

	public static inline function bitSet( _v : Int , _i : Int) : Int 						return _v | _i;
	public static inline function bitIs( _v : Int , _i : Int) : Bool						return  (_v & _i) == _i;
	public static inline function bitClear( _v : Int, _i : Int) : Int 						return (_v & ~_i);
	public static inline function bitNeg(  _i : Int) : Int									return ~_i;
	public static inline function bitToggle( _v : Int , _onoff : Bool, _i : Int) : Int 		return 	_onoff ? bitSet(_v,  _i) : bitClear(_v, _i);
	
	var initialised = false;
	var shaders :  Map<Int,h2d.DrawableShader>;
	
	static function fromSig(sig:ShaderSignature){
		var sh  = new h2d.Drawable.DrawableShader();
		sh.hasVertexColor = vertexColor;
		sh.alpha = hasAlpha ? 0.999 : 1;
		sh.multMapFactor = 1.0;
		sh.zValue = 0;
		sh.isAlphaPremul = alphaPremul;
		
		if ( nbTextures == 1) sh.tex  = h2d.Tile.fromColor(0xFFFF00FF);
		else {
			t = [];
			for ( i in 0...nbTextures) 
				t.push(h2d.Tile.fromColor(0xFFFF00FF)); 
			sh.textures = t;
		}
		return sh;
	}
	
	public inline function get( sig : ShaderSignature ) : h2d.DrawableShader {
		if ( shaders.exists( sig.sig ))
			return shaders.get( sig.sig );
		else {
			var sh =fromSig(sig);
			shaders.set(sig.sig, sh);
			return sh;
		}
		sig = null;
	}
	
	public static function init() {
		shaders = new Map();
		initialised = true;
	}
	
	
}