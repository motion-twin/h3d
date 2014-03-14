package h2d;

import h2d.CachedBitmap;
import h2d.Drawable;
import h2d.Drawable.*;
import h2d.RenderContext;
import h3d.anim.Animation;
import h3d.impl.Shader;
import h3d.mat.Texture;
import h3d.Vector;

enum BlurMethod {
	Gaussian3x3OnePass;//high qualit, not so slow but can disrupt gpu
	Gaussian5x1TwoPass;//grainy blurry, fast
	Gaussian7x1TwoPass;//nice blur, slower
	Scale( factor : Int , filtered : Bool); // will scale the render target by factor and upscale using filtering (or not), SUPER FAST
	// factor should start at 2 and up
}

/**
 * todo add blurring to the drawavble shader, anyway it will be wasted for heaps so dont do it
 */
class BlurredDrawableShader extends Shader {
	
	
	#if flash
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
		var uvScale : Float2;
		var uvPos : Float2;
		var skew : Float;
		var zValue : Float;

		function vertex( size : Float3, matA : Float3, matB : Float3 ) {
			var tmp : Float4;
			var spos = input.pos.xyw;
			if( size != null ) spos *= size;
			tmp.x = spos.dp3(matA);
			tmp.y = spos.dp3(matB);
			tmp.z = zValue;
			tmp.w = skew != null ? 1 - skew * input.pos.y : 1;
			out = tmp;
			var t = input.uv;
			if( uvScale != null ) t *= uvScale;
			if( uvPos != null ) t += uvPos;
			tuv = t;
			if( hasVertexColor ) tcolor = input.vcolor;
			if( hasVertexAlpha ) talpha = input.valpha;
		}
		
		var hasAlpha : Bool;
		var killAlpha : Bool;
		
		var alpha : Float;
		var colorAdd : Float4;
		var colorMul : Float4;
		var colorMatrix : M44;
		var colorSet : Float4;
	
		var colorSetPreserveAlpha : Bool;
		var hasAlphaMap : Bool;
		var alphaMap : Texture;
		var alphaUV : Float4;
		var filter : Bool;
		
		var sinusDeform : Float3;
		var tileWrap : Bool;

		var hasMultMap : Bool;
		var multMapFactor : Float;
		var multMap : Texture;
		var multUV : Float4;
		var hasColorKey : Bool;
		var colorKey : Int;
		var u_Scale:Float2;
		
		var useGaussian7x1TwoPass:Bool;
		var useGaussian5x1TwoPass:Bool;
		var useGaussian3x3OnePass:Bool;
		var useScale : Bool;
		
		function getCol(tex:Texture, tuv:Float2) {
			return tex.get(sinusDeform != null ? [tuv.x + sin(tuv.y * sinusDeform.y + sinusDeform.x) * sinusDeform.z, tuv.y] : tuv, filter = ! !filter, wrap = tileWrap);
		}
		
		function fragment( tex : Texture ) {
			var col = [0, 0, 0, 0];
			if( useGaussian7x1TwoPass){
				col += 0.015625 * 		getCol(tex,	[tuv.x +  -3 * u_Scale.x, 	tuv.y + u_Scale.y * -3 ]);
				col += 0.09375 	*		getCol(tex, [tuv.x +  -2* u_Scale.x,	tuv.y + u_Scale.y * -2 ]);
				col += 0.234375 * 		getCol(tex,	[tuv.x +  -1* u_Scale.x, 	tuv.y + u_Scale.y * -1 ]);
					   
				col += 0.3125 	*	 	getCol(tex, [tuv.x , 					tuv.y ]	);
					   
				col += 0.234375 * 		getCol(tex,	[tuv.x +  1 * u_Scale.x, 	tuv.y + u_Scale.y * 1 ]);
				col += 0.09375 * 		getCol(tex,	[tuv.x +  2 * u_Scale.x, 	tuv.y + u_Scale.y * 2 ]);
				col += 0.015625 * 		getCol(tex,	[tuv.x +  3 * u_Scale.x, 	tuv.y + u_Scale.y * 3 ]);
			}
			
			if( useGaussian5x1TwoPass){
				col += 0.204164 * 		getCol(tex,	[tuv.x +  u_Scale.x			, 	tuv.y + u_Scale.y  ]);
				col += 0.304005 *		getCol(tex, [tuv.x +  1.407333 * u_Scale.x	,	tuv.y + u_Scale.y * 1.407333 ]);
				col += 0.304005 * 		getCol(tex,	[tuv.x +  -1.407333 * u_Scale.x	, 	tuv.y + u_Scale.y *  -1.407333 ]);
				col += 0.093913 *	 	getCol(tex, [tuv.x +  3.294215  * u_Scale.x	, 	tuv.y + u_Scale.y * 3.294215 ]	);
				col += 0.093913 * 		getCol(tex,	[tuv.x +  -3.294215  * u_Scale.x, 	tuv.y + u_Scale.y * -3.294215 ]);
			}
			
			if( useGaussian3x3OnePass){
				col += 0.00078633 * getCol(tex,	[tuv.x + -2*u_Scale.x, 	tuv.y + 2 * u_Scale.y  ]);
				col += 0.00655965 * getCol(tex,	[tuv.x + -u_Scale.x, 	tuv.y + 2 * u_Scale.y  ]);
				col += 0.01330373 * getCol(tex,	[tuv.x  			, 	tuv.y + 2 * u_Scale.y  ]);
				col += 0.00655965 * getCol(tex,	[tuv.x + u_Scale.x, 	tuv.y + 2 * u_Scale.y  ]);
				col += 0.00078633 * getCol(tex,	[tuv.x + 2*u_Scale.x, 	tuv.y + 2 * u_Scale.y  ]);
				
				
				col += 0.00655965* getCol(tex,	[tuv.x + -2*u_Scale.x, 	tuv.y + u_Scale.y  ]);
				col += 0.05472157* getCol(tex,	[tuv.x + -u_Scale.x, 	tuv.y + u_Scale.y  ]);
				col += 0.11098164* getCol(tex,	[tuv.x , 				tuv.y + u_Scale.y  ]);
				col += 0.05472157* getCol(tex,	[tuv.x + u_Scale.x, 	tuv.y + u_Scale.y  ]);
				col += 0.00655965* getCol(tex,	[tuv.x + 2*u_Scale.x, 	tuv.y + u_Scale.y  ]);
				
				
				col += 0.01330373* getCol(tex,	[tuv.x + -2*u_Scale.x, 	tuv.y   ]);
				col += 0.11098164* getCol(tex,	[tuv.x + -u_Scale.x, 	tuv.y   ]);
				col += 0.22508352* getCol(tex,	[tuv.x 				, 	tuv.y   ]);
				col += 0.11098164* getCol(tex,	[tuv.x + u_Scale.x, 	tuv.y   ]);
				col += 0.01330373* getCol(tex,	[tuv.x + 2*u_Scale.x, 	tuv.y   ]);
				
				
				col += 0.00655965 * getCol(tex,	[tuv.x + -2*u_Scale.x, 	tuv.y - u_Scale.y  ]);
				col += 0.05472157 * getCol(tex,	[tuv.x + -u_Scale.x, 	tuv.y - u_Scale.y  ]);
				col += 0.11098164 * getCol(tex,	[tuv.x 				, 	tuv.y - u_Scale.y  ]);
				col += 0.05472157 * getCol(tex,	[tuv.x + u_Scale.x, 	tuv.y - u_Scale.y  ]);
				col += 0.00655965 * getCol(tex,	[tuv.x + 2*u_Scale.x, 	tuv.y - u_Scale.y  ]);
				
				
				col += 0.00078633  * getCol(tex,[tuv.x + -2*u_Scale.x, 	tuv.y - 2*u_Scale.y  ]);
				col += 0.00655965  * getCol(tex,[tuv.x + -u_Scale.x, 	tuv.y - 2*u_Scale.y  ]);
				col += 0.01330373  * getCol(tex,[tuv.x 				, 	tuv.y - 2*u_Scale.y  ]);
				col += 0.00655965  * getCol(tex,[tuv.x + u_Scale.x, 	tuv.y - 2*u_Scale.y  ]);
				col += 0.00078633  * getCol(tex,[tuv.x + 2*u_Scale.x, 	tuv.y - 2*u_Scale.y  ]);
			}
			
			if ( useScale ) {
				col = tex.get(sinusDeform != null ? [tuv.x + sin(tuv.y * sinusDeform.y + sinusDeform.x) * sinusDeform.z, tuv.y] : tuv, filter = filter, wrap = tileWrap);
			}
			
			if( hasColorKey ) {
				var cdiff = col.rgb - colorKey.rgb;
				kill(cdiff.dot(cdiff) - 0.00001);
			}
			if( killAlpha ) kill(col.a - 0.001);
			if( hasVertexAlpha ) col.a *= talpha;
			if( hasVertexColor ) col *= tcolor;
			if( hasAlphaMap ) col.a *= alphaMap.get(tuv * alphaUV.zw + alphaUV.xy).r;
			if( hasMultMap ) col *= multMap.get(tuv * multUV.zw + multUV.xy) * multMapFactor;
			if( hasAlpha ) col.a *= alpha;
			if( colorMatrix != null ) col *= colorMatrix;
			if( colorMul != null ) col *= colorMul;
			if ( colorAdd != null ) col += colorAdd;
			if ( colorSet != null) 
				if ( !colorSetPreserveAlpha ) 
					col = colorSet;
				else 
					col.rgb = colorSet.rgb;
			/*
			var c = col.r*0.3 + col.g*0.59 + col.b*0.11;
			col.r = c;
			col.g = c;
			col.b = c;
			*/
			out = col;
		}


	}
	
	#elseif (js || cpp)
	
	public var hasColorKey : Bool;
	
	// not supported
	public var skew : Float;
	public var sinusDeform : h3d.Vector;
	public var hasAlphaMap : Bool;
	public var hasMultMap : Bool;
	public var multMap : h3d.mat.Texture;
	public var multUV : h3d.Vector;
	public var multMapFactor : Float;
	public var alphaMap : h3d.mat.Texture;
	public var alphaUV : h3d.Vector;
	// --
	
	public var filter : Bool;
	public var tileWrap : Bool;
	public var killAlpha : Bool;
	public var hasAlpha : Bool;
	public var hasVertexAlpha : Bool;
	public var hasVertexColor : Bool;
	public var hasColorSet : Bool;
	
	public var useGaussian7x1TwoPass:Bool;
	public var useGaussian5x1TwoPass:Bool;
	public var useGaussian3x3OnePass:Bool;
	public var colorSetPreserveAlpha:Bool;
	public var useScale : Bool;
	
	
	override function getConstants( vertex : Bool ) {
		var cst = [];
		if( vertex ) {
			if( size != null ) cst.push("#define hasSize");
			if( uvScale != null ) cst.push("#define hasUVScale");
			if( uvPos != null ) cst.push("#define hasUVPos");
		} else {
			if( killAlpha ) cst.push("#define killAlpha");
			if( hasColorKey ) cst.push("#define hasColorKey");
			if( hasAlpha ) cst.push("#define hasAlpha");
			if( colorMatrix != null ) cst.push("#define hasColorMatrix");
			if( colorMul != null ) cst.push("#define hasColorMul");
			if( colorAdd != null ) cst.push("#define hasColorAdd");
		}
		if( hasVertexAlpha ) cst.push("#define hasVertexAlpha");
		if( hasVertexColor ) cst.push("#define hasVertexColor");
		if( hasColorSet ) cst.push("#define hasColorSet");
		
		if( useGaussian7x1TwoPass ) cst.push("#define useGaussian7x1TwoPass");
		if( useGaussian5x1TwoPass ) cst.push("#define useGaussian5x1TwoPass");
		if( useGaussian3x3OnePass ) cst.push("#define useGaussian3x3OnePass");
		if( colorSetPreserveAlpha ) cst.push("#define colorSetPreserveAlpha");
		if( useScale ) cst.push("#define useScale");
		
		return cst.join("\n");
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
			vec2 t = uv;
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
		}

	";
	
	static var FRAGMENT = "
	
		varying vec2 tuv;
		uniform sampler2D tex;
		
		#if hasVertexAlpha
		varying float talpha;
		#end
		#if hasVertexColor
		varying vec4 tcolor;
		#end
		
		uniform float alpha;
		uniform vec3 colorKey/*byte4*/;
	
		uniform vec4 colorAdd;
		uniform vec4 colorSet;
		uniform vec4 colorMul;
		uniform mat4 colorMatrix;
		
		uniform vec2 u_Scale;

		void main(void) {
			vec4 col;
			
			#if useGaussian3x3OnePass
			
			col += 0.00078633 * texture2D(tex,	vec2(tuv.x + -2*u_Scale.x, 	tuv.y + 2 * u_Scale.y  ));
			col += 0.00655965 * texture2D(tex,	vec2(tuv.x + -1*u_Scale.x, 	tuv.y + 2 * u_Scale.y  ));
			col += 0.01330373 * texture2D(tex,	vec2(tuv.x + 0*u_Scale.x, 	tuv.y + 2 * u_Scale.y  ));
			col += 0.00655965 * texture2D(tex,	vec2(tuv.x + 1*u_Scale.x, 	tuv.y + 2 * u_Scale.y  ));
			col += 0.00078633 * texture2D(tex,	vec2(tuv.x + 2*u_Scale.x, 	tuv.y + 2 * u_Scale.y  ));
			
			
			col += 0.00655965* texture2D(tex,	vec2(tuv.x + -2*u_Scale.x, 	tuv.y + u_Scale.y  ));
			col += 0.05472157* texture2D(tex,	vec2(tuv.x + -1*u_Scale.x, 	tuv.y + u_Scale.y  ));
			col += 0.11098164* texture2D(tex,	vec2(tuv.x + 0*u_Scale.x, 	tuv.y + u_Scale.y  ));
			col += 0.05472157* texture2D(tex,	vec2(tuv.x + 1*u_Scale.x, 	tuv.y + u_Scale.y  ));
			col += 0.00655965* texture2D(tex,	vec2(tuv.x + 2*u_Scale.x, 	tuv.y + u_Scale.y  ));
			
			
			col += 0.01330373* texture2D(tex,	vec2(tuv.x + -2*u_Scale.x, 	tuv.y   ));
			col += 0.11098164* texture2D(tex,	vec2(tuv.x + -1*u_Scale.x, 	tuv.y   ));
			col += 0.22508352* texture2D(tex,	vec2(tuv.x + 0*u_Scale.x, 	tuv.y   ));
			col += 0.11098164* texture2D(tex,	vec2(tuv.x + 1*u_Scale.x, 	tuv.y   ));
			col += 0.01330373* texture2D(tex,	vec2(tuv.x + 2*u_Scale.x, 	tuv.y   ));
			
			
			col += 0.00655965 * texture2D(tex,	vec2(tuv.x + -2*u_Scale.x, 	tuv.y - u_Scale.y  ));
			col += 0.05472157 * texture2D(tex,	vec2(tuv.x + -1*u_Scale.x, 	tuv.y - u_Scale.y  ));
			col += 0.11098164 * texture2D(tex,	vec2(tuv.x + 0*u_Scale.x, 	tuv.y - u_Scale.y  ));
			col += 0.05472157 * texture2D(tex,	vec2(tuv.x + 1*u_Scale.x, 	tuv.y - u_Scale.y  ));
			col += 0.00655965 * texture2D(tex,	vec2(tuv.x + 2*u_Scale.x, 	tuv.y - u_Scale.y  ));
			
			
			col += 0.00078633  * texture2D(tex,vec2(tuv.x + -2*u_Scale.x, 	tuv.y - 2*u_Scale.y));
			col += 0.00655965  * texture2D(tex,vec2(tuv.x + -1*u_Scale.x, 	tuv.y - 2*u_Scale.y  ));
			col += 0.01330373  * texture2D(tex,vec2(tuv.x + 0*u_Scale.x, 	tuv.y - 2*u_Scale.y  ));
			col += 0.00655965  * texture2D(tex,vec2(tuv.x + 1*u_Scale.x, 	tuv.y - 2*u_Scale.y  ));
			col += 0.00078633  * texture2D(tex,vec2(tuv.x + 2*u_Scale.x, 	tuv.y - 2*u_Scale.y  ));
			
			#end
			
			#if useGaussian5x1TwoPass 
				col += 0.204164 * 		 texture2D(tex,	vec2(tuv.x +  u_Scale.x			, 		tuv.y + u_Scale.y  				));
				col += 0.304005 *		 texture2D(tex, vec2(tuv.x +  1.407333 * u_Scale.x	,	tuv.y + u_Scale.y * 1.407333 	));
				col += 0.304005 * 		 texture2D(tex,	vec2(tuv.x +  -1.407333 * u_Scale.x	, 	tuv.y + u_Scale.y *  -1.407333 	));
				col += 0.093913 *	 	 texture2D(tex, vec2(tuv.x +  3.294215  * u_Scale.x	, 	tuv.y + u_Scale.y * 3.294215 	));
				col += 0.093913 * 		 texture2D(tex,	vec2(tuv.x +  -3.294215  * u_Scale.x, 	tuv.y + u_Scale.y * -3.294215 	));
			#end
			
			#if useGaussian7x1TwoPass 
				col += 0.015625 * 		texture2D(tex,	vec2(tuv.x +  -3 * u_Scale.x, 	tuv.y + u_Scale.y * -3 ));
				col += 0.09375 	*		texture2D(tex, 	vec2(tuv.x +  -2* u_Scale.x,	tuv.y + u_Scale.y * -2 ));
				col += 0.234375 * 		texture2D(tex,	vec2(tuv.x +  -1* u_Scale.x, 	tuv.y + u_Scale.y * -1 ));
					                                    
				col += 0.3125 	*	 	texture2D(tex,	vec2(tuv.x +  0*u_Scale.x, 		tuv.y + u_Scale.y * 0 ));
					                                    
				col += 0.234375 * 		texture2D(tex,	vec2(tuv.x +  1 * u_Scale.x, 	tuv.y + u_Scale.y * 1 ));
				col += 0.09375 * 		texture2D(tex,	vec2(tuv.x +  2 * u_Scale.x, 	tuv.y + u_Scale.y * 2 ));
				col += 0.015625 * 		texture2D(tex,	vec2(tuv.x +  3 * u_Scale.x, 	tuv.y + u_Scale.y * 3 ));
			#end
			
			#if useScale
				col = texture2D(tex, tuv);
			#end
			
			#if killAlpha
				if( col.a - 0.001 <= 0 ) discard;
			#end
			#if hasColorKey
				vec3 dc = col.rgb - colorKey;
				if( dot(dc,dc) < 0.001 ) discard;
			#end
			#if hasAlpha
				col.w *= alpha;
			#end
			#if hasVertexAlpha
				col.w *= talpha;
			#end
			#if hasVertexColor
				col *= tcolor;
			#end
			#if hasColorMatrix
				col = colorMatrix * col;
			#end
			#if hasColorMul
				col *= colorMul;
			#end
			#if hasColorAdd
				col += colorAdd;
			#end
			#if hasColorSet
				#if colorSetPreserveAlpha
					col.rgb = colorSet.rgb;
				#else
					col = colorSet;
				#end
			#end
			gl_FragColor = col;
		}
			
	";
	
	#end
}

class BlurredBitmap extends CachedBitmap {
	
	public var redrawChilds = false;
	public var colorSet(get, set):h3d.Vector;
	public var colorSetPreserveAlpha(get, set):Bool;
	public var blurScale = 1.0;
	
	
	var blurShader : BlurredDrawableShader;
	
	var finalTex : Texture;
	var finalTile : Tile;
	var curUScale : Vector;
	
	var nbPass = 0;
	
	//offset to rtt parts
	public var ofsX=0.0;
	public var ofsY=0.0;
	
	
	public function new(?parent,?w:Float=-1.0, ?h:Float=-1.0,?mode) {
		super( parent, Math.ceil(w), Math.ceil(h));
		blurShader = new BlurredDrawableShader();
		blurShader.alpha = 1;
		blurShader.zValue = 0;
		blurShader.colorSetPreserveAlpha = false;
		writeAlpha = true;
		blendMode = Normal;
		curUScale = new Vector();
		if ( mode == null ) {
			setMode(Gaussian3x3OnePass);
		}
		else {
			setMode(mode);
		}
	}
	
	override function clean() {
		super.clean();
		if( finalTex != null ) {
			finalTex.dispose();
			finalTex = null;
		}
		finalTile = null;
	}
	
	public override function getTile() {
		var tile = super.getTile();
		if ( nbPass == 1 )
			return tile;
			
		if( finalTile == null ) {
			var tw = 1, th = 1;
			var engine = h3d.Engine.getCurrent();
			realWidth = width < 0 ? engine.width : Math.ceil(width);
			realHeight = height < 0 ? engine.height : Math.ceil(height);
			while( tw < realWidth ) tw <<= 1;
			while ( th < realHeight ) th <<= 1;
			
			finalTex = engine.mem.allocTargetTexture(tw, th);
			finalTile = new Tile(finalTex,0, 0, realWidth, realHeight);
		}
		return tile;
	}
	
	function setupMyShader( engine : h3d.Engine, tile : h2d.Tile, options : Int, u_scale:Vector ) {
		var core = Tools.getCoreObjects();
		var shader = blurShader;
		var mat = core.tmpMaterial;

		if( tile == null )
			tile = new Tile(core.getEmptyTexture(), 0, 0, 5, 5);

		switch( blendMode ) {
		case Normal:
			mat.blend(SrcAlpha, OneMinusSrcAlpha);
		case None:
			mat.blend(One, Zero);
		case Add:
			mat.blend(SrcAlpha, One);
		case SoftAdd:
			mat.blend(OneMinusDstColor, One);
		case Multiply:
			mat.blend(DstColor, OneMinusSrcAlpha);
		case Erase:
			mat.blend(Zero, OneMinusSrcAlpha);
		case Hide:
			mat.blend(Zero, One);
		}

		if( options & HAS_SIZE != 0 ) {
			var tmp = core.tmpSize;
			// adds 1/10 pixel size to prevent precision loss after scaling
			tmp.x = tile.width + 0.1 + ofsX;
			tmp.y = tile.height + 0.1 + ofsY;
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
			shader.alphaUV = new h3d.Vector(alphaMap.u, alphaMap.v, (alphaMap.u2 - alphaMap.u) / tile.u2, (alphaMap.v2 - alphaMap.v) / tile.v2);
		}

		if( shader.hasMultMap ) {
			shader.multMap = multiplyMap.getTexture();
			shader.multUV = new h3d.Vector(multiplyMap.u, multiplyMap.v, (multiplyMap.u2 - multiplyMap.u) / tile.u2, (multiplyMap.v2 - multiplyMap.v) / tile.v2);
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
		
		
		shader.matB = tmp;
		
		var t = tile.getTexture();
		shader.tex = t;
		u_scale.x *= blurScale;
		u_scale.y *= blurScale;
		shader.u_Scale = u_scale; 
		
		shader.useGaussian3x3OnePass = false;
		shader.useGaussian5x1TwoPass = false;
		shader.useGaussian7x1TwoPass = false;
		shader.useScale = false;
		
		switch( mode ) {
			case Gaussian3x3OnePass: shader.useGaussian3x3OnePass =  true;
			case Gaussian5x1TwoPass: shader.useGaussian5x1TwoPass =  true;
			case Gaussian7x1TwoPass: shader.useGaussian7x1TwoPass =  true;
			case Scale(_, _): shader.useScale = true;
		}
		
		mat.shader = shader;
		engine.selectMaterial(mat);
	}
	
	override function drawTile( engine, tile ) {
		super.drawTile(engine,tile);
		
	}
	
	override function drawRec( ctx : RenderContext ) {
		var engine = ctx.engine;
		
		if ( freezed && renderDone) {
			if ( finalTile != null){
				tile = finalTile;
				tex = finalTex;
			}
			super.drawRec(ctx);
			return;
		}
				
		tile.width = Std.int(realWidth  / targetScale);
		tile.height = Std.int(realHeight / targetScale);
		
		if(finalTile!=null){
			finalTile.width = Std.int(realWidth  / targetScale);
			finalTile.height = Std.int(realHeight / targetScale);
		}
		
		if( nbPass > 1 ) 	curUScale.set(0, 1 / finalTex.height,0,0);
		else				curUScale.set(1 / tex.width, 1 / tex.height, 0, 0);
			
		setupMyShader(engine, nbPass>1?finalTile:tile, HAS_SIZE | HAS_UV_POS | HAS_UV_SCALE, curUScale );
		engine.renderQuadBuffer(Tools.getCoreObjects().planBuffer);
		
		if ( redrawChilds ) {
			calcAbsPos();
			for( c in childs )
				c.posChanged = true;
			for( c in childs )
				c.drawRec(ctx);
		}
	}
	
	var mode : BlurMethod;
	public function setMode( mode : BlurMethod ) {
		this.mode = mode;
		var nbPass = switch(mode) {
			case Gaussian3x3OnePass:1;
			case Gaussian5x1TwoPass:2;
			case Gaussian7x1TwoPass:2;
			case Scale(nb, filt): 
			if (nb < 1) nb = 1;
			targetScale = 1.0 / nb;
			shader.filter = filt;
			nbPass = 1;
		}
	}
	
	static var tmpMatrix = new h2d.Matrix();
	override function sync(ctx:RenderContext) {
		var wasDone = renderDone;
		
		super.sync(ctx);
		//return;
		
		if ( freezed && wasDone && renderDone)
			return;
		
		if ( nbPass == 1 )
			return;
			
		var oldA = matA, oldB = matB, oldC = matC, oldD = matD, oldX = absX, oldY = absY;
		var engine = ctx.engine;
		
		var w = 2 / tex.width * targetScale;
		var h = -2 / tex.height * targetScale;
		var m = Tools.getCoreObjects().tmpMatrix2D;
		var engine = ctx.engine;
		
		m.identity();
		m.scale(w, h);
		m.translate( - 1, 1);
		
		#if !flash
		m.scale(1, -1);
		#end
		
		matA=m.a;
		matB=m.b;
		matC=m.c;
		matD=m.d;
		absX=m.tx;
		absY=m.ty;

		var oc = engine.triggerClear;
		engine.triggerClear = true;
		engine.setTarget(finalTex);
		engine.setRenderZone(0, 0, realWidth, realHeight);
		curUScale.set(1 / finalTex.width, 0, 0, 0);
		
		setupMyShader(engine, tile, HAS_SIZE | HAS_UV_POS | HAS_UV_SCALE, curUScale);
		engine.renderQuadBuffer(Tools.getCoreObjects().planBuffer);
		
		engine.setTarget(null);
		engine.setRenderZone();
		engine.triggerClear = oc;
		
		// restore
		matA = oldA;
		matB = oldB;
		matC = oldC;
		matD = oldD;
		absX = oldX;
		absY = oldY;
	}
	
	override function get_alpha() {
		return blurShader.alpha;
	}
	
	override function set_alpha( v : Null<Float> ) {
		blurShader.alpha = v;
		blurShader.hasAlpha = v < 1;
		return v;
	}
	
	function set_colorSet(m) 				return blurShader.colorSet = m;
	function get_colorSet() 				return blurShader.colorSet;
	function set_colorSetPreserveAlpha(m) 	return blurShader.colorSetPreserveAlpha = m;
	function get_colorSetPreserveAlpha() 	return blurShader.colorSetPreserveAlpha;
	
	override function set_colorMatrix(m) 	return blurShader.colorMatrix = m;
	override function set_color(m) 			return blurShader.colorMul = m;
	override function set_colorAdd(m) 		return blurShader.colorAdd = m;
	override function get_colorMatrix() 	return blurShader.colorMatrix;
	override function get_colorAdd() 		return blurShader.colorAdd;
	override function get_color() 			return blurShader.colorMul;
	override function get_filter()			return blurShader.filter;
	override function set_filter(v) 		return blurShader.filter = v;
	override function get_tileWrap() 		return blurShader.tileWrap;
	override function set_tileWrap(v) 		return blurShader.tileWrap = v;
	override function get_killAlpha() 		return blurShader.killAlpha;
	override function set_killAlpha(v) 		return blurShader.killAlpha = v;
	override function get_colorKey() 		return blurShader.colorKey;
	override function set_colorKey(v) 		{ blurShader.hasColorKey = true;	return blurShader.colorKey = v; }
}

