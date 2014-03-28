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
package format.vtf;
import format.vtf.Data;
import format.vtf.Data.*;
import haxe.EnumFlags;
import haxe.io.Bytes;

class Reader {
	var input : haxe.io.BytesInput;
	var bytes : haxe.io.Bytes; 
	
	public var checkCRC : Bool;
	
	public function new(bytes : haxe.io.Bytes ) {
		this.bytes = bytes;
		input = new haxe.io.BytesInput(bytes);
		input.bigEndian = false;
		checkCRC = true;
	}
	
	public function read() : Data {
		var i = input;
		for( b in ['V'.code,'T'.code,'F'.code, 0] )
			if ( i.readByte() != b ) {
				i.position = 0;
				throw "Invalid VTF header :" + i.readString(10);
			}
				
		var d = new Data();
		d.bytes = bytes;
		d.version = i.readInt32() << 8 | i.readInt32();
		var vMin = d.version >> 8;
		var vMax = d.version & 0xFF;
		
		if ( vMin > 2 && vMin < 5 )
			throw "unsupported vtf..well untested... vtf format"+d.major() + "." + d.minor();
		
		d.headerSize = i.readInt32();
		d.width = i.readInt16();
		d.height = i.readInt16();
		d.flags = haxe.EnumFlags.ofInt(i.readInt32());
		d.frames = i.readInt16();
		d.firstFrame = i.readInt16();
		var pad = i.readInt32();
		d.reflectivity = [i.readFloat(), i.readFloat(), i.readFloat()];
		var pad = i.readInt32();
		d.bumpmapScale = i.readFloat();
		
		var fmt = i.readInt32();
		d.highResImageFormat = (fmt == -1) ? null : Type.createEnumIndex(ImageFormat,fmt);
		d.mipmapCount = i.readByte();
		
		var fmt = i.readInt32();
		d.lowResImageFormat = (fmt == -1) ? null : Type.createEnumIndex(ImageFormat,fmt);
		d.lowResImageWidth = i.readByte();
		d.lowResImageHeight = i.readByte();
		d.depth = i.readInt16();
		
		if ( d.minor() < VTF_MINOR_VERSION_MIN_RESOURCE) {
			d.numResources = 0;
			i.position = d.headerSize;
			
			var size  = d.lowResImageWidth * d.lowResImageHeight * getBitStride(d.lowResImageFormat);
			size >>= 3; //get in bytes instead of bits.
			d.lowRes = (size > 0 ) ? new ImagePointer(bytes, i.position, size ) : null;
			i.position += size;
			
			d.imageSet=[];
			for ( mips in 0...d.mipmapCount) {
				d.imageSet[mips] = [];
				for ( fr in 0...d.frames) {
					d.imageSet[mips][fr] = [];
					for ( fcs in 0...d.getFaceCount()) {
						d.imageSet[mips][fr][fcs] = [];
						for ( zslices in 0...d.depth ) {
							var miplevel = d.mipmapCount - mips;
							
							//extract current mip size
							var lwidth = d.width >> (miplevel-1);
							if ( lwidth <= 0) lwidth = 1;
							
							var lheight = d.height >> (miplevel-1);
							if ( lheight <= 0) lheight = 1;
							//trace(lwidth + " " + lheight);
							var size  = lwidth * lheight * getBitStride(d.highResImageFormat);
							size >>= 3; //get in bytes instead of bits.
							trace('img size:'+size+" pos:"+i.position+" hd size:"+d.headerSize );
							d.imageSet[mips][fr][fcs][zslices] =  new ImagePointer(bytes, i.position, size);
							i.position += size;
						}
					}
				}
			}
			//var a = 0;
		}
		else {
			var uiThumbnailBufferOffset  = 0;
			var uiImageDataOffset  = 0;
			
			for( _ in 0...3) i.readByte(); 
			d.numResources = i.readInt32();
			d.resources = [];
			
			for( _ in 0...8) i.readByte();
			for (n in 0...d.numResources) {
				var t : Dynamic = { };
				t.type = i.readInt32();
				var flags = t >> 24;
				t.data = i.readInt32();
				d.resources[n] = cast t;
				var r = d.resources[n];
				
				if ( t.type == VTF_LEGACY_RSRC_LOW_RES_IMAGE() ) {
					uiThumbnailBufferOffset = t.data;
				}
				else if ( t.type == VTF_LEGACY_RSRC_IMAGE()) {
					uiImageDataOffset = t.data;
				}
				else if ( (flags & RSRCF_HAS_NO_DATA_CHUNK) == 0) {
					//there is a resource to load
					var lsize =  i.readInt32();
					var lpos = i.position;
					r.ptr = new ImagePointer(bytes,lpos,lsize);
					i.position += lsize;
				}
			}
			
			var loPos = uiThumbnailBufferOffset;
			if ( d.lowResImageFormat != null) {
				i.position = loPos;
				var size  = d.lowResImageWidth * d.lowResImageHeight * getBitStride(d.lowResImageFormat);
				size >>= 3; //get in bytes instead of bits.
				d.lowRes = new ImagePointer(bytes, i.position, size );
				i.position += size;
			}
			var hiPos = uiImageDataOffset;
			if ( d.highResImageFormat != null) {
				i.position = hiPos;
				d.imageSet=[];
				for ( mips in 0...d.mipmapCount) {
					d.imageSet[mips] = [];
					for ( fr in 0...d.frames) {
						d.imageSet[mips][fr] = [];
						for ( fcs in 0...d.getFaceCount()) {
							d.imageSet[mips][fr][fcs] = [];
							for ( zslices in 0...d.depth ) {
								var miplevel = d.mipmapCount - mips;
							
								//extract current mip size
								var lwidth = d.width >> (miplevel-1);
								if ( lwidth <= 0) lwidth = 1;
								
								var lheight = d.height >> (miplevel-1);
								if ( lheight <= 0) lheight = 1;
								
								var size  = lwidth * lheight * getBitStride(d.highResImageFormat);
								size >>= 3; //get in bytes instead of bits.
								d.imageSet[mips][fr][fcs][zslices] =  new ImagePointer(bytes, i.position, size);
								i.position += size;
							}
						}
					}
				}
			}
		}
		
		input  = null;
		bytes = null;
		
		return d;
	}
	
	/**
	 * @return bits size
	 */
	public function getBitStride(format:ImageFormat) {
		return
		if ( format == null ) 
			0;
		else 
		switch(format)  {
			case RGBA8888 : 			32;
			case ABGR8888 : 			32;
			case RGB888 : 				24;
			case BGR888 : 				24;
			case RGB565 : 				16;
			case I8 : 					8;
			case IA88 : 				16;
			case P8 :					8;
			case A8 : 					8;
			case RGB888_BLUESCREEN :	24;
			case BGR888_BLUESCREEN :	24;
			case ARGB8888 : 			32;
			case BGRA8888 : 			32;
			case DXT1 : 				4;
			case DXT3 : 				8;
			case DXT5 : 				8;
			case BGRX8888 : 			32;
			case BGR565 : 				16;
			case BGRX5551 : 			16;
			case BGRA4444 : 			16;
			case DXT1_ONEBITALPHA : 	4;
			case BGRA5551 : 			16;
			case UV88 : 				16;
			case UVWQ8888 : 			32;
			case RGBA16161616F : 		64;
			case RGBA16161616 : 		64;
			case UVLX8888 : 			32;
		}
	}
}

