package h3d.impl;

import h3d.impl.Driver;
import h3d.Matrix;
import h3d.impl.Shader;
import h3d.impl.Shader.*;
import h3d.Vector;

import haxe.Timer;
import hxd.Assert;
import haxe.CallStack;


import haxe.ds.IntMap;
import hxd.BytesBuffer;
import hxd.Math;
import hxd.Profiler;

import hxd.FloatBuffer;
import hxd.Pixels;
import hxd.System;

using StringTools;

#if (js||cpp)
	#if js
	import js.html.Uint16Array;
	import js.html.Uint8Array;
	import js.html.Float32Array;
	typedef _GLActiveInfo = js.html.webgl.ActiveInfo;
	
	#elseif cpp
	import openfl.gl.GLObject;
	import openfl.gl.GL;
	
	typedef _GLActiveInfo = openfl.gl.GLActiveInfo;
	#end

	//to allow writin
	@:publicFields
	class GLActiveInfo {
		var size : Int;
		var type : Int;
		var name : String;
		
		function new(g:_GLActiveInfo) {
			size = g.size;
			type = g.type;
			name = g.name;
		}
	}
	
	#if js
	private typedef GL = js.html.webgl.GL;
	#elseif cpp
	private typedef Uint16Array = openfl.utils.Int16Array;
	private typedef Uint8Array = openfl.utils.UInt8Array;
	private typedef Float32Array = openfl.utils.Float32Array;
	#end

	#if js
	typedef NativeFBO = js.html.webgl.Framebuffer;//todo test
	typedef NativeRBO = js.html.webgl.Renderbuffer;//todo test
	#elseif cpp
	typedef NativeFBO = openfl.gl.GLFramebuffer;//todo test
	typedef NativeRBO = openfl.gl.GLRenderbuffer;//todo test
	#end

@:publicFields
class FBO {
	var fbo : NativeFBO;
	var color : h3d.mat.Texture;
	var rbo : NativeRBO;
	
	var width : Int=0;
	var height : Int = 0;
	
	var age : Int = 0;
	
	public function new() {}
}

@:publicFields
class UniformContext { 
	var texIndex : Int; 
	var inf: GLActiveInfo;
	public function new(t,i) {
		texIndex = t;
		inf = i;
	}
}

enum BGRAMode{
	BGRANone;
	BGRADesktop;
	BGRAExt;
}


@:access(h3d.impl.Shader)
class GlDriver extends Driver {

	#if js
	var canvas : js.html.CanvasElement;
	public var gl : js.html.webgl.RenderingContext;
	#elseif cpp
	static var gl = GL;
	var fixMult : Bool;
	#end
	
	public static inline var BGR_EXT = 0x80E0;
	public static inline var BGRA_EXT = 0x80E1;
	
	public static inline var GL_BGRA_IMG = 0x80E1;
	public static inline var GL_BGRA_EXT = 0x80E1;
	public static inline var GL_BGRA8_EXT = 0x93A1;
	
	public static inline var GL_UNSIGNED_INT_8_8_8_8_REV = 0x8367;
	public static inline var GL_RGBA8 = 0x8058;
	
	public static inline var GL_MULTISAMPLE 	= 0x809D;
	public static inline var GL_SAMPLE_BUFFERS 	= 0x80A8;
	public static inline var GL_SAMPLES 		= 0x80A9;
	
	
	//var curAttribs : Int;
	var curShader : Shader.ShaderInstance;
	var curMatBits : Null<Int>;
	
	var curTex : Array<h3d.mat.Texture> = [];
	
	public var shaderSwitch = 0;
	public var textureSwitch = 0;
	public var resetSwitch = 0;
	public var currentContextId = 0;
	public var vendor : String = null;
	public var renderer : String = null;
	
	public var shaderCache : haxe.ds.IntMap<ShaderInstance>;
	public var extensions : Array<String>;
	public var bgraSupport = BGRANone;
	
	var vpWidth = 0;
	var vpHeight = 0;
	
	public function new() {
		#if js
			#if !openfl
			canvas = cast js.Browser.document.getElementById("webgl");
			#else
			canvas = cast js.Browser.document.getElementById("Root_MovieClip");
			#end 
		if( canvas == null ) throw "Canvas #webgl not found";
		gl = canvas.getContextWebGL();
		if( gl == null ) throw "Could not acquire GL context";
		// debug if webgl_debug.js is included
		untyped if( __js__('typeof')(WebGLDebugUtils) != "undefined" ) gl = untyped WebGLDebugUtils.makeDebugContext(gl);
		#elseif cpp
		// check for a bug in HxCPP handling of sub buffers
		var tmp = new Float32Array(8);
		var sub = new Float32Array(tmp.buffer, 0, 4);
		fixMult = sub.length == 1; // should be 4
		#end

		curMatBits = null;
		
		System.trace3('gldriver newed');
		
		fboList = new hxd.Stack<FBO>();
		shaderCache = new IntMap();
		
		#if openfl 
		flash.Lib.current.stage.addEventListener( openfl.display.OpenGLView.CONTEXT_LOST , onContextLost );
		flash.Lib.current.stage.addEventListener( openfl.display.OpenGLView.CONTEXT_RESTORED , onContextRestored );
		
		vendor = gl.getParameter(GL.VENDOR);
		renderer = gl.getParameter(GL.RENDERER);
		extensions = gl.getSupportedExtensions();
		
		#if debug
		trace('running on $renderer by $vendor');
		trace("supported extensions:" + extensions.join("\n"));
		#end
		
		#end
		
		detectCaps();
	}
	
	function detectCaps() {
		if ( extensions != null) 
			for ( s in extensions) {
				switch(s) {
					case 	"GL_EXT_bgra", "GL_APPLE_texture_format_BGRA8888":		
						bgraSupport = BGRADesktop;
					case 	"GL_EXT_texture_format_BGRA8888", "GL_IMG_texture_format_BGRA8888", "EXT_texture_format_BGRA8888": 
						if( bgraSupport != BGRADesktop)
						bgraSupport = BGRAExt;
				}
			}
		if ( bgraSupport != BGRANone) hxd.System.trace1("BGRA support is :" + bgraSupport);
	}
	
	public function onContextRestored(_) {
		hxd.System.trace1("Context restored " + currentContextId + ", do your magic");
		
		currentContextId++;
		if ( currentContextId == 1) {
			hxd.System.trace1("fake context lost heuristic...");
			return; //lime sends a dummy context lost...
		}
		
		var eng = Engine.getCurrent();
		if ( eng != null ) {
			//reset driver context
			shaderCache = new IntMap();
			fboList.reset();
			reset();
			
			//reset engine context
			@:privateAccess Engine.getCurrent().onCreate( true );
		}
	}
	
	public function onContextLost(_) {
		hxd.System.trace1("Context lost "+currentContextId+", do your magic");
	}
	
	inline function getUints( h : haxe.io.Bytes, pos = 0, size = null)
	{
		return 
		new Uint8Array(
		#if openfl 
		flash.utils.ByteArray.fromBytes( h )
		#else
		h.getData()
		#end
		, pos,size );
	}
	
	inline function getUints16( h : haxe.io.Bytes, pos = 0)
	{
		return 
		new Uint16Array(
		#if openfl 
		flash.utils.ByteArray.fromBytes( h )
		#else
		h.getData()
		#end
		, pos );
	}
	
	override function reset() {
		resetSwitch++;
		curBuffer = null;
		curMultiBuffer = null;
		curShader = null;
		for( i in 0...curTex.length)
			curTex[i] = null;
		gl.useProgram(null);
	}
	
	function resetMaterials() {
		curMatBits = 0;
			
		gl.disable(GL.CULL_FACE);
		gl.cullFace(FACES[1]);//one cannot put a cull none setting;
		
		gl.disable(GL.DEPTH_TEST);
		gl.depthFunc(COMPARE[0]);
		gl.depthMask(false);
		
		gl.blendFunc(BLEND[0], BLEND[1]);
	}
	
	inline function matIsCulling(bits : Int):Bool{
		return (bits & 3) != 0;
	}
	
	inline function matGetCulling(bits : Int){
		return (bits & 3);
	}
	
	inline function matIsDepthWrite(bits : Int):Bool{
		return (bits & 4) != 0;
	}
	
	inline function matIsDepthRead(bits : Int):Bool{
		return ((bits >> 3) & 7) != 0;
	}
	
	inline function matGetDepthFunc(bits : Int){
		return ((bits >> 3) & 7);
	}
	
	inline function matGetBlendSrc(bits : Int){
		return (bits >> 6) & 15;
	}
	
	inline function matGetBlendDst(bits : Int){
		return (bits >> 10) & 15;
	}
	
	inline function matIsAlphaToCoverage(bits : Int){
		return (bits & (1<<20)) != 0;
	}
	
	function forceMaterial( mbits : Int ) {
		
		checkError();
		
		if ( !matIsCulling(mbits) ) {
			//System.trace2("disabling cull");
			gl.disable(GL.CULL_FACE);
		}
		else {
			//System.trace2("enabling cull");
			gl.enable(GL.CULL_FACE);
		}
		
		var cullVal =  matGetCulling(mbits);
		
		if( cullVal>0){
			//System.trace2("cull func " + Type.createEnumIndex(h3d.mat.Data.Face, cullVal));
			gl.cullFace(FACES[ cullVal ]);
		}
		
		checkError();
		
		var src = (mbits >> 6) & 15;
		var dst = (mbits >> 10) & 15;
		
		if( src == 0 && dst == 1 ){
			gl.disable(GL.BLEND);
			//System.trace4('disabling blend');
		}
		else {
			if ( (curMatBits >> 6) & 0xFF == 0x10 ) {
				gl.enable(GL.BLEND);
				//System.trace4('enabling blend');
			}
				
			gl.blendFunc(BLEND[src], BLEND[dst]);
			//System.trace4('blend func ${BLEND[src]} ${BLEND[dst]}');
		}
		
		if ( !matIsDepthRead(mbits) ) {
			//System.trace2("disabling depth test");
			gl.disable(GL.DEPTH_TEST);
		}
		else {
			//System.trace2("enabling depth test");
			gl.enable(GL.DEPTH_TEST);
		}
		
		if ( matIsDepthWrite(mbits) ) {
			//System.trace2("enabling depth write");
			gl.depthMask(true);
		}
		else {
			//System.trace2("disabling depth write");
			gl.depthMask(false);
		}
		
		gl.disable( GL.SAMPLE_ALPHA_TO_COVERAGE );
		checkError();
		
		var eq = matGetDepthFunc(mbits);
		//System.trace2("using depth test equation "+ Type.createEnumIndex(h3d.mat.Data.Compare,eq));
		gl.depthFunc(COMPARE[eq]);
		
		gl.colorMask((mbits >> 14) & 1 != 0, (mbits >> 14) & 2 != 0, (mbits >> 14) & 4 != 0, (mbits >> 14) & 8 != 0);
		curMatBits = mbits;
		
		checkError();
	}
	
	override function selectMaterial( mbits : Int ) {
		
		var diff = 0;
		
		if( curMatBits != null )	diff = curMatBits ^ mbits;
		else {	
			resetMaterials();
			return;
		}
			
		checkError();
		
		//hxd.Profiler.begin("glDriver:selectMaterial");
		if ( matIsCulling(diff) ) {
			if ( !matIsCulling(mbits) ) {
				//System.trace2("disabling cull");
				gl.disable(GL.CULL_FACE);
			}
			else {
				if ( !matIsCulling(curMatBits) ){
					//System.trace2("enabling cull");
					gl.enable(GL.CULL_FACE);
				}
				//else 
				//	System.trace2("cull already enabled");
					
				gl.cullFace(FACES[ matGetCulling(mbits) ]);
				//System.trace2("cull func "+ Type.createEnumIndex(h3d.mat.Data.Face,mbits & 3));
			}
		}
		
		checkError();
		
		if ( diff & (0xFF << 6) != 0 ) {
			
			var src = (mbits >> 6) & 15;
			var dst = (mbits >> 10) & 15;
			if( src == 0 && dst == 1 ){
				gl.disable(GL.BLEND);
				//System.trace4('disabling blend');
			}
			else {
				if ( (curMatBits >> 6) & 0xFF == 0x10 ) {
					gl.enable(GL.BLEND);
					//System.trace4('enabling blend');
				}
					
				gl.blendFunc(BLEND[src], BLEND[dst]);
				//System.trace4('blend func ${BLEND[src]} ${BLEND[dst]}');
			}
		}
		
		checkError();
		
		if ( matIsDepthRead(diff) ) {
			if ( !matIsDepthRead(mbits) ) {
				//System.trace2("disabling depth test");
				gl.disable(GL.DEPTH_TEST);
			}
			else {
				//System.trace2("enabling depth test");
				gl.enable(GL.DEPTH_TEST);
			}
		}
		
		//has equation changed
		if ( matGetDepthFunc(diff) != 0  ) {
			var eq = matGetDepthFunc(mbits);
			//System.trace2("using depth test equation "+ Type.createEnumIndex(h3d.mat.Data.Compare,eq));
			gl.depthFunc(COMPARE[eq]);
		}
		
		checkError();
		
		if ( matIsDepthWrite(diff) ) {
			if ( matIsDepthWrite(mbits) ) {
				//System.trace2("enabling depth write");
				gl.depthMask(true);
			}
			else {
				//System.trace2("disabling depth write");
				gl.depthMask(false);
			}
		}
		
		checkError();
		
		if ( matIsAlphaToCoverage(diff) ) 
			if ( matIsAlphaToCoverage( mbits ) ) 
				gl.enable(GL.SAMPLE_ALPHA_TO_COVERAGE);
			else 
				gl.disable(GL.SAMPLE_ALPHA_TO_COVERAGE);
	
		checkError();
		
		if ( diff & (15 << 14) != 0 ) {
			//System.trace4("using color mask");
			gl.colorMask((mbits >> 14) & 1 != 0, (mbits >> 14) & 2 != 0, (mbits >> 14) & 4 != 0, (mbits >> 14) & 8 != 0);
			checkError();
		}
		
		curMatBits = mbits;
		//hxd.Profiler.end("glDriver:selectMaterial");
		//System.trace4('gldriver select material');
	}
	
	override function clear( r : Float, g : Float, b : Float, a : Float ) {
		//Profiler.begin("clear");
		
		super.clear(r, g, b, a);
		
		#if android
		//fix for samsung galaxy tab
		if ( a <= hxd.Math.EPSILON ) a = 1.0001 / 255.0;
		#end
		
		gl.clearColor(r, g, b, a);
		gl.depthMask(true);
		gl.clearDepth(Engine.getCurrent().depthClear);
		gl.depthRange(0, 1 );
		
		gl.disable(GL.DEPTH_TEST);
		gl.disable(GL.SCISSOR_TEST);
		
		checkError();
		//always clear depth & stencyl to enable op
		gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT | GL.STENCIL_BUFFER_BIT);
		
		checkError();
		
		//Profiler.end("clear");
	}

	override function begin() {
		
		#if debug
		//if ( ! hxd.System.hasLoop() )
		//	throw "hxd.System.setLoop is not done, please do so or you might have black rendering !";
		#end
		
		gl.frontFace( GL.CW );
		gl.enable(GL.SCISSOR_TEST);
		
		resetMaterials();
		
		curTex = [];
		curShader = null;
		
		textureSwitch = 0;
		shaderSwitch = 0;
		resetSwitch = 0;
	}
	
	override function getShaderInputNames() {
		return curShader.attribs.map(function(t) return t.name );
	}
	
	override function resize(width, height) {
		#if js
		canvas.width = width;
		canvas.height = height;
		#elseif cpp
		// resize window
		#end
		gl.viewport(0, 0, width, height);
		vpWidth = width; vpHeight = height;
		setRenderZone(0,0,-1,-1);
		
		System.trace2("resizing");
	}
	
	override function allocTexture( t : h3d.mat.Texture ) : h3d.impl.Texture {
		//hxd.Profiler.begin("allocTexture");
		//System.trace4("allocTexture");
		
		var tt = gl.createTexture();
		#if debug
		hxd.System.trace2("Creating texture pointer" + tt + haxe.CallStack.toString(haxe.CallStack.callStack()) );
		#end
		checkError();
		
		//unnecessary as internal format is not definitive and avoid some draw calls
		//BUT mandatory for framebuffer textures...so do it anyway
		gl.bindTexture(GL.TEXTURE_2D, tt); 																			checkError();
		gl.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, t.width, t.height, 0, GL.RGBA, GL.UNSIGNED_BYTE, null); 			checkError();
		gl.bindTexture(GL.TEXTURE_2D, null);																		checkError();
		
		#if debug
		var cs = haxe.CallStack.callStack();
		System.trace3("allocated " + tt + " " + cs[6]);
		#end
		
		//hxd.Profiler.end("allocTexture");
		return tt;
	}
	
	override function allocVertex( count : Int, stride : Int , isDynamic = false) : VertexBuffer {
		System.trace4("allocVertex");
		
		var b = gl.createBuffer();
		#if js
		gl.bufferData(GL.ARRAY_BUFFER, count * stride * 4, isDynamic? GL.DYNAMIC_DRAW : GL.STATIC_DRAW);
		gl.bindBuffer(GL.ARRAY_BUFFER, b);
		gl.bindBuffer(GL.ARRAY_BUFFER, null); curBuffer = null; curMultiBuffer = null;
		#else
		var tmp = new Uint8Array(count * stride * 4);
		gl.bindBuffer(GL.ARRAY_BUFFER, b);
		gl.bufferData(GL.ARRAY_BUFFER, tmp,  isDynamic? GL.DYNAMIC_DRAW : GL.STATIC_DRAW);
		gl.bindBuffer(GL.ARRAY_BUFFER, null); curBuffer = null; curMultiBuffer = null;
		#end
		
		return new VertexBuffer(b, stride );
	}
	
	override function allocIndexes( count : Int ) : IndexBuffer {
		System.trace4("allocIndex");
		var b = gl.createBuffer();
		#if js
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, b);
		gl.bufferData(GL.ELEMENT_ARRAY_BUFFER, count * 2, GL.STATIC_DRAW);
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);
		#else
		var tmp = new Uint16Array(count);
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, b);
		gl.bufferData(GL.ELEMENT_ARRAY_BUFFER, tmp, GL.STATIC_DRAW);
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);
		#end
		return b;
	}

	public override function setRenderZone( x : Int, y : Int, width : Int, height : Int ) {
		if( x == 0 && y == 0 && width < 0 && height < 0 ){
			gl.scissor(0, 0, vpWidth, vpHeight);
		}
		else {
			if( x < 0 ) {
				width += x;
				x = 0;
			}
			if( y < 0 ) {
				height += y;
				y = 0;
			}
			
			var tw = vpWidth;
			var th = vpHeight;
			if( x+width > tw ) width = tw - x;
			if( y+height > th ) height = th - y;
			if( width <= 0 ) { x = 0; width = 1; };
			if ( height <= 0 ) { y = 0; height = 1; };
			
			gl.scissor(x, vpHeight-y-height, width, height);
		}
	}
	
	var fboList : hxd.Stack<FBO>;
	
	public function checkFBO(fbo:FBO) {
		
		#if debug
		hxd.System.trace3("checking fbo");
		var st = gl.checkFramebufferStatus(GL.FRAMEBUFFER);
		if (st ==  GL.FRAMEBUFFER_COMPLETE ) {
			hxd.System.trace3("fbo is complete");
			return;
		}
		
		var msg = switch(st) {
			default: 											"UNKNOWN ERROR";
			case GL.FRAMEBUFFER_INCOMPLETE_ATTACHMENT:			"FRAMEBUFFER_INCOMPLETE_ATTACHMENT​";
			case GL.FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:	"FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT";
			case GL.FRAMEBUFFER_INCOMPLETE_DIMENSIONS:   		"FRAMEBUFFER_INCOMPLETE_DIMENSIONS";
			
			case GL.FRAMEBUFFER_UNSUPPORTED:                    "FRAMEBUFFER_UNSUPPORTED";
		}
		
		hxd.System.trace3("whoops "+msg);
		throw msg;
		#end
		
	}
	
	public function tidyFramebuffers() {
		//tidy a bit
		for ( f in fboList) {
			if ( f.color == null ){
				fboList.remove(f);
				break;//only remove one per frame stack is not iterable removal safe, and it is sufficient
			}
			
			if ( f.color.isDisposed() ) {
				fboList.remove( f );
				
				hxd.System.trace2('color disposed #' +f.color.id+', disposing fbo');
				
				gl.deleteFramebuffer( f.fbo );
				if ( f.rbo != null ) gl.deleteRenderbuffer( f.rbo);
				
				f.color = null;
				f.fbo = null;
				f.rbo = null;
				break;
			}
		}
	}
	
	public override function setRenderTarget( tex : Null<h3d.mat.Texture>, useDepth : Bool, clearColor : Null<Int> ) {
		
		trace(fboList);
		tidyFramebuffers();
		trace(fboList);
		
		if ( tex == null ) {
			gl.bindRenderbuffer( GL.RENDERBUFFER, null);
			gl.bindFramebuffer( GL.FRAMEBUFFER, null ); 
			gl.viewport( 0, 0, vpWidth, vpHeight);
		}
		else {
			var fbo : FBO = null;
			
			for ( f in fboList) {
				if ( f.color == tex ) {
					fbo = f;
					System.trace3('reusing render target of ${tex.width} ${tex.height}');
					break;
				}
			}
			
			if ( fbo == null) {
				fbo = new FBO();
				fbo.color = tex;
				
				if ( tex.isDisposed()) throw "invalid target texture, not allocated";
					
				fboList.push(fbo);
			}
			
			System.trace3('creating fbo');
			if ( fbo.fbo == null ) fbo.fbo = gl.createFramebuffer();
			gl.bindFramebuffer(GL.FRAMEBUFFER, fbo.fbo);
			checkError();
						
			var bw = Math.bitCount(tex.width );
			var bh = Math.bitCount(tex.height );
			
			System.trace3('allocating render target of ${tex.width} ${tex.height}');
			
			if ( bh > 1 || bw > 1) throw "invalid texture size, must be a power of two texture";
			
			fbo.width = tex.width;
			fbo.height = tex.height;
			
			//bind color
			gl.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, fbo.color.t, 0);
			checkError();
			//bind depth
			if ( useDepth ) {
				System.trace3("fbo : using depth");
				checkError();
				if ( fbo.rbo == null) {
					fbo.rbo = gl.createRenderbuffer();
				}
				
				gl.bindRenderbuffer( GL.RENDERBUFFER, fbo.rbo);
				gl.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT, fbo.width,fbo.height);
				
				System.trace3("fbo : allocated " + fbo.rbo);
				checkError();
				
				System.trace3("fbo : bound rbo" );
				checkError();
				
				gl.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, fbo.rbo);
				
				//if( useStencil ) gl.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.STENCIL_ATTACHMENT, GL.RENDERBUFFER, fbo.rbo);
				//System.trace3("fbo : framebufferRenderbuffer" );
				checkError();
			}
			checkError();
			checkFBO(fbo);
			
			checkError();
			begin();
			checkError();
			reset();
			
			checkError();
			//ADRENO
			gl.bindFramebuffer(GL.FRAMEBUFFER, fbo.fbo);
			checkError();
			
			if( clearColor != null)
				//needed ?
				clear(	Math.b2f(clearColor>> 16),
						Math.b2f(clearColor>> 8),
						Math.b2f(clearColor),
						Math.b2f(clearColor >> 24));
			checkError();
					
			gl.viewport( 0, 0, tex.width, tex.height);
			
			checkError();
			#if debug
			if ( tex.width > gl.getParameter(GL.MAX_VIEWPORT_DIMS) )
				throw "invalid texture size, must be within gpu range";
			if ( tex.height > gl.getParameter(GL.MAX_VIEWPORT_DIMS) )
				throw "invalid texture size, must be within gpu range";
				
			if ( fboList.length > 256 ) 
				throw "it is unsafe to have more than 256 active fbo";
			#end
		}
	}
	
	override function disposeTexture( t : Texture ) {
		gl.deleteTexture(t);
	}

	override function disposeIndexes( i : IndexBuffer ) {
		gl.deleteBuffer(i);
	}
	
	override function disposeVertex( v : VertexBuffer ) {
		gl.deleteBuffer(v.b);
	}
	
	inline function makeMips(){
		gl.hint(GL.GENERATE_MIPMAP_HINT, GL.DONT_CARE);
		gl.generateMipmap(GL.TEXTURE_2D);
		checkError();
	}
	
	function getPreferredFormat() : hxd.PixelFormat {
		if ( bgraSupport!=BGRANone ) return BGRA;
		return RGBA;
	}
	
	override function uploadTextureBitmap( t : h3d.mat.Texture, bmp : hxd.BitmapData, mipLevel : Int, side : Int ) {
		uploadTexturePixels(t, bmp.getPixels(), mipLevel, side);
	}
	
	function checkTextureSize(w,h) {
		#if debug
		var sz = gl.getParameter( GL.MAX_TEXTURE_SIZE );
		hxd.Assert.isTrue( w * h <= sz * sz, "texture too big for video driver");
		#end
	}
	
	override function uploadTexturePixels( t : h3d.mat.Texture, pix : hxd.Pixels, mipLevel : Int, side : Int ) {
		//Profiler.begin("uploadTexturePixels");
		gl.bindTexture(GL.TEXTURE_2D, t.t); checkError();
		checkTextureSize( t.width, t.height);
		
		var oldFormat = pix.format;
		var newFormat = getPreferredFormat();
		
		if ( oldFormat != newFormat ) {
			if ( oldFormat != RGBA) {
				pix.convert(newFormat);
				trace("WARNING : texture format converted from " + oldFormat + " to " + newFormat+" name:"+t.name);
			}
			else { 
				newFormat = RGBA;
				trace("keeping texture in format " + oldFormat+" name:"+t.name);
			}
		}
		else {
			trace("keeping texture in format " + oldFormat+" name:"+t.name);
		}
			
		var ss = haxe.Timer.stamp();
		
		#if debug
		var sz = gl.getParameter( GL.MAX_TEXTURE_SIZE );
		hxd.Assert.isTrue( t.width * t.height <= sz * sz, "texture too big for video driver");
		#end
		
		var internalFormat = GL.RGBA; //aka file structure format do not ever touch this
		var externalFormat =  GL.RGBA; // aka pixel packing format
		var byteType = GL.UNSIGNED_BYTE;
		
		hxd.Assert.isTrue( newFormat == RGBA || newFormat == BGRA );
		
		switch(newFormat) {
			case BGRA: {
				switch (bgraSupport) {
					case BGRADesktop:
						internalFormat = GL.RGBA; 
						externalFormat = GL_BGRA_EXT; 
					case BGRAExt:
						internalFormat = GL_BGRA_EXT; 
						externalFormat = GL_BGRA_EXT; 
					case BGRANone:
				}
			}
			default:
		}
		
		var pixelBytes = getUints( pix.bytes, pix.offset);
		gl.texImage2D(GL.TEXTURE_2D, mipLevel, 
						internalFormat, t.width, t.height, 0, 
						externalFormat, byteType, pixelBytes);
		
		if ( mipLevel > 0 ) makeMips();
		
		gl.bindTexture(GL.TEXTURE_2D, null);
		checkError();
	}
	
	override function uploadVertexBuffer( v : VertexBuffer, startVertex : Int, vertexCount : Int, buf : hxd.FloatBuffer, bufPos : Int ) {
		//Profiler.begin("uploadVertexBuffer");
		var stride : Int = v.stride;
		var buf = buf.getNative();//new Float32Array(buf.getNative());
		var sub = new Float32Array(buf.buffer, bufPos, vertexCount * stride #if cpp * (fixMult?4:1) #end);
		gl.bindBuffer(GL.ARRAY_BUFFER, v.b);
		gl.bufferSubData(GL.ARRAY_BUFFER, startVertex * stride * 4, sub);
		gl.bindBuffer(GL.ARRAY_BUFFER, null);
		curBuffer = null; curMultiBuffer = null;
		checkError();
		//Profiler.end("uploadVertexBuffer");
	}

	override function uploadVertexBytes( v : VertexBuffer, startVertex : Int, vertexCount : Int, buf : haxe.io.Bytes, bufPos : Int ) {
		//Profiler.begin("uploadVertexBytes");
		var stride : Int = v.stride;
		var buf = getUints(buf);
		var sub = getUints(buf.buffer, bufPos, vertexCount * stride * 4);
		gl.bindBuffer(GL.ARRAY_BUFFER, v.b);
		gl.bufferSubData(GL.ARRAY_BUFFER, startVertex * stride * 4, sub);
		gl.bindBuffer(GL.ARRAY_BUFFER, null);
		curBuffer = null; curMultiBuffer = null;
		checkError();
		//Profiler.end("uploadVertexBytes");
	}

	override function uploadIndexesBuffer( i : IndexBuffer, startIndice : Int, indiceCount : Int, buf : hxd.IndexBuffer, bufPos : Int ) {
		//Profiler.begin("uploadIndexesBuffer");
		var buf = new Uint16Array(buf.getNative());
		var sub = new Uint16Array(buf.getByteBuffer(), bufPos, indiceCount #if cpp * (fixMult?2:1) #end);
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, i);
		gl.bufferSubData(GL.ELEMENT_ARRAY_BUFFER, startIndice * 2, sub);
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);
		//Profiler.end("uploadIndexesBuffer");
	}

	override function uploadIndexesBytes( i : IndexBuffer, startIndice : Int, indiceCount : Int, buf : haxe.io.Bytes , bufPos : Int ) {
		//Profiler.begin("uploadIndexesBytes");
		var buf = new Uint8Array(buf.getData());
		var sub = new Uint8Array(buf.getByteBuffer(), bufPos, indiceCount * 2);
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, i);
		gl.bufferSubData(GL.ELEMENT_ARRAY_BUFFER, startIndice * 2, sub);
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);
		//Profiler.end("uploadIndexesBytes");
	}
	
	function decodeType( t : String ) : Shader.ShaderType {
		return switch( t ) {
		case "float": Float;
		case "vec2": Vec2;
		case "vec3": Vec3;
		case "vec4": Vec4;
		case "mat4": Mat4;
		default: throw "Unknown type " + t;
		}
	}
	
	function decodeTypeInt( t : Int ) : Shader.ShaderType {
		return switch( t ) {
		case GL.SAMPLER_2D:	Tex2d;
		case GL.SAMPLER_CUBE: TexCube;
		case GL.FLOAT: Float;
		case GL.FLOAT_VEC2: Vec2;
		case GL.FLOAT_VEC3: Vec3;
		case GL.FLOAT_VEC4: Vec4;
		case GL.FLOAT_MAT2: Mat2;
		case GL.FLOAT_MAT3: Mat3;
		case GL.FLOAT_MAT4: Mat4;
		default:
			gl.pixelStorei(t, 0); // get DEBUG value
			throw "Unknown type " + t;
		}
	}
	
	function typeSize( t : Shader.ShaderType ) {
		return switch( t ) {
		case Float, Byte4, Byte3: 1;
		case Vec2: 2;
		case Vec3: 3;
		case Vec4: 4;
		case Mat2: 4;
		case Mat3: 9;
		case Mat4: 16;
		case Tex2d, TexCube, Struct(_), Index(_): throw "Unexpected " + t;
		case Elements(_, nb,t ): return nb * typeSize(t); 
		}
	}
	
	function buildShaderInstance( shader : Shader ) {
		var cl = Type.getClass(shader);
		var fullCode = "";
		
		function parseShader(type) {
			var vertex = type == GL.VERTEX_SHADER;
			var name = vertex ? "VERTEX" : "FRAGMENT";
			var code = Reflect.field(cl, name);
			if ( code == null ) throw "Missing " + Type.getClassName(cl) + "." + name + " shader source";
			
			var cst = shader.getConstants(vertex);
			
			code = StringTools.trim(cst + code);

			var gles = [ "#ifndef GL_FRAGMENT_PRECISION_HIGH\n precision mediump float;\n precision mediump int;\n #else\nprecision highp float;\n precision highp int;\n #end"];
			var notgles = [ "#define lowp  ", "#define mediump  " , "#define highp  " ];

			code = gles.map( function(s) return "#if GL_ES \n\t"+s+" \n #end \n").join('') + code;
			code = notgles.map( function(s) return "#if !defined(GL_ES) \n\t"+s+" \n #end \n").join('') + code;

			// replace haxe-like #if/#else/#end by GLSL ones
			code = ~/#if ([A-Za-z0-9_]+)/g.replace(code, "#if defined ( $1 ) \n");
			code = ~/#elseif ([A-Za-z0-9_]+)/g.replace(code, "#elif defined ( $1 ) \n");
			code = code.split("#end").join("#endif");

			//on apple software version should come first
			#if !mobile
			code = "#version 120 \n" + code;
			#end

			return code;
		}
		
		function compileShader(type,code) {
			var s = gl.createShader(type);
			gl.shaderSource(s, code);
			
			#if debug
			System.trace3("source shaderInfoLog:" + getShaderInfoLog(s, code));
			#end
				
			gl.compileShader(s);
			
			if ( gl.getShaderParameter(s, GL.COMPILE_STATUS) != cast 1 ) {
				System.trace1("error occured");
				
				var log = getShaderInfoLog(s, code);
				throw "An error occurred compiling the " + Type.getClass(shader) + " : " + log;
				
				checkError();
			}
			else {
				//always print him becaus it can hint gles errors
				#if debug
				System.trace3("compile shaderInfoLog ok:" + getShaderInfoLog(s, code));
				#end
			}
			
			return s;
		}
		
		var vsCode = parseShader(GL.VERTEX_SHADER);
		var fsCode = parseShader(GL.FRAGMENT_SHADER);
					
		fullCode = vsCode+ "\n" + fsCode;
		
		var sig = haxe.crypto.Crc32.make( haxe.io.Bytes.ofString( fullCode ) );
		if ( shaderCache.exists( sig )) {
			hxd.System.trace3("shader cache hit !");
			return shaderCache.get(sig);
		}
		
		var vs = compileShader(GL.VERTEX_SHADER,vsCode);
		var fs = compileShader(GL.FRAGMENT_SHADER,fsCode);
		
		var p = gl.createProgram();

		//before doing that we should parse code to check those attrs existence
		gl.bindAttribLocation(p, 0, "pos");
		gl.bindAttribLocation(p, 1, "uv");
		gl.bindAttribLocation(p, 2, "normal");
		gl.bindAttribLocation(p, 3, "color");
		gl.bindAttribLocation(p, 4, "weights");
		gl.bindAttribLocation(p, 5, "insdexes");
		
		gl.attachShader(p, vs);
		checkError();
		
		#if debug
		System.trace3("attach vs programInfoLog:" + getProgramInfoLog(p, fullCode));
		#end
		
		gl.attachShader(p, fs);
		checkError();
		
		#if debug
		System.trace3("attach fs programInfoLog:" + getProgramInfoLog(p, fullCode));
		#end
		
		gl.linkProgram(p);
		checkError();
		
		#if debug
		System.trace3("link programInfoLog:" + getProgramInfoLog(p, fullCode));
		#end
		
		if( gl.getProgramParameter(p, GL.LINK_STATUS) != cast 1 ) {
			var log = gl.getProgramInfoLog(p);
			throw "Program linkage failure: "+log;
		}
		else {
			#if debug
			System.trace3("linked programInfoLog:" + getProgramInfoLog(p, fullCode));
			#end
		}
		
		checkError();
	
		var inst = new Shader.ShaderInstance();
			
		inst.contextId = currentContextId;
		var nattr = gl.getProgramParameter(p, GL.ACTIVE_ATTRIBUTES);
		inst.attribs = [];
		
		var amap = new Map();
		for( k in 0...nattr ) {
			var inf = gl.getActiveAttrib(p, k);
			amap.set(inf.name, { index : gl.getAttribLocation(p,inf.name), inf : inf } );
		}
		
		var code = gl.getShaderSource(vs);

		// remove (and save) all #define's
		var rdef = ~/#define ([A-Za-z0-9_]+)/;
		var defs = new Map();
		while( rdef.match(code) ) {
			defs.set(rdef.matched(1), true);
			code = rdef.matchedLeft() + rdef.matchedRight();
		}
		
		// remove parts of the codes that are undefined
		var rif = ~/#if defined\(([A-Za-z0-9_]+)\)([^#]+)#endif/;
		while( rif.match(code) ) {
			if( defs.get(rif.matched(1)) )
				code = rif.matchedLeft() + rif.matched(2) + rif.matchedRight();
			else
				code = rif.matchedLeft() + rif.matchedRight();
		}
		
		// extract attributes from code (so we know the offset and stride)
		var r = ~/attribute[ \t\r\n]+([A-Za-z0-9_]+)[ \t\r\n]+([A-Za-z0-9_]+)/;
		var offset = 0;
		var ccode = code;
		while( r.match(ccode) ) {
			var aname = r.matched(2);
			var atype = decodeType(r.matched(1));
			var a = amap.get(aname);
			var size = typeSize(atype);
			if ( a != null ) {
				
				var etype = GL.FLOAT;
				var com = findVarComment(aname,ccode);
				if ( com != null ) {
					//if ( System.debugLevel>=2) trace("found comment on " + aname + " " + com);
					if ( com.startsWith("byte") )
						etype = GL.UNSIGNED_BYTE;
				}
				else 
				{
					//if ( System.debugLevel>=2) trace("didn't find comment on var " + aname);
				}
				
				#if debug
				hxd.System.trace3("setting attribute offset " + offset);
				#end
				inst.attribs.push( new Shader.Attribute( aname,  atype, etype, offset , a.index , size ));
				offset += size;
			}
			else {
				#if debug
				hxd.System.trace3("skipping attribute " + aname);
				#end
			}
			ccode = r.matchedRight();
		}
		inst.stride = offset;//this stride is mostly not useful as it can be broken down into several stream
		
		// list uniforms needed by shader
		var allCode = code + gl.getShaderSource(fs);
		
		var nuni = gl.getProgramParameter(p, GL.ACTIVE_UNIFORMS);
		inst.uniforms = [];
		
		parseUniInfo = new UniformContext(-1,null);
		for( k in 0...nuni ) {
			parseUniInfo.inf = new GLActiveInfo( gl.getActiveUniform(p, k) );
			
			if( parseUniInfo.inf.name.substr(0, 6) == "webgl_" ) 	continue; // skip native uniforms
			if( parseUniInfo.inf.name.substr(0, 3) == "gl_" )		continue;
				
			var tu = parseUniform(  allCode,p );
			inst.uniforms.push( tu );
			#if debug
			System.trace4('adding uniform ${tu.name} ${tu.type} ${tu.loc} ${tu.index}');
			#end
		}
		
		inst.program = p;
		checkError();
		
		gl.deleteShader( vs );
		gl.deleteShader( fs );
		
		checkError();
		
		@:allowAccess inst.sig = sig;
		shaderCache.set( sig , inst);
		return inst;
	}
	
	//var parseUniInfo : { var texIndex : Int; var inf: openfl.gl.GLActiveInfo;};
	var parseUniInfo : UniformContext;
	
	function findVarComment(str,code){
		var r = new EReg(str + "[ \\t]*\\/\\*([A-Za-z0-9_]+)\\*\\/", "g");
		return 
		if ( r.match(code) )
			r.matched(1);
		else 
			return null;
	}
	
	function hasArrayAccess(str,code){
		var r = new EReg("[A-Z0-9_]+[ \t]+" + str + "\\[[a-z](.+?)\\]", "gi");
		return 
		if ( r.match(code) )
			true;
		else false;
	}

	
	function parseUniform(allCode,p)
	{
		var inf : GLActiveInfo = parseUniInfo.inf;
		
		System.trace4('retrieved uniform $inf');
		
		var isSubscriptArray = false;
		var t = decodeTypeInt(inf.type);
		var scanSubscript = true;
		var r_array = ~/\[([0-9]+)\]$/g;
		
		switch( t ) {
			case Tex2d, TexCube: parseUniInfo.texIndex++;
			case Vec3:
				var c = findVarComment( inf.name,allCode );
				if( c != null && c.startsWith( "byte" )){
					t = Byte3;
				}
				else 
				{
					if ( hasArrayAccess(inf.name.split('.').pop(), allCode ) ) {
						isSubscriptArray = true;
					}
				}
			case Vec4:
				var c = findVarComment( inf.name,allCode );
				if( c != null && c.startsWith( "byte" )){
					t = Byte4;
				}
				else 
				{
					if ( hasArrayAccess(inf.name.split('.').pop(), allCode ) ) {
						isSubscriptArray = true;
					}
				}
			case Mat4:
				var li = inf.name.lastIndexOf("[");
				if ( li >= 0 )
					inf.name = inf.name.substr( 0,li );
					
				if(  hasArrayAccess(inf.name,allCode ) ) {
					scanSubscript = false;
					t = Elements( inf.name, null, t );
					System.trace4('subtyped ${inf.name} $t ${inf.type} as array');
				}
				else System.trace4('can t subtype ${inf.name} $t ${inf.type}');
				
			default:	
				System.trace4('can t subtype $t ${inf.type}');
		}
		
		//todo refactor all...but it will wait hxsl3

		var name = inf.name;
		while ( scanSubscript ) {
			if ( r_array.match(name) ) { //
				System.trace4('0_ pre $name ');
				name = r_array.matchedLeft();
				t = Index(Std.parseInt(r_array.matched(1)), t);
				System.trace4('0_ sub $name -> $t');
				continue;
			}
			
			var c = name.lastIndexOf(".");
			if ( c < 0) {
				c = name.lastIndexOf("[");
			}
			
			if ( c > 0 ) {
				System.trace4('1_ $name -> $t');
				var field = name.substr(c + 1);
				name = name.substr(0, c);
				System.trace4('1_ $name -> field $field $t');
				if ( !isSubscriptArray){ //struct subscript{
					t = Struct(field, t);
				}
				else //array subscript{
					t = Elements( field, inf.size, t );
			}
			break;
		}
		
		
		return new Shader.Uniform(
			name,
			gl.getUniformLocation(p, inf.name),
			t,
			parseUniInfo.texIndex
		);
	}
	
	public override function deleteShader(shader : Shader) {
		if ( shader == null ) {
			#if debug
				throw "Shader not set ?";
			#end
			return;
		}
		
		gl.deleteProgram(shader.instance.program);
	}
	
	override function selectShader( shader : Shader ) : Bool {
		if ( shader == null ) {
			#if debug
				throw "Shader not set ?";
			#end
			return false;
		}
		
		var change = false;
		
		if ( shader.instance != null && shader.instance.contextId != currentContextId )
			shader.instance = null;
			
		//hxd.Profiler.begin("GlDriver:buildShaderInstance");
		if ( shader.instance == null ) {
			//System.trace4("building shader" + Type.typeof(shader));
			shader.instance = buildShaderInstance(shader);
		}
		//hxd.Profiler.end("GlDriver:buildShaderInstance");

		//hxd.Profiler.begin("GlDriver:shaderSwitch");
		if ( shader.instance != curShader ) {
			var old = curShader;
			//System.trace4("binding shader "+Type.getClass(shader)+" nbAttribs:"+shader.instance.attribs.length);
			curShader = shader.instance;
			
			if (curShader.program == null) throw "invalid shader";
			//System.trace4("using program");
			gl.useProgram(curShader.program);
			
			var oa = 0;
			if ( old != null )
				for ( a in old.attribs) 
					oa |= 1<<a.index;
					
			var na = 0;
				for ( a in curShader.attribs) 
					na |= 1<<a.index;
				
			if ( old != null )
				for ( a in old.attribs)
					if( na&(1<<a.index) == 0)
						gl.disableVertexAttribArray(a.index);
			
			for ( a in curShader.attribs)
				if( oa&(1<<a.index) == 0)
					gl.enableVertexAttribArray(a.index);
				
			//System.trace4("attribs set program");
			change = true;
			shaderSwitch++;
		}
		//hxd.Profiler.end("GlDriver:shaderSwitch");
			
//		if ( System.debugLevel>=2 && change) trace("shader switch");
		
		//if ( System.debugLevel>=2 ) trace("setting uniforms");
		//hxd.Profiler.begin("GlDriver:setUniform");
		for ( u in curShader.uniforms ) {
			if ( u == null ) throw "Missing uniform pointer";
			if ( u.loc == null ) throw "Missing uniform location";
			
			var val : Dynamic = Reflect.getProperty(shader, u.name);
			
			if ( val == null ) val = Reflect.field(shader, u.name);
			
			if ( val == null ) {
				if ( Reflect.hasField( shader, u.name) ) 
					throw 'Shader param ${u.name} is null';
				else 
					throw "Missing shader value " + u.name + " among "+ Reflect.fields(shader);
			}
			//System.trace3('retrieving uniform ($u) $val ');
			//System.trace4('retrieving uniform ${u.name} ');
			setUniform(val, u, u.type,change);
		}
		//hxd.Profiler.end("GlDriver:setUniform");
		
		//System.trace4('shader custom setup ');
		shader.customSetup(this);
		checkError();
		//System.trace4('shader is now setup ');
		
		return change;
	}
	
	/**
	 * 
	 * @param	t
	 * @param	?stage relevant texture stage
	 * @param	mipMap
	 * @param	filter
	 * @param	wrap
	 * @return true if context was reused ( maybe you can make good use of the info )
	 */
	public function setupTexture( t : h3d.mat.Texture, stage : Int, mipMap : h3d.mat.Data.MipMap, filter : h3d.mat.Data.Filter, wrap : h3d.mat.Data.Wrap ) : Bool {
		if ( curTex[stage] != t ) {
			//trace("activating tex#" + t.id + " at " +stage + " name:" + t.name);
			#if debug
			if ( t != null && t.isDisposed()) {
				hxd.System.trace1("alarm texture setup is suspicious : " + t.name);
				if( t.isDisposed() )
					t.realloc();
			
				if ( t.isDisposed() )
					t = h3d.mat.Texture.fromColor( 0xFFff00ff );
			}
			#end
			
			gl.activeTexture(GL.TEXTURE0 + stage);
			gl.bindTexture(GL.TEXTURE_2D, t.t);
			var flags = TFILTERS[Type.enumIndex(mipMap)][Type.enumIndex(filter)];
			gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, flags[0]);
			gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, flags[1]);
			var w = TWRAP[Type.enumIndex(wrap)];
			gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, w);
			gl.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, w);
			checkError();
			curTex[stage] = t;
			
			if ( t != null) t.lastFrame = h3d.Engine.getCurrent().frameCount;
			
			textureSwitch++;
			return true;
		}
		return false;
	}
	
	inline function blitMatrices(a:Array<Matrix>, transpose) {
		var t = createF32( a.length * 16 );
		var p = 0;
		for ( m in a ){
			blitMatrix( m, transpose, p,t  );
			p += 16;
		}
		return t;
	}
	
	inline function blitMatrix(a:Matrix, transpose, ofs = 0, t :Float32Array=null) {
		if (t == null) t = createF32( 16 );
		
		if ( !transpose) {
			t[ofs+0] 	= a._11; 
			t[ofs+1] 	= a._12; 
			t[ofs+2] 	= a._13; 
			t[ofs+3] 	= a._14;
			     
			t[ofs+4] 	= a._21; 
			t[ofs+5] 	= a._22; 
			t[ofs+6] 	= a._23; 
			t[ofs+7] 	= a._24;
			    
			t[ofs+8] 	= a._31; 
			t[ofs+9]	= a._32; 
			t[ofs+10] = a._33; 
			t[ofs+11] = a._34;
			 
			t[ofs+12] = a._41; 
			t[ofs+13] = a._42; 
			t[ofs+14] = a._43; 
			t[ofs+15] = a._44;
		}
		else {
			t[ofs+0] 	= a._11; 
			t[ofs+1] 	= a._21; 
			t[ofs+2] 	= a._31; 
			t[ofs+3] 	= a._41;
			     
			t[ofs+4] 	= a._12; 
			t[ofs+5] 	= a._22; 
			t[ofs+6] 	= a._32; 
			t[ofs+7] 	= a._42;
			    
			t[ofs+8] 	= a._13; 
			t[ofs+9] 	= a._23; 
			t[ofs+10] = a._33; 
			t[ofs+11] = a._43;
			      
			t[ofs+12] = a._14; 
			t[ofs+13] = a._24; 
			t[ofs+14] = a._34; 
			t[ofs+15] = a._44;
		}
		return t;
	}
	
	public static var f32Pool : IntMap<Float32Array> =  new haxe.ds.IntMap();
	
	function createF32(sz:Int) : Float32Array {
		if ( !f32Pool.exists(sz) ) {
			f32Pool.set(sz, new Float32Array([for( i in 0...sz) 0.0]));
		}
		
		var p = f32Pool.get( sz );
		
		for ( i in 0...p.length ) p[i] = 0.0;
		
		f32Pool.set( sz, null);
		return p;
	}
	
	function deleteF32(a:Float32Array) {
		f32Pool.set(a.length, a);
	}
	
	
	
	function setUniform( val : Dynamic, u : Shader.Uniform, t : Shader.ShaderType , shaderChange) {
		
		var buff : Float32Array = null;
		#if debug if (u == null) throw "no uniform set, check your shader"; #end
		#if debug if (u.loc == null) throw "no uniform loc set, check your shader"; #end
		#if debug if (val == null) throw "no val set, check your shader"; #end
		#if debug if (gl == null) throw "no gl set, Arrrghh"; #end
		
		checkError();
		
		//System.trace2("setting uniform "+u.name);
		//System.trace3("setting uniform " + u.name+ " of type "+t +" and value "+val );
		
		switch( t ) {
		case Mat4:
			
			#if debug
			if ( Std.is( val , Array)) throw "error";
			#end
			
			var m : h3d.Matrix = val;
			gl.uniformMatrix4fv(u.loc, false, buff = blitMatrix(m, true) );
			deleteF32(buff);
			
			//System.trace3("one matrix batch " + m + " of val " + val);
			
		case Tex2d:
			var t : h3d.mat.Texture = val;
			
			#if debug
			if ( t != null && t.isDisposed()) {
				hxd.System.trace1("Uniform:alarm texture setup is suspicious");
			}
			#end
			
			var reuse = setupTexture(t, u.index, t.mipMap, t.filter, t.wrap);
			if ( !reuse || shaderChange ) {
				//trace("activating tex#"+t.id+" at "+u.index + " name:"+t.name);
				gl.activeTexture(GL.TEXTURE0 + u.index);
				gl.bindTexture(GL.TEXTURE_2D,t.t);
				gl.uniform1i(u.loc,  u.index);
			}
			
		case Float: var f : Float = val;  		gl.uniform1f(u.loc, f);
		case Vec2:	var v : h3d.Vector = val;	gl.uniform2f(u.loc, v.x, v.y);
		case Vec3:	var v : h3d.Vector = val;	gl.uniform3f(u.loc, v.x, v.y, v.z);
		case Vec4:	var v : h3d.Vector = val;	gl.uniform4f(u.loc, v.x, v.y, v.z, v.w);
		
		case Struct(field, t):
			var vs = Reflect.field(val, field);
			
			if ( t == null ) throw "Missing shader type " + t;
			if ( u == null ) throw "Missing shader loc " + u;
			if ( vs == null ) throw "Missing shader field " + field+ " in " +val;
			
			setUniform(vs, u, t,shaderChange);
			
		case Elements(field, nb, t): {
			
			switch(t) {
				case Vec3: 
					var arr : Array<Vector> = Reflect.field(val, field);
					if (arr.length > nb) arr = arr.slice(0, nb);
					gl.uniform3fv( u.loc, buff = packArray3(arr));
					
				case Vec4: 
					var arr : Array<Vector> = Reflect.field(val, field);
					if (arr.length > nb) arr = arr.slice(0, nb);
					gl.uniform4fv( u.loc, buff = packArray4(arr));
					
				case Mat4: 
					var ms : Array<h3d.Matrix> = val;
					if ( nb != null && ms.length != nb)  System.trace3('Array uniform type mismatch $nb requested, ${ms.length} found');
						
					gl.uniformMatrix4fv(u.loc, false, buff = blitMatrices(ms,true) );
					
				default: throw "not supported";
			}
			deleteF32(buff);
		}
			
		case Index(index, t):
			var v = val[index];
			if( v == null ) throw "Missing shader index " + index;
			setUniform(v, u, t,shaderChange);
		case Byte4:
			var v : Int = val;
			gl.uniform4f(u.loc, ((v >> 16) & 0xFF) / 255, ((v >> 8) & 0xFF) / 255, (v & 0xFF) / 255, (v >>> 24) / 255);
		case Byte3:
			var v : Int = val;
			gl.uniform3f(u.loc, ((v >> 16) & 0xFF) / 255, ((v >> 8) & 0xFF) / 255, (v & 0xFF) / 255);
		default:
			throw "Unsupported uniform " + u.type;
		}
		
		checkError();
		
	}
	//TODO cache this
	function packArray4( vecs : Array<Vector> ):Float32Array{
		var a = createF32(vecs.length*4);
		for ( i in 0...vecs.length) {
			var vec = vecs[i];
			a[i * 4] = vec.x;
			a[i * 4+1] = vec.y;
			a[i * 4+2] = vec.z;
			a[i * 4+3] = vec.w;
		}
		return a;
	}
	
	//TODO cache this
	function packArray3( vecs : Array<Vector> ):Float32Array{
		var a = createF32(vecs.length*4);
		for ( i in 0...vecs.length) {
			var vec = vecs[i];
			a[i * 3] = vec.x;
			a[i * 3+1] = vec.y;
			a[i * 3+2] = vec.z;
		}
		return a;
	}
	
	var curBuffer : VertexBuffer;
	var curMultiBuffer : Array<Buffer.BufferOffset>;
	
	override function selectBuffer( v : VertexBuffer ) {
		//hxd.Profiler.begin("selectBuffer");
		var ob = curBuffer;
		
		curBuffer = v;
		curMultiBuffer = null;
		
		var stride : Int = v.stride;
		if ( ob != v ) {
			gl.bindBuffer(GL.ARRAY_BUFFER, v.b);
			//System.trace4("buffer is bound");
		}
		else {
			//System.trace4("buffer is already bound");
		}
		checkError();
		
		//System.trace3("setting attrip Pointer nbAttribs:" + curShader.attribs.length);
		//System.trace3("setting attribs :"+ curShader.attribs);
		
		//this one is sharde most of the time, let's define it fully
		for ( a in curShader.attribs ) {
			var ofs = a.offset * 4;
			gl.vertexAttribPointer(a.index, a.size, a.etype, false, stride*4, ofs);
			//System.trace4("selectBuffer: set vertex attrib: "+a+" stride:"+(stride*4)+" ofs:"+ofs);
		}
		
		//System.trace3("selected Buffer");
		//hxd.Profiler.end("selectBuffer");
		checkError();
	}
	
	override function selectMultiBuffers( buffers : Array<Buffer.BufferOffset> ) {
		var changed = curMultiBuffer == null || curMultiBuffer.length != buffers.length;
		
		#if debug
		//System.trace4("selectMultiBuffers");
		#end
		
		if( !changed )
			for( i in 0...curMultiBuffer.length )
				if( buffers[i] != curMultiBuffer[i] ) {
					changed = true;
					break;
				}
				
		if ( changed ) {
			for ( i in 0...buffers.length ) {
				var b = buffers[i];
				var a = curShader.attribs[i];
				gl.bindBuffer(GL.ARRAY_BUFFER, b.b.b.vbuf.b);

				//this is a single stream, let's bind it without stride
				if( !b.shared ){
					gl.vertexAttribPointer( a.index, a.size, a.etype, false, 0, 0);
				//this is a composite one
					#if debug
					System.trace4("selectMultiBuffer: set vertex attrib not shared: " + a);
					#end
				}
				
				else {
					gl.vertexAttribPointer( a.index, a.size, a.etype, false, b.stride, b.offset * 4);
					#if debug
					System.trace4("selectMultiBuffer: set vertex attrib shared: " + a);
					#end
				}
				
				checkError();
			}
				
			curBuffer = null;
			curMultiBuffer = buffers;
		}
	}
	
	public function checkObject(o) {
		#if cpp
		System.trace2( o.toString() + " " + (untyped o.getType()) + " " + Std.string(o.isValid()) );
		hxd.Assert.isTrue(o.isValid());
		#end
	}
	
	override function draw( ibuf : IndexBuffer, startIndex : Int, ntriangles : Int ) {
		//checkObject(ibuf);
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ibuf);
		checkError();
		
		//Profiler.begin("drawElements");
		gl.drawElements(GL.TRIANGLES, ntriangles * 3, GL.UNSIGNED_SHORT, startIndex * 2);
		checkError();
		//Profiler.end("drawElements");
		
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);
		checkError();
	}
	
	override function present() {
		//useless ofl will do it at swap time
		#if !openfl
			gl.finish();
		#end
	}

	override function isDisposed() {
		return false;
	}

	override function init( onCreate : Bool -> Void, forceSoftware = false ) {
		haxe.Timer.delay(onCreate.bind(false), 1);
	}
	
	static var TFILTERS = [
		[[GL.NEAREST,GL.NEAREST],[GL.LINEAR,GL.LINEAR]],
		[[GL.NEAREST,GL.NEAREST_MIPMAP_NEAREST],[GL.LINEAR,GL.LINEAR_MIPMAP_NEAREST]],
		[[GL.NEAREST,GL.NEAREST_MIPMAP_LINEAR],[GL.LINEAR,GL.LINEAR_MIPMAP_LINEAR]],
	];
	
	static var TWRAP = [
		GL.CLAMP_TO_EDGE,
		GL.REPEAT,
	];
	
	static var FACES = [
		
		-1,
		
		GL.BACK,
		GL.FRONT,
		
		
		GL.FRONT_AND_BACK,
	];
	
	static var BLEND = [
		GL.ONE,
		GL.ZERO,
		GL.SRC_ALPHA,
		GL.SRC_COLOR,
		GL.DST_ALPHA,
		GL.DST_COLOR,
		GL.ONE_MINUS_SRC_ALPHA,
		GL.ONE_MINUS_SRC_COLOR,
		GL.ONE_MINUS_DST_ALPHA,
		GL.ONE_MINUS_DST_COLOR,
		GL.CONSTANT_COLOR,
		GL.CONSTANT_ALPHA,
		GL.ONE_MINUS_CONSTANT_COLOR,
		GL.ONE_MINUS_CONSTANT_ALPHA,
		GL.SRC_ALPHA_SATURATE,
	];
	
	static var COMPARE = [
		GL.ALWAYS,
		GL.NEVER,
		GL.EQUAL,
		GL.NOTEQUAL,
		GL.GREATER,
		GL.GEQUAL,
		GL.LESS,
		GL.LEQUAL,
	];
	
	function glCompareToString(c){
		return switch(c) {
			case GL.ALWAYS    :      "ALWAYS";
			case GL.NEVER     :      "NEVER";  
			case GL.EQUAL     :      "EQUAL";   
			case GL.NOTEQUAL  :      "NOTEQUAL";
			case GL.GREATER   :      "GREATER";
			case GL.GEQUAL    :      "GEQUAL";  
			case GL.LESS      :      "LESS";    
			case GL.LEQUAL    :      "LEQUAL";
			default :			 	"Unknown";
		}
	}


	public inline function checkError() {
		#if debug
		if (gl.getError() != GL.NO_ERROR)
		{
			var s = getError();
			if ( s != null) {
				var str = "GL_ERROR:" + s;
				trace(str);
				throw s;
			}
		}
		#end
	}
	
	public inline function getError() {
		return 
		switch(gl.getError()) {
			case GL.NO_ERROR                      	: null;
			case GL.INVALID_ENUM                  	:"INVALID_ENUM";
			case GL.INVALID_VALUE                 	:"INVALID_VALUE";
			case GL.INVALID_OPERATION           	:"INVALID_OPERATION";
			case GL.OUT_OF_MEMORY               	:"OUT_OF_MEMORY";
			default 								:null;
		}
	}
	
	public inline function getShaderInfoLog(s, code) {
		var log = gl.getShaderInfoLog(s);
		if ( log == null ) return "";
		var lines = code.split("\n");
		var index = Std.parseInt(log.substr(9));
		if (index == null) return "";
		index--;
		if ( lines[index] == null ) return "";
		var line = lines[index];
		if ( line == null ) 
			line = "-" 
		else 
			line = "(" + StringTools.trim(line) + ").";
		return log + line;
	}
	
	public inline function getProgramInfoLog(p,code) {
		var log = gl.getProgramInfoLog(p);
		var hnt = log.substr(26);
		var line = code.split("\n")[Std.parseInt(hnt)];
		if ( line == null ) 
			line = "-" 
		else 
			line = "(" + StringTools.trim(line) + ").";
		return log + line;
	}

	static var MAX_TEXTURE_IMAGE_UNITS = 0;
	
	override function restoreOpenfl() {
		gl.depthRange(0, 1);
		gl.clearDepth(1);
		gl.depthMask(true);
		gl.colorMask(true,true,true,true);
		gl.disable(GL.DEPTH_TEST);
		gl.frontFace(GL.CCW);
		gl.enable( GL.BLEND );
		gl.blendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
		gl.disable(GL.CULL_FACE);
		gl.disable(GL.SCISSOR_TEST);
		gl.disable(GL.SAMPLE_ALPHA_TO_COVERAGE);
		
		if ( MAX_TEXTURE_IMAGE_UNITS == 0) MAX_TEXTURE_IMAGE_UNITS = gl.getParameter(GL.MAX_TEXTURE_IMAGE_UNITS);
		
		for (i in 0...MAX_TEXTURE_IMAGE_UNITS) {
			gl.activeTexture(GL.TEXTURE0 + i);
			gl.bindTexture(GL.TEXTURE_CUBE_MAP, null);
			gl.bindTexture(GL.TEXTURE_2D, null);
		}
		
		gl.bindBuffer(GL.ARRAY_BUFFER, null);
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);
		
		curShader = null;
		curMatBits = null;
		
		curTex = null;
		curBuffer = null; 
		curMultiBuffer = null;
	}
	
	var hasSampleAlphaToCoverage :Null<Bool> = null;
	
	public override function hasFeature( f : Feature ) : Bool{
		return
		switch(f) {
			case BgraTextures:	bgraSupport != BGRANone;
			case SampleAlphaToCoverage:
				if ( hasSampleAlphaToCoverage != null ) return hasSampleAlphaToCoverage;
				
				if ( hasSampleAlphaToCoverage == null ) {
					trace(gl.getParameter(GL_MULTISAMPLE));
					trace(gl.getParameter(GL_SAMPLE_BUFFERS));
					
					hasSampleAlphaToCoverage = (gl.getParameter(GL_MULTISAMPLE) == true) || gl.getParameter( GL_SAMPLE_BUFFERS ) >= 1;
					
					hxd.System.trace1("hasSampleAlphaToCoverage support is :" + hasSampleAlphaToCoverage);
				}
				
				return true;
					
				return hasSampleAlphaToCoverage;
				
			default:			super.hasFeature(f);
		}
	}
}

#end
