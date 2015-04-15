package hxd.fmt.idx;

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

class Writer {

	var output : haxe.io.Output;
	
	public function new(o : haxe.io.Output) {
		output = o;
		output.bigEndian = false;
		
	}
	
	public static function makeBitmapData( bmp:flash.display.BitmapData, premultiply = false) : Data {
		var data = new Data();
		var pidx = 0;
		
		data.width = bmp.width;
		data.height = bmp.height;
		
		data.index = new haxe.ds.Vector(data.width*data.height);
		
		data.paletteByRgba = new Map();
		data.paletteByIndex = [];
		
		for( y in 0...bmp.height )
			for( x in 0...bmp.width ){
				var rgba = bmp.getPixel32(x,y);
				
				var r = (rgba>>16)&255;
				var g = (rgba>>8)&255;
				var b = (rgba)&255;
				var a = (rgba>>>24)&255;
				//trace('in: $r $g $b $a');
				
				if( premultiply ){
					var afloat : Float = 255.0/a;
					var iafloat : Float = 1.0/afloat;
					
					var rf = (r/255.0);
					var gf = (g/255.0);
					var bf = (b/255.0);
					var af = (a/255.0);
					//trace('float: $rf $gf $bf $af');
					
					if( af >= 0.0001){
						rf*=af;
						gf*=af;
						bf*=af;
						//trace('premul: $rf $gf $bf $af');
						
						rf/=af;
						gf/=af;
						bf/=af;
						//trace('remul: $rf $gf $bf $af');
					}
					else {
						rf=gf=bf=0;
					}
					
					var ri=Math.round(rf*255.0);
					var gi=Math.round(gf*255.0);
					var bi=Math.round(bf*255.0);
					
					r = hxd.Math.iclamp(ri,0,255);
					g = hxd.Math.iclamp(gi,0,255);
					b = hxd.Math.iclamp(bi,0,255);
					
					//trace('pos premul: $r $g $b $a');
				}
				
				r >>= data.reduceR;
				g >>= data.reduceG;
				b >>= data.reduceB;
				a >>>= data.reduceA;
				
				r <<= data.reduceR;
				g <<= data.reduceG;
				b <<= data.reduceB;
				a <<= data.reduceA;
				
				//trace('out: $r $g $b $a');
				var rgba = (a<<24)|(r<<16)|(g<<8)|b;
				var idx = -1;
				if( data.paletteByRgba.exists(rgba))
					idx = data.paletteByRgba.get( rgba ).idx;
				else {
					idx = pidx;
					var e = new Data.Entry(pidx,rgba);
					data.paletteByRgba.set( rgba,e);
					data.paletteByIndex[pidx] = e.rgba;
					pidx++;
				}
				
				data.index[y*data.width+x] = idx;
			}
			
		data.nbBits = hxd.Math.highestBitIndex(data.paletteByIndex.length);
		return data;
	}
	
	/**
	32B img width
	32B img height
	32B paletteLength
	--B paletteByIndex
	32B nbBits of index elements
	w*h*nbBits*width*height index
	*/
	public function write(data:Data) {
		if( data.nbBits < 0 ) throw "assert";
		
		var o = output;
		
		o.writeInt32( data.reduceR );
		o.writeInt32( data.reduceG );
		o.writeInt32( data.reduceB );
		o.writeInt32( data.reduceA );
		
		o.writeInt32( data.nbBits );
		o.writeInt32( data.width );
		o.writeInt32( data.height );
		o.writeInt32( data.paletteByIndex.length );
		for( i in 0...data.paletteByIndex.length)
			o.writeInt32( data.paletteByIndex[i]);
		var writer	= new format.tools.BitsOutput(o);
		for( i in 0...data.width*data.height)
			writer.writeBits(data.nbBits,data.index[i]);
		writer.flush();
	}
	
}