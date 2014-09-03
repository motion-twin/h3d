package h3d.mat;
import h2d.BlendMode;
import h3d.Engine;
import h3d.mat.MeshMaterial.MeshShader;
import h3d.Matrix;
import h3d.Vector;
import h3d.mat.Data;
import hxd.Save;
import hxd.System;


typedef LightSystem = {
	var ambient : h3d.Vector;
	var dirs : Array<{ dir : h3d.Vector, color : h3d.Vector }>;
	var points : Array<{ pos : h3d.Vector, color : h3d.Vector, att : h3d.Vector }>;
}

typedef ShadowMap = {
	var lightProj : h3d.Matrix;
	var lightCenter : h3d.Matrix;
	var color : h3d.Vector;
	var texture : Texture;
}

typedef DecalInfos = {
	var depthTexture : Texture;
	var uvScaleRatio : h3d.Vector;
	var screenToLocal : h3d.Matrix;
}

@:keep
class MeshShader extends h3d.impl.Shader {
	
#if flash
	static var SRC = {

		var input : {
			pos : Float3,
			uv : Float2,
			normal : Float3,
			color : Float3,
			colorAdd : Float3,
			blending : Float,
			weights : Float3,
			indexes : Int,
		};
		
		var tuv : Float2;
		
		var uvScale : Float2;
		var uvDelta : Float2;
		var hasSkin : Bool;
		var hasVertexColor : Bool;
		var hasVertexColorAdd : Bool;
		var skinMatrixes : M34<34>;

		var tcolor : Float3;
		var acolor : Float3;
		var talpha : Float;
		
		var zBias : Float;
		var hasZBias : Bool;
		
		var alphaMap : Texture;
		var hasAlphaMap : Bool;
		
		var lightSystem : Param < {
			var ambient : Float3;
			var dirs : Array < { dir : Float3, color : Float3 }>;
			var points : Array<{ pos : Float3, color : Float3, att : Float3 }>;
		}>;
		
		var fog : Float4;
		
		var fastFog : Float4;
		var fastFogEq : Float4;// start end density
		
		var glowTexture : Texture;
		var glowAmount : Float3;
		var hasGlow : Bool;
		
		var blendTexture : Texture;
		var hasBlend : Bool;
		var tblend : Float;

		var hasShadowMap : Bool;
		var shadowLightProj : Matrix;
		var shadowLightCenter : Matrix;
		var shadowColor : Float4;
		var shadowTexture : Texture;
		var tshadowPos : Float4;

		var isOutline : Bool;
		var outlineColor : Int;
		var outlineSize : Float;
		var outlinePower : Float;
		//var outlineProj : Float3;
		
		var cameraPos : Float3;
		var worldNormal : Float3;
		var eyeNormal : Float3;
		var worldView : Float3;
		var eyeView : Float3;
		
		var rimColor : Float4;

		function smoothstep(edge0:Float,edge1:Float,e:Float) {
			var x = saturate( (e-edge0) / (edge1 - edge0) );
			return x * x * (3.0 - 2.0 * x);
		}
		
		function vertex( mpos : Matrix, mproj : Matrix ) {
			var tpos = input.pos.xyzw;
			var tnorm : Float3 = [0, 0, 0];
			
			if( lightSystem != null || isOutline || rimColor != null ) {
				var n = input.normal;
				if( hasSkin )
					n = n * input.weights.x * skinMatrixes[input.indexes.x * (255 * 3)].m33 + n * input.weights.y * skinMatrixes[input.indexes.y * (255 * 3)].m33 + n * input.weights.z * skinMatrixes[input.indexes.z * (255 * 3)].m33;
				else if( mpos != null )
					n *= mpos.m33;
				tnorm = n.normalize();
			}
			if( hasSkin )
				tpos.xyz = tpos * input.weights.x * skinMatrixes[input.indexes.x * (255 * 3)] + tpos * input.weights.y * skinMatrixes[input.indexes.y * (255 * 3)] + tpos * input.weights.z * skinMatrixes[input.indexes.z * (255 * 3)];
			else if( mpos != null )
				tpos *= mpos;
				
			if( isOutline ) {
				tpos.xyz += tnorm.xyz  * outlineSize;
				//tpos.xy += tnorm.xy * outlineProj.xy * outlineSize;
			}
			
			if( isOutline || rimColor != null ){
				worldNormal = tnorm;
				eyeNormal = normalize(tnorm * mproj);
				worldView = (cameraPos - tpos.xyz).normalize();
			}
			
			if ( rimColor != null ) {
				eyeView = normalize( (cameraPos - tpos.xyz).normalize() * mproj );
				eyeNormal = normalize(tnorm * mproj);
			}
			
			var ppos = tpos * mproj;
			if( hasZBias ) ppos.z += zBias;
			out = ppos;
			var t = input.uv;
			if( uvScale != null ) t *= uvScale;
			if( uvDelta != null ) t += uvDelta;
			tuv = t;
			if( lightSystem != null ) {
				var col : Float3 = lightSystem.ambient.rgb;
				
				for( d in lightSystem.dirs )
					col += d.color.rgb * tnorm.dot( -d.dir).max(0);
				
				for( p in lightSystem.points ) {
					var d = tpos.xyz - p.pos;
					var dist2 = d.dot(d);
					var dist = dist2.sqt();
					var att = p.att.x * dist + p.att.y * dist2 + p.att.z * dist2 * dist;
					col += p.color.rgb * (tnorm.dot(d).max(0) / att);
				}
				
				if( hasVertexColor )
					tcolor = col * input.color.rgb;
				else
					tcolor = col;
					
			} else if( hasVertexColor )
				tcolor = input.color;
			if( hasVertexColorAdd )
				acolor = input.colorAdd;
				
			if( fog != null ) {
				var dist = tpos.xyz - fog.xyz;
				talpha = (fog.w * dist.dot(dist).rsqrt()).min(1);
			}
			
			if ( fastFog != null ) {
				var d = fastFogEq.w;
				var l = ( (ppos.z - fastFogEq.x) / (fastFogEq.y - fastFogEq.x) ) * fastFogEq.z;
				talpha = 1.0 - ( exp( - d*d*l*l ) );
			}
			
			if( hasBlend ) tblend = input.blending;
			if( hasShadowMap )
				tshadowPos = tpos * shadowLightProj * shadowLightCenter;
		}
		
		var killAlpha : Bool;
		var killAlphaThreshold : Float;
		var isDXT1 : Bool;
		var isDXT5 : Bool;
		
		var isAlphaPremul:Bool;
		
		function fragment( tex : Texture, colorAdd : Float4, colorMul : Float4, colorMatrix : M44 ) {
			var c : Float4;
			
			if ( isOutline ) {
				c = tex.get(tuv.xy, type = isDXT1 ? 1 : isDXT5 ? 2 : 0);
				var e = 1 - worldNormal.normalize().dot(worldView.normalize());
				c = c * outlineColor * e.pow(outlinePower);
			} else {
				c = tex.get(tuv.xy, type = isDXT1 ? 1 : isDXT5 ? 2 : 0);
				if ( isAlphaPremul ) c.rgb /= c.a;
				
				if ( rimColor != null ) {
					var e = 1 - eyeView.dot( eyeNormal ) ;
					c.rgb += rimColor.rgb * smoothstep(0.6,1.0, e);
				}
				
				if( hasAlphaMap ) c.a *= alphaMap.get(tuv.xy,type=isDXT1 ? 1 : isDXT5 ? 2 : 0).b;
				if( killAlpha ) kill(c.a - killAlphaThreshold);
				if( hasBlend ) c.rgb = c.rgb * (1 - tblend) + tblend * blendTexture.get(tuv.xy,type=isDXT1 ? 1 : isDXT5 ? 2 : 0).rgb;
				if( colorAdd != null ) c += colorAdd;
				if( colorMul != null ) c = c * colorMul;
				if( colorMatrix != null ) c = c * colorMatrix;
				if( hasVertexColorAdd )
					c.rgb += acolor;
				if( lightSystem != null || hasVertexColor )
					c.rgb *= tcolor.rgb;
				if( hasShadowMap ) {
					// ESM filtering
					var shadow = exp( shadowColor.w * (tshadowPos.z - shadowTexture.get(tshadowPos.xy).dot([1, 1 / 255, 1 / (255 * 255), 1 / (255 * 255 * 255)]))).sat();
					c.rgb *= (1 - shadow) * shadowColor.rgb + shadow.xxx;
				}
				if ( hasGlow ) c.rgb += glowTexture.get(tuv.xy).rgb * glowAmount;
				if( isAlphaPremul ) c.rgb *= c.a;
			}
			
			if( fog != null ) c.a *= talpha;
			if( fastFog != null)
				c.rgb = ((talpha) * fastFog.rgb + (1.0 - talpha) * c.rgb);
				
			out = c;
		}
		
	}
#else

	public var maxSkinMatrixes : Int = 34;
	public var hasVertexColor : Bool;
	public var hasVertexColorAdd : Bool;
	public var lightSystem(default, set) : LightSystem;
	public var hasSkin : Bool;
	public var hasZBias : Bool;
	public var hasShadowMap : Bool;
	public var killAlpha : Bool;
	public var hasAlphaMap : Bool;
	public var hasBlend : Bool;
	public var hasGlow : Bool;
	
	public var isOutline : Bool;
	public var isAlphaPremul:Bool;
	
	var lights : {
		ambient : h3d.Vector,
		dirsDir : Array<h3d.Vector>,
		dirsColor : Array<h3d.Vector>,
		pointsPos : Array<h3d.Vector>,
		pointsColor : Array<h3d.Vector>,
		pointsAtt : Array<h3d.Vector>,
	};
	
	/**
	 * Changes the light system setup
	 * in termes of speed ambient > dirs > points
	 * The system is structurally cloned util the vector themselves, which allows to centralize value modification
	 */
	function set_lightSystem(l) {
		this.lightSystem = l;
		lights = l==null?null:{
			ambient : l.ambient,
			dirsDir : [for( l in l.dirs ) l.dir],
			dirsColor : [for( l in l.dirs ) l.color],
			pointsPos : [for( p in l.points ) p.pos],
			pointsColor : [for( p in l.points ) p.color],
			pointsAtt : [for( p in l.points ) p.att],
		};
		return l;
	}
	
	override function getConstants(vertex) {
		var cst = [];
		if( hasVertexColor ) cst.push("#define hasVertexColor");
		if( hasVertexColorAdd ) cst.push("#define hasVertexColorAdd");
		
		if( fog != null ) cst.push("#define hasFog");
		if( fastFog != null ) cst.push("#define hasFastFog");
		
		if( hasBlend ) cst.push("#define hasBlend");
		if( hasShadowMap ) cst.push("#define hasShadowMap");
		if( lightSystem != null ) {
			cst.push("#define hasLightSystem");
			cst.push("const int numDirLights = " + lightSystem.dirs.length+";");
			cst.push("const int numPointLights = " + lightSystem.points.length + ";");
			
			if ( lightSystem.dirs.length == 0 ) 
				cst.push("#define lightSystemNoDirs");
				
			if ( lightSystem.points.length == 0 ) 
				cst.push("#define lightSystemNoPoints");
		}
		
		if ( lightSystem != null || isOutline || hasSkin || rimColor != null ) 
			cst.push("#define hasNormals");
		
		if( vertex ) {
			if( mpos != null ) cst.push("#define hasPos");
			if( hasSkin ) {
				cst.push("#define hasSkin");
				cst.push("const int maxSkinMatrixes = " + maxSkinMatrixes+";");
			}
			if( uvScale != null ) cst.push("#define hasUVScale");
			if( uvDelta != null ) cst.push("#define hasUVDelta");
			if( hasZBias ) cst.push("#define hasZBias");
		} else {
			if( killAlpha ) cst.push("#define killAlpha");
			if( colorAdd != null ) cst.push("#define hasColorAdd");
			if ( colorMul != null ) cst.push("#define hasColorMul");
			if( colorMatrix != null ) cst.push("#define hasColorMatrix");
			if( hasAlphaMap ) cst.push("#define hasAlphaMap");
			if( hasGlow ) cst.push("#define hasGlow");
			if( hasVertexColorAdd || lightSystem != null ) cst.push("#define hasFragColor");
		}
		
		if ( isOutline ) 								cst.push("#define isOutline");
		if ( rimColor != null )							cst.push("#define hasRim");
		if ( hasSkin || isOutline || rimColor != null) 	cst.push("#define processNormals");
			
		return cst.join("\n");
	}
	

	//warning int vars does not work on gles
	static var VERTEX = "
	
		attribute vec3 pos;
		attribute vec2 uv;
		#if processNormals
		attribute vec3 normal;
		#end
		#if hasVertexColor
		attribute vec3 color;
		#end
		#if hasVertexColorAdd
		attribute vec3 colorAdd;
		#end
		#if hasBlend
		attribute float blending;
		#end
		
		#if hasSkin
		uniform mat4 skinMatrixes[maxSkinMatrixes];
		
		attribute vec4 indexes/*byte4*/;
		attribute vec3 weights;
		#end

		uniform mat4 mpos;
		uniform mat4 mproj;
		uniform float zBias;
		uniform vec2 uvScale;
		uniform vec2 uvDelta;
		
		uniform vec4 fastFogEq; // start end density
		
		#if hasLightSystem
		// we can't use Array of structures in GLSL
		struct LightSystem {
			vec3 ambient;
			
			#if !lightSystemNoDirs
			vec3 dirsColor[numDirLights];
			vec3 dirsDir[numDirLights];
			#end
			
			#if !lightSystemNoPoints
			vec3 pointsColor[numPointLights];
			vec3 pointsPos[numPointLights];
			vec3 pointsAtt[numPointLights];
			#end
		};
		uniform LightSystem lights;
		#end
			
		#if hasShadowMap
		uniform mat4 shadowLightProj;
		uniform mat4 shadowLightCenter;
		#end

		uniform vec4 fog;
		
		uniform float outlineSize;
		uniform vec3 cameraPos;
		
		varying lowp vec2 tuv;
		varying lowp vec3 tcolor;
		varying lowp vec3 acolor;
		
		varying lowp float talpha;
		varying mediump float tblend;
		
		#if hasShadowMap
		varying mediump vec4 tshadowPos;
		#end
		
		uniform mat3 mposInv;
		
		varying mediump vec3 worldNormal;
		varying mediump vec3 worldView;
		varying mediump vec3 eyeNormal;
		varying mediump vec3 eyeView;

		void main(void) {
			vec4 tpos = vec4(pos.x,pos.y, pos.z, 1.0);
			
			#if hasSkin
				int ix = int(indexes.x); 
				int iy = int(indexes.y); 
				int iz = int(indexes.z);
				
				float wx = weights.x;
				float wy = weights.y;
				float wz = weights.z;
				
				//fetching in local vars is mandatory on adreno my ass
				mat4 mx = skinMatrixes[ix];
				mat4 my = skinMatrixes[iy];
				mat4 mz = skinMatrixes[iz];
				
				tpos.xyz = (tpos * wx * mx ).xyz
				+ (tpos * wy * my).xyz
				+ (tpos * wz * mz).xyz
				;
				
			#elseif hasPos
				tpos *= mpos;
			#end
			
			vec2 t = uv;
			#if hasUVScale
				t *= uvScale;
			#end
			#if hasUVDelta
				t += uvDelta;
			#end
			tuv = t;
			
			#if processNormals
			vec3 n = normal;
				#if hasSkin
					n = 	wx*(n*mat3(mx))  
						+ 	wy*(n*mat3(my))  
						+ 	wz*(n*mat3(mz));
				#elseif hasPos
					n *= mat3(mpos);
				#end
				n = normalize(n);
			#end 
			
			#if hasLightSystem
				vec3 col = lights.ambient.rgb;
				
				#if !lightSystemNoDirs
				for (int i = 0; i < numDirLights; i++ )
					col += lights.dirsColor[i].rgb * max(dot(n, -lights.dirsDir[i]), 0.);
				#end
				
				#if !lightSystemNoPoints
				for(int i = 0; i < numPointLights; i++ ) {
					vec3 d = tpos.xyz - lights.pointsPos[i];
					float dist2 = dot(d,d);
					float dist = sqrt(dist2);
					float att = clamp(dot(lights.pointsAtt[i].rgb, vec3(dist, dist2, dist2 * dist)),0.0,1.0);
					float lf = max(dot(n, d), 0.) / att;
					col += lf * lights.pointsColor[i].rgb;
				}
				#end
				
				#if hasVertexColor
					tcolor = col * color;
				#else
					tcolor = col;
				#end
				
			#elseif hasVertexColor
				tcolor = color;
			#else
				tcolor = vec3(1.,1.,1.);
			#end 
			
			#if isOutline 
				tpos.xyz += n.xyz * outlineSize;
				
				worldNormal = n;
				worldView = normalize(cameraPos - tpos.xyz);
			#end
			
			#if hasRim 
				eyeNormal = normalize( n * mat3(mproj) );
				eyeView = normalize( (cameraPos - tpos.xyz) * mat3(mproj) );
			#end
			
			#if hasVertexColorAdd
				acolor = colorAdd;
			#end
			
			#if hasFog
				vec3 dist = tpos.xyz - fog.xyz;
				talpha = min(1.0,(fog.w * dist.dot(dist).rsqrt()));
			#end
			
			#if hasBlend
				tblend = blending;
			#end	
			#if hasShadowMap
				tshadowPos = shadowLightCenter * shadowLightProj * tpos;
			#end
			
			vec4 ppos = tpos * mproj;
			
			#if hasZBias
				ppos.z += zBias;
			#end
			
			#if hasFastFog 
				float d = fastFogEq.w;
				float l = ( (ppos.z - fastFogEq.x) / (fastFogEq.y - fastFogEq.x) ) * fastFogEq.z;
				talpha = 1.0 - ( exp( - *d*l*l ) );
			#end
			
			gl_Position = ppos;
		}

	";
	
	static var FRAGMENT = "
		varying lowp vec2 tuv;
		varying lowp vec3 tcolor;
		varying lowp vec3 acolor;
		
		uniform lowp vec4 colorAdd;
		uniform lowp vec4 colorMul;
		
		varying lowp float talpha;
		varying mediump float tblend;
		varying mediump vec4 tshadowPos;
		
		varying mediump vec3 worldNormal;
		varying mediump vec3 worldView;
		
		varying mediump vec3 eyeNormal;
		varying mediump vec3 eyeView;
		
		uniform sampler2D tex;
		uniform mediump mat4 colorMatrix;
		uniform lowp float killAlphaThreshold;
		uniform lowp vec4 outlineColor/*byte4*/;
		uniform float outlinePower;
		
		uniform mediump vec3 rimColor;

		#if hasAlphaMap
		uniform sampler2D alphaMap;
		#end
		
		#if hasBlend
		uniform sampler2D blendTexture;
		#end

		#if hasGlow
		uniform sampler2D glowTexture;
		uniform vec3 glowAmount;
		#end

		#if hasShadowMap
		uniform sampler2D shadowTexture;
		uniform vec4 shadowColor;
		#end

		#if hasFastFog
		uniform vec4 fastFog;
		#end

		void main(void) {
			lowp vec4 c = texture2D(tex, tuv);
			
			#if isOutline 
				float e = 1.0 - dot( worldNormal, worldView );
				c = c * outlineColor * pow(e, outlinePower);
			#else
				#if isAlphaPremul 
					c.rgb /= c.a;
				#end
				#if hasRim
					float e = 1.0 - dot( eyeView,eyeNormal );
					c.rgb += rimColor.rgb * smoothstep(0.6,1.0, e);
				#end
				#if hasAlphaMap
					c.a *= texture2D(alphaMap, tuv).b;
				#end
				#if killAlpha
					if( c.a - killAlphaThreshold <= 0.0 ) discard;
				#end
				#if hasBlend
					c.rgb = c.rgb * (1. - tblend) + tblend * texture2D(blendTexture, tuv).rgb;
				#end
				#if hasColorAdd
					c += colorAdd;
				#end
				#if hasColorMul
					c *= colorMul;
				#end
				#if hasColorMatrix
					c = colorMatrix * c;
				#end
				#if hasVertexColorAdd
					c.rgb += acolor;
				#end
				#if hasFragColor
					c.rgb *= tcolor;
				#end
				#if hasShadowMap
					// ESM filtering
					mediump float shadow = exp( shadowColor.w * (tshadowPos.z - shadowTexture.get(tshadowPos.xy).dot([1., 1. / 255., 1. / (255. * 255.), 1. / (255. * 255. * 255.)]))).sat();
					c.rgb *= (1. - shadow) * shadowColor.rgb + shadow.xxx;
				#end
				#if hasGlow
					c.rgb += texture2D(glowTexture,tuv).rgb * glowAmount.rgb;
				#end
				
				#if isAlphaPremul 
					c.rgb *= c.a;
				#end
			#end
			
			#if hasFog
				c.a *= talpha;
			#end
			
			#if hasFastFog
				c.rgb = mix(c.rgb, fastFog.rgb, talpha);
			#end
			
			gl_FragColor = c;
		}

	";


#end
	
}

class MeshMaterial extends Material {

	var mshader(get,set) : MeshShader;
	
	public var texture : Texture;
	
	public var glowTexture(get, set) : Texture;
	public var glowAmount(get, set) : Float;
	public var glowColor(get, set) : h3d.Vector;

	public var useMatrixPos : Bool;
	public var uvScale(get,set) : Null<h3d.Vector>;
	public var uvDelta(get,set) : Null<h3d.Vector>;

	@:isVar
	public var killAlpha(get,set) : Bool;

	public var hasVertexColor(get, set) : Bool;
	public var hasVertexColorAdd(get,set) : Bool;
	
	public var colorAdd(get,set) : Null<h3d.Vector>;
	public var colorMul(get,set) : Null<h3d.Vector>;
	public var colorMatrix(get,set) : Null<h3d.Matrix>;
	
	public var hasSkin(get,set) : Bool;
	public var skinMatrixes(get,set) : Array<h3d.Matrix>;
	
	public var lightSystem(get, set) : LightSystem;
	
	public var alphaMap(get, set): Texture;
	
	public var fog(get, set) : h3d.Vector;
	
	public var zBias(get, set) : Null<Float>;
	
	public var blendTexture(get, set) : Texture;
	
	public var killAlphaThreshold(get, set) : Float;
	
	
	public var shadowMap(null, set) : ShadowMap;
	public static var uid = 0;
	public var  id : Int = -1;
	
	public function new(texture : Texture, ?sh) {
		mshader = (sh==null) ? new MeshShader() : sh;
		super(mshader);
		this.texture = texture;
		useMatrixPos = true;
		killAlphaThreshold = 0.001;
		id = uid++;
	}

	
	override function clone( ?m : Material ) {
		var m = m == null ? new MeshMaterial(texture) : cast m;
		super.clone(m);
		
		m.useMatrixPos = useMatrixPos;
		m.uvScale = uvScale;
		m.uvDelta = uvDelta;
		m.killAlpha = killAlpha;
		m.hasVertexColor = hasVertexColor;
		m.hasVertexColorAdd = hasVertexColorAdd;
		m.hasSkin = hasSkin;
		
		m.colorAdd = colorAdd==null?null:colorAdd.clone();
		m.colorMul = colorMul == null?null:colorMul.clone();
		m.colorMatrix = colorMatrix == null?null:colorMatrix.clone();
		m.skinMatrixes = skinMatrixes == null?null:skinMatrixes.copy();
		
		m.lightSystem = lightSystem;
		m.alphaMap = alphaMap;
		m.fog = fog;
		m.setFastFog( mshader.fastFog, mshader.fastFogEq );
		m.zBias = zBias;
		m.blendTexture = blendTexture;
		m.killAlphaThreshold = killAlphaThreshold;
		m.glowAmount = glowAmount;
		
		m.glowColor = glowColor == null ? null : glowColor.clone();
		m.glowTexture = glowTexture;
		
		m.isOutline = isOutline;
		m.outlineSize = outlineSize;
		m.outlineColor = outlineColor;
		m.outlinePower = outlinePower;
		
		m.rimColor = rimColor;
		return m;
	}
	
	override function setup( ctx : h3d.scene.RenderContext ) {
		var engine = h3d.Engine.getCurrent();
		
		if (texture == null ) {
			texture = Texture.fromColor(0xffFF00FF);
		}

		mshader.mpos = useMatrixPos ? ctx.localPos : null;
		mshader.mproj = ctx.engine.curProjMatrix;
		mshader.tex = texture;
		
		mshader.isAlphaPremul = texture.flags.has(AlphaPremultiplied);
		
		if ( killAlpha && killAlphaThreshold <= 0.01 && blendSrc == One && blendDst == Zero) {
			if ( engine.driver.hasFeature( SampleAlphaToCoverage)) {
				mshader.killAlpha = false;
				sampleAlphaToCoverage = true;
			}
			else 
				if(!mshader.killAlpha) mshader.killAlpha = true;
		}
		
		if( mshader.isOutline || mshader.rimColor!=null) {
			mshader.cameraPos = ctx.camera.pos;
			//mshader.outlineProj = new h3d.Vector(ctx.camera.mproj._11, ctx.camera.mproj._22);
		}
	}
	
	function get_mshader() : MeshShader {
		return cast shader;
	}
	
	function set_mshader(v:MeshShader) : MeshShader {
		shader = (cast v);
		return v;
	}
	
	/**
		Set the DXT compression access mode for all textures of this material.
	**/
	public function setDXTSupport( enable : Bool, alpha = false ) {
		#if flash
		if( !enable ) {
			mshader.isDXT1 = false;
			mshader.isDXT5 = false;
		} else {
			mshader.isDXT1 = !alpha;
			mshader.isDXT5 = alpha;
		}
		#else
		throw "Not implemented";
		#end
	}
	
	inline function get_uvScale() {
		return mshader.uvScale;
	}

	inline function set_uvScale(v) {
		return mshader.uvScale = v;
	}

	inline function get_uvDelta() {
		return mshader.uvDelta;
	}

	inline function set_uvDelta(v) {
		return mshader.uvDelta = v;
	}

	inline function get_killAlpha() {
		return killAlpha=mshader.killAlpha;
	}

	inline function set_killAlpha(v) {
		return killAlpha=mshader.killAlpha = v;
	}

	inline function get_colorAdd() {
		return mshader.colorAdd;
	}

	inline function set_colorAdd(v) {
		return mshader.colorAdd = v;
	}

	inline function get_colorMul() {
		return mshader.colorMul;
	}

	inline function set_colorMul(v) {
		return mshader.colorMul = v;
	}

	inline function get_colorMatrix() {
		return mshader.colorMatrix;
	}

	inline function set_colorMatrix(v) {
		return mshader.colorMatrix = v;
	}
	
	inline function get_hasSkin() {
		return mshader.hasSkin;
	}
	
	inline function set_hasSkin(v) {
		return mshader.hasSkin = v;
	}

	inline function get_hasVertexColor() {
		return mshader.hasVertexColor;
	}
	
	inline function set_hasVertexColor(v) {
		return mshader.hasVertexColor = v;
	}
	
	inline function get_hasVertexColorAdd() {
		return mshader.hasVertexColorAdd;
	}
	
	inline function set_hasVertexColorAdd(v) {
		return mshader.hasVertexColorAdd = v;
	}
	
	inline function get_skinMatrixes() {
		return mshader.skinMatrixes;
	}
	
	function set_skinMatrixes( v : Array<h3d.Matrix> ) {
		//if ( System.debugLevel >= 2) trace('set_skinMatrixes ${v[0]}');
		#if debug
		if( v != null && v.length > 35 )
			throw "Maximum 35 bones are allowed for skinning (has " + v.length + ")";
		#end
		return mshader.skinMatrixes = v;
	}
	
	inline function get_lightSystem() : LightSystem {
		return mshader.lightSystem;
	}

	inline function set_lightSystem(v:LightSystem) {
		if( v != null && hasSkin && v.dirs.length + v.points.length > 6 )
			throw "Maximum 6 lights are allowed with skinning ("+(v.dirs.length+v.points.length)+" set)";
		return mshader.lightSystem = v;
	}
	
	inline function get_alphaMap() {
		return mshader.alphaMap;
	}
	
	inline function set_alphaMap(m) {
		mshader.hasAlphaMap = m != null;
		return mshader.alphaMap = m;
	}
	
	inline function get_zBias() {
		return mshader.hasZBias ? mshader.zBias : null;
	}

	inline function set_zBias(v : Null<Float>) {
		mshader.hasZBias = v != null;
		mshader.zBias = v;
		return v;
	}
	
	inline function get_glowTexture() {
		return mshader.glowTexture;
	}

	inline function set_glowTexture(t) {
		mshader.hasGlow = t != null;
		if( t != null && mshader.glowAmount == null ) mshader.glowAmount = new h3d.Vector(1, 1, 1);
		return mshader.glowTexture = t;
	}
	
	inline function get_glowAmount() {
		if( mshader.glowAmount == null ) mshader.glowAmount = new h3d.Vector(1, 1, 1);
		return mshader.glowAmount.x;
	}

	inline function set_glowAmount(v) {
		if( mshader.glowAmount == null ) mshader.glowAmount = new h3d.Vector(1, 1, 1);
		mshader.glowAmount.set(v, v, v);
		return v;
	}
	
	inline function get_glowColor() {
		if( mshader.glowAmount == null ) mshader.glowAmount = new h3d.Vector(1, 1, 1);
		return mshader.glowAmount;
	}

	inline function set_glowColor(v) {
		return mshader.glowAmount = v;
	}

	inline function get_fog() {
		return mshader.fog;
	}

	inline function set_fog(v) {
		return mshader.fog = v;
	}
	
	inline function get_blendTexture() {
		return mshader.blendTexture;
	}
	
	inline function set_blendTexture(v) {
		mshader.hasBlend = v != null;
		return mshader.blendTexture = v;
	}
	
	inline function get_killAlphaThreshold() {
		return mshader.killAlphaThreshold;
	}
	
	inline function set_killAlphaThreshold(v) {
		return mshader.killAlphaThreshold = v;
	}
	
	inline function set_shadowMap(v:ShadowMap) {
		if( v != null ) {
			mshader.hasShadowMap = true;
			mshader.shadowColor = v.color;
			mshader.shadowTexture = v.texture;
			mshader.shadowLightProj = v.lightProj;
			mshader.shadowLightCenter = v.lightCenter;
		} else
			mshader.hasShadowMap = false;
		return v;
	}
	
	public var isOutline(get, set) : Bool;
	public var outlineColor(get, set) : Int;
	public var outlineSize(get, set) : Float;
	public var outlinePower(get, set) : Float;
	
	
	
	public var rimColor(get, set) : h3d.Vector;
	
	inline function get_isOutline()		return mshader.isOutline;
	inline function set_isOutline(v) 	return mshader.isOutline = v;
	
	inline function get_rimColor()		return mshader.rimColor;
	inline function set_rimColor(v) 	return mshader.rimColor = v;

	inline function get_outlineColor() 	return mshader.outlineColor;
	inline function set_outlineColor(v) return mshader.outlineColor = v;
	inline function get_outlineSize() 	return mshader.outlineSize;
	inline function set_outlineSize(v) 	return mshader.outlineSize = v;
	inline function get_outlinePower() 	return mshader.outlinePower;
	inline function set_outlinePower(v) return mshader.outlinePower = v;
	
	public function setBlendMode(b:h2d.BlendMode) {
		blendMode = b;
		
		var isTexPremul = false;
		var engine = h3d.Engine.getCurrent();
		
		if( texture!=null)				isTexPremul  = texture.flags.has(AlphaPremultiplied);
		if (!killAlpha) 				sampleAlphaToCoverage = false; 
		if( b != None && killAlpha)		mshader.killAlpha = true;
		
		switch( b ) {
			case Normal:
				blend(isTexPremul ? One : SrcAlpha, OneMinusSrcAlpha);
			case None:
				blend(One, Zero);
			case Add:
				blend(isTexPremul ? One : SrcAlpha, One);
			case SoftAdd:
				blend(OneMinusDstColor, One);
			case Multiply:
				blend(DstColor, OneMinusSrcAlpha);
			case Erase:
				blend(Zero, OneMinusSrcAlpha);
			case SoftOverlay:
				blend(DstColor, One);
		}
		return b;
	}
	
	public function setFastFog(fogColor:h3d.Vector,fogParams:h3d.Vector) {
		mshader.fastFog = fogColor;
		mshader.fastFogEq = fogParams; 
	}
	
	public override function ofData(mdata:hxd.fmt.h3d.Data.Material, texLoader:String->h3d.mat.Texture ) {
		this.texture = texLoader(mdata.diffuseTexture); 
		
		if(null!=mdata.alphaTexture)
			this.alphaMap = texLoader(mdata.alphaTexture);
		
		this.killAlpha = mdata.alphaKill != null;
		this.killAlphaThreshold = mdata.alphaKill;
		
		super.ofData(mdata, texLoader);
		
		this.colorMul = mdata.colorMultiply;
	}
}
