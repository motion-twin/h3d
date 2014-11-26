package hxd;

enum PixelFormat {
	ARGB;
	BGRA;
	RGBA;
	
	Compressed( glCompressedFormat:Int );
	Mixed( red:Int, green:Int, blue:Int, alpha:Int );
}