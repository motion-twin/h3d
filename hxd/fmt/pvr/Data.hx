/*
 * format - haXe File Formats
 *
 * Copyright (c) 2008-2020, The Haxe Project Contributors
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   - Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   - Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE HAXE PROJECT CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE HAXE PROJECT CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 */
package hxd.fmt.pvr;

@:publicFields
class Pointer {
	var bytes : haxe.io.Bytes;
	var pos:Int;
	var len:Int;
	
	function new (b, p, l) {
		this.bytes = b;
		this.pos = p;
		this.len = l;
	}
	
	function toString() return 'bytes:$bytes pos:$pos len:$len';
}

//Compressed pixel formats
enum PixelFormat{
	PVRTCI_2bpp_RGB;
	PVRTCI_2bpp_RGBA;
	PVRTCI_4bpp_RGB;
	PVRTCI_4bpp_RGBA;
	PVRTCII_2bpp;
	PVRTCII_4bpp;
	ETC1;
	DXT1;
	DXT2;
	DXT3;
	DXT4;
	DXT5;


	//These formats are identical to some DXT formats.
	//BC1 = ePVRTPF_DXT1,
	//BC2 = ePVRTPF_DXT3,
	//BC3 = ePVRTPF_DXT5,

	//These are currently unsupported:
	BC4;
	BC5;
	BC6;
	BC7;

	//These are supported
	UYVY;
	YUY2;
	BW1bpp;
	SharedExponentR9G9B9E5;
	RGBG8888;
	GRGB8888;
	ETC2_RGB;
	ETC2_RGBA;
	ETC2_RGB_A1;
	EAC_R11;
	EAC_RG11;
}


@:publicFields
class Header {
	var version : Int;
	var flags :Int;
	var pixelFormat:haxe.Int64;
	var colourSpace: Int;
	
	var channelType : Int;
	var height : Int;
	var width:Int;
	var depth:Int;
	
	var numSurfaces:Int;
	var numFaces:Int;
	
	var mipmapCount:Int;
	var metadataSize:Int;
	
	inline function new() {}
	inline function getFormat() return Type.createEnumIndex( PixelFormat, haxe.Int64.getLow(pixelFormat));
	
	static inline var PVRTEX3_PREMULTIPLIED = (1<<1);
}

@:publicFields
class Metadata {
	var fourcc : Int;
	var key:Int;
	var size:Int;
	var data: Pointer;
	inline function new(){}
}


typedef Const<T> = T;

/**
 */
@:publicFields
class Data {
	var header:Header;
	var meta:Array<Metadata>;
	var bytes:Const<haxe.io.Bytes>;
	var dataStart:Int;
	
	var mipmapCount(get, null) : Int;
	
	inline function new(){}
	
	private inline function get_mipmapCount():Int{
		return header.mipmapCount;
	}

	#if sys
	function getGlFormat() {
		var GL = h3d.impl.GlDriver;
		
		return switch(header.getFormat()) {
			case DXT1: GL.COMPRESSED_RGBA_S3TC_DXT1_EXT;
			case DXT3: GL.COMPRESSED_RGBA_S3TC_DXT3_EXT;
			case DXT5: GL.COMPRESSED_RGBA_S3TC_DXT5_EXT;
			
			case PVRTCI_2bpp_RGB: 	GL.COMPRESSED_RGB_PVRTC_2BPPV1_IMG;
			case PVRTCI_2bpp_RGBA:	GL.COMPRESSED_RGBA_PVRTC_2BPPV1_IMG;
			
			case PVRTCI_4bpp_RGB: 	GL.COMPRESSED_RGB_PVRTC_4BPPV1_IMG;
			case PVRTCI_4bpp_RGBA: 	GL.COMPRESSED_RGBA_PVRTC_4BPPV1_IMG;
			
			case PVRTCII_2bpp:		GL.COMPRESSED_RGBA_PVRTC_2BPPV2_IMG;
			case PVRTCII_4bpp:		GL.COMPRESSED_RGBA_PVRTC_4BPPV2_IMG;
				
			default: throw "todo !"+header.getFormat();
		}
	}
	#end
	
	function getBpp() {
		return switch(header.getFormat()) {
			case PVRTCI_2bpp_RGB	: 2;
			case PVRTCI_2bpp_RGBA	: 2;
			case PVRTCI_4bpp_RGB 	: 4;
			case PVRTCI_4bpp_RGBA	: 4;
			case PVRTCII_2bpp 		: 2;
			case PVRTCII_4bpp		: 4;
			case ETC1				: 3;		//todo check this
			
			default: 0; 
			case RGBG8888,GRGB8888:32;
			
			case ETC2_RGB : 3;
			case ETC2_RGBA : 3;
			case ETC2_RGB_A1 : 4;
			
			case EAC_R11:4; 
			case EAC_RG11:4;
			
			case DXT1: 4;
			case DXT3: 8;
			case DXT5: 8;
		}
	}
	
	inline function isCompressed() {
		return switch( header.getFormat()) {
			case 
				PVRTCI_2bpp_RGB, PVRTCI_2bpp_RGBA, PVRTCI_4bpp_RGB, PVRTCI_4bpp_RGBA, PVRTCII_2bpp, PVRTCII_4bpp, 
				DXT1, DXT2, DXT3, DXT4, DXT5, 
				ETC1, ETC2_RGB, ETC2_RGBA, ETC2_RGB_A1, ETC1, EAC_R11, EAC_RG11: true;
			default:false;
		};
	}
	
	function fixSize(width, height) : Null<Int> {
		var max = hxd.Math.imax;
		
		return
		switch(header.getFormat()) {
			case PVRTCI_2bpp_RGB, PVRTCI_2bpp_RGBA, PVRTCII_2bpp:
				( max(width, 8) * max(height, 8) * 4 + 7) >>3;
				
			case PVRTCI_4bpp_RGB, PVRTCI_4bpp_RGBA, PVRTCII_4bpp:
				( max(width, 16) * max(height, 8) * 2 + 7) >>3;
				
			default:null;
		}
	}
	
	function get(mip = 0, surface = 0, face = 0, depth = 0) : Null<Pointer> {
		if ( mip < 0 ) mip =  mipmapCount + mip;
		
		if(isCompressed()){
			var ptr = 0;
			var mipLevel = 0;
			trace("mipmaps:"+mipmapCount+" searching:"+mip);
			while (mipLevel <= mip) {
				var mip0w = getMipWidth(mipLevel);
				var mip0h = getMipHeight(mipLevel);
			
				var size = (mip0w * mip0h * getBpp()) >> 3;//go to bytes
				trace("mip0w:"+mip0w);
				trace("mip0h:"+mip0h);
				
				var s = fixSize( mip0w, mip0h );
				if ( s != null ) size = s;
				
				trace("reading buffer:" + size +" at:"+dataStart);
				
				for ( s in 0...header.numSurfaces) {
					for ( f in 0...header.numFaces) {
						for ( d in 0...header.depth ) {
							if ( mipLevel == mip && d == depth && f == face && s == surface && mipLevel == mip) {
								trace("retrieved !");
								return new Pointer(bytes, dataStart + ptr, size);
							}
							ptr += size;
						}
					}
				}
				mipLevel++;
			}
			return null;
		}
		else //todo
			return null;
	}
	
	
	static inline function posMod( i :Int,m:Int ) {
		var mod = i % m;
		return (mod >= 0)
		? mod
		: mod + m;
	}

	
	public inline function getMipWidth(mipLevel : Int){
		var miplevel = posMod(mipmapCount + mipLevel, mipmapCount);
		var l = header.width >> miplevel;
		if ( l <= 0) l = 1;
		return l;
	}
	
	public inline function getMipHeight(mipLevel : Int){
		var miplevel = posMod(mipmapCount + mipLevel, mipmapCount);
		var l = header.height  >> miplevel;
		if ( l <= 0) l = 1;
		return l;
	}
	
	#if h3d
	public function toPixels( ?mipLevel : Int = 0, ?frame = 0, ?face = 0, ?depth = 0 ) : hxd.Pixels {
		if ( isCompressed() ) {
			var ptr = get(mipLevel, frame, face, depth); hxd.Assert.notNull( ptr );
		
			var lwidth = getMipWidth(mipLevel);
			var lheight = getMipHeight(mipLevel);
			
			#if sys
			var pix = new hxd.Pixels(lwidth, lheight, bytes, Compressed(getGlFormat()), ptr.pos );
			pix.flags.set(ReadOnly);
			pix.flags.set(Compressed);
			#else 
			var fmt : hxd.PixelFormat = null;
			var pix = new hxd.Pixels(lwidth, lheight, bytes, fmt, ptr.pos );
			pix.flags.set(ReadOnly);
			#end
			
			return pix;
		}
		else {
			throw "TODO";
		}
	}
	#end
}
