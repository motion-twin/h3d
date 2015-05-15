package h2d;

import h2d.SpriteBatch;
import hxd.Math;

class TBLayout implements h2d.Text.ITextPos{
	var t : TextBatch;

	public inline function new(t:h2d.TextBatch) {
		this.t = t;
	}

	public inline function reset() {
		var te = @:privateAccess t.elements;
		if ( te.length <= 0 ) return;
		for ( e in @:privateAccess te)
			e.remove();
		@:privateAccess t.elements.splice(0,t.elements.length);
	}

	public inline function add(x:Int , y:Int, tile:h2d.Tile) {
		//skip
		if ( tile.innerTex == null)
			return;

		#if debug
		if ( tile.getTexture() != t.getTexture())
			throw "master texture assert";
		#end

		var es = @:privateAccess t.elements;
		if(t.dropShadow != null) {
			var d = t.dropShadow;
			var e = t.sp.alloc(tile);
			es.push(e);
			e.x = t.x + ((x + d.dx) * t.scaleX);
			e.y = t.y + ((y + d.dy) * t.scaleY);
			e.tile = tile;
			e.color.setColor( d.color  );
			e.color.a = t.alpha * d.alpha;
			e.scaleX = t.scaleX;
			e.scaleY = t.scaleY;
		}

		var e = t.sp.alloc(tile);
		es.push(e);
		e.x = x* t.scaleX + t.x;
		e.y = y * t.scaleY + t.y;
		e.scaleX = t.scaleX;
		e.scaleY = t.scaleY;
		e.tile = tile;
		e.color.setColor( t.textColor );
		e.color.a = t.alpha;
	}
}

/**
 * Allow heavy text rendering with adding some minor constraints
 * scale and rot are do not make sense
 * init is usually faster and whold code generates a lot less draw calls
 */
@:allow(h2d.TextBatch.TBLayout)
class TextBatch implements IText {
	public var font(default,null) 		: Font;
	public var sp 						: h2d.SpriteBatch;

	public var text(default, set) 		: String;

	//only lower bits rgb significant
	public var textColor(default, set) 	: Int;
	public var maxWidth(default, set) 	: Null<Float>;
	public var dropShadow(default,set)	: Null<{ dx : Float, dy : Float, color : Int, alpha : Float }>;

	public var textWidth(get, null) 		: Int;
	public var textHeight(get, null)	 	: Int;
	public var textAlign(default, set) 		: h2d.Text.Align;
	public var letterSpacing(default,set) 	: Int;
	public var lineSpacing(default, set) 	: Int;

	var elements : Array<BatchElement>=[];
	var layout : TBLayout;

	public var x(default,set) 	: Float = 0.0;
	public var y(default, set)	: Float = 0.0;

	public var alpha(default, set)	:Float = 1.0;
	public var scaleX(default, set) : Float = 1.0;
	public var scaleY(default, set) : Float = 1.0;
	public var visible(default, set) : Bool = true;

	public function new(font:h2d.Font, master:SpriteBatch) {
		this.font = font;
		this.sp = master;
		sp.hasVertexColor = true;
		layout = new TBLayout(this);

		textAlign = Left;
		letterSpacing = 1;
		text = "";
		textColor = 0xFFFFFF;
		alpha = 1.0;
	}

	public inline function getTexture() return sp.tile.getTexture();

	public inline function nbQuad() {
		return dropShadow == null ? text.length : text.length * 2;
	}

	inline function set_scaleX(v) 	{
		scaleX = v;
		rebuild();
		return v;
	}

	inline function set_scaleY(v) {
		scaleY = v;
		rebuild();
		return scaleY;
	}

	inline function set_dropShadow(v) 	{
		dropShadow = v;
		rebuild();
		return v;
	}

	inline function set_visible(v) 	{
		visible = v;
		for ( i in 0...elements.length)
			elements[i].visible = v;
		return v;
	}

	inline function set_alpha(v:Float) 	{
		alpha = v;
		var hasDropShadow = dropShadow != null;
		var i = 0;
		for ( i in 0...elements.length) {
			var e = elements[i];
			if( !hasDropShadow)
				e.alpha = v;
			else
				e.alpha = ( (i & 1) == 0 )?(dropShadow.alpha * alpha):alpha;
		}
		return v;
	}

	inline function set_x(v:Float) {
		var ox = x;
		x = v;
		if( elements.length>0 )
		for ( e in elements)
			e.x += x-ox;
		return x;
	}

	inline function set_y(v:Float) {
		var oy = y;
		y = v;

		if( elements.length>0 )
		for ( e in elements)
			e.y += y-oy;
		return y;
	}

	public inline function traverse( f : BatchElement -> Void ) {
		for ( e in elements)
			f(e);
	}

	function set_text(t:String) {
		var t = t == null ? "null" : t;
		if( t == this.text ) return t;
		this.text = t;
		rebuild();
		return t;
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

	public
	function rebuild() {
		if ( text != null && font != null ) {
			var r = initGlyphs(text);
			tWidth = r.x;
			tHeight = r.y;
		}
	}

	function initGlyphs( text : String, rebuild = true, lines : Array<Int> = null ) : h2d.col.PointInt {
		var info = new h2d.Text.TextLayoutInfos(textAlign, maxWidth, lineSpacing, letterSpacing);
		return @:privateAccess h2d.Text._initGlyphs( layout, font, info, text, rebuild, lines);
	}

	var tHeight : Null<Int> = null;
	function get_textHeight() : Int {
		if ( tHeight != null) return tHeight;
		var r = initGlyphs(text, false);
		tWidth = r.x;
		tHeight = r.y;
		return tHeight;
	}

	var tWidth : Null<Int> = null;
	function get_textWidth() : Int {
		if ( tWidth != null) return tWidth;
		var r = initGlyphs(text, false);
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
		var hasDropShadow = dropShadow != null;
		if ( !hasDropShadow) {
			for ( e in elements) {
				e.color.setColor( textColor );
				e.color.a = alpha;
			}
		}
		else {
			for ( i in 0...elements.length) {
				var e = elements[i];
				if ( (i & 1) == 0 ) {
					e.color.setColor( dropShadow.color);
					e.color.a = dropShadow.alpha * alpha;
				}
				else {
					e.color.setColor( textColor  );
					e.color.a = alpha;
				}
			}
		}
		return c;
	}

	public inline function isDisposed() return elements==null;

	public function dispose() {
		for(e in elements)
			e.remove();
		elements = null;

		font = null;
		sp = null;
		layout = null;
	}

}