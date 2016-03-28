package hxd.snd;

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
		samples = reader.totalSample * Std.int(44100 / reader.header.sampleRate);
		output = new BytesOutput();
	}

	override public function decode(out:haxe.io.Bytes, outPos:Int, sampleStart:Int, sampleCount:Int) {
		var r = reader.header.sampleRate / 44100;
		reader.currentSample = Std.int(sampleStart * r);
		output.bytes = out;
		output.position = outPos;
		reader.read(output, sampleCount, 2, 44100, true);
	}


}
