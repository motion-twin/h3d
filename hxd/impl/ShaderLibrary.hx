package hxd.impl;

import h2d.Drawable;
import h2d.Drawable.DrawableShader;

@:publicFields
private class ShaderSignature {
	var vertexColor : Bool;
	var hasShaderAlpha : Bool;
	var alphaPremul:Bool;
	var nbTextures : Int;
	
	var signature :Int;
	
	public inline function new(vertexColor : Bool, hasShaderAlpha : Bool, alphaPremul:Bool, nbTextures : Int) {
		this.vertexColor=vertexColor;
		this.hasShaderAlpha=hasShaderAlpha; 
		this.alphaPremul=alphaPremul;
		this.nbTextures = nbTextures;
		signature = mkSig();
	}
	
	inline function mkSig() :Int {
		var sig = 0;
		var i = 0;
		
		sig = bitToggle( sig , 1 << i, vertexColor);			i++;
		sig = bitToggle( sig , 1 << i, hasShaderAlpha);			i++;
		sig = bitToggle( sig , 1 << i, alphaPremul);			i++;
		
		sig = bitSet( sig , (nbTextures & 1) << i);				i++;
		sig = bitSet( sig , (nbTextures & 3) << i);				i++;
		
		return sig;
	}
	
	static inline function bitSet( v : Int , i : Int) : Int 						
		return v | i;
	static inline function bitIs( v : Int , i : Int) : Bool				
		return  (v & i) == i;
	static inline function bitClear( v : Int, i : Int) : Int 					
		return (v & ~i);
	static inline function bitNeg(  i : Int) : Int								
		return ~i;
	static inline function bitToggle( v : Int , i : Int, onoff : Bool) : Int 
		return 	onoff ? bitSet(v,  i) : bitClear(v, i);
		
	function toString() {
		var str = "";
		
		str += "vtxCol:";
		str += "vtxCol:";
		str += "vtxCol:";
		
		return str;
	}
	
}

class ShaderLibrary {

	
	static var initialised = false;
	static var shaders :  Map<Int,h2d.Drawable.DrawableShader>;
	
	static function fromSig(sig:ShaderSignature){
		var sh  = new h2d.Drawable.DrawableShader();
		
		sh.hasVertexColor = sig.vertexColor;
		sh.hasVertexAlpha = false;
		sh.multMapFactor = 1.0;
		sh.zValue = 0;
		sh.isAlphaPremul = sig.alphaPremul;
		
		#if flash
		sh.tex  = null;
		#else
		if ( sig.nbTextures == 1) sh.tex = h2d.Tile.fromColor(0xFFFF00FF).getTexture();
		else {
			var t = [];
			for ( i in 0...sig.nbTextures) 
				t.push(h2d.Tile.fromColor(0xFFFF00FF).getTexture()); 
			sh.textures = t;
		}
		#end
		return sh;
	}
	
	public inline static function get(vertexColor : Bool, hasAlpha : Bool, alphaPremul:Bool, nbTextures : Int) {
		var sig = new ShaderSignature(vertexColor, hasAlpha, alphaPremul, nbTextures);
		var sh = getFromSig( sig );
		sig = null;
		return sh;
	}
	
	inline static function getFromSig( s : ShaderSignature ) : h2d.DrawableShader {
		if ( shaders.exists( s.signature ))
			return shaders.get( s.signature );
		else {
			var sh = fromSig(s);
			shaders.set(s.signature, sh);
			return sh;
		}
	}
	
	public static function init() {
		if ( initialised ) return;
		
		shaders = new Map();
		initialised = true;
	}
	
	
}