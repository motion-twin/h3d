package h3d.impl;

import h2d.Tools;
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
		
		#if debug
		function toString() {
			return 'GLActiveInfo : sz:$size type:$type name:$name';
		}
		#end
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
	var variables : Map<String, Dynamic>;
	public function new(t,i) {
		texIndex = t;
		inf = i;
		variables = new Map();
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
	
	public static inline var GL_UNSIGNED_BYTE_3_3_2            	= 0x8032;
	public static inline var GL_UNSIGNED_SHORT_4_4_4_4         	= 0x8033;
	public static inline var GL_UNSIGNED_SHORT_5_5_5_1         	= 0x8034;
	public static inline var GL_UNSIGNED_INT_8_8_8_8           	= 0x8035;
	public static inline var GL_UNSIGNED_INT_10_10_10_2        	= 0x8036;
	                                                                    
	public static inline var GL_UNSIGNED_BYTE_2_3_3_REV        	= 0x8362;
	public static inline var GL_UNSIGNED_SHORT_5_6_5           	= 0x8363;
	public static inline var GL_UNSIGNED_SHORT_5_6_5_REV       	= 0x8364;
	public static inline var GL_UNSIGNED_SHORT_4_4_4_4_REV     	= 0x8365;
	public static inline var GL_UNSIGNED_SHORT_1_5_5_5_REV     	= 0x8366;
	public static inline var GL_UNSIGNED_INT_8_8_8_8_REV       	= 0x8367;
	public static inline var GL_UNSIGNED_INT_2_10_10_10_REV    	= 0x8368;
	
	public static inline var GL_RGBA8 = 0x8058;
	public static inline var GL_RGB565 = 0x8D62;
	public static inline var GL_RGB5 = 0x8050;
	public static inline var GL_RGBA4 = 0x8056;
	public static inline var GL_RGB5_A1 = 0x8057;
	
	public static inline var GL_RED =  0x1903;
	public static inline var GL_R8 =  0x8229;
	
	public static inline var GL_ALPHA4_EXT	= 0x803B;
	public static inline var GL_ALPHA8_EXT  = 0x803C;
	public static inline var GL_ALPHA12_EXT = 0x803D;
	public static inline var GL_ALPHA16_EXT = 0x803E;
	public static inline var GL_ALPHA  		= 0x1906;
	
	public static inline var GL_MULTISAMPLE 	= 0x809D;
	public static inline var GL_SAMPLE_BUFFERS 	= 0x80A8;
	public static inline var GL_SAMPLES 		= 0x80A9;
	
	#if mobile
	public static inline var GL_DEPTH_COMPONENT16 = 0x81A5;
	public static inline var GL_DEPTH_COMPONENT24 = 0x81A6;
	public static inline var GL_DEPTH_COMPONENT32 = 0x81A7;
	#end
	
	public static inline var COMPRESSED_RGB_PVRTC_4BPPV1_IMG = 0x8C00;
    public static inline var COMPRESSED_RGB_PVRTC_2BPPV1_IMG = 0x8C01;
	
    public static inline var COMPRESSED_RGBA_PVRTC_4BPPV1_IMG = 0x8C02;
    public static inline var COMPRESSED_RGBA_PVRTC_2BPPV1_IMG  = 0x8C03;
	
	public static inline var COMPRESSED_RGBA_PVRTC_2BPPV2_IMG = 0x9137;
    public static inline var COMPRESSED_RGBA_PVRTC_4BPPV2_IMG  = 0x9138;

	public static inline var COMPRESSED_RGB_S3TC_DXT1_EXT = 0x83F0;
    public static inline var COMPRESSED_RGBA_S3TC_DXT1_EXT = 0x83F1;
    public static inline var COMPRESSED_RGBA_S3TC_DXT3_EXT = 0x83F2;
    public static inline var COMPRESSED_RGBA_S3TC_DXT5_EXT  = 0x83F3;
	
    public static inline var TEXTURE_MAX_ANISOTROPY_EXT  		= 0x84FE;
    public static inline var MAX_TEXTURE_MAX_ANISOTROPY_EXT  	= 0x84FF;
	public static inline var TEXTURE_CUBE_MAP_SEAMLESS          = 0x884F;
	
	
	public static inline var ETC1_RGB8_OES =  0x8D64;
	
	public var frame:Int;
	
	//var curAttribs : Int;
	var curShader : Shader.ShaderInstance;
	var curMatBits : Null<Int>;
	
	var curTex : Array<h3d.mat.Texture> = [];
	var vidx : Array<Int> = [0, 0, 0, 0];
	
	public var resetSwitch = 0;
	public var currentContextId = 0;
	public var vendor : String = null;
	public var renderer : String = null;
	
	public var shaderCache : haxe.ds.IntMap<ShaderInstance>;
	public var extensions : Map<String,String>;
	public var supportsBGRA = BGRANone;
	public var supports565	= false;
	public var supports4444	= false;
	public var supports5551	= false;
	public var supportAnisotropic : Null<Int> = null;
	public var supportSeamlessCubemap = false;
	
	var vpWidth = 0;
	var vpHeight = 0;
	var screenBuffer : openfl.gl.GLFramebuffer = null;  
	var curTarget : Null<FBO>;
	var engine(get, never) : h3d.Engine; 

	inline function get_engine() return h3d.Engine.getCurrent();  
	
	public static #if prod inline #end var debugForceTex4x4 : Bool = false;
	public static #if prod inline #end var debugSendZeroes : Bool = false;
		
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
		extensions = new Map();
		for ( e in gl.getSupportedExtensions() )
			extensions.set(e, e);
		
		#if debug
		System.trace1('running on $renderer by $vendor');
		System.trace1("supported extensions:" + Lambda.array(extensions).join("\n"));
		System.trace1("max combined tex units : " + gl.getParameter(GL.MAX_COMBINED_TEXTURE_IMAGE_UNITS));
		System.trace1("max tex img units : " + gl.getParameter(GL.MAX_TEXTURE_IMAGE_UNITS));
		#end
		
		#end
		
		detectCaps();
		setupDevice();
	}
	
	function setupDevice() {
		#if ios
		screenBuffer = new openfl.gl.GLFramebuffer(GL.version, GL.getParameter(GL.FRAMEBUFFER_BINDING));
		#end

		#if !mobile
		gl.enable(GL.TEXTURE_CUBE_MAP);
		#end
		
		if ( supportSeamlessCubemap)
			gl.enable( TEXTURE_CUBE_MAP_SEAMLESS );
	}
	
	function detectCaps() {
		
		#if mobile
		supports565 = true;
		supports4444 = true;
		supports5551 = true;
		#end
		
		if ( extensions != null) 
			for ( s in extensions) {
				switch(s) {
					case "GL_EXT_texture_filter_anisotropic", "EXT_texture_filter_anisotropic":
						supportAnisotropic = 2;
						
						var prm : Dynamic = gl.getParameter(MAX_TEXTURE_MAX_ANISOTROPY_EXT);
						if ( prm != null)
							supportAnisotropic = prm;
							
					case "GL_ARB_seamless_cube_map":
						supportSeamlessCubemap = true;
					case 
						#if !mobile
						"GL_EXT_bgra","EXT_bgra",
						#end
						
						"GL_APPLE_texture_format_BGRA8888":		
						supportsBGRA = BGRADesktop;
						
					#if mobile
					case 	"GL_EXT_texture_format_BGRA8888",
							"GL_IMG_texture_format_BGRA8888", 
							"EXT_texture_format_BGRA8888": 
						supportsBGRA = BGRAExt;
					#end
					
					case "GL_ARB_ES3_compatibility", "ARB_ES3_compatibility":
						supports565 = true;
						supports4444 = true;
						supports5551 = true;
				}
			}
		if ( supportsBGRA != BGRANone) hxd.System.trace1("BGRA support is :" + supportsBGRA);
		
		#if noBGRA
		supportsBGRA = BGRANone;
		#end
		
	}
	
	public function onContextLost(_) {
		hxd.System.trace2("Context lost "+currentContextId+"...waiting restoration ");
	}
	
	/**
	 * Context lost should occur on a real context lost, beware android will trigger some context lost via onSurfaceCreate that could have been onSurfaceChanged 
	 * via the android:configChanges:"screensize" in the manifest.
	 */
	public function onContextRestored(_) {
		hxd.System.trace2("Context restored " + currentContextId + ", do your magic");
		
		currentContextId++;
		if ( currentContextId == 1) {
			return; //lime sends a dummy context lost...
		}
		
		if ( engine != null ) {
			//reset driver context
			shaderCache = new IntMap();
			fboList.reset();
			reset();
			
			//reset engine context
			@:privateAccess engine.onCreate( true );
		}
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
		gl.frontFace( GL.CW );
		gl.enable(GL.SCISSOR_TEST);
		resetMaterials();
		
		resetSwitch++;
		
		engine.textureSwitches = 0;
		
		curBuffer = null;
		curMultiBuffer = null;
		curShader = null;
		if(curTex!=null)
		for( i in 0...curTex.length)
			curTex[i] = null;
			
		gl.useProgram(null);
	}
	
	function resetMaterials() {
		curMatBits = 0x10<<6;
			
		gl.disable(GL.CULL_FACE);
		gl.cullFace(FACES[1]);//one cannot put a cull none setting;
		
		gl.disable(GL.DEPTH_TEST);
		gl.depthFunc(COMPARE[0]);
		gl.depthMask(false);
		
		gl.disable( GL.BLEND );
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
			gl.colorMask((mbits >> 14) & 1 != 0, (mbits >> 14) & 2 != 0, (mbits >> 14) & 4 != 0, (mbits >> 14) & 8 != 0);
			checkError();
		}
		
		curMatBits = mbits;
	}
	
	override function clear( r : Float, g : Float, b : Float, a : Float ) {
		super.clear(r, g, b, a);
		
		#if (android||ios)
		//fix for samsung galaxy tab
		if ( a <= hxd.Math.EPSILON ) a = 1.0001 / 255.0;
		#end
		
		gl.clearColor(r, g, b, a);
		gl.depthMask(true);
		gl.clearDepth(engine.depthClear);
		gl.depthRange(0, 1 );
		
		gl.disable(GL.DEPTH_TEST);
		gl.disable(GL.SCISSOR_TEST);
		
		checkError();
		//always clear depth & stencyl to enable op
		gl.clear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT | GL.STENCIL_BUFFER_BIT);

		gl.enable(GL.SCISSOR_TEST);
		setRenderZone( scissorX, scissorY, scissorW, scissorH );
		
		checkError();
		
	}

	override function begin(frame:Int) {
		reset();
		this.frame = frame;
	}
	
	override function getShaderInputNames() {
		if( curShader.attribsNames == null)
			curShader.attribsNames = curShader.attribs.map(function(t) return t.name );
		return curShader.attribsNames;
	}
	
	override function resize(width, height) {
		#if js
		canvas.width = width;
		canvas.height = height;
		#elseif cpp
		// resize window ?
		#end
		gl.viewport(0, 0, width, height);
		vpWidth = width; vpHeight = height;
		setRenderZone(0,0,-1,-1);
		
		System.trace2("resizing");
	}
	
	inline function getTexMode( t : h3d.mat.Texture ) {
		return (t!=null && t.isCubic) ? GL.TEXTURE_CUBE_MAP : GL.TEXTURE_2D;
	}
	
	override function allocTexture( t : h3d.mat.Texture ) : h3d.impl.Texture {
		return glAllocTexture(t,null);
	}
	
	function glAllocTexture( t : h3d.mat.Texture , pix : hxd.Pixels ) : h3d.impl.Texture {
		var tt = gl.createTexture();
		#if debug
		hxd.System.trace2("Creating texture pointer\n" + tt + haxe.CallStack.toString(haxe.CallStack.callStack()) );
		#end
		checkError();
		
		var isCompressed = t.flags.has( h3d.mat.Data.TextureFlags.Compressed );
		var isMixed =  (pix != null) && pix.isMixed();
		
		if ( !isCompressed && !isMixed ){
			//unnecessary as internal format is not definitive and avoid some draw calls
			//BUT mandatory for framebuffer textures...so do it anyway
			var texMode = getTexMode(t);
			gl.bindTexture(texMode, tt);
			checkError();
			
			var internalFormat =  GL.RGBA;
			var externalFormat =  GL.RGBA;
			
			var byteType = GL.UNSIGNED_BYTE;
			
			if( t.flags.has( NoAlpha ) ) {
				internalFormat =  GL.RGB;
				externalFormat =  GL.RGB;
			}
			
			gl.texImage2D(texMode, 0, internalFormat, t.width, t.height, 0, externalFormat, byteType, null); 	
			
			checkError();
			
			gl.bindTexture(texMode, null);
			checkError();
		}
		
		#if debug
		var cs = haxe.CallStack.callStack();
		System.trace3("allocated " + tt + " " + cs[6]);
		#end
		
		return tt;
	}
	
	override function allocVertex( count : Int, stride : Int , isDynamic = false) : VertexBuffer {
		
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
		//System.trace4("allocIndex");
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

	public var scissorX=0;
	public var scissorY=0;
	
	public var scissorW=-1;
	public var scissorH=-1;
	
	public override function setRenderZone( x : Int, y : Int, width : Int, height : Int ) {
		var tw = curTarget == null ? vpWidth : curTarget.width;
		var th = curTarget == null ? vpHeight : curTarget.height;
		
		if( x == 0 && y == 0 && width < 0 && height < 0 ){
			gl.scissor(0, 0, tw, th);
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

			if( x+width > tw ) width = tw - x;
			if( y+height > th ) height = th - y;
			if( width <= 0 ) { x = 0; width = 1; };
			if( height <= 0 ) { y = 0; height = 1; }; 
			
			gl.scissor(x, th - y - height, width, height);
		}
		
		scissorX = 0;
		scissorY = 0;
		
		scissorW = width;
		scissorH = height;
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
			case GL.FRAMEBUFFER_INCOMPLETE_ATTACHMENT:			"FRAMEBUFFER_INCOMPLETE_ATTACHMENT";
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
 		inline function rm( f : FBO ) {
			fboList.remove(f);
			if( f == curTarget )
				curTarget = null;
		}
		for ( f in fboList) {
			if ( f.color == null ){
				rm( f );
				break;//only remove one per frame stack is not iterable removal safe, and it is sufficient
			}
			
			if ( f.color.isDisposed() ) {
				rm( f );
				
				//hxd.System.trace2('color disposed #' +f.color.id+', disposing fbo');
				
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
		tidyFramebuffers();
		
		if ( tex == null ) {	
			gl.bindRenderbuffer( GL.RENDERBUFFER, null);
			gl.bindFramebuffer( GL.FRAMEBUFFER, null ); 
			gl.viewport( 0, 0, vpWidth, vpHeight);
			
			curTarget = null;
		}
		else {
			var fbo : FBO = null;
			
			for ( f in fboList) {
				if ( f.color == tex ) {
					fbo = f;
					//System.trace3('reusing render target of ${tex.width} ${tex.height}');
					break;
				}
			}
			
			if ( fbo == null) {
				fbo = new FBO();
				fbo.color = tex;
				
				if ( tex.isDisposed()) throw "invalid target texture, not allocated";
					
				fboList.push(fbo);
			}

			//System.trace3('creating fbo');
			if ( fbo.fbo == null ) fbo.fbo = gl.createFramebuffer();
			gl.bindFramebuffer(GL.FRAMEBUFFER, fbo.fbo);
			checkError();
						
			var bw = Math.bitCount(tex.width );
			var bh = Math.bitCount(tex.height );
			
			//System.trace3('allocating render target of ${tex.width} ${tex.height}');
			
			if ( bh > 1 || bw > 1) throw "invalid texture size, must be a power of two texture";
				
			fbo.width = tex.width;
			fbo.height = tex.height;
			
			//bind color
			gl.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, fbo.color.t, 0);
			checkError();
			//bind depth
			if ( useDepth ) {
				//System.trace3("fbo : using depth");
				checkError();
				if ( fbo.rbo == null) {
					fbo.rbo = gl.createRenderbuffer();
				}
				
				gl.bindRenderbuffer( GL.RENDERBUFFER, fbo.rbo);
				checkError();
				
				#if mobile
					gl.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT16, fbo.width, fbo.height);
				#else 
					gl.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT, fbo.width, fbo.height);
				#end
				
				//System.trace3("fbo : allocated " + fbo.rbo);
				checkError();
				
				//System.trace3("fbo : bound rbo" );
				checkError();
				
				gl.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, fbo.rbo);
				
				//System.trace3("fbo : framebufferRenderbuffer rbo" );
				//if( useStencil ) gl.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.STENCIL_ATTACHMENT, GL.RENDERBUFFER, fbo.rbo);
				//System.trace3("fbo : framebufferRenderbuffer" );
				checkError();
			}
			
			//System.trace3("fbo : bindings finished" );
			checkError();
			checkFBO(fbo);
			
			checkError();
			begin(frame);
			checkError();
			
			//System.trace3("fbo : rebinding" );
			
			//ADRENO
			gl.bindFramebuffer(GL.FRAMEBUFFER, fbo.fbo);
			checkError();
			
			if ( clearColor != null) {
				//needed ?
				clear(	Math.b2f(clearColor>> 16),
						Math.b2f(clearColor>> 8),
						Math.b2f(clearColor),
						Math.b2f(clearColor >>> 24));
			}
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
				
			curTarget = fbo;
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
	
	inline function makeMips(t:h3d.mat.Texture){
		gl.hint(GL.GENERATE_MIPMAP_HINT, GL.DONT_CARE);
		gl.generateMipmap(getTexMode(t));
		checkError();
	}
	
	function getPreferredFormat() : hxd.PixelFormat {
		if ( supportsBGRA!=BGRANone ) return BGRA;
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
		/**
		 * Warning if the texture is not registered in mem, problems can ensue...
		 */
		//This should be done sooner
		if ( t.t == null ){
			hxd.System.trace2("suspicious texture allocation required, should be done sooner");
			t.t = glAllocTexture( t , pix);
		}
		
		if( !pix.flags.has(Compressed) )
			uploadTexturePixelsDirect(t, pix, mipLevel, side);
		else 
			uploadTexturePixelsCompressed(t, pix, mipLevel, side);
			
		if ( 	t.flags.has( h3d.mat.Data.TextureFlags.MipMapped ) 
		&&		t.flags.has( h3d.mat.Data.TextureFlags.GenerateMipMap )  )
				makeMips(t);
			
	}
	
	function uploadTexturePixelsCompressed( t : h3d.mat.Texture, pix : hxd.Pixels, mipLevel : Int, side : Int ) {
		var texMode = getTexMode(t);
		gl.bindTexture( texMode, t.t); checkError();
		checkTextureSize( t.width, t.height);
		
		var byteType = GL.UNSIGNED_BYTE;
		var internalFormat = switch(pix.format) {
			case Compressed(glCompressedFormat):glCompressedFormat;
			default: throw "gl format identifier assert";
		}; 
		var pixelBytes = getUints( pix.bytes.bytes, pix.bytes.position,pix.bytes.length );
		
		if( texMode == GL.TEXTURE_2D)
			gl.compressedTexImage2D(	texMode, mipLevel, 
										internalFormat, t.width >> mipLevel, t.height >> mipLevel, 0, 
										pixelBytes );
		else if( texMode == GL.TEXTURE_CUBE_MAP){
			gl.compressedTexImage2D(	GL.TEXTURE_CUBE_MAP_POSITIVE_X + side, mipLevel, 
										internalFormat, t.width >> mipLevel, t.height >> mipLevel, 0, 
										pixelBytes );
		}
		else 
			throw "Unsupported";
		
		checkError();
		gl.bindTexture( texMode, null);
		checkError();
	}
	
	
	function uploadTexturePixelsDirect( t : h3d.mat.Texture, pix : hxd.Pixels, mipLevel : Int, side : Int ) {
		Profiler.begin("uploadTexturePixelsDirect");
		
		var texMode = getTexMode(t);
		gl.bindTexture(texMode, t.t); checkError();
		checkTextureSize( t.width, t.height);
		
		var oldFormat = pix.format;
		var newFormat = getPreferredFormat();
		
		if ( !pix.isMixed() && oldFormat != newFormat ) {
			if ( oldFormat != RGBA ) {
				pix.convert(newFormat);
				#if debug
				System.trace1("WARNING : texture format converted from " + oldFormat + " to " + newFormat + " name:" + t.name);
				#end
			}
			else { 
				newFormat = RGBA;
				#if debug
				System.trace3("keeping texture in format " + oldFormat + " name:" + t.name);
				#end
			}
		}
		else {
			#if debug
			System.trace3("keeping texture in format " + oldFormat + " name:" + t.name);
			#end
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
		
		#if debug
		System.trace3("guessing params");
		#end
		
		if(!pix.isMixed() )
			switch(newFormat) {
				case BGRA: {
					switch (supportsBGRA) {
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
		else {
			var rs = 0, bs = 0, gs = 0, as = 0;
			switch(pix.format) {
				case Mixed(r, g, b, a): rs = r; gs = g; bs = b; as = a;
				default: throw "gl pixel format assert "+ pix.format;
			}
			
			#if true
			//experimental
			if ( as == 0 && rs == 8 && bs == 0 && gs == 0) {
				#if mobile
				internalFormat = GL.LUMINANCE;
				externalFormat = GL.LUMINANCE;
				#else 
				internalFormat = GL_R8;
				externalFormat = GL.LUMINANCE;
				#end
				byteType = GL.UNSIGNED_BYTE;
			} else
			#end
			
			if ( rs == 5 && gs == 6 && bs == 5) {
				#if mobile
				internalFormat = GL.RGB;
				externalFormat = GL.RGB;
				#else 
				internalFormat = GL_RGB565;
				externalFormat = GL.RGB;
				#end
				byteType = GL_UNSIGNED_SHORT_5_6_5;
			} else
			
			if ( rs == 4 && gs == 4 && bs == 4 && as == 4) {
				#if mobile
				internalFormat = GL.RGBA;
				externalFormat = GL.RGBA;
				#else 
				internalFormat = GL_RGBA4;
				externalFormat = GL.RGBA;
				#end
				byteType = GL_UNSIGNED_SHORT_4_4_4_4;
			} else
			
			if ( rs == 5 && gs == 5 && bs == 5 && as == 1 ) {
				#if mobile
				internalFormat = GL.RGBA;
				externalFormat = GL.RGBA;
				#else 
				internalFormat = GL_RGB5_A1;
				externalFormat = GL.RGBA;
				#end
				
				byteType = GL_UNSIGNED_SHORT_5_5_5_1;
			} else 
				throw "mixed format assert";
			
		}
		
		#if false
		inline function hex(e)  return StringTools.hex(e);
		System.trace3('uploaded texture attribs internalFormat:0x${hex(internalFormat)} externalFormat:0x${hex(externalFormat)} t.width:${t.width} t.height:${t.height} texMode:$texMode');
		#end
			
		var pixelBytes = getUints( pix.bytes.bytes, pix.bytes.position, pix.bytes.length);
		
		if( texMode == GL.TEXTURE_2D )
			gl.texImage2D(	texMode, mipLevel, 
							internalFormat, t.width >> mipLevel, t.height >> mipLevel, 0, 
							externalFormat, byteType, pixelBytes);
		else if ( texMode == GL.TEXTURE_CUBE_MAP ) {
			gl.texImage2D(	GL.TEXTURE_CUBE_MAP_POSITIVE_X+side, mipLevel, 
							internalFormat, t.width >> mipLevel, t.height >> mipLevel, 0, 
							externalFormat, byteType, pixelBytes);
		}
		else {
			trace("assertion");
			throw "assert";
		}
		
		gl.bindTexture(texMode, null);
		checkError();
		
		Profiler.end("uploadTexturePixelsDirect");
	}
	
	override function uploadVertexBuffer( v : VertexBuffer, startVertex : Int, vertexCount : Int, buf : hxd.FloatBuffer, bufPos : Int ) {
		var stride : Int = v.stride;
		var buf = buf.getNative();
		var sub = new Float32Array(buf.buffer, bufPos, vertexCount * stride #if cpp * (fixMult?4:1) #end);
		
		if ( debugSendZeroes ) 
			for ( i in 0...sub.length )
				sub[i] = 0.0;
		
		gl.bindBuffer(GL.ARRAY_BUFFER, v.b);
		gl.bufferSubData(GL.ARRAY_BUFFER, startVertex * stride * 4, sub);
		gl.bindBuffer(GL.ARRAY_BUFFER, null);
		curBuffer = null; curMultiBuffer = null;
		checkError();
	}

	override function uploadVertexBytes( v : VertexBuffer, startVertex : Int, vertexCount : Int, buf : haxe.io.Bytes, bufPos : Int ) {
		var stride : Int = v.stride;
		var buf = getUints(buf);
		var sub = getUints(buf.buffer, bufPos, vertexCount * stride * 4);
		gl.bindBuffer(GL.ARRAY_BUFFER, v.b);
		gl.bufferSubData(GL.ARRAY_BUFFER, startVertex * stride * 4, sub);
		gl.bindBuffer(GL.ARRAY_BUFFER, null);
		curBuffer = null; curMultiBuffer = null;
		checkError();
	}

	override function uploadIndexesBuffer( i : IndexBuffer, startIndice : Int, indiceCount : Int, buf : hxd.IndexBuffer, bufPos : Int ) {
		var buf = new Uint16Array(buf.getNative());
		var sub = new Uint16Array(buf.getByteBuffer(), bufPos, indiceCount #if cpp * (fixMult?2:1) #end);
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, i);
		gl.bufferSubData(GL.ELEMENT_ARRAY_BUFFER, startIndice * 2, sub);
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);
	}

	override function uploadIndexesBytes( i : IndexBuffer, startIndice : Int, indiceCount : Int, buf : haxe.io.Bytes , bufPos : Int ) {
		var buf = new Uint8Array(buf.getData());
		var sub = new Uint8Array(buf.getByteBuffer(), bufPos, indiceCount * 2);
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, i);
		gl.bufferSubData(GL.ELEMENT_ARRAY_BUFFER, startIndice * 2, sub);
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);
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
		case GL.SAMPLER_2D:		Tex2d;
		case GL.SAMPLER_CUBE: 	TexCube;
		case GL.FLOAT: 			Float;
		case GL.FLOAT_VEC2:		Vec2;
		case GL.FLOAT_VEC3:		Vec3;
		case GL.FLOAT_VEC4:		Vec4;
		case GL.FLOAT_MAT2:		Mat2;
		case GL.FLOAT_MAT3:		Mat3;
		case GL.FLOAT_MAT4:		Mat4;
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
			code = notgles.map( function(s) return "#if !GL_ES \n\t"+s+" \n #end \n").join('') + code;

			// replace haxe-like #if/#else/#end by GLSL ones
			
			code = ~/#if +(?!defined) *([A-Za-z0-9_]+)/g.replace(code, "#if defined ( $1 ) \n");
			code = ~/#if +(?!defined) *! *([A-Za-z0-9_]+)/g.replace(code, "#if !defined ( $1 ) \n");
			
			code = ~/#elseif +(?!defined) *([A-Za-z0-9_]+)/g.replace(code, "#elif defined ( $1 ) \n");
			code = ~/#elseif +(?!defined) *! *([A-Za-z0-9_]+)/g.replace(code, "#elif !defined ( $1 ) \n");
			
			code = code.split("#end").join("#endif");

			//version should come first
			#if !mobile
				#if mac
				code = "#version 110 \n" + code;
				#else 
				code = "#version 100 \n" + code;
				#end
			#end

			return code;
		}
		
		var vsCode = parseShader(GL.VERTEX_SHADER);
		var fsCode = parseShader(GL.FRAGMENT_SHADER);
					
		fullCode = vsCode+ "\n" + fsCode;
		
		var sig = haxe.crypto.Crc32.make( haxe.io.Bytes.ofString( fullCode ) );
		if ( shaderCache.exists( sig )) {
			//hxd.System.trace4("shader cache hit !");
			return shaderCache.get(sig);
		}
		
		function compileShader(type,code) {
			var s = gl.createShader(type);
			
			gl.shaderSource(s, code);
			
			gl.compileShader(s);
			
			#if (windows && debug && dumpShader)
			//System.trace2("source:"+code);
			var f = sys.io.File.write( "./" + sig + ((type == GL.VERTEX_SHADER) ? ".vsh" : ".fsh"), true);
			code.replace("\n\n", "\n");
			f.writeString( code );
			f.close();
			#end 
			
			var shCode = gl.getShaderParameter(s, GL.COMPILE_STATUS);
			if ( shCode != cast 1 ) {
				System.trace1("a shader error occured !");
				//System.trace1("shader source : \n" + code);
				
				var shlog = try {
					getShaderInfoLog(s, code);
				}catch (d:Dynamic) {
					"cannot retrieve";
				};
				
				throw "An error occurred compiling the " + Type.getClass(shader)  + "\n"
				+ " infolog: " + shlog + "\n"
				+ " gl_err: " + gl.getError() + "\n"
				+ " shader_param_err : "+shCode + "\n"
				+ " code : " + StringTools.htmlEscape(code);
				
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
		
		var vs = compileShader(GL.VERTEX_SHADER,vsCode);
		var fs = compileShader(GL.FRAGMENT_SHADER,fsCode);
		
		var p = gl.createProgram();

		//before doing that we should parse code to check those attrs existence
		gl.bindAttribLocation(p, 0, "pos");
		gl.bindAttribLocation(p, 1, "uv");
		gl.bindAttribLocation(p, 2, "normal");
		gl.bindAttribLocation(p, 3, "color");
		gl.bindAttribLocation(p, 4, "weights");
		gl.bindAttribLocation(p, 5, "indexes");
		
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
		
		var parseUniInfo = new UniformContext( -1, null);
		
		for( k in 0...nuni ) {
			parseUniInfo.inf = new GLActiveInfo( gl.getActiveUniform(p, k) );
			
			if( parseUniInfo.inf.name.substr(0, 6) == "webgl_" ) 	continue; // skip native uniforms
			if( parseUniInfo.inf.name.substr(0, 3) == "gl_" )		continue;
				
			var name = parseUniInfo.inf.name;
			
			var tu = parseUniform(  parseUniInfo, allCode, p );
			if ( tu == null ) continue;
			//skip redundant variables ( ex array of texture that were output as single elements by drivers (adreno)
			
			inst.uniforms.push( tu );
			parseUniInfo.variables.set( tu.name, { } );
		}
		
		#if debug
		System.trace4('shader code : $allCode');
		#end
		
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
	
	inline function findVarComment(str,code){
		var r = new EReg(str + "[ \\t]*\\/\\*([A-Za-z0-9_]+)\\*\\/", "g");
		return 
		if ( r.match(code) )
			r.matched(1);
		else 
			return null;
	}
	
	inline function hasArrayAccess(str,code){
		var r = new EReg("[A-Z0-9_]+[ \t]+" + str + "\\[[a-z](.+?)\\]", "gi");
		return 
		if ( r.match(code) )
			true;
		else false;
	}
	
	
	inline function getUniformArrayLength(name:String, code:String) {
		var r = new EReg("uniform sampler2D " + name+"\\[([0-9]+)\\]", "gi");
		//trace( code);
		if ( r.match( code )) {
			return Std.parseInt( r.matched(1));
		}
		else 
			return -1;
	}
	/**
	 * 
	 * uniform sampler2D textures[8];
	 * textures-> known
	 * 
	 */
	
	function parseUniform(parseUniInfo: UniformContext,allCode,p)
	{
		var inf : GLActiveInfo = parseUniInfo.inf;
		
		var isSubscriptArray = false;
		var t = decodeTypeInt(inf.type);
		var scanSubscript = true;
		var r_array = ~/\[([0-9]+)\]$/g;
		
		switch( t ) {
			case Tex2d, TexCube:{
				var name = inf.name;
				if ( name.indexOf("[") < 0 ) 
					parseUniInfo.texIndex++;
				else {
					var name = name.substr( 0, name.indexOf("["));
					inf.name = name;
					
					if ( parseUniInfo.variables.exists( inf.name ))
						return null;
						
					var arrayLength = getUniformArrayLength(name, allCode);
					#if debug
					System.trace3("texture array len : "+name+" "+arrayLength+" size:"+parseUniInfo.inf.size);
					#end
					parseUniInfo.texIndex += arrayLength;
					t = Elements( inf.name, inf.size, t );
					scanSubscript = false;
				}
			}
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
				}
				
			default:	
		}
		
		//todo refactor all...but it will wait hxsl3

		var name = inf.name;
		while ( scanSubscript ) {
			if ( r_array.match(name) ) { //
				name = r_array.matchedLeft();
				t = Index(Std.parseInt(r_array.matched(1)), t);
				continue;
			}
			
			var c = name.lastIndexOf(".");
			if ( c < 0) {
				c = name.lastIndexOf("[");
			}
			
			if ( c > 0 ) {
				var field = name.substr(c + 1);
				name = name.substr(0, c);
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
			
		if ( shader.instance == null ) {
			shader.instance = buildShaderInstance(shader);
		}

		if ( shader.instance != curShader ) {
			var old = curShader;
			curShader = shader.instance;
			
			if (curShader.program == null) throw "invalid shader";
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
				
			change = true;
		}
			
		
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
			setUniform(val, u, u.type,change);
		}
		
		shader.customSetup(this);
		checkError();
		
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
			
			if ( t != null && t.isDisposed()) {
				if ( t.isDisposed() ) {
					#if debug
					hxd.System.trace3("texture disposed : realloc name:"+t.name);
					#end
					t.realloc();
				}
			
				if ( t.isDisposed() ) {
					#if debug
					hxd.System.trace3("texture not reallocated : allocating default name:"+t.name);
					#end
					t = Tools.getEmptyTexture();
					if (t.isDisposed()){
						t.realloc();
						#if debug
						hxd.System.trace3("empty texture not allocated : reallocating default name:"+t.name);
						#end
					}
				}
			}
			
			if (debugForceTex4x4) {
				t = Tools.getEmptyTexture();
			}
			
			var texMode = getTexMode(t);
			gl.activeTexture(GL.TEXTURE0 + stage);
			gl.bindTexture(texMode, t.t);
			var flags = TFILTERS[Type.enumIndex(mipMap)][Type.enumIndex(filter)];
			gl.texParameteri(texMode, GL.TEXTURE_MAG_FILTER, flags[0]);
			gl.texParameteri(texMode, GL.TEXTURE_MIN_FILTER, flags[1]);
			var w = TWRAP[Type.enumIndex(wrap)];
			gl.texParameteri(texMode, GL.TEXTURE_WRAP_S, w);
			gl.texParameteri(texMode, GL.TEXTURE_WRAP_T, w);
			if ( t.anisotropicLevel > 0 ) 
				gl.texParameteri(texMode, TEXTURE_MAX_ANISOTROPY_EXT, hxd.Math.imin( supportAnisotropic, t.anisotropicLevel) );
			
			checkError();
			curTex[stage] = t;
			
			if ( t != null) t.lastFrame = frame;
			
			engine.textureSwitches++;
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
		if ( !f32Pool.exists(sz) ) 
			f32Pool.set(sz, new Float32Array([for ( i in 0...sz) 0.0]));
			
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
			
		case Tex2d,TexCube:
			var t : h3d.mat.Texture = val;
			if ( t == null)  t = h2d.Tools.getEmptyTexture();
			
			var reuse = setupTexture(t, u.index, t.mipMap, t.filter, t.wrap);
			if ( !reuse || shaderChange ) {
				gl.activeTexture(GL.TEXTURE0 + u.index);
				gl.bindTexture(getTexMode(t),t.t);
				gl.uniform1i(u.loc,  u.index);
				t.lastFrame = frame;
				engine.textureSwitches++;
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
					//if ( nb != null && ms.length != nb)  System.trace3('Array uniform type mismatch $nb requested, ${ms.length} found');
						
					gl.uniformMatrix4fv(u.loc, false, buff = blitMatrices(ms, true) );
					
				case Tex2d,TexCube:
				{
					var textures : Array<h3d.mat.Texture> = val;
					var base = u.index;
					var vid = vidx;
					
					#if debug
					if ( textures.length > 4 ) {
						hxd.System.trace1("ALARM textures array is wayy too lonnng : "+ textures.length);
					}
					#end
					
					for ( i in 0...curTex.length) {
						var t = curTex[i];
						gl.activeTexture(GL.TEXTURE0 + i );
						gl.bindTexture(getTexMode(t), null);
					}
					
					for ( i in 0...textures.length) {
						var t = textures[i];
						
						if ( t == null ) break;
						if ( t.isDisposed())	t.realloc();
						
						var reuse = setupTexture(t, u.index + i, t.mipMap, t.filter, t.wrap);
						if( reuse ){
							gl.activeTexture(GL.TEXTURE0 + u.index+i);
							gl.bindTexture(getTexMode(t), t.t);
							t.lastFrame = frame;
							engine.textureSwitches++;
						}
						vid[i] = u.index + i;
					}
					gl.uniform1iv(u.loc, vid);
					vid = null;
				}
					
				default: 
					trace("unsupported elemtents !");
					throw "not supported";
			}
			if( buff != null)
				deleteF32(buff);
		}
			
		case Index(index, t):
			var v = val[index];
			if ( v == null ) {
				//trace( Type.getClass( val ));
				//trace( Type.getClass( v ));
				throw "Missing shader for index " + index + " of type " + t + " in " + val;
			}
			setUniform(v, u, t, shaderChange);
			
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
		var ob = curBuffer;
		
		curBuffer = v;
		curMultiBuffer = null;
		
		var stride : Int = v.stride;
		if ( ob != v ) {
			gl.bindBuffer(GL.ARRAY_BUFFER, v.b);
			checkError();
		}
		
		//this one is sharde most of the time, let's define it fully
		for ( a in curShader.attribs ) 
			gl.vertexAttribPointer(a.index, a.size, a.etype, false, stride << 2, a.offset << 2);
		
		checkError();
	}
	
	override function selectMultiBuffers( buffers : Array<Buffer.BufferOffset> ) {
		var changed = curMultiBuffer == null || curMultiBuffer.length != buffers.length;
		
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
		#if (cpp&&debug)
		System.trace2( o.toString() + " " + (untyped o.getType()) + " " + Std.string(o.isValid()) );
		hxd.Assert.isTrue(o.isValid());
		#end
	}
	
	override function draw( ibuf : IndexBuffer, startIndex : Int, ntriangles : Int ) {
		//checkObject(ibuf);
		Profiler.begin("drawElements");
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ibuf);
		checkError();
		
		gl.drawElements(GL.TRIANGLES, ntriangles * 3, GL.UNSIGNED_SHORT, startIndex * 2);
		checkError();
		
		gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, null);
		checkError();
		Profiler.end("drawElements");
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
		if ( log == null ) return "getShaderInfoLog() returns null";
		var lines = code.split("\n");
		var index = Std.parseInt(log.substr(9));
		if (index == null) return log;
		index--;
		if ( lines[index] == null ) return log;
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

	//we won't use more than 4
	static var MAX_TEXTURE_IMAGE_UNITS = 4;
	
	override function restoreOpenfl() {
		//cost is 0
		//hxd.Profiler.begin("restoreOpenfl");
		
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
		
		curBuffer = null; 
		curMultiBuffer = null;
		//hxd.Profiler.end("restoreOpenfl");
	}
	
	public var qMaxTexureSize:Int = -1;
	
	public override function query(q:Query) : Dynamic {
		switch(q) {
			case MaxTextureSize: 
				if ( qMaxTexureSize < 0 )
					qMaxTexureSize = gl.getParameter( GL.MAX_TEXTURE_SIZE );
				return qMaxTexureSize;
			case MaxTextureSideSize:
				return query(MaxTextureSize);
		}
	}
	
	var hasSampleAlphaToCoverage :Null<Bool> = null;
	var hasPVRTC1 : Null<Bool> = null;
	var hasS3TC: Null<Bool> = null;
	var hasETC1 : Null<Bool> = null;
	
	public override function hasFeature( f : Feature ) : Bool{
		return
		switch(f) {
			case PVRTC1: 
				if ( hasPVRTC1 == null) {
					hasPVRTC1 = extensions.get("GL_IMG_texture_compression_pvrtc" )!=null;
					hxd.System.trace2("pvrtc support is :" + hasPVRTC1);
				}
				return hasPVRTC1;
				
				
			case S3TC: 
				if ( hasS3TC == null) {
					hasS3TC = extensions.get("GL_EXT_texture_compression_s3tc" )!=null;
					hxd.System.trace2("s3tc support is :" + hasS3TC);
				}
				return hasS3TC;
				
			case ETC1: 
				if ( hasETC1 == null) {
					hasETC1 = extensions.get("GL_OES_compressed_ETC1_RGB8_texture" )!=null;
					hxd.System.trace2("etc support is :" + hasETC1);
				}
				return hasETC1;
				
			case BgraTextures:	supportsBGRA != BGRANone;
			case SampleAlphaToCoverage:
				if ( hasSampleAlphaToCoverage == null ) {
					hasSampleAlphaToCoverage = (gl.getParameter(GL_MULTISAMPLE) == true) || gl.getParameter( GL_SAMPLE_BUFFERS ) >= 1;
					hxd.System.trace2("hasSampleAlphaToCoverage support is :" + hasSampleAlphaToCoverage);
				}
				return hasSampleAlphaToCoverage;
			
			case AnisotropicFiltering:
				return supportAnisotropic > 0;
				
			default:			super.hasFeature(f);
		}
	}
}

#end
