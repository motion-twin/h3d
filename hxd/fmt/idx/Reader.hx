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
package hxd.fmt.idx;

import hxd.fmt.idx.Data;
import hxd.fmt.idx.Data.*;

class Reader {
	var input : haxe.io.BytesInput;
	
	public inline function new(input ) {
		this.input = input;
		input.bigEndian = false;
	}
	
	public function read() : Data {
		var data = new Data();
		
		data.reduceR = input.readInt32();
		data.reduceG = input.readInt32();
		data.reduceB = input.readInt32();
		data.reduceA = input.readInt32();
		
		data.nbBits = input.readInt32();
		data.width = input.readInt32();
		data.height = input.readInt32();
		
		var paletteLen = input.readInt32();
		
		data.paletteByIndex = [];
		for( j in 0...paletteLen)
			data.paletteByIndex[j] = input.readInt32();
		var reader	= new format.tools.BitsInput(input);
		
		data.index = new haxe.ds.Vector(data.width*data.height);
		for( i in 0...data.width*data.height)
			data.index[i] = reader.readBits( data.nbBits );
		return data;
	}
	
	
}












