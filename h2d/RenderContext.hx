package h2d;
import h2d.Drawable.DrawableShader;
import h3d.mat.Texture;
import haxe.CallStack;
import haxe.ds.Vector;
import hxd.FloatBuffer;
import hxd.Stack;
import hxd.System;
import hxd.impl.ShaderLibrary;

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
	
	public static inline var MAX_TEXTURES = #if sys 4 #else 1 #end;
	
	public function new() {
		frame = 0;
		time = 0.;
		elapsedTime = 1. / hxd.Stage.getInstance().getFrameRate();
		buffer = new hxd.FloatStack();
		textures = [];
		hxd.impl.ShaderLibrary.init();
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
		var tex = textures[0];
		var isTexPremul  = tex.flags.has(AlphaPremultiplied);
		var nbTex = 1;
		
		#if !flash
		var nb = 0;
		for ( t in textures) 
			if (t != null) 
				nb++;
		nbTex = nb;
		#end
		
		var shader = hxd.impl.ShaderLibrary.get(true,false,isTexPremul,nbTex);
		
		#if flash
			shader.tex = (tex=textures[0]);
		#else 
		if ( MAX_TEXTURES > 1 && nbTex > 1 ) {
			shader.tex = null;
			shader.setTextures( textures );
		}
		else {
			shader.tex = tex;
			shader.setTextures( null );
		}
		#end
		
		tex.filter = currentObj.filter ? Linear : Nearest;
		mat.depth( false, Always);
		
		if( shader.killAlpha != currentObj.killAlpha)
			shader.killAlpha = currentObj.killAlpha;
		
		shader.leavePremultipliedColors = false;
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
				shader.leavePremultipliedColors = true;
		}

		var core = Tools.getCoreObjects();
		shader.size = null;
		shader.uvPos = null;
		shader.uvScale = null;
		
		var tmp = core.tmpMatA;
		tmp.set(1, 0, 0, 1);
		shader.matA = tmp;
		
		var tmp = core.tmpMatB;
		tmp.set(0, 1, 0, 1);
		shader.matB = tmp;
		
		var cm = currentObj.writeAlpha ? 15 : 7;
		if( mat.colorMask != cm ) mat.colorMask = cm;
	
		mat.shader = shader;
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
		hxd.System.trace4("emit current streak:" + (streak >> 2) + " flush cause:" + fc);
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
				if ( nTexture.flags.has(AlphaPremultiplied) != textures[0].flags.has(AlphaPremultiplied) )	{
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
		buffer.push(x);
		buffer.push(y);
		buffer.push(u);
		buffer.push(v);
		
		buffer.push(color.r);
		buffer.push(color.g);
		buffer.push(color.b);
		buffer.push(color.a);
		
		#if sys
		buffer.push(slot==0?1.0:0.0);
		buffer.push(slot==1?1.0:0.0);
		buffer.push(slot==2?1.0:0.0);
		buffer.push(slot==3?1.0:0.0);
		#end
		
		streak++;
	}

}