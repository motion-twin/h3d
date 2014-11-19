package h2d.css;

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
}

enum RepeatStyle {
	Repeat;
	RepeatX;
	RepeatY;
	NoRepeat;
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
	
	public inline function new() { }
	public function getCustomTexture() : h3d.mat.Texture{
		return null;
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
