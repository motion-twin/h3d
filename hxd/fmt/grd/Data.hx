package hxd.fmt.grd;

typedef Gradient = {
	name              : String,
	interpolation     : Float,
	colorStops        : Array<ColorStop>,
	transparencyStops : Array<TransparencyStop>,
	gradientStops     : Array<GradientStop>
}

typedef ColorStop = {
	color    : Color,
	location : Int,
	midpoint : Int,
	type     : ColorStopType,
}

enum ColorStopType {
	USER;
	BACKGROUND;
	FOREGROUND;
}

typedef TransparencyStop = {
	opacity  : Float,
	location : Int,
	midpoint : Int
}

enum Color {
	RGB(r:Float, g:Float, b:Float);
	HSB(h:Float, s:Float, b:Float);
}

typedef GradientStop = {
	opacity   : Float,
	colorStop : ColorStop
}

class Data extends haxe.ds.StringMap<Gradient> { }
