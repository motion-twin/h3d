package h3d.impl;
import h2d.Tools;
import h3d.Engine;
import h3d.impl.Driver;

#if (flash&&!cpp&&!js)

@:allow(h3d.impl.Stage3dDriver)
class VertexWrapper {
	var vbuf : flash.display3D.VertexBuffer3D;
	var stride : Int;
	var written : Bool;
	var b : MemoryManager.BigBuffer;
	var size : Int;
	
	function new(vbuf, stride,size) {
		this.vbuf = vbuf;
		this.stride = stride;
		this.size = size;
	}
	
	@:noDebug
	function finalize( driver : Stage3dDriver ) {
		if( written ) return;
		written = true;
		// fill all the free positions that were unwritten with zeroes (necessary for flash)
		var f = b.free;
		while( f != null ) {
			if( f.count > 0 ) {
				var mem = f.count * b.stride * 4;
				if( cast driver.empty.length < cast mem ) driver.empty.length = mem;
				driver.uploadVertexBytes(b.vbuf, f.pos, f.count, haxe.io.Bytes.ofData(driver.empty), 0);
			}
			f = f.next;
		}
	}

}

class Stage3dDriver extends Driver {
	
	var s3d : flash.display.Stage3D;
	var ctx : flash.display3D.Context3D;
	var onCreateCallback : Bool -> Void;
	
	var curMatBits : Int;
	var curShader : hxsl.Shader.ShaderInstance;
	var curBuffer : VertexBuffer;
	var curMultiBuffer : Array<h3d.impl.Buffer.BufferOffset>;
	var curAttributes : Int;
	var curTextures : Array<h3d.mat.Texture>;
	var curSamplerBits : Array<Int>;
	var curTarget : h3d.mat.Texture;
	public var antiAlias : Int = 0;

	var engine(get, never) : h3d.Engine; 
	
	public var frame:Int;
	
	inline function get_engine() return h3d.Engine.getCurrent();  
	
	/**
	 * Allows to dump content into a CPU side texture
	 */
	public var onCapture : hxd.BitmapData -> Void;
	
	@:allow(h3d.impl.VertexWrapper)
	var empty : flash.utils.ByteArray;
	
	public function new() {
		empty = new flash.utils.ByteArray();
		s3d = flash.Lib.current.stage.stage3Ds[0];
		curTextures = [];
	}
	
	override function getDriverName(details:Bool) {
		return (ctx == null) ? "None" : (details ? ctx.driverInfo : ctx.driverInfo.split(" ")[0]);
	}
	
	override function begin( frame : Int ) {
		reset();
		this.frame = frame;
		h3d.Engine.getCurrent().textureSwitches = 0;
	}
	
	override function reset() {
		curMatBits = -1;
		curShader = null;
		curBuffer = null;
		curMultiBuffer = null;
		for( i in 0...curAttributes )
			ctx.setVertexBufferAt(i, null);
		curAttributes = 0;
		for( i in 0...curTextures.length )
			ctx.setTextureAt(i, null);
		curTextures = [];
		curSamplerBits = [];
	}
	
	override function init( onCreate, forceSoftware = false ) {
		this.onCreateCallback = onCreate;
		s3d.addEventListener(flash.events.Event.CONTEXT3D_CREATE, this.onCreate);
		
		/*
		#if flash12
		//experimental
		var vec = flash.utils.vector.toArrayCopy([
			flash.display3D.Context3DProfile.STANDARD_EXTENDED,flash.display3D.Context3DProfile.STANDARD,flash.display3D.Context3DProfile.STANDARD_CONSTRAINED
			flash.display3D.Context3DProfile.BASELINE_EXTENDED, flash.display3D.Context3DProfile.BASELINE, flash.display3D.Context3DProfile.BASELINE_CONSTRAINED
		]);
		s3d.requestContext3DMatchingProfiles(vec);
		#else
		*/
		#if (haxe_ver >= 3.2)
		s3d.requestContext3D( forceSoftware ? flash.display3D.Context3DRenderMode.SOFTWARE : flash.display3D.Context3DRenderMode.AUTO );
		#else
		s3d.requestContext3D( Std.string((forceSoftware ? flash.display3D.Context3DRenderMode.SOFTWARE : flash.display3D.Context3DRenderMode.AUTO) ));
		#end
	}
	
	function onCreate(_) {
		var old = ctx;
		if( old != null ) {
			if( old.driverInfo != "Disposed" ) throw "Duplicate onCreate()";
			old.dispose();
			hxsl.Shader.ShaderGlobals.disposeAll();
			ctx = s3d.context3D;
			onCreateCallback(true);
		} else {
			ctx = s3d.context3D;
			onCreateCallback(false);
		}
	}
	
	override function isHardware() {
		return ctx != null && ctx.driverInfo.toLowerCase().indexOf("software") == -1;
	}
	
	override function resize(width, height) {
		ctx.configureBackBuffer(width, height, antiAlias);
	}
	
	override function clear(r, g, b, a) {
		super.clear(r,g,b,a);
		ctx.clear(r, g, b, a, engine.depthClear);
	}
	
	override function dispose() {
		s3d.removeEventListener(flash.events.Event.CONTEXT3D_CREATE, onCreate);
		if( ctx != null ) ctx.dispose();
		ctx = null;
	}
	
	static var disposed = "Disposed";
	override function isDisposed() {
		return ctx == null || ctx.driverInfo == disposed;
	}
	
	override function present() {
		if ( onCapture != null ) {
			var w = engine.width;
			var h = engine.height;
			var b = new flash.display.BitmapData(w, h, true, 0x0);
			ctx.drawToBitmapData(b);
			onCapture(hxd.BitmapData.fromNative(b));
			onCapture = null;
		}
		
		ctx.present();
		selectMaterial(0);
		
	}
	
	override function disposeTexture( t : Texture ) {
		t.dispose();
	}
	
	override function allocVertex( count : Int, stride : Int , isDynamic = false) : VertexBuffer {
		var v;
		try {
			#if flash12
			v = ctx.createVertexBuffer(count, stride, isDynamic?"dynamicDraw":"staticDraw" );
			#else
			v = ctx.createVertexBuffer(count, stride  );
			#end
		} catch( e : flash.errors.Error ) {
			// too many resources / out of memory
			if( e.errorID == 3691 )
				return null;
			throw e;
		}
		return new VertexWrapper(v, stride, count*stride*4);
	}
	
	

	override function allocIndexes( count : Int ) : IndexBuffer {
		return ctx.createIndexBuffer(count);
	}
	
	override function allocTexture( t : h3d.mat.Texture ) : Texture {
		t.lastFrame = frame;
		
		return ( t.isCubic ) 
		? ctx.createCubeTexture(t.width, flash.display3D.Context3DTextureFormat.BGRA, t.isTarget, t.getMipLevels() )
		: ctx.createTexture(t.width, t.height, flash.display3D.Context3DTextureFormat.BGRA, t.isTarget,  t.getMipLevels() );
	}

	//todo support start end
	override function uploadTextureBitmap( t : h3d.mat.Texture, bmp : hxd.BitmapData, mipLevel : Int, side : Int ) {
		if ( t.t == null ) 
			t.t = allocTexture( t );
		
		t.lastFrame = frame;
				
		if( t.isCubic ) {
			var st : flash.display3D.textures.CubeTexture = flash.Lib.as(t.t, flash.display3D.textures.CubeTexture);
			st.uploadFromBitmapData(bmp.toNative(), side, mipLevel);
		}
		else {
			var t = flash.Lib.as(t.t, flash.display3D.textures.Texture);
			t.uploadFromBitmapData(bmp.toNative(), mipLevel);
		}
	}

	override function uploadTexturePixels( t : h3d.mat.Texture, pixels : hxd.Pixels, mipLevel : Int, side : Int ) {
		try{
			if( t == null)
				throw "no texture assert";
			
			if( pixels == null)
				throw "no pixels assert";
				
			if( pixels.bytes == null)
				throw "empty pixels";
				
			if ( t.t == null ) 
				t.t = allocTexture( t );
				
			t.lastFrame = engine.frameCount;
			pixels.convert(BGRA);
			
			var offset = pixels.bytes.position;
			var data = hxd.ByteConversions.bytesToByteArray(pixels.bytes.bytes);
			
			if( t.isCubic ) {
				var t = Std.instance(t.t, flash.display3D.textures.CubeTexture);
				if( t!= null)
					t.uploadFromByteArray(data, offset, side, mipLevel);
			}
			else {
				var t = Std.instance(t.t,  flash.display3D.textures.Texture);
				if ( t != null) 
					t.uploadFromByteArray(data, offset, mipLevel);
			}
		}catch(d:Dynamic){
			#if debug
				throw t.name+" "+t+" error "+d+" "+pixels;
			#end
		}
	}
	
	override function disposeVertex( v : VertexBuffer ) {
		v.vbuf.dispose();
		v.b = null;
	}
	
	override function disposeIndexes( i : IndexBuffer ) {
		i.dispose();
	}
	
	override function setDebug( d : Bool ) {
		if( ctx != null ) ctx.enableErrorChecking = d && isHardware();
	}
	
	override function uploadVertexBuffer( v : VertexBuffer, startVertex : Int, vertexCount : Int, buf : hxd.FloatBuffer, bufPos : Int ) {
		var data = buf.getNative();
		v.vbuf.uploadFromVector( bufPos == 0 ? data : data.slice(bufPos, vertexCount * v.stride + bufPos), startVertex, vertexCount );
	}

	override function uploadVertexBytes( v : VertexBuffer, startVertex : Int, vertexCount : Int, bytes : haxe.io.Bytes, bufPos : Int ) {
		v.vbuf.uploadFromByteArray( bytes.getData(), bufPos, startVertex, vertexCount );
	}

	override function uploadIndexesBuffer( i : IndexBuffer, startIndice : Int, indiceCount : Int, buf : hxd.IndexBuffer, bufPos : Int ) {
		var data = buf.getNative();
		i.uploadFromVector( bufPos == 0 ? data : data.slice(bufPos, indiceCount + bufPos), startIndice, indiceCount );
	}

	override function uploadIndexesBytes( i : IndexBuffer, startIndice : Int, indiceCount : Int, buf : haxe.io.Bytes, bufPos : Int ) {
		i.uploadFromByteArray(buf.getData(), bufPos, startIndice, indiceCount );
	}
	
	override function selectMaterial( mbits : Int ) {
		var diff = curMatBits ^ mbits;
		if( diff != 0 ) {
			if( curMatBits < 0 || diff&3 != 0 )
				ctx.setCulling(FACE[mbits&3]);
			if( curMatBits < 0 || diff & (0xFF << 6) != 0 )
				ctx.setBlendFactors(BLEND[(mbits>>6)&15], BLEND[(mbits>>10)&15]);
			if( curMatBits < 0 || diff & (15 << 2) != 0 )
				ctx.setDepthTest((mbits >> 2) & 1 == 1, COMPARE[(mbits>>3)&7]);
			if( curMatBits < 0 || diff & (15 << 14) != 0 )
				ctx.setColorMask((mbits >> 14) & 1 != 0, (mbits >> 14) & 2 != 0, (mbits >> 14) & 4 != 0, (mbits >> 14) & 8 != 0);
			curMatBits = mbits;
		}
	}

	@:noDebug
	override function selectShader( shader : Shader ) {
		var shaderChanged = false;
		var s = shader.getInstance();
		if( s.program == null ) {
			s.program = ctx.createProgram();
			var vdata = s.vertexBytes.getData();
			var fdata = s.fragmentBytes.getData();
			vdata.endian = flash.utils.Endian.LITTLE_ENDIAN;
			fdata.endian = flash.utils.Endian.LITTLE_ENDIAN;
			s.program.upload(vdata, fdata);
			curShader = null; // in case we had the same shader and it was disposed
		}
		if( s != curShader ) {
			ctx.setProgram(s.program);
			shaderChanged = true;
			s.varsChanged = true;
			// unbind extra textures
			var tcount : Int = s.textures.length;
			while( curTextures.length > tcount ) {
				curTextures.pop();
				ctx.setTextureAt(curTextures.length, null);
			}
			// force remapping of vertex buffer
			curBuffer = null;
			curMultiBuffer = null;
			curShader = s;
		}
		if( s.varsChanged ) {
			s.varsChanged = false;
			ctx.setProgramConstantsFromVector(flash.display3D.Context3DProgramType.VERTEX, 0, s.vertexVars.toData());
			ctx.setProgramConstantsFromVector(flash.display3D.Context3DProgramType.FRAGMENT, 0, s.fragmentVars.toData());
			for( i in 0...s.textures.length ) {
				var t = s.textures[i];
				if ( t == null || t.isDisposed() ) {
					if ( t.realloc != null ) 	t.realloc();
					if ( t.isDisposed() ) 		t = h2d.Tools.getEmptyTexture();
				}
				
				var cur = curTextures[i];
				t.lastFrame = engine.frameCount;
				
				if ( t != cur ) {
					ctx.setTextureAt(i, t.t);
					curTextures[i] = t;
					engine.textureSwitches++;
				}
				// if we have set one of the texture flag manually or if the shader does not configure the texture flags
				if( !t.hasDefaultFlags() || !s.texHasConfig[s.textureMap[i]] ) {
					if( cur == null || t.bits != curSamplerBits[i] ) {
						ctx.setSamplerStateAt(i, WRAP[t.wrap.getIndex()], FILTER[t.filter.getIndex()], MIP[t.mipMap.getIndex()]);
						curSamplerBits[i] = t.bits;
					}
				} else {
					// the texture flags has been set by the shader, so we are in an unkown state
					curSamplerBits[i] = -1;
				}
			}
		}
		
		for ( i in 0...s.textures.length ) {
			var t = s.textures[i];
			if ( t != null) {
				if ( t.isDisposed() && t.realloc != null)t.realloc();
				t.lastFrame = engine.frameCount;
			}
		}
		return shaderChanged;
	}
	
	override function selectBuffer( v : VertexBuffer ) {
		if( v == curBuffer )
			return;
		curBuffer = v;
		curMultiBuffer = null;
		if( v.stride < curShader.stride )
			throw "Buffer stride (" + v.stride + ") and shader stride (" + curShader.stride + ") mismatch";
		if( !v.written )
			v.finalize(this);
		var pos = 0, offset = 0;
		var bits = curShader.bufferFormat;
		while( offset < curShader.stride ) {
			var size = bits & 7;
			ctx.setVertexBufferAt(pos++, v.vbuf, offset, FORMAT[size]);
			offset += size == 0 ? 1 : size;
			bits >>= 3;
		}
		for( i in pos...curAttributes )
			ctx.setVertexBufferAt(i, null);
		curAttributes = pos;
	}
	
	override function getShaderInputNames() {
		return curShader.bufferNames;
	}
	
	override function selectMultiBuffers( buffers : Array<Buffer.BufferOffset> ) {
		// select the multiple buffers elements
		var changed = curMultiBuffer == null || curMultiBuffer.length != buffers.length;
		if( !changed )
			for( i in 0...curMultiBuffer.length )
				if( buffers[i] != curMultiBuffer[i] ) {
					changed = true;
					break;
				}
		if( changed ) {
			var pos = 0, offset = 0;
			var bits = curShader.bufferFormat;
			while( offset < curShader.stride ) {
				var size = bits & 7;
				var b = buffers[pos];
				if( b.b.next != null )
					throw "Buffer is split";
				if( !b.b.b.vbuf.written )
					b.b.b.vbuf.finalize(this);
				ctx.setVertexBufferAt(pos, b.b.b.vbuf.vbuf, b.offset, FORMAT[size]);
				offset += size == 0 ? 1 : size;
				bits >>= 3;
				pos++;
			}
			for( i in pos...curAttributes )
				ctx.setVertexBufferAt(i, null);
			curAttributes = pos;
			curBuffer = null;
			curMultiBuffer = buffers;
		}
	}
	
	override function draw( ibuf : IndexBuffer, startIndex : Int, ntriangles : Int ) {
		ctx.drawTriangles(ibuf, startIndex, ntriangles);
	}

	static var tmpRect : flash.geom.Rectangle = new flash.geom.Rectangle(0,0,0,0);
	
	override function setRenderZone( x : Int, y : Int, width : Int, height : Int ) {
		var tw = curTarget == null ? engine.width : curTarget.width;
		var th = curTarget == null ? engine.height : curTarget.height;
		
		if ( x == 0 && y == 0 && width < 0 && height < 0 ) {
			tmpRect.setTo(0, 0, tw, th);
			ctx.setScissorRectangle(tmpRect);
			tmpRect.setTo(0, 0, 0, 0);
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
			
			//this.width was never feed

			if( x + width > tw ) width = tw - x;
			if( y + height > th ) height = th - y;
			// for flash, width=0 means no scissor...
			if( width <= 0 ) { x = tw; width = 1; };
			if ( height <= 0 ) { y = th; height = 1; };
			
			tmpRect.setTo(x, y, width, height);
			ctx.setScissorRectangle(tmpRect);
			tmpRect.setTo(0, 0, 0, 0);
		}
	}

	override function setRenderTarget( t : Null<h3d.mat.Texture>, useDepth : Bool, clearColor : Null<Int> ) {
		if( t == null ) {
			ctx.setRenderToBackBuffer();
			curTarget = null;
		} else {
			if( t.t == null )
				t.alloc();
			ctx.setRenderToTexture(t.t, useDepth||t.flags.has(TargetUseDefaultDepth),antiAlias,0);
			curTarget = t;
			t.lastFrame = frame;
			reset();
			
			if( clearColor!=null)
				ctx.clear( ((clearColor>>16)&0xFF)/255 , ((clearColor>>8)&0xFF)/255, (clearColor&0xFF)/255, ((clearColor>>>24)&0xFF)/255);
		}
	}
	
	public override function query(q:Query) : Dynamic {
		switch(q) {
			case MaxTextureSize: return 2048;
			case MaxTextureSideSize: return 2048;
		}
	}
	
	static var BLEND = [
		flash.display3D.Context3DBlendFactor.ONE,
		flash.display3D.Context3DBlendFactor.ZERO,
		flash.display3D.Context3DBlendFactor.SOURCE_ALPHA,
		flash.display3D.Context3DBlendFactor.SOURCE_COLOR,
		flash.display3D.Context3DBlendFactor.DESTINATION_ALPHA,
		flash.display3D.Context3DBlendFactor.DESTINATION_COLOR,
		flash.display3D.Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA,
		flash.display3D.Context3DBlendFactor.ONE_MINUS_SOURCE_COLOR,
		flash.display3D.Context3DBlendFactor.ONE_MINUS_DESTINATION_ALPHA,
		flash.display3D.Context3DBlendFactor.ONE_MINUS_DESTINATION_COLOR
	];

	static var FACE = [
		flash.display3D.Context3DTriangleFace.NONE,
		flash.display3D.Context3DTriangleFace.BACK,
		flash.display3D.Context3DTriangleFace.FRONT,
		flash.display3D.Context3DTriangleFace.FRONT_AND_BACK,
	];

	static var COMPARE = [
		flash.display3D.Context3DCompareMode.ALWAYS,
		flash.display3D.Context3DCompareMode.NEVER,
		flash.display3D.Context3DCompareMode.EQUAL,
		flash.display3D.Context3DCompareMode.NOT_EQUAL,
		flash.display3D.Context3DCompareMode.GREATER,
		flash.display3D.Context3DCompareMode.GREATER_EQUAL,
		flash.display3D.Context3DCompareMode.LESS,
		flash.display3D.Context3DCompareMode.LESS_EQUAL,
	];

	static var FORMAT = [
		flash.display3D.Context3DVertexBufferFormat.BYTES_4,
		flash.display3D.Context3DVertexBufferFormat.FLOAT_1,
		flash.display3D.Context3DVertexBufferFormat.FLOAT_2,
		flash.display3D.Context3DVertexBufferFormat.FLOAT_3,
		flash.display3D.Context3DVertexBufferFormat.FLOAT_4,
	];
	
	static var WRAP = [
		flash.display3D.Context3DWrapMode.CLAMP,
		flash.display3D.Context3DWrapMode.REPEAT,
	];
	
	static var FILTER = [
		flash.display3D.Context3DTextureFilter.NEAREST,
		flash.display3D.Context3DTextureFilter.LINEAR,
	];
	
	static var MIP = [
		flash.display3D.Context3DMipFilter.MIPNONE,
		flash.display3D.Context3DMipFilter.MIPNEAREST,
		flash.display3D.Context3DMipFilter.MIPLINEAR,
	];
	
}
#end