package h2d.css;
import h2d.css.Defs;

/**
 * Helper for css background color/gradient fill
 */
class Fill extends h2d.TileColorGroup {
	
	public var afterDraw : Null < Void->Void > ;
	var fill : { color:FillStyle, x:Float,y:Float,w:Float,h:Float };
	var line : { color:FillStyle, x:Float,y:Float,w:Float,h:Float, size: Float };
	var needReset : Bool;

	public function new(?parent) {
		super(h2d.Tools.getWhiteTile(), parent);
	}
	
	public inline function fillRectColor(x:Float, y:Float, w:Float, h:Float, c:Int) {
		content.rectColor(x, y, w, h, c);
	}

	public inline function fillRectGradient(x:Float, y:Float, w:Float, h:Float, ctl:Int, ctr:Int, cbl:Int, cbr:Int) {
		content.rectGradient(x, y, w, h, ctl, ctr, cbl, cbr);
	}
	
	public inline function addPoint(x:Float, y:Float, color:Int) {
		content.addPoint(x, y, color);
	}

	public function fillRect(fill:FillStyle,x:Float,y:Float,w:Float,h:Float) {
		switch( fill ) {
		case Transparent:
		case Color(c):
			fillRectColor(x,y,w,h,c);
		case Gradient(a,b,c,d):
			fillRectGradient(x,y,w,h,a,b,c,d);
		}
	}

	inline function clerp(c1:Int,c2:Int,v:Float) {
		var a = Std.int( (c1>>24) * (1-v) + (c2>>24) * v );
		var r = Std.int( ((c1>>16)&0xFF) * (1-v) + ((c2>>16)&0xFF) * v );
		var g = Std.int( ((c1>>8)&0xFF) * (1-v) + ((c2>>8)&0xFF) * v );
		var b = Std.int( (c1&0xFF) * (1-v) + (c2&0xFF) * v );
		return (a << 24) | (r << 16) | (g << 8) | b;
	}

	public function lineRect(fill:FillStyle, x:Float, y:Float, w:Float, h:Float, size:Float) {
		if( size <= 0 ) return;
		switch( fill ) {
		case Transparent:
		case Color(c):
			fillRectColor(x,y,w,size,c);
			fillRectColor(x,y+h-size,w,size,c);
			fillRectColor(x,y+size,size,h-size*2,c);
			fillRectColor(x+w-size,y+size,size,h-size*2,c);
		case Gradient(a,b,c,d):
			var px = size / w;
			var py = size / h;
			var a2 = clerp(a,c,py);
			var b2 = clerp(b,d,py);
			var c2 = clerp(a,c,1-py);
			var d2 = clerp(b,d,1-py);
			fillRectGradient(x,y,w,size,a,b,a2,b2);
			fillRectGradient(x,y+h-size,w,size,c2,d2,c,d);
			fillRectGradient(x,y+size,size,h-size*2,a2,clerp(a2,b2,px),c2,clerp(c2,d2,px));
			fillRectGradient(x+w-size,y+size,size,h-size*2,clerp(a2,b2,1-px),b2,clerp(c2,d2,1-px),d2);
		}
	}
	
	public override function drawRec(ctx) {
		super.drawRec(ctx);
		if ( afterDraw != null )
			afterDraw();
	}

	public function setFill( color, x, y, w, h ){
		if( fill == null || fill.x != x || fill.y != y || fill.w != w || fill.h != h || !Type.enumEq(fill.color,color) ){
			needReset = true;
			fill = {color: color, x: x, y: y, w: w, h: h};
		}
	}

	public function setLine( color, x, y, w, h, size ){
		if( line == null || line.x != x || line.y != y || line.w != w || line.h != h || !Type.enumEq(line.color,color) || line.size != size ){
			needReset = true;
			line = {color: color, x: x, y: y, w: w, h: h, size: size};
		}
	}

	public function softReset(){
		if( needReset ){
			needReset = false;
			reset();
			lineRect( line.color, line.x, line.y, line.w, line.h, line.size );
			fillRect( fill.color, fill.x, fill.y, fill.w, fill.h );
		}
	}


}
