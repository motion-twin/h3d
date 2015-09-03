package h2d;

import h2d.col.Point;
import h3d.anim.Animation;

enum Align {
	Left;
	Right;
	Center;
}

class TextLayoutInfos { 
	public var textAlign:Align;
	public var maxWidth:Null<Float>;
	public var lineSpacing:Int;
	public var letterSpacing:Int;
	
	public inline function new(t,m,lis,les) {
		textAlign = t;
		maxWidth = m;
		lineSpacing = lis;
		letterSpacing = les;
	}
}

interface ITextPos {
	public function reset():Void;
	public function add(x:Int, y:Int, t:h2d.Tile):Void;
}

class TileGroupAsPos implements ITextPos {
	var tg:TileGroup;
	public inline function new(tg) {
		this.tg = tg;
	}
	
	public inline function reset() {
		tg.reset();
	}
	
	public inline function add(x:Int,y:Int,t:h2d.Tile) {
		tg.add(x,y,t);
	}
}

/**
 * @see h2d.Font for the font initalisation
 *
 * @usage
 * 	fps=new h2d.Text(font, root);
 *	fps.textColor = 0xFFFFFF;
 *	fps.dropShadow = { dx : 0.5, dy : 0.5, color : 0xFF0000, alpha : 0.8 };
 *	fps.text = "";
 *	fps.x = 0;
 *	fps.y = 400;
 *	fps.name = "tf";
 */
class Text extends Drawable implements IText {

	public var font(default, set) : Font;
	public var text(default, set) : String;
	
	var utf : hxd.IntStack = new hxd.IntStack();
	
	/**
	 * Does not take highter bits alpha into account
	 */
	public var textColor(default, set) : Int;
	public var maxWidth(default, set) : Null<Float>;
	public var dropShadow : { dx : Float, dy : Float, color : Int, alpha : Float };

	public var textWidth(get, null) : Int;
	public var textHeight(get, null) : Int;
	public var textAlign(default, set) : Align;
	public var letterSpacing(default,set) : Int;
	public var lineSpacing(default,set) : Int;

	public var numLines(default, null):Int;
	/**
	 * Glyph is stored as child
	 */
	var glyphs : TileGroup;

	public function new( font : Font, ?parent, ?sh:h2d.Drawable.DrawableShader) {
		super(parent,sh);
		this.font = font;
		
		textAlign = Left;
		letterSpacing = 1;
		text = "";
		textColor = 0xFFFFFFFF;
	}
	
	public inline function nbQuad() {
		return dropShadow == null ? utf.length : utf.length*2;
	}
	
	public override function clone<T>(?s:T) : T {
		var t : Text = (s == null) ? new Text(font, parent) : cast s;
		
		var g = glyphs;
		
		var idx = getChildIndex(glyphs);
		glyphs.remove();
		super.clone(t);//skip glyph cloning
		addChildAt(glyphs, idx);
		
		t.text = text;
		t.textColor = textColor;
		t.maxWidth = maxWidth;
		
		var ds = dropShadow;
		t.dropShadow = { dx:ds.dx, dy:ds.dy, color:ds.color, alpha:ds.alpha };
		
		t.textAlign = textAlign;
		t.letterSpacing = letterSpacing;
		t.lineSpacing = lineSpacing;
		
		return cast t;
	}

	function set_font(font) {
		if( glyphs != null && font == this.font )
			return font;
		this.font = font;
		if( glyphs != null ) glyphs.remove();
		glyphs = new TileGroup(font == null ? null : font.tile, this, shader);
		shader = glyphs.shader;
		rebuild();
		return font;
	}

	override function set_color(v:h3d.Vector) : h3d.Vector {
		alpha = v.w;
		set_textColor( v.toColor() );
		return v;
	}

	override function set_alpha(v) {
		super.alpha = v;
		set_textColor(textColor);
		return v;
	}

	function set_textAlign(a) {
		if( a == this.textAlign )
			return a;
		textAlign = a;
		rebuild();
		return a;
	}

	function set_letterSpacing(s) {
		if( s == letterSpacing )
			return s;
		letterSpacing = s;
		rebuild();
		return s;
	}

	function set_lineSpacing(s) {
		if( s == this.lineSpacing )
			return s;
		lineSpacing = s;
		rebuild();
		return s;
	}

	override function onAlloc() {
		super.onAlloc();
		rebuild();
	}

	var bulkColor : h3d.Vector = new h3d.Vector(1,1,1,1);
	var shadowColor : h3d.Vector = new h3d.Vector(1,1,1,1);

	override function draw(ctx:RenderContext) {
		glyphs.filter = filter;
		glyphs.blendMode = blendMode;
		
		if( dropShadow != null ) {
			glyphs.x += dropShadow.dx;
			glyphs.y += dropShadow.dy;
			glyphs.calcAbsPos();

			bulkColor.load( color );
			shadowColor.setColor( dropShadow.color );
			shadowColor.a = dropShadow.alpha * alpha;

			glyphs.color = shadowColor;

			glyphs.draw(ctx);
			glyphs.x -= dropShadow.dx;
			glyphs.y -= dropShadow.dy;

			glyphs.color = bulkColor;
		}
		super.draw(ctx);
	}

	override function get_width() {
		if ( !allocated ) onAlloc();
		return glyphs.width + ((dropShadow!=null)?dropShadow.dx:0.0);
	}

	override function get_height() {
		if ( !allocated ) onAlloc();
		return glyphs.height + ((dropShadow!=null)?dropShadow.dy:0.0);
	}

	function set_text(t:String) {
		var t = t == null ? "null" : t;
		if( t == this.text ) return t;
		this.text = t;
		
		utf.reset();
		haxe.Utf8.iter( text,utf.push );
		
		//rebuild();
		if ( !allocated ) 	onAlloc();
		else 				rebuild();
		return t;
	}

	function rebuild() {
		if ( allocated && text != null && font != null ) {
			var r = initGlyphs(utf);
			tWidth = r.x;
			tHeight = r.y;
		}
	}

	function textToUtf(str:String) {
		var s = new hxd.IntStack();
		haxe.Utf8.iter( str,s.push );
		return s;
	}
	
	public function calcTextWidth( text : String ) {
		return initGlyphs(textToUtf(text),false).x;
	}

	@:noDebug
	function initGlyphs( utf : hxd.IntStack, rebuild = true, lines : Array<Int> = null ) : h2d.col.PointInt {
		var info = new TextLayoutInfos(textAlign, maxWidth, lineSpacing, letterSpacing);
		var r = _initGlyphs( new TileGroupAsPos(glyphs), font, info, utf, rebuild, lines);
		numLines = 	if( font == null || r == null || info == null ) 1
					else Std.int(r.y / (font.lineHeight + info.lineSpacing));
		return r;
	}
	
	static var utf8Text = new hxd.IntStack();
	
	@:noDebug
	static
	function _initGlyphs( glyphs :ITextPos, font:h2d.Font,info : TextLayoutInfos, utf : hxd.IntStack, rebuild = true, lines : Array<Int> = null ) : h2d.col.PointInt {
		if ( rebuild ) glyphs.reset();
		var x = 0, y = 0, xMax = 0, prevChar = -1;
		var align = rebuild ? info.textAlign : Left;
		switch( align ) {
		case Center, Right:
			lines = [];
			var inf = _initGlyphs(glyphs,font,info,utf, false, lines);
			var max = (info.maxWidth == null) ? inf.x : Std.int(info.maxWidth);
			var k = align == Center ? 1 : 0;
			for( i in 0...lines.length )
				lines[i] = (max - lines[i]) >> k;
			x = lines.shift();
		default:
		}
		var dl = font.lineHeight + info.lineSpacing;
		var calcLines = !rebuild && lines != null;
		
		for ( i in 0...utf.length ) {
			var cc = utf.unsafeGet(i);
			var e = font.getChar(cc);
			var newline = cc == '\n'.code;
			var esize : Int = e.width + e.getKerningOffset(prevChar);
			// if the next word goes past the max width, change it into a newline
			if( font.charset.isBreakChar(cc) && info.maxWidth != null ) {
				var size = x + esize + info.letterSpacing;
				var k = i + 1, max = utf.length;
				var prevChar = prevChar;
				while( size <= info.maxWidth && k < utf.length ) {
					var cc = utf.unsafeGet(k++);
					if( font.charset.isSpace(cc) || cc == '\n'.code ) break;
					var e = font.getChar(cc);
					size += e.width + info.letterSpacing + e.getKerningOffset(prevChar);
					prevChar = cc;
				}
				if( size > info.maxWidth ) {
					newline = true;
					if( font.charset.isSpace(cc) ) e = null;
				}
			}
			if( e != null ) {
				if( rebuild ) glyphs.add(x, y, e.t);
				x += esize + info.letterSpacing;
			}
			if ( newline ) {
				if( x > xMax ) xMax = x;
				if( calcLines ) lines.push(x);
				if( rebuild )
					switch( align ) {
					case Left:
						x = 0;
					case Right, Center:
						x = lines.shift();
					}
				else
					x = 0;
				y += dl;
				prevChar = -1;
			} else
				prevChar = cc;
		}
		if( calcLines ) lines.push(x);
		
		var ret = new h2d.col.PointInt( 
			x > xMax ? x : xMax,
			x > 0 ? y + dl : y > 0 ? y : dl );
		return ret;
	}
	
	var tHeight : Null<Int> = null;
	function get_textHeight() : Int {
		if ( tHeight != null) return tHeight;
		var r = initGlyphs(utf, false);
		tWidth = r.x;
		tHeight = r.y;
		return tHeight;
	}

	var tWidth : Null<Int> = null;
	function get_textWidth() : Int {
		if ( tWidth != null) return tWidth;
		var r = initGlyphs(utf, false);
		tWidth = r.x;
		tHeight = r.y;
		return tWidth;
	}

	function set_maxWidth(w) {
		if( w == this.maxWidth )
			return w;
		maxWidth = w;
		rebuild();
		return w;
	}

	function set_textColor(c) {
		if( c == this.textColor )
			return c;
		this.textColor = c;
		if( glyphs!=null){
			glyphs.color = h3d.Vector.fromColor(c);
			glyphs.color.w = alpha;
		}
		return c;
	}

}
