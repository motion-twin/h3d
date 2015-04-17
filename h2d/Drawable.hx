package h2d;
import h3d.Engine;
import h3d.Vector;
import hxd.Profiler;

class DrawableShader extends h3d.impl.Shader {
	#if flash
	public override function clone(?c:h3d.impl.Shader) : h3d.impl.Shader {
		var n : DrawableShader = (c != null) ? cast c :Type.createEmptyInstance( cast Type.getClass(this) );
		super.clone( n );
		return n;
	}
	static var SRC = {
		var input : {
			pos : Float2,
			uv : Float2,
			valpha : Float,
			vcolor : Float4,
		};
		var tuv : Float2;
		var tcolor : Float4;
		var talpha : Float;

		var hasVertexColor : Bool;
		var hasVertexAlpha : Bool;
		var hasFXAA : Bool;
		var uvScale : Float2;
		var uvPos : Float2;
		var zValue : Float;
		var pixelAlign : Bool;
		var texelAlign : Bool;
		var halfPixelInverse 	: Float2;
		var halfTexelInverse	: Float2;
		
		var texResolution 		: Float2;
		var texResolutionFS 	: Float2;
		//var fbResolutionFS		: Float2;

		var fxaaNW 	: Float2;
		var fxaaNE 	: Float2;
		var fxaaSE 	: Float2;
		var fxaaSW 	: Float2;
		
		function mix( x : Float, y : Float, v : Float ) {
			return x * (1.0 - v) + y * v;
		}
		
		function mix3( x : Float3, y : Float3, v : Float ) {
			return [
					mix(x.x, y.x,v),
					mix(x.y, y.y,v),
					mix(x.z, y.z,v)
				];
		}

		function vertex( size : Float3, matA : Float3, matB : Float3 ) {
			var tmp : Float4;
			var spos = input.pos.xyw;
			if( size != null ) spos *= size;
			tmp.x = spos.dp3(matA);
			tmp.y = spos.dp3(matB);
			tmp.z = zValue;
			tmp.w = 1;
			if ( pixelAlign )
				tmp.xy -= halfPixelInverse;
			out = tmp;
			var t = input.uv;
			if( uvScale != null ) t *= uvScale;
			if ( uvPos != null ) t += uvPos;
			if ( texelAlign )
				t.xy += halfTexelInverse;
			tuv = t;
			if ( hasVertexColor ) 
				tcolor = input.vcolor;
			if ( hasVertexAlpha ) 
				talpha = input.valpha;
				
			if ( hasFXAA ) {
				fxaaNW = t + [ -texResolution.x, 	-texResolution.y];
				fxaaNE = t + [ texResolution.x, 	-texResolution.y];
				fxaaSW = t + [ -texResolution.x, 	texResolution.y];
				fxaaSE = t + [ texResolution.x, 	texResolution.y];
			}
		}
		
		var hasAlpha : Bool;
		var killAlpha : Bool;
		
		var alpha : Float;
		var colorAdd : Float4;
		var colorMul : Float4;
		var colorMatrix : M44;

		var hasAlphaMap : Bool = false;
		
		var alphaMap : Texture;
		var alphaUV : Float4;
		var filter : Bool;
		
		var displacementMap    : Texture;
		var hasDisplacementMap : Bool = false;
		var displacementUV     : Float4;
		var displacementAmount : Float;
		
		var sinusDeform : Float3;
		var tileWrap : Bool;

		var hasMultMap : Bool;
		var multMapFactor : Float;
		var multMap : Texture;
		var multUV : Float4;
		var hasColorKey : Bool;
		var colorKey : Int;
		
		var isAlphaPremul:Bool;
		var leavePremultipliedColors:Bool;

		
		function fxaa(tex:Texture, uv:Float2, resolution:Float2, nw:Float2, ne:Float2, sw:Float2, se:Float2) {
			var FXAA_REDUCE_MIN = (1.0 / 128.0);
			var FXAA_REDUCE_MUL = 1.0 / 8.0;
			var FXAA_SPAN_MAX = 8.0;
			
			var cNW = tex.get(nw,linear).xyz;
			var cNE = tex.get(ne,linear).xyz;
			var cSW = tex.get(sw,linear).xyz;
			var cSE = tex.get(se,linear).xyz;
			
			var texColor = tex.get(uv, linear);
			var cM =  texColor.xyz;
			
			var luma = [0.299, 0.587, 0.114];
			
			var lumaNW = dot(cNW, luma);
			var lumaNE = dot(cNE, luma);
			var lumaSW = dot(cSW, luma);
			var lumaSE = dot(cSE, luma);
			var lumaM  = dot(cM,  luma);
			var lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
			var lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
			
			var dir = [
				-((lumaNW + lumaNE) - (lumaSW + lumaSE)),
				((lumaNW + lumaSW) - (lumaNE + lumaSE))];
			
			var dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) *
                          (0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN);
						  
			var rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
			dir = min([FXAA_SPAN_MAX, FXAA_SPAN_MAX],
              max([-FXAA_SPAN_MAX, -FXAA_SPAN_MAX],
              dir * rcpDirMin)) * resolution;
			
			var dax = [(1.0 / 3.0 - 0.5),(1.0 / 3.0 - 0.5)];
			var day = [(2.0 / 3.0 - 0.5),(2.0 / 3.0 - 0.5)];
			var rgbA = 0.5 * ( 
				tex.get( uv + dir * dax	,linear).xyz +
				tex.get( uv + dir * day	,linear).xyz);
				
			var rgbB = rgbA * 0.5 + 0.25 * (
				tex.get(  uv + dir * -0.5	,linear).xyz +
				tex.get(  uv + dir * 0.5	,linear	).xyz);
			var lumB = dot(rgbB, luma);	
			
			var cmp = [lumB, -lumB] >= [lumaMin, -lumaMax];
			var color = mix3(rgbA,rgbB, cmp.x * cmp.y );
			return [color.x, color.y,color.z, texColor.a];
		}
		
		function fragment( tex : Texture ) {
			var tcoord = tuv;
			if (hasDisplacementMap) {
				var dir = displacementMap.get(tcoord * displacementUV.zw - displacementUV.xy);
				tcoord.x += (dir.r * 2.0 - 1.0) * displacementAmount;
				tcoord.y += (dir.g * 2.0 - 1.0) * displacementAmount;
			}
			
			var col:Float4;
			if( !hasFXAA )
				col = tex.get(sinusDeform != null ? [tcoord.x + sin(tcoord.y * sinusDeform.y + sinusDeform.x) * sinusDeform.z, tcoord.y] : tcoord, filter = ! !filter, wrap = tileWrap);
			else
				col = fxaa( tex, tcoord, texResolutionFS, fxaaNW, fxaaNE, fxaaSW, fxaaSE);
			
			if( hasColorKey ) {
				var cdiff = col.rgb - colorKey.rgb;
				kill(cdiff.dot(cdiff) - 0.001);
			}
			if ( killAlpha ) kill(col.a - 0.001);
			
			if ( isAlphaPremul ) 
				col.rgb /= col.a;
			
			if( hasVertexAlpha ) 		col.a *= talpha;
			if( hasVertexColor ) 		col *= tcolor;
			if( hasAlphaMap ) 			col.a *= alphaMap.get(tcoord * alphaUV.zw + alphaUV.xy).r;
			if( hasMultMap ) 			col *= multMap.get(tcoord * multUV.zw + multUV.xy) * multMapFactor;
			if( hasAlpha ) 				col.a *= alpha;
			if( colorMatrix != null ) 	col *= colorMatrix;
			if( colorMul != null ) 		col *= colorMul;
			if( colorAdd != null ) 		col += colorAdd;
			
			if( isAlphaPremul ) 
				col.rgb *= col.a;
				
			if(leavePremultipliedColors)
				col.rgb *= col.a;
			
			out = col;
		}
	}
	
	#elseif (js || cpp)
	
	public override function clone(?c:h3d.impl.Shader) {
		hxd.Profiler.begin("shader clone");
		var cl = Type.getClass(this);
		var n = (c != null) ? (cast c) : Type.createEmptyInstance( cast cl );
		super.clone(n);
		for ( c in Type.getClassFields(cl))
			Reflect.setField( n, c, Reflect.getProperty( this, c ));
		hxd.Profiler.end("shader clone");
		return n;
	}
	
	// not supported
	public var sinusDeform : h3d.Vector;
	
	//meaningless should migrate to Coverage API
	public var hasColorKey(default,set) : Bool;			public function set_hasColorKey(v)		{ if( hasColorKey != v ) 	invalidate();  return hasColorKey = v; }
		
	public var filter : Bool;				
	
	public var tileWrap : Bool;	        
	public var killAlpha(default, set) : Bool;	        
	
	public function set_killAlpha(v) {
		if ( killAlpha != v ) invalidate();  
		return killAlpha = v; 
	}
	
	public var hasAlpha(default, set) : Bool;	       
	public function set_hasAlpha(v)	{
		if ( hasAlpha != v ) 		
			invalidate(); 
		return hasAlpha = v; 
	}
	
	public var hasVertexAlpha(default,set) : Bool;	    public function set_hasVertexAlpha(v)		{ if( hasVertexAlpha != v ) 	invalidate();  	return hasVertexAlpha = v; }
	public var hasVertexColor(default,set) : Bool;	    public function set_hasVertexColor(v)		{ if( hasVertexColor != v ) 	invalidate();  	return hasVertexColor = v; }
	public var hasAlphaMap(default,set) : Bool;	        public function set_hasAlphaMap(v)			{ if( hasAlphaMap != v ) 		invalidate();  	return hasAlphaMap = v; }
	public var hasMultMap(default,set) : Bool;	        public function set_hasMultMap(v)			{ if( hasMultMap != v ) 		invalidate();  	return hasMultMap = v; }
	public var isAlphaPremul(default, set) : Bool;      public function set_isAlphaPremul(v)		{ if( isAlphaPremul != v ) 		invalidate();  	return isAlphaPremul = v; }
	public var hasDisplacementMap(default,set) : Bool;	public function set_hasDisplacementMap(v)	{ if( hasDisplacementMap != v ) invalidate();  	return hasDisplacementMap = v; }
	public var hasFXAA(default,set) : Bool;				public function set_hasFXAA(v)				{ if( hasFXAA != v ) invalidate();  			return hasFXAA = v; }
	
	public var leavePremultipliedColors(default, set) : Bool = false;   
	public function set_leavePremultipliedColors(v)	{
		if ( leavePremultipliedColors != v ) invalidate(); 
		return leavePremultipliedColors = v; 
	}
		
	/**
	 * This is the constant set, they are set / compiled for first draw and will enabled on all render thereafter
	 * 
	 */
	override function getConstants( vertex : Bool ) {
		var engine = h3d.Engine.getCurrent();
		
		var cst = [];
		if( vertex ) {
			if( size != null ) cst.push("#define hasSize");
			if( uvScale != null ) cst.push("#define hasUVScale");
			if( uvPos != null ) cst.push("#define hasUVPos");
		} else {
			if ( killAlpha ) cst.push("#define killAlpha");
			if( hasColorKey ) cst.push("#define hasColorKey");
			if( hasAlpha ) cst.push("#define hasAlpha");
			if( colorMatrix != null ) cst.push("#define hasColorMatrix");
			if( colorMul != null ) cst.push("#define hasColorMul");
			if( colorAdd != null ) cst.push("#define hasColorAdd");
		}
		if( hasVertexAlpha ) 	cst.push("#define hasVertexAlpha");
		if( hasVertexColor ) 	cst.push("#define hasVertexColor");
		if( hasAlphaMap ) 		cst.push("#define hasAlphaMap");
		if( hasMultMap ) 		cst.push("#define hasMultMap");
		if( isAlphaPremul ) 	cst.push("#define isAlphaPremul");
		if( hasDisplacementMap ) cst.push("#define hasDisplacementMap");
		
		if( hasFXAA )cst.push("#define hasFXAA");
		
		if ( textures != null ) {
			cst.push("#define hasSamplerArray");
			
			if ( textures[1] != null ) cst.push("#define hasSamplerArray2");
			if ( textures[2] != null ) cst.push("#define hasSamplerArray3");
			if ( textures[3] != null ) cst.push("#define hasSamplerArray4");
		}
		
		if ( leavePremultipliedColors ) cst.push( "#define leavePremultipliedColors");
		
		return cst.join("\n");
	}
	
	public function setTextures(v) { 
		if ( 	(textures != null && v == null)
		||		(textures == null && v != null))
			invalidate();
		
		return textures = v;
	}
	
	static var VERTEX = "
	
		attribute vec2 pos;
		attribute vec2 uv;
		
		#if hasVertexAlpha
		attribute float valpha;
		varying lowp float talpha;
		#end
		
		#if hasVertexColor
		attribute vec4 vcolor;
		varying lowp vec4 tcolor;
		#end
		
		#if hasSamplerArray
		attribute vec4 textureSources;
		varying vec4 ttextureSources;
		#end
		
        #if hasSize
		uniform vec3 size;
		#end
		uniform vec3 matA;
		uniform vec3 matB;
		uniform float zValue;
		
        #if hasUVPos
		uniform vec2 uvPos;
		#end
        #if hasUVScale
		uniform vec2 uvScale;
		#end
		
		#if hasFXAA
		uniform vec2 texResolution;
		varying lowp vec2 fxaaNW;
		varying lowp vec2 fxaaNE;
		varying lowp vec2 fxaaSE;
		varying lowp vec2 fxaaSW;
		#end
		
		varying vec2 tuv;

		void main(void) {
			vec3 spos = vec3(pos.x,pos.y, 1.0);
			#if hasSize
				spos = spos * size;
			#end
			vec4 tmp;
			tmp.x = dot(spos,matA);
			tmp.y = dot(spos,matB);
			tmp.z = zValue;
			tmp.w = 1.;
			gl_Position = tmp;
			lowp vec2 t = uv;
			#if hasUVScale
				t *= uvScale;
			#end
			#if hasUVPos
				t += uvPos;
			#end
			tuv = t;
			#if hasVertexAlpha
				talpha = valpha;
			#end
			#if hasVertexColor
				tcolor = vcolor;
			#end
			
			#if hasSamplerArray
			ttextureSources = textureSources;
			#end
			
			#if hasFXAA 
			fxaaNW = tuv + vec2(-texResolution.x, 	-texResolution.y);
			fxaaNE = tuv + vec2(texResolution.x, 	-texResolution.y);
			fxaaSW = tuv + vec2(-texResolution.x, 	texResolution.y);
			fxaaSE = tuv + vec2(texResolution.x, 	texResolution.y);
			#end
		}

	";
	
	static var FRAGMENT = "
	
		varying vec2 tuv;
		
		#if hasSamplerArray
		varying vec4 ttextureSources;
		uniform sampler2D textures[4];
		#else
		uniform sampler2D tex;
		#end
		
		#if hasVertexAlpha
		varying float talpha;
		#end
		
		#if hasVertexColor
		varying vec4 tcolor;
		#end
		
		#if hasAlphaMap
			uniform vec4 alphaUV;
			uniform sampler2D alphaMap;
		#end
		
		#if hasMultMap
			uniform float multMapFactor;
			uniform vec4 multUV;
			uniform sampler2D multMap;
		#end
		
		#if hasDisplacementMap
			uniform sampler2D displacementMap;
			uniform float displacementAmount;
			uniform vec4 displacementUV;
		#end
		
		#if hasFXAA
		uniform vec2 texResolutionFS;
		varying lowp vec2 fxaaNW;
		varying lowp vec2 fxaaNE;
		varying lowp vec2 fxaaSE;
		varying lowp vec2 fxaaSW;
		
		vec4 fxaa( sampler2D tex, vec2 uv, vec2 resolution, vec2 nw, vec2 ne, vec2 sw, vec2 se) {
			float FXAA_REDUCE_MIN = (1.0 / 128.0);
			float FXAA_REDUCE_MUL = 1.0 / 8.0;
			float FXAA_SPAN_MAX = 8.0;
			
			vec3 rgbNW = texture2D(tex, nw).xyz;
			vec3 rgbNE = texture2D(tex, ne).xyz;
			vec3 rgbSW = texture2D(tex, sw).xyz;
			vec3 rgbSE = texture2D(tex, se).xyz;
			vec4 texColor = texture2D(tex, uv);
			vec3 rgbM  = texColor.xyz;
			vec3 luma = vec3(0.299, 0.587, 0.114);
			float lumaNW = dot(rgbNW, luma);
			float lumaNE = dot(rgbNE, luma);
			float lumaSW = dot(rgbSW, luma);
			float lumaSE = dot(rgbSE, luma);
			float lumaM  = dot(rgbM,  luma);
			float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
			float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
			mediump vec2 dir;
			dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
			dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));
			
			float dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) *
								  (0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN);
			
			float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
			dir = min(vec2(FXAA_SPAN_MAX, FXAA_SPAN_MAX),
					  max(vec2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),
			dir * rcpDirMin)) * resolution;
			
			vec3 rgbA = 0.5 * (
				texture2D(tex, uv + dir * (1.0 / 3.0 - 0.5)).xyz +
				texture2D(tex, uv + dir * (2.0 / 3.0 - 0.5)).xyz);
			vec3 rgbB = rgbA * 0.5 + 0.25 * (
				texture2D(tex, uv + dir * -0.5).xyz +
				texture2D(tex, uv + dir * 0.5).xyz);

			float lumaB = dot(rgbB, luma);
			
			vec4 color;
			if ((lumaB < lumaMin) || (lumaB > lumaMax))
				color = vec4(rgbA, texColor.a);
			else
				color = vec4(rgbB, texColor.a);
			return color;
		}
		#end
		
		uniform float alpha;
		uniform vec3 colorKey/*byte4*/;
	
		uniform vec4 colorAdd;
		uniform vec4 colorMul;
		uniform mat4 colorMatrix;

		void main(void) {
			vec2 tcoord = tuv;
			
			#if hasDisplacementMap
				lowp vec2 dir = texture2D(displacementMap, tcoord * displacementUV.zw - displacementUV.xy ).xy;
				tcoord += (dir * vec2(2.0) - vec2(1.0)) * vec2(displacementAmount);
			#end
			
			#if hasSamplerArray
				vec4 col 	= ttextureSources.x * texture2D(textures[0], tcoord).rgba
				#if hasSamplerArray2
				+ ttextureSources.y * texture2D(textures[1], tcoord).rgba
				#end
				#if hasSamplerArray3
				+ ttextureSources.z * texture2D(textures[2], tcoord).rgba
				#end
				#if hasSamplerArray4
				+ ttextureSources.w * texture2D(textures[3], tcoord).rgba
				#end
				;
			#else
				#if hasFXAA
				vec4 col = fxaa( tex,tcoord,texResolutionFS,fxaaNW, fxaaNE, fxaaSW, fxaaSE);
				#else 
				vec4 col = texture2D(tex, tcoord).rgba;
				#end
			#end
			
			#if killAlpha
				if( col.a - 0.001 <= 0.0 ) discard;
			#end
			
			#if hasColorKey
				vec3 dc = col.rgb - colorKey;
				if( dot(dc, dc) < 0.001 ) discard;
			#end
			
			#if isAlphaPremul
				col.rgb /= col.a;
			#end 
			
			#if hasVertexAlpha
				col.a *= talpha;
			#end 
			
			#if hasVertexColor
				col *= tcolor;
			#end
			
			#if hasAlphaMap
				col.a *= texture2D( alphaMap, tcoord * alphaUV.zw + alphaUV.xy ).r;
			#end
			
			#if hasMultMap
				col *= multMapFactor * texture2D(multMap,tcoord * multUV.zw + multUV.xy);
			#end
			
			#if hasAlpha
				col.a *= alpha;
			#end
			#if hasColorMatrix
				col *= colorMatrix;
			#end
			#if hasColorMul
				col *= colorMul;
			#end
			#if hasColorAdd
				col += colorAdd;
			#end
			
			#if isAlphaPremul
				col.rgb *= col.a;
			#end 
			
			#if leavePremultipliedColors
				col.rgb *= col.a;
			#end 
			
			gl_FragColor = col;
		}
			
	";
	
	#end
}

class Drawable extends Sprite {
	
	public static inline var HAS_SIZE = 1;
	public static inline var HAS_UV_SCALE = 2;
	public static inline var HAS_UV_POS = 4;
	public static inline var BASE_TILE_DONT_CARE = 8;

	public var shader(default,null) : DrawableShader;
	
	//public var alpha(get, set) : Float;
	
	public var filter(get, set) : Bool;
	public var color(get, set) : h3d.Vector;
	public var colorAdd(get, set) : h3d.Vector;
	
	/*
	 * rr gr br ar
	 * rg gg bg ag
	 * rb gb bb ab
	 * ra ga ba aa
	 * for offsets ( the fifth vector of flash matrix 45 transform use the colorAdd )
	*/
	public var colorMatrix(get, set) : h3d.Matrix;
	
	public var blendMode(default, set) : BlendMode;
	
	public var sinusDeform(get, set) : h3d.Vector;
	
	/**
	 * Sets the uv of the alphamap point to sample, beware format is u,v,u2-u, v2-v
	 * ...i think...
	 */
	public var alphaUV(default,set) : h3d.Vector;
	
	public var tileWrap(get, set) : Bool;
	
	public var killAlpha(default, set) : Bool;
	
	public var alphaMap(default, set) : h2d.Tile;
	public var alpha(get, set) : Float;
	
	public var displacementMap(default, set) : h2d.Tile;
	public var displacementPos : h3d.Vector;
	public var displacementAmount : Float = 1/255;

	public var multiplyMap(default, set) : h2d.Tile;
	public var multiplyFactor(get, set) : Float;
	
	public var colorKey(get, set) : Int;
	
	public var writeAlpha : Bool;
	
	public var textures : Array<h3d.mat.Texture>;
	public var emit : Bool;
	
	public static var DEFAULT_EMIT = false;
	public static var DEFAULT_FILTER = false;

	
	/**
	 * Passing in a similar shader will vastly improve performances
	 */
	function new(parent, ?sh:DrawableShader) {
		super(parent);
		
		writeAlpha = true;
		blendMode = Normal;
		
		shader = (sh == null) ? new DrawableShader() : cast sh;
		shader.alpha = 1.0;
		shader.multMapFactor = 1.0;
		shader.zValue = 0;
		filter = DEFAULT_FILTER;
		shader.texResolution 	= new h3d.Vector(0, 0, 0, 0);
		shader.texResolutionFS 	= new h3d.Vector(0, 0, 0, 0);
		
		#if flash
		shader.pixelAlign = true;
		shader.texelAlign = true;
		shader.halfPixelInverse = new h3d.Vector(0, 0, 0, 0);
		shader.halfTexelInverse = new h3d.Vector(0, 0, 0, 0);
		#end
		
		emit = DEFAULT_EMIT;		
	}

	public override function clone<T>( ?s:T ) : T {
		if ( s == null ) {
			var cl : Class<T> = cast Type.getClass(this);
			throw "impossible hierarchy cloning. Cloning not yet implemented for " + Std.string(cl);
		}
			
		var d : Drawable = cast s;
		
		d.blendMode = blendMode;
		d.color = color;
		d.colorAdd = colorAdd;
		d.colorMatrix = colorMatrix;
		d.filter = filter;
		d.hasAlpha = hasAlpha;
		d.killAlpha = killAlpha;
		d.colorKey = colorKey;
		//todo support others
		return cast d;
	}
	
	
	public var hasAlpha(get, set):Bool;				
	function get_hasAlpha() return shader.hasAlpha; 
	function set_hasAlpha(v) {
		var ov = shader.hasAlpha;
		if ( ov != v ) shader.invalidate();
		return shader.hasAlpha = v;
	}
	
		//does nothing on glsl yet
	public var hasFXAA(get, set) : Bool;
	
	function get_hasFXAA() return shader.hasFXAA; 
	function set_hasFXAA(v) {
		var ov = shader.hasFXAA;
		if ( ov != v ) shader.invalidate();
		return shader.hasFXAA = v;
	}
	
	function get_alpha() : Float return shader.alpha;
	function set_alpha( v : Float ) : Float{
		shader.alpha = v;
		set_hasAlpha( v < 1.0 );
		return v;
	}
	
	function set_blendMode(b) {
		blendMode = b;
		return b;
	}
	
	inline function get_multiplyFactor() 	return shader.multMapFactor;
	inline function set_multiplyFactor(v) 	return shader.multMapFactor = v;
	inline function get_sinusDeform() 		return shader.sinusDeform;
	inline function set_sinusDeform(v) 		return shader.sinusDeform = v;
	
	function set_multiplyMap(t:h2d.Tile) {
		multiplyMap = t;
		shader.hasMultMap = t != null;
		return t;
	}
	
	function set_alphaMap(t:h2d.Tile) {
		if( t != null && alphaMap == null 
		||	t == null && alphaMap != null )
			shader.invalidate();
		
		alphaMap = t;
		shader.hasAlphaMap = t != null;
		
		if ( t == null) { //clean a bit
			alphaUV = null;
			shader.alphaUV = null;
		}
		
		return t;
	}

	inline function set_alphaUV(v) {
		alphaUV=v;
		return v;
	}
	
	function set_displacementMap(t:h2d.Tile) {
		if( t != null && displacementMap == null 
		||	t == null && displacementMap != null )
			shader.invalidate();
		
		displacementMap = t;
		shader.hasDisplacementMap = t != null;
		
		if ( t == null) {
			displacementPos = null;
			shader.displacementUV = null;
		}
		
		return t;
	}
	
	function get_colorMatrix()	return shader.colorMatrix;
	function set_colorMatrix(m) {
		
		if ( 	shader.colorMatrix == null && m != null 
		||		shader.colorMatrix != null && m == null )
			shader.invalidate();
			
		return shader.colorMatrix = m;
	}
	
	function set_color(m:h3d.Vector) : h3d.Vector{
		
		if ( 	shader.colorMul == null && m != null 
		||		shader.colorMul != null && m == null )
			shader.invalidate();
			
		return shader.colorMul = m;
	}

	function set_colorAdd(m) {
		
		if ( 	shader.colorAdd == null && m != null 
		||		shader.colorAdd != null && m == null )
			shader.invalidate();
			
		return shader.colorAdd = m;
	}

	function get_colorAdd() {
		return shader.colorAdd;
	}
	
	function get_color() {
		return shader.colorMul;
	}	

	function get_filter() {
		return shader.filter;
	}
	
	function set_filter(v) {
		return shader.filter = v;
	}

	function get_tileWrap() {
		return shader.tileWrap;
	}
	
	function set_tileWrap(v) {
		return shader.tileWrap = v;
	}

	function set_killAlpha(v) {
		if ( hasSampleAlphaToCoverage() && blendMode == None) {
			return this.killAlpha = v;
		}
		else {
			return this.killAlpha = shader.killAlpha = v;
		}
	}

	function get_colorKey() {
		return shader.colorKey;
	}
	
	function set_colorKey(v) {
		shader.hasColorKey = true;
		return shader.colorKey = v;
	}
	
	static var tmpColor = h3d.Vector.ONE.clone();
	
	function emitTile( ctx : h2d.RenderContext, tile : Tile ) {
		var tile = tile == null ? h2d.Tools.getEmptyTile() : tile;
		
		tmpColor.load(this.color == null ? h3d.Vector.ONE : this.color);
		var color = tmpColor;
		color.a *= alpha;
		var texSlot = ctx.beginDraw(this, tile.getTexture() );
		
		var ax = absX + tile.dx * matA + tile.dy * matC;
		var ay = absY + tile.dx * matB + tile.dy * matD;
		
		#if flash 
		ax -= 0.5 * ctx.engine.width;
		ay -= 0.5 * ctx.engine.height;
		#end
		
		var u = tile.u;
		var v = tile.v;
		var u2 = tile.u2;
		var v2 = tile.v2;
		var tw = tile.width;
		var th = tile.height;
		var dx1 = tw * matA;
		var dy1 = tw * matB;
		var dx2 = th * matC;
		var dy2 = th * matD;

		ctx.emitVertex( 
			ax, ay, u, v,
			color, texSlot);
		
		ctx.emitVertex( 
			ax + dx1,
			ay + dy1,
			u2, v,
			color,
			texSlot);

		ctx.emitVertex( 
			ax + dx2,
			ay + dy2,
			u, v2,
			color,
			texSlot);

		ctx.emitVertex( 
			ax + dx1 + dx2,
			ay + dy1 + dy2,
			u2, v2,
			color, texSlot);
	}
	
	function drawTile( ctx:RenderContext, tile ) {
		ctx.flush();
		shader.hasVertexColor = false;
		setupShader(ctx.engine, tile, HAS_SIZE | HAS_UV_POS | HAS_UV_SCALE);
		ctx.engine.renderQuadBuffer(Tools.getCoreObjects().planBuffer);
	}
	
	//@:noDebug
	function setupShader( engine : h3d.Engine, tile : h2d.Tile, options : Int ) {
		var core = Tools.getCoreObjects();
		var shader = shader;
		var mat = core.tmpMaterial;
		
		if ( tile == null ) 
			tile = core.getEmptyTile();

		var tex : h3d.mat.Texture = tile.getTexture();
		var isTexPremul = false;
		if( tex!=null){
			tex.filter = (filter)? Linear:Nearest;
			isTexPremul  = tex.flags.has(AlphaPremultiplied);
		}
		
		if ( blendMode != None && killAlpha) 
			shader.killAlpha = killAlpha;
		
		switch( blendMode ) {
			case Normal:
				mat.blend(isTexPremul ? One : SrcAlpha, OneMinusSrcAlpha);
				
			case None:
				mat.blend(One, Zero);
				mat.sampleAlphaToCoverage = false;
				if( killAlpha ){
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
		
		#if sys
		switch( blendMode ) {
			default:			shader.leavePremultipliedColors = false;
			case SoftOverlay:	shader.leavePremultipliedColors = true;
		}
		#end

		if( options & HAS_SIZE != 0 ) {
			var tmp = core.tmpSize;
			tmp.x = tile.width;
			tmp.y = tile.height;
			tmp.z = 1;
			shader.size = tmp;
		}
		
		if( options & HAS_UV_POS != 0 ) {
			core.tmpUVPos.x = tile.u;
			core.tmpUVPos.y = tile.v;
			
			shader.uvPos = core.tmpUVPos;
		}
		
		if( options & HAS_UV_SCALE != 0 ) {
			core.tmpUVScale.x = tile.u2 - tile.u;
			core.tmpUVScale.y = tile.v2 - tile.v;
			
			shader.uvScale = core.tmpUVScale;
		}
		
		if( shader.hasAlphaMap ) {
			shader.alphaMap = alphaMap.getTexture();
			
			if ( alphaUV == null ) {
				if ( shader.alphaUV == null ) shader.alphaUV = new Vector(0, 0, 1, 1);
				shader.alphaUV.set(alphaMap.u, alphaMap.v, (alphaMap.u2 - alphaMap.u) / tile.u2, (alphaMap.v2 - alphaMap.v) / tile.v2);
			}
			else {
				if ( shader.alphaUV == null ) shader.alphaUV = new Vector(0, 0, 1, 1);
				shader.alphaUV.load(alphaUV);
			}
		}

		if( shader.hasMultMap ) {
			shader.multMap = multiplyMap.getTexture();
			shader.multUV = new h3d.Vector(multiplyMap.u, multiplyMap.v, (multiplyMap.u2 - multiplyMap.u) / tile.u2, (multiplyMap.v2 - multiplyMap.v) / tile.v2);
		}
		
		if ( shader.hasDisplacementMap ) { 
			shader.displacementMap    = displacementMap.getTexture();
			shader.displacementAmount = displacementAmount;
			
			if (displacementPos == null)
				displacementPos = new Vector(0, 0, 0, 1);
			
			var dm = displacementMap;
			if ( shader.displacementUV == null ) shader.displacementUV = new Vector();
			shader.displacementUV.set(
				dm.u + (dm.dx / dm.width ) + (displacementPos.x / dm.width), 
				dm.v + (dm.dy / dm.height) + (displacementPos.y / dm.height), 
				(dm.u2 - dm.u) * tile.width / dm.width, 
				(dm.v2 - dm.v) * tile.height / dm.height);
		}
		
		var cm = writeAlpha ? 15 : 7;
		if( mat.colorMask != cm ) mat.colorMask = cm;
		
		var tmp = core.tmpMatA;
		tmp.x = matA;
		tmp.y = matC;
		
		if ( options & BASE_TILE_DONT_CARE!=0 ) tmp.z = absX;
		else tmp.z = absX + tile.dx * matA + tile.dy * matC;
		
		shader.matA = tmp;
		var tmp = core.tmpMatB;
		tmp.x = matB;
		tmp.y = matD;
		
		if ( options & BASE_TILE_DONT_CARE!=0 )	tmp.z = absY
		else 									tmp.z = absY + tile.dx * matB + tile.dy * matD;
		
		shader.texResolution.x = 1.0 / tex.width;
		shader.texResolution.y = 1.0 / tex.height;
		shader.texResolutionFS.load( shader.texResolution);
		
		//var tgt =  engine.getTarget();
		//shader.fbResolutionFS.x = tgt != null ? tgt.width : engine.width;
		//shader.fbResolutionFS.y = tgt != null ? tgt.height : engine.height;
		
		#if flash
		shader.pixelAlign = false;
		shader.halfPixelInverse.x = 0.5 / engine.width;
		shader.halfPixelInverse.y = 0.5 / engine.height;
		
		shader.texelAlign = false;
		shader.halfTexelInverse.x = -0.5 / tex.width;
		shader.halfTexelInverse.y = -0.5 / tex.height;
		#end
		
		shader.matB = tmp;
		shader.tex = tile.getTexture();
		
		shader.isAlphaPremul = tex.flags.has(AlphaPremultiplied)
		&& (shader.hasAlphaMap || shader.hasAlpha || shader.hasMultMap 
		|| shader.hasVertexAlpha || shader.hasVertexColor 
		|| shader.colorMatrix != null || shader.colorAdd != null
		|| shader.colorMul != null );
		
		mat.shader = shader;
		engine.selectMaterial(mat);
	}
	
	/**
	 * isExoticShader means shader it too complex and we haven't made the work to make either shader parameter flushing or inlined the parameter in the vertex buffers
	 */
	public function isExoticShader() {
		return shader.hasMultMap 
		|| shader.hasAlphaMap 
		|| shader.hasColorKey 
		|| shader.colorMatrix != null 
		|| shader.colorAdd != null 
		|| shader.hasMultMap
		|| shader.hasDisplacementMap
		|| shader.hasFXAA;
	}

	inline function hasSampleAlphaToCoverage() return h3d.Engine.getCurrent().driver.hasFeature( SampleAlphaToCoverage );
	
	public inline function canEmit() {
		#if (flash||noEmit)
			return false;
		#else
		if ( isExoticShader() || ! emit)	return false;
		else  								return true;
		#end
	}
	
}
