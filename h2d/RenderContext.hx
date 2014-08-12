package h2d;
import h3d.mat.Texture;
import haxe.ds.Vector;
import hxd.FloatBuffer;
import hxd.Stack;
import hxd.System;

class RenderContext {
	public var engine : h3d.Engine;
	public var time : Float;
	public var elapsedTime : Float;
	public var frame : Int;
	public var currentPass : Int = 0;
	public var buffer : hxd.FloatStack;
	public var shader : h2d.Drawable.DrawableShader;
	
	var currentObj : h2d.Drawable;
	var textures : Array<h3d.mat.Texture>;
	var streak:Int;
	
	static inline var MAX_TEXTURES = #if sys 6 #else 1 #end;
	
	public function new() {
		frame = 0;
		time = 0.;
		elapsedTime = 1. / hxd.Stage.getInstance().getFrameRate();
		buffer = new hxd.FloatStack();
		textures = [];
	}
	
	public function reset() {
		flushTextures();
		currentObj = null;
		shader = null;
		buffer.reset();
	}
	
	public function begin() {
		reset();
	}
	
	public function end() {
		flush();
	}
	
	
	public function beforeDraw() {
		var core = Tools.getCoreObjects();
		var mat = core.tmpMaterial;
		textures[0].filter = currentObj.filter ? Linear : Nearest;
		
		var isTexPremul  = textures[0].alpha_premultiplied;
		mat.depth( false, Always);
		
		switch( currentObj.blendMode ) {
			
			case Normal:
				mat.blend(isTexPremul ? One : SrcAlpha, OneMinusSrcAlpha);
				
			case None:
				mat.blend(One, Zero);
				mat.sampleAlphaToCoverage = false;
				if( currentObj.killAlpha ){
					if ( engine.driver.hasFeature( SampleAlphaToCoverage )) {
						shader.killAlpha = false;
						mat.sampleAlphaToCoverage = true;
					}
				}
				
			case Add:
				mat.blend(isTexPremul ? One : SrcAlpha, One);
				
			case SoftAdd:
				mat.blend(OneMinusDstColor, One);
				
			case Multiply:
				mat.blend(DstColor, OneMinusSrcAlpha);
				
			case Erase:
				mat.blend(Zero, OneMinusSrcAlpha);
				
			case SoftOverlay:
				mat.blend(DstColor, One);
		}

		var core = Tools.getCoreObjects();
		
		shader.size = null;
		shader.uvPos = null;
		shader.uvScale = null;
		shader.hasVertexColor = true;
		
		var tmp = core.tmpMatA;
		tmp.set(1, 0, 0, 1);
		shader.matA = tmp;
		
		var tmp = core.tmpMatB;
		tmp.set(0, 1, 0, 1);
		shader.matB = tmp;
		
		#if flash
		shader.tex = textures[0];
		#else 
		shader.tex = null;
		shader.textures = textures;
		#end
		
		shader.isAlphaPremul = textures[0].alpha_premultiplied 
		&& (shader.hasAlphaMap || shader.hasAlpha || shader.hasMultMap 
		|| shader.hasVertexAlpha || shader.hasVertexColor 
		|| shader.colorMatrix != null || shader.colorAdd != null
		|| shader.colorMul != null );
		
		mat.shader = currentObj.shader;
		
		var cm = currentObj.writeAlpha ? 15 : 7;
		if( mat.colorMask != cm ) mat.colorMask = cm;
	
		engine.selectMaterial(mat);
	}
	
	public inline function getStride() {
		return #if sys 12 #else 8 #end;
	}
	
	public function flush(force=false) {
		if ( buffer.length == 0 ) {
			reset();
			return;
		}
		
		beforeDraw();
		
		var tmp = engine.mem.allocStack( buffer, getStride(), 4, true);
		engine.renderQuadBuffer(tmp);
		tmp.dispose();
		
		reset();
		
		hxd.System.trace2("emit current streak:" + (streak >> 2));
		streak = 0;
	}
	
	/**
	 * @return true if draw was flushed
	 * @param	t
	 */
	public function addTexture(t:h3d.mat.Texture) : Int{
		for ( i in 0...MAX_TEXTURES ) 
			if ( null == textures[i] ){
				textures[i] = t;
				return i;
			}
			
		return -1;
	}
	
	function flushTextures() {
		for ( i in 0...MAX_TEXTURES ) 
			textures[i] = null;
	}
	
	
	public function beginDraw(	obj : h2d.Drawable, nTex:Texture ) : Int {
		var nTexture = nTex;
		var doFlush = false;
		
		var v = addTexture(nTex);
		if ( v == -1 ) doFlush = true;
		
		if ( shader == null ) doFlush = true;
		else {
			
			if ( obj.filter != currentObj.filter )				
				doFlush = true;
				
			if ( obj.blendMode != currentObj.blendMode )		
				doFlush = true;
				
			if ( obj.killAlpha != currentObj.killAlpha )						
				doFlush = true;
				
			if( textures[0]!=null)
				if ( nTexture.alpha_premultiplied != textures[0].alpha_premultiplied )	
					doFlush = true;
			
			#if sys 
			if( obj.shader!=null ){
				if ( !obj.shader.hasInstance() ) 							doFlush = true;
				if ( obj.shader.getSignature() != shader.getSignature()) 	doFlush = true;
			}
			#end
		}
		
		if ( doFlush ){
			flush();
			flushTextures();
			v = addTexture(nTexture);
		}
		
		this.currentObj = obj;
		this.shader = obj.shader;
		
		return v;
	}
	
	public function emitVertex( x, y, u, v, color:h3d.Vector, slot ) {
		buffer.push(x);
		buffer.push(y);
		
		buffer.push(u);
		buffer.push(v);
		
		buffer.push(color.r);
		buffer.push(color.g);
		buffer.push(color.b);
		buffer.push(color.a);
		
		#if sys
		buffer.push(slot);
		buffer.push(0.0);
		buffer.push(0.0);
		buffer.push(0.0);
		#end
		
		streak++;
	}

}