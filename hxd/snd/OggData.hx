package hxd.snd;

#if stb_ogg_sound
private class BytesOutput extends haxe.io.Output {
	public var bytes : haxe.io.Bytes;
	public var position : Int;
	public function new() {
	}
	#if flash
	override function writeFloat(f) {
		bytes.setFloat(position, f);
		position += 4;
	}
	#else
	override function writeInt32(v) {
		bytes.setInt32(position, v);
		position += 4;
	}
	#end
}

class OggData extends Data {

	var reader : stb.format.vorbis.Reader;
	var output : BytesOutput;

	public function new( bytes : haxe.io.Bytes ) {
		reader = stb.format.vorbis.Reader.openFromBytes(bytes);
		samples = reader.totalSample;
		output = new BytesOutput();
		trace(samples);
	}

	override public function decode(out:haxe.io.Bytes, outPos:Int, sampleStart:Int, sampleCount:Int) {
		reader.currentSample = sampleStart;
		output.bytes = out;
		output.position = outPos;
		reader.read(output, sampleCount, 2, 44100, true);
	}


}

#else

class OggData extends Data {
	// buf int16
	var buf : haxe.io.Bytes;
	var channels : Int;
	var sampleRate : Int;
	var sampleRepeat : Int;

	public function new( bytes : haxe.io.Bytes ){
		var lbuf = lime.audio.AudioBuffer.fromBytes( bytes );
		buf = lbuf.data.toBytes();
		channels = lbuf.channels;
		sampleRate = lbuf.sampleRate;
		if( 2%channels != 0 )
			throw "invalid OGG channels";
		if( 44100%sampleRate != 0 )
			throw "invalid OGG sampleRate";
		
		sampleRepeat = Std.int(2/channels * 44100/sampleRate);
		samples = Std.int(((buf.length>>1) / channels / sampleRate) * 44100);
	}

	override public function decode(out:haxe.io.Bytes, outPos:Int, sampleStart:Int, sampleCount:Int ) {
		var d = buf.getData();
		var p = Std.int( sampleStart * 2 / sampleRepeat );
		var s = 0;
		while( s < sampleCount*2 ){
			out.setFloat( outPos+(s<<2), untyped __global__.__hxcpp_memory_get_i16( d, p<<1 ) / 0x7FFF );
			if( ++s%sampleRepeat == 0 )
				p++;
		}
	}
}

#end
