package format.tga;

@:publicFields
class Data {
	var stride : Int;
	var width : Int;
	var height : Int;
	
	var imageOffset : Int;
	var bytes : haxe.io.Bytes;
	
	public function new(b:haxe.io.Bytes) {
		bytes=b;
	}
	
	#if h3d
	var pixels : hxd.Pixels;
	public function toPixels() : hxd.Pixels {
		if( pixels == null){
			pixels = new hxd.Pixels(width, height, bytes, BGRA, imageOffset);
			pixels.flags.set(NO_REUSE);
		}
		return pixels;
	}
	#end
	
	function col(c:{r:Int,g:Int,b:Int,a:Int}) {
		return '{ r:${c.r}  g:${c.g} b:${c.b} a:${c.a} }';
	}
	
	//return s in BGRA
	public function getPixel(x:Int, y:Int) : {a:Int,r:Int,g:Int,b:Int} {
		var p = imageOffset + ((y*width)+x) * stride;
		
		var b = bytes.get(p);
		var g = bytes.get(p+1);
		var r = bytes.get(p+2);
		var a = bytes.get(p + 3);
		
		return { r:r, b:b, g:g, a:a };
	}
}