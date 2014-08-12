package h2d;
import h2d.Drawable.DrawableShader;
import h3d.mat.Texture;
import haxe.CallStack;
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
	
	var currentObj : h2d.Drawable;
	var textures : Array<h3d.mat.Texture>;
	var streak:Int;
	
	var innerShader : h2d.Drawable.DrawableShader;
	
	static inline var MAX_TEXTURES = #if sys 6 #else 1 #end;
	
	public function new() {
		frame = 0;
		time = 0.;
		elapsedTime = 1. / hxd.Stage.getInstance().getFrameRate();
		buffer = new hxd.FloatStack();
		textures = [];
		innerShader = new h2d.Drawable.DrawableShader();
		innerShader.hasVertexColor = true;
		innerShader.alpha = 1;
		innerShader.multMapFactor = 1.0;
		innerShader.zValue = 0;
	}
	
	public function reset() {
		flushTextures();
		currentObj = null;
		buffer.reset();
	}
	
	public function begin() {
		reset();
	}
	
	public function end() {
		flush();
	}
	
	function beforeDraw(){
		var core = Tools.getCoreObjects();
		var mat = core.tmpMaterial;
		
		textures[0].filter = currentObj.filter ? Linear : Nearest;
		
		var isTexPremul  = textures[0].alpha_premultiplied;
		mat.depth( false, Always);
		
		if( innerShader.killAlpha != currentObj.killAlpha)
			innerShader.killAlpha = currentObj.killAlpha;
		
		switch( currentObj.blendMode ) {
			
			case Normal:
				mat.blend(isTexPremul ? One : SrcAlpha, OneMinusSrcAlpha);
				
			case None:
				mat.blend(One, Zero);
				mat.sampleAlphaToCoverage = false;
				if( currentObj.killAlpha ){
					if ( engine.driver.hasFeature( SampleAlphaToCoverage )) {
						innerShader.killAlpha = false;
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
		var shader = innerShader;
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
		shader.setTextures( textures );
		#end
		
		shader.isAlphaPremul = textures[0].alpha_premultiplied 
		&& (shader.hasAlphaMap || shader.hasAlpha || shader.hasMultMap 
		|| shader.hasVertexAlpha || shader.hasVertexColor 
		|| shader.colorMatrix != null || shader.colorAdd != null
		|| shader.colorMul != null );
		
		mat.shader = shader;
		
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
		
		#if debug
		var fc = flushCause == null ? ("flushed by engine") : flushCause;
		hxd.System.trace2("emit current streak:" + (streak >> 2)+" flush cause:"+fc);
		#end
		streak = 0;
	}
	
	/**
	 * @return true if draw was flushed
	 * @param	t
	 */
	public function addTexture(t:h3d.mat.Texture) : Int {
		for ( i in 0...MAX_TEXTURES ) 
			if ( t == textures[i] )
				return i;
			
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
	
	var flushCause = null;
	function setFlushCause(str) {
		#if debug
		flushCause = str;
		#end
	}
	
	public function beginDraw(	obj : h2d.Drawable, nTex:Texture ) : Int {
		var nTexture = nTex;
		var doFlush = false;
		
		var v = addTexture(nTex);
		if ( v == -1 ) {
			doFlush = true;
			setFlushCause("textures exhaustion");
		}
		
		//no need to flush for first object
		if( currentObj != null ){
		
			if ( obj.filter != currentObj.filter )	{
				doFlush = true;
				setFlushCause("filtering change");
			}
				
			if ( obj.blendMode != currentObj.blendMode ){	
				doFlush = true;
				setFlushCause("blendmode change");
			}
				
			if ( obj.killAlpha != currentObj.killAlpha ){
				doFlush = true;
				setFlushCause("kill alpha change");
			}
				
			if( textures[0]!=null)
				if ( nTexture.alpha_premultiplied != textures[0].alpha_premultiplied )	{
					doFlush = true;
					setFlushCause("premultiplication change");
				}
			
		}
		
		if ( doFlush ){
			flush();
			flushTextures();
			v = addTexture(nTexture);
			setFlushCause(null);
		}
		
		this.currentObj = obj;
		
		return v;
	}
	
	public function emitVertex( x:Float, y:Float, u:Float, v:Float, color:h3d.Vector, slot : Int ) {
		#if debug
		//hxd.System.trace4("spr:" + currentObj.name+" emitting x:" + x + " y:" + y +" u:" + " v:" + v);
		#end
		
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