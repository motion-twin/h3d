package h2d;

import haxe.Utf8;
import hxd.System;


class Text extends Drawable {

	public var font(default, set) : Font;
	
	public var text(default, set) : String;
	
	public var textColor(default, set) : Int;
	public var maxWidth(default, set) : Null<Float>;
	public var dropShadow : { dx : Float, dy : Float, color : Int, alpha : Float };
	
	public var textWidth(get, null) : Int;
	public var textHeight(get, null) : Int;
	public var letterSpacing : Int;
	
	/**
	 * Glyph is stored as child
	 */
	var glyphs : TileGroup;
	
	public function new( font : Font, ?parent ) {
		super(parent);
		this.font = font;
		text = "";
		textColor = 0xFFFFFF;
		letterSpacing = 1;
	}
	
	function set_font(font) {
		this.font = font;
		if( glyphs != null ) glyphs.remove();
		glyphs = new TileGroup(font == null ? null : font.tile, this);
		shader = glyphs.shader;
		this.text = text;
		return font;
	}
	
	override function onAlloc() {
		super.onAlloc();
		if( text != null && font != null ) initGlyphs(text);
	}
	
	override function draw(ctx:RenderContext) {
		glyphs.blendMode = blendMode;
		if( dropShadow != null ) {
			glyphs.x += dropShadow.dx;
			glyphs.y += dropShadow.dy;
			glyphs.calcAbsPos();
			var old = glyphs.color;
			glyphs.color = h3d.Vector.fromColor(dropShadow.color);
			glyphs.color.w = dropShadow.alpha;
			glyphs.draw(ctx);
			glyphs.x -= dropShadow.dx;
			glyphs.y -= dropShadow.dy;
			glyphs.color = old;
		}
		super.draw(ctx);
	}
	
	
	override function getMyBounds() {
		var m = getPixSpaceMatrix(null,null);
		var bounds = h2d.col.Bounds.fromValues(0,0, textWidth,textHeight);
		bounds.transform( m );
		return bounds;
	}
	
	function set_text(t) {
		this.text = t == null ? "null" : t;
		if( allocated && font != null ) initGlyphs(text);
		return t;
	}
	
	public function calcTextWidth( text : String ) {
		return initGlyphs(text,false).width;
	}

	function initGlyphs( text : String, rebuild = true ) {
		if( rebuild ) glyphs.reset();
		var x = 0, y = 0, xMax = 0, prevChar = -1;
		
		//todo optimize to iter
		for( i in 0...Utf8.length(text) ) {
			var cc = Utf8.charCodeAt( text,i );
			var e = font.getChar(cc);
			var newline = cc == '\n'.code;
			var esize = e.width + e.getKerningOffset(prevChar);
			// if the next word goes past the max width, change it into a newline
			if( font.charset.isBreakChar(cc) && maxWidth != null ) {
				var size = x + esize + letterSpacing;
				var k = i + 1, max = text.length;
				var prevChar = prevChar;
				while( size <= maxWidth && k < text.length ) {
					var cc = Utf8.charCodeAt(text,k++);
					if( font.charset.isSpace(cc) || cc == '\n'.code ) break;
					var e = font.getChar(cc);
					size += e.width + letterSpacing + e.getKerningOffset(prevChar);
					prevChar = cc;
				}
				if( size > maxWidth ) {
					newline = true;
					if( font.charset.isSpace(cc) ) e = null;
				}
			}
			if( e != null ) {
				if( rebuild ) glyphs.add(x, y, e.t);
				x += esize + letterSpacing;
			}
			if( newline ) {
				if( x > xMax ) xMax = x;
				x = 0;
				y += font.lineHeight;
				prevChar = -1;
			} else
				prevChar = cc;
		}
		return { width : x > xMax ? x : xMax, height : x > 0 ? y + font.lineHeight : y };
	}
	
	function get_textHeight() {
		return initGlyphs(text,false).height;
	}
	
	function get_textWidth() {
		return initGlyphs(text,false).width;
	}
	
	function set_maxWidth(w) {
		maxWidth = w;
		this.text = text;
		return w;
	}
	
	function set_textColor(c) {
		this.textColor = c;
		glyphs.color = h3d.Vector.fromColor(c);
		glyphs.color.w = alpha;
		return c;
	}

}