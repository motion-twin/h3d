package h2d.css;
import h2d.css.Defs.TileStyle;
import h2d.Tile;

enum Unit {
	Pix( v : Float );
	Percent( v : Float );
	EM( v : Float );
}

enum FillStyle {
	Transparent;
	Color( c : Int );
	Gradient( a : Int, b : Int, c : Int, d : Int );
}

enum Layout {
	Horizontal;
	Vertical;
	Absolute;
	Dock;
	Inline;
}

enum DockStyle {
	Top;
	Left;
	Right;
	Bottom;
	Full;
}

enum TextAlign {
	Left;
	Right;
	Center;
}

enum TextVAlign {
	Top;
	Middle;
	Bottom;
}

enum TextTransform {
	None;
	Uppercase;
	Lowercase;
	Capitalize;
}

enum FileMode {
	Assets;
	Custom;
}

enum BackgroundSize{
	Auto; //fit to width and height
	Cover; //crop to width keeping aspect
	Contain; //crop to width keeping aspect
	Percent(w:Float, h:Float);
	Rect(w:Float, h:Float);
	Zoom;//fit to keep maximum sides aspect and center image
}

enum RepeatStyle {
	Repeat;
	RepeatX;
	RepeatY;
	NoRepeat;
}

enum ColorTransform {
	Brightness(v:Float);
	Contrast(v:Float);
	Hue(v:Float);
	Saturation(v:Float);
}

class TileStyle {
	public var mode 	: FileMode;
	public var file		: String;
	
	public var x 		: Float = 0.0;
	public var y 		: Float = 0.0;
	public var w 		: Float = 0.0;
	public var h 		: Float = 0.0;
	
	public var dx 		: Float = 0.0;
	public var dy 		: Float = 0.0;
	
	public var widthAsPercent = false;
	public var heightAsPercent = false;
	
	public var nativeWidth : Int;
	public var nativeHeight : Int;
	
	public inline function new() { }
	public function getCustomTexture() : h3d.mat.Texture{
		return null;
	}
	
	public var update : h2d.comp.Component -> Void;
	
	
	public function clone() {
		var t = new TileStyle();
		t.mode 				= mode;
		t.file				= file;
		                           
		t.x 				= x; 	
		t.y 				= y; 	
		t.w 				= w; 	
		t.h 				= h; 	
		
		t.dx 				= dx; 
		t.dy 				= dy; 
		
		t.widthAsPercent 	= widthAsPercent;
		t.heightAsPercent	= heightAsPercent; 
		                            
		t.nativeWidth     	= nativeWidth;
		t.nativeHeight    	= nativeHeight;
		
		t.update = update;
		
		return t;
	}
}



class CssClass {
	public var parent : Null<CssClass>;
	public var node : Null<String>;
	public var className : Null<String>;
	public var pseudoClass : Null<String>;
	public var id : Null<String>;
	public function new() {
	}
}
