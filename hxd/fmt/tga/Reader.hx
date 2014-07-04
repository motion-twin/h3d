package hxd.fmt.tga;

class Reader {
	var input : haxe.io.BytesInput;
	var bytes : haxe.io.Bytes; 
	
	public function new( bytes : haxe.io.Bytes ) {
		this.bytes = bytes;
		input = new haxe.io.BytesInput(bytes);
	}
	
	public function read() : Data {
		var id = 0;
		var d = new Data(bytes);
		
		inline function readByte() {return input.readByte();}
		
		readByte();
		readByte();
		
		var type		= readByte();							// [2] image type code 0x02=uncompressed BGR or BGRA
		readByte();readByte();readByte();readByte();readByte();readByte();readByte();readByte();readByte();
		d.width		= readByte() + (readByte() << 8);
		d.height		= readByte() + (readByte() << 8);
		var pixsize		= readByte();							// [16] image pixel size 0x20=32bit, 0x18=24bit
		d.stride = pixsize == 0x18 ? 3 : 4;
		
		readByte();												// [17] Image Descriptor Byte=0x28 (00101000)=32bit/origin upperleft/non-interleaved
		
		d.imageOffset = input.position;
		return d;
	}
}

