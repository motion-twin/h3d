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
import h3d.mat.Texture;
import haxe.EnumFlags;
import haxe.io.Bytes;

using haxe.Int64;

#if h3d
import h3d.mat.Data;
#end

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
	
	function toString() return 'pos:$pos len:$len bytes:${bytes.get(0)} ${bytes.get(1)} ${bytes.get(2)} ${bytes.get(bytes.length-1)}';
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
	function getFormat() {
		return pixelFormat.getHigh() != 0 ? null : Type.createEnumIndex( PixelFormat, pixelFormat.getLow() );
	}
	
	static inline var PVRTEX3_PREMULTIPLIED = (1<<1);
}

@:publicFields
class Metadata {
	var fourcc : Int;
	var key:Int;
	var size:Int;
	var data: Pointer;
	inline function new() 		{ }
	
	public function validate() 	{
		var fcc0 = (fourcc >> 0) 	&0xFF;
		var fcc1 = (fourcc >> 8)	&0xFF;
		var fcc2 = (fourcc >> 16) 	&0xFF;
		var fcc3 = (fourcc >> 24)	&0xFF;
		
		var P = "P".code;
		var V = "V".code;
		var R = "R".code;
		
		if ( 	fcc0 != P 
		&&		fcc1 != V 
		&&		fcc2 != R ) {
			throw "PVR: Unknown meta data";
		}
		
		switch(key) {
			case 0 : //property atlassing
			case 1 : //normal map desc
			case 2 : //cubemap
			case 3 : //mapping direction
			case 4 : //mapping borders
			case 5 : //skipped padding
		}
	}
}

/**
 */
@:publicFields
class Data {
	var header:Header;
	var meta:Array<Metadata>;
	var bytes:haxe.io.Bytes;
	var dataStart:Int;
	
	public var mipmapCount(get, null) : Int;
	
	
	/**
	 * Texture chunks ordered by mip frame face depth
	 */
	var images : Array<Array<Array<Array<hxd.BytesView>>>>;
	
	public function isCubemap() {
		for ( h in meta ) {
			switch(h.key) {
				case 2:	return true;
				default:
			}
		}
		if ( header.numFaces == 6 )
			return true;
		else 
			return false;
	}
	
	inline function new(){}
	inline function get_mipmapCount():Int{
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
			
			case ETC1:				GL.ETC1_RGB8_OES;
				
			//usually add render systems as one deploys them...
			default: throw "todo !"+header.getFormat();
		}
	}
	#end
	
	
	function getPixelFormat() : hxd.PixelFormat {
		if( isCompressed())
			#if sys 
				return Compressed( getGlFormat() );
			#else
				return null;
			#end
		else {
			var lo = haxe.Int64.getLow( header.pixelFormat );
			var hi = haxe.Int64.getHigh( header.pixelFormat );
			
			var str = "";
			
			str += String.fromCharCode((lo >> 0) & 255);
			str += String.fromCharCode((lo >> 8) & 255);
			str += String.fromCharCode((lo >> 16) & 255);
			str += String.fromCharCode((lo >> 24) & 255);
			
			str = str.toUpperCase();
			
			var rs = hi&255;
			var gs = (hi >> 8)&255;
			var bs = (hi >> 16)&255;
			var as = (hi >> 24)&255;
			
			if( rs==8&&gs==8&&bs == 8&&as==8 )
				return switch(str) {
					case "RGBA": hxd.PixelFormat.RGBA;
					case "ARGB": hxd.PixelFormat.ARGB;
					case "BGRA": hxd.PixelFormat.BGRA;
					default: throw "unsupported pixel format "+str; 
				};
				
			if ( rs == 5 && gs == 6 && bs == 5)	
				return Mixed(5,6,5,0);
				
			if ( rs == 4 && gs == 4 && bs == 4 && as==4)	
				return Mixed(4,4,4,4);
				
			if ( rs == 5 && gs == 5 && bs == 5 && as==1)	
				return Mixed(5,5,5,1);
				
			throw "pixelFormat assertion "+rs+gs+bs+as;
			return null;
		}
	}
	
	function getBpp() {
		if ( haxe.Int64.getHigh(header.pixelFormat) != 0) {
			var sum = 0, hi = haxe.Int64.getHigh(header.pixelFormat);
			
			sum += (hi >> 24)	& 0xFF;
			sum += (hi >> 16)	& 0xFF;
			sum += (hi >> 8)	& 0xFF;
			sum += (hi >> 0)	& 0xFF;
			
			return sum;
		}
		else 
			return switch(header.getFormat()) {
				case PVRTCI_2bpp_RGB	: 2;
				case PVRTCI_2bpp_RGBA	: 2;
				case PVRTCI_4bpp_RGB 	: 4;
				case PVRTCI_4bpp_RGBA	: 4;
				case PVRTCII_2bpp 		: 2;
				case PVRTCII_4bpp		: 4;
				case ETC1				: 4;		
				
				default: 0; 
				case RGBG8888,GRGB8888:32;
				
				//begin unchecked
				case ETC2_RGB : 4;
				case ETC2_RGBA : 4;
				case ETC2_RGB_A1 : 4;
				
				case EAC_R11:4; 
				case EAC_RG11:4;
				//end unchecked
				
				case DXT1: 4;
				case DXT3: 8;
				case DXT5: 8;
			}
	}
	
	inline function isCompressed() {
		var fmt = header.getFormat();
		if ( fmt == null ) return false;
		
		return switch( fmt) {
			case 
				PVRTCI_2bpp_RGB, PVRTCI_2bpp_RGBA, PVRTCI_4bpp_RGB, PVRTCI_4bpp_RGBA, PVRTCII_2bpp, PVRTCII_4bpp, 
				DXT1, DXT2, DXT3, DXT4, DXT5, 
				ETC1, ETC2_RGB, ETC2_RGBA, ETC2_RGB_A1, ETC1, EAC_R11, EAC_RG11: true;
			default:false;
		};
	}
	
	public function hasAlpha() {
		return 
		if ( isCompressed() ) 
			true;
		else 
			(((haxe.Int64.getHigh( header.pixelFormat ))>>24)&255) > 0;
	}
	
	function get(mip = -1, surface = 0, face = 0, depth = 0) {
		var mip = ( mip < 0 ) ? (mip =  mipmapCount + mip) : mip;
		return images[mip][surface][face][depth];
	}
	
	public function getMipWidth(ml : Int) {
		var ml = ( ml < 0 ) ? mipmapCount + ml : ml;
		var l =  header.width >> ml;
		if ( l <= 0) l = 1;
		return l;
	}
	
	public function getMipHeight(ml : Int) {
		var ml = ( ml < 0 ) ? mipmapCount + ml : ml;
		var l =  header.height >> ml;
		if ( l <= 0) l = 1;
		return l;
	}
	
	#if h3d
	public function toPixels( ?mipLevel : Int = 0, ?frame = 0, ?face = 0, ?depth = 0 ) : hxd.Pixels {
		var ml 		= mipLevel;
		
		if ( mipLevel > mipmapCount ) throw "no such mipmap level" ;
		var ptr 	= get(ml, frame, face, depth); hxd.Assert.notNull( ptr );
		
		var lwidth 	= getMipWidth(ml);
		var lheight = getMipHeight(ml);
		
		var pix 	= new hxd.Pixels(lwidth, lheight,ptr, getPixelFormat() );
		
		pix.flags.set(ReadOnly);
		if ( isCompressed() )
			pix.flags.set(Compressed);
		if ( !hasAlpha() ) 
			pix.flags.set(NoAlpha);
			
		return pix;
	}
	
	
	function buildTexture() : h3d.mat.Texture {
		var fl = haxe.EnumFlags.ofInt(0);
		fl.set(TextureFlags.NoAlloc);
		if ( mipmapCount > 1 ) fl.set( TextureFlags.MipMapped );
		return new h3d.mat.Texture(header.width, header.height, fl);
	}
	
	function buildCubeTexture() : h3d.mat.Texture {
		var fl = haxe.EnumFlags.ofInt(0);
		fl.set(TextureFlags.NoAlloc);
		fl.set(TextureFlags.Cubic);
		if ( mipmapCount > 1 ) fl.set( TextureFlags.MipMapped );
		return new h3d.mat.Texture(header.width, header.height, fl);
	}
	
	/**
	 * reads and commit all available mipmaps
	 */
	public function toTexture( ?frame = 0, ?depth = 0, ?alloc = true) : h3d.mat.Texture {
		var fl = haxe.EnumFlags.ofInt(0);
		if ( isCubemap() ) return toCubeTexture(frame, depth);
		
		var tex = buildTexture();
		var lthis = this;
		function reallocTex(tex:h3d.mat.Texture) {
			tex.alloc();
			
			for ( i in 0...mipmapCount ) {
				var pixels = lthis.toPixels(i, frame, 0, depth );
				tex.uploadPixels( pixels, i , 0);
				pixels = null;
			}
		}
		tex.realloc = reallocTex.bind(tex);
		if( alloc ) tex.realloc();
		return tex;
	}
	
	public function toCubeTexture( ?frame = 0, ?depth = 0, ?alloc = true) : h3d.mat.Texture {
		var fl = haxe.EnumFlags.ofInt(0);
		if ( !isCubemap() ) throw "PVR: assert not a cubemap";
		
		var allMips = mipmapCount;
		var tex = buildCubeTexture();
		var lthis = this;
		
		function reallocTex(tex:h3d.mat.Texture) {
			tex.alloc();
			var sideMap = [0, 1, 3, 2, 4, 5];
			for ( i in 0...mipmapCount ) {
				for( side in 0...6) {
					var pixels = lthis.toPixels(i, frame, side, depth );
					tex.uploadPixels( pixels, i , sideMap[side]);
					pixels = null;
				}
			}
		}
		tex.realloc = reallocTex.bind(tex);
		if ( alloc ) tex.realloc();
		return tex;
	}
	#end
}
